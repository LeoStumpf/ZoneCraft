import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/height.dart';

/// Builds a constant-elevation Terrarium PNG tile ([elevation] m).
Uint8List _flatTile(int elevation) {
  final v = elevation + 32768;
  final r = v ~/ 256;
  final g = v % 256;
  final image = img.Image(width: 256, height: 256);
  img.fill(image, color: img.ColorRgb8(r, g, 0));
  return img.encodePng(image);
}

/// Assembles a [HeightGenRequest] over [centerLat]/[centerLng]/[radius] whose
/// covering tiles all encode the same flat [elevation].
HeightGenRequest _flatRequest({
  required double centerLat,
  required double centerLng,
  required double radius,
  required int elevation,
  required double threshold,
  required bool above,
  int z = 14,
}) {
  final box = heightTileBox(centerLat, centerLng, radius, z);
  final bytes = _flatTile(elevation);
  final tileX = <int>[];
  final tileY = <int>[];
  final tileBytes = <Uint8List>[];
  for (var x = box.minX; x <= box.maxX; x++) {
    for (var y = box.minY; y <= box.maxY; y++) {
      tileX.add(x);
      tileY.add(y);
      tileBytes.add(bytes);
    }
  }
  return HeightGenRequest(
    tileX: tileX,
    tileY: tileY,
    tileBytes: tileBytes,
    sampleZoom: z,
    centerLat: centerLat,
    centerLng: centerLng,
    radiusMeters: radius,
    thresholdMeters: threshold,
    aboveThreshold: above,
  );
}

bool _pointInRing(LatLng p, List<double> flat) {
  var inside = false;
  final n = flat.length ~/ 2;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final yi = flat[i * 2], xi = flat[i * 2 + 1];
    final yj = flat[j * 2], xj = flat[j * 2 + 1];
    if (((yi > p.latitude) != (yj > p.latitude)) &&
        (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  return inside;
}

void main() {
  const centerLat = 47.42, centerLng = 10.98, radius = 400.0;

  test('all terrain above threshold fills the bounded circle', () {
    final rings = buildHeightRings(_flatRequest(
      centerLat: centerLat,
      centerLng: centerLng,
      radius: radius,
      elevation: 1000,
      threshold: 500,
      above: true,
    ));
    expect(rings, isNotEmpty);
    // The fill encloses the centre…
    expect(rings.any((r) => _pointInRing(const LatLng(centerLat, centerLng), r)),
        isTrue);
    // …and stays within ~the circle (no vertex far outside the radius).
    const dist = Distance(calculator: Haversine());
    for (final ring in rings) {
      for (var i = 0; i + 1 < ring.length; i += 2) {
        final d = dist.as(LengthUnit.Meter,
            const LatLng(centerLat, centerLng), LatLng(ring[i], ring[i + 1]));
        expect(d, lessThan(radius * 1.25));
      }
    }
  });

  test('terrarium decode is correct (1000 m flat, below 500 => empty)', () {
    final rings = buildHeightRings(_flatRequest(
      centerLat: centerLat,
      centerLng: centerLng,
      radius: radius,
      elevation: 1000,
      threshold: 500,
      above: false,
    ));
    expect(rings, isEmpty);
  });

  test('elevationFromTilePng decodes the pixel under a point', () {
    const z = 14;
    final x = terrariumTileX(centerLng, z);
    final y = terrariumTileY(centerLat, z);
    final e = elevationFromTilePng(
        _flatTile(1234), z, x, y, centerLat, centerLng);
    expect(e, isNotNull);
    expect(e!.round(), 1234);
  });

  test('all terrain below threshold (above=true) yields no fill', () {
    final rings = buildHeightRings(_flatRequest(
      centerLat: centerLat,
      centerLng: centerLng,
      radius: radius,
      elevation: 100,
      threshold: 500,
      above: true,
    ));
    expect(rings, isEmpty);
  });
}
