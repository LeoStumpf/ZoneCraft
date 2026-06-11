import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/freearea.dart';

void main() {
  const distance = Distance(calculator: Haversine());

  // Planar signed-area magnitude in lat/lng degrees — only used for relative
  // size comparisons here.
  double area(List<LatLng> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      final q = p[i];
      final r = p[(i + 1) % p.length];
      a += q.longitude * r.latitude - r.longitude * q.latitude;
    }
    return a.abs() / 2;
  }

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

  // A ~4 km box centred on (60°N, 0°).
  const box = <LatLng>[
    LatLng(60.02, -0.02),
    LatLng(60.02, 0.02),
    LatLng(59.98, 0.02),
    LatLng(59.98, -0.02),
  ];

  test('no offset / no band leaves the ring unchanged', () {
    final r = freeAreaRegion(ring: box, offsetMeters: 0, bandMeters: 0);
    expect(r.outer.length, box.length);
    for (var i = 0; i < box.length; i++) {
      expect(r.outer[i].latitude, closeTo(box[i].latitude, 1e-9));
      expect(r.outer[i].longitude, closeTo(box[i].longitude, 1e-9));
    }
    expect(area(r.core), closeTo(area(box), 1e-12));
  });

  test('band: outer grows and core shrinks relative to the ring', () {
    final r = freeAreaRegion(ring: box, offsetMeters: 0, bandMeters: 500);
    expect(area(r.outer), greaterThan(area(box)));
    expect(area(r.core), lessThan(area(box)));
    // Core vertices sit inside the original ring; outer vertices outside it.
    expect(r.core.every((v) => inside(box, v)), isTrue);
    expect(r.outer.every((v) => !inside(box, v)), isTrue);
  });

  test('positive offset moves each vertex inward by ~offsetMeters', () {
    final r = freeAreaRegion(ring: box, offsetMeters: 1000, bandMeters: 0);
    expect(r.outer.length, box.length);
    for (var i = 0; i < box.length; i++) {
      expect(distance(box[i], r.outer[i]), closeTo(1000, 30));
      expect(inside(box, r.outer[i]), isTrue); // moved into the interior
    }
  });

  test('over-large inset collapses to empty', () {
    // 100 km inset on a ~4 km box cannot survive.
    final r = freeAreaRegion(ring: box, offsetMeters: 100000, bandMeters: 0);
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });
}
