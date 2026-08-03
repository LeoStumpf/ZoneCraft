import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../geo/height.dart';
import 'database.dart';
import 'repository.dart';

/// Orchestrates one height-region generation: enumerate the covering Terrarium
/// terrain tiles, fetch them cache-first (reusing the shared tile cache), run
/// the CPU-heavy contouring in an isolate, then store the result polygons.
///
/// Throws [HeightGenException] with a user-facing message on a too-large area or
/// when required tiles can't be fetched (offline / server error).
class HeightGenException implements Exception {
  HeightGenException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HeightGenResult {
  const HeightGenResult(this.polygonCount, this.fetchedTiles, this.missingTiles);
  final int polygonCount;
  final int fetchedTiles;
  final int missingTiles;
}

/// How long one terrain tile gets before it is treated as unavailable.
///
/// `package:http` has **no** default timeout, so a stalled connection (captive
/// portal, a mobile handoff, a wedged CDN edge) never completes and never
/// errors. Without this the elevation probe's spinner runs forever and the
/// height "Generate" button can never be pressed again.
const Duration kTerrainTileTimeout = Duration(seconds: 15);

/// Overall budget for one [generateHeightRegion] run. Per-tile timeouts alone
/// are not enough: [heightMaxTiles] is 80, so 80 slow-but-not-timing-out tiles
/// could otherwise add up to twenty minutes behind a modal dialog. Once the
/// budget is spent the remaining tiles count as missing, and the contouring
/// runs on what did arrive.
const Duration kHeightGenBudget = Duration(seconds: 90);

/// Looks up the terrain elevation (metres) at [lat]/[lng] from the single
/// Terrarium tile covering it (cache-first, then network). Returns null when the
/// tile can't be fetched (offline) or decoded. Used by the map elevation probe
/// and the current-position readout.
Future<double?> queryElevation({
  required Repository repo,
  required http.Client client,
  required double lat,
  required double lng,
  int z = 13,
  Map<String, String> headers = const {},
}) async {
  final x = terrariumTileX(lng, z);
  final y = terrariumTileY(lat, z);
  final url = terrariumTileUrl(z, x, y);
  Uint8List? bytes = await repo.getTile(url);
  if (bytes == null) {
    try {
      final resp = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(kTerrainTileTimeout);
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        bytes = resp.bodyBytes;
        await repo.putTile(url, bytes);
      }
    } catch (_) {
      // Offline, server error, or the tile took longer than we're willing to
      // make the caller's spinner wait.
      return null;
    }
  }
  if (bytes == null) return null;
  return elevationFromTilePng(bytes, z, x, y, lat, lng);
}

Future<HeightGenResult> generateHeightRegion({
  required Repository repo,
  required http.Client client,
  required HeightRegion region,
  Map<String, String> headers = const {},
}) async {
  if (!region.radiusMeters.isFinite || region.radiusMeters <= 0) {
    throw HeightGenException('Set a positive radius first');
  }
  if (region.radiusMeters > heightMaxRadiusMeters) {
    throw HeightGenException(
        'Area too large — keep the radius under '
        '${(heightMaxRadiusMeters / 1000).round()} km');
  }
  final z = region.sampleZoom;
  final box = heightTileBox(
      region.centerLat, region.centerLng, region.radiusMeters, z);
  if (box.count > heightMaxTiles) {
    throw HeightGenException(
        'Area too detailed (${box.count} tiles) — lower the resolution or '
        'shrink the radius');
  }

  final tileX = <int>[];
  final tileY = <int>[];
  final tileBytes = <Uint8List>[];
  var missing = 0;
  // Cached tiles stay free after the budget runs out — only the network is cut
  // off — so an area you've generated before still regenerates fully offline.
  final deadline = DateTime.now().add(kHeightGenBudget);
  for (var x = box.minX; x <= box.maxX; x++) {
    for (var y = box.minY; y <= box.maxY; y++) {
      final url = terrariumTileUrl(z, x, y);
      Uint8List? bytes = await repo.getTile(url);
      if (bytes == null && DateTime.now().isBefore(deadline)) {
        try {
          final resp = await client
              .get(Uri.parse(url), headers: headers)
              .timeout(kTerrainTileTimeout);
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            bytes = resp.bodyBytes;
            await repo.putTile(url, bytes);
          }
        } catch (_) {
          // Offline / server error / too slow: leave this tile missing
          // (sea level).
        }
      }
      if (bytes == null) {
        missing++;
      } else {
        tileX.add(x);
        tileY.add(y);
        tileBytes.add(bytes);
      }
    }
  }

  if (tileBytes.isEmpty) {
    throw HeightGenException(
        'Could not fetch elevation data — $missing tiles unavailable '
        '(offline?)');
  }

  final rings = await compute(
    buildHeightRings,
    HeightGenRequest(
      tileX: tileX,
      tileY: tileY,
      tileBytes: tileBytes,
      sampleZoom: z,
      centerLat: region.centerLat,
      centerLng: region.centerLng,
      radiusMeters: region.radiusMeters,
      thresholdMeters: region.thresholdMeters,
      aboveThreshold: region.aboveThreshold,
    ),
  );

  final polygons = <List<LatLng>>[
    for (final flat in rings)
      [
        for (var i = 0; i + 1 < flat.length; i += 2) LatLng(flat[i], flat[i + 1]),
      ],
  ];
  await repo.replaceHeightPolygons(region.id, polygons);
  await repo.markHeightGenerated(region.id);
  return HeightGenResult(polygons.length, tileBytes.length, missing);
}
