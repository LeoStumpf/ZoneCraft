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
  for (var x = box.minX; x <= box.maxX; x++) {
    for (var y = box.minY; y <= box.maxY; y++) {
      final url = terrariumTileUrl(z, x, y);
      Uint8List? bytes = await repo.getTile(url);
      if (bytes == null) {
        try {
          final resp = await client.get(Uri.parse(url), headers: headers);
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            bytes = resp.bodyBytes;
            await repo.putTile(url, bytes);
          }
        } catch (_) {
          // Offline / server error: leave this tile missing (sea level).
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
