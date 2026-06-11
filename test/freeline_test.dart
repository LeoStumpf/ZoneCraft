import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/freeline.dart';

void main() {
  const distance = Distance(calculator: Haversine());

  bool inside(List<LatLng> poly, LatLng q) {
    var hit = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      final intersect = (yi > q.latitude) != (yj > q.latitude) &&
          q.longitude < (xj - xi) * (q.latitude - yi) / (yj - yi) + xi;
      if (intersect) hit = !hit;
    }
    return hit;
  }

  test('returns empty for fewer than two finite points', () {
    final r = freeLineRegion(
      points: const <LatLng>[LatLng(0, 0)],
      offsetMeters: 0,
      bandMeters: 0,
      spanMeters: 20000,
    );
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });

  test('fills the right-hand side of the travel direction', () {
    // West→east at the equator: travel bearing 90°, filled side bearing 180°
    // (south), so points south of the line are inside, north are outside.
    final r = freeLineRegion(
      points: const <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)],
      offsetMeters: 0,
      bandMeters: 0,
      spanMeters: 20000,
    );
    expect(inside(r.outer, const LatLng(-0.02, 0)), isTrue); // south
    expect(inside(r.outer, const LatLng(0.02, 0)), isFalse); // north
  });

  test('offset moves the boundary a constant ground distance at latitude', () {
    // At 60°N the old single-reference pixel scale would mis-size the offset;
    // the geodesic version offsets each vertex by exactly offsetMeters.
    const p0 = LatLng(60, -0.05);
    final r = freeLineRegion(
      points: const <LatLng>[p0, LatLng(60, 0.05)],
      offsetMeters: 1000,
      bandMeters: 0,
      spanMeters: 20000,
    );
    var minD = double.infinity;
    for (final v in r.outer) {
      final d = distance(p0, v);
      if (d < minD) minD = d;
    }
    expect(minD, closeTo(1000, 30));
  });

  test('band makes outer enclose a strictly wider side than core', () {
    final r = freeLineRegion(
      points: const <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)],
      offsetMeters: 0,
      bandMeters: 1000, // half-band 1 km
      spanMeters: 20000,
    );
    // 500 m north of the line: inside the enlarged outer, outside the shrunk core.
    const justNorth = LatLng(0.0045, 0);
    expect(inside(r.outer, justNorth), isTrue);
    expect(inside(r.core, justNorth), isFalse);
  });
}
