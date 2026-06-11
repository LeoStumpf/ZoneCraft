import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/spherical.dart';

void main() {
  const distance = Distance(calculator: Haversine());

  group('ecef / toLatLng', () {
    test('round-trips a range of points', () {
      const samples = <LatLng>[
        LatLng(0, 0),
        LatLng(45, 90),
        LatLng(-30, -120),
        LatLng(70, 179),
        LatLng(-60, -1),
      ];
      for (final p in samples) {
        final back = toLatLng(ecef(p));
        expect(back.latitude, closeTo(p.latitude, 1e-9));
        expect(back.longitude, closeTo(p.longitude, 1e-9));
      }
    });

    test('ecef returns a unit vector', () {
      expect(ecef(const LatLng(33, 21)).length, closeTo(1.0, 1e-12));
    });
  });

  group('slerp', () {
    test('midpoint is the geodesic midpoint', () {
      const a = LatLng(10, 20);
      const b = LatLng(14, 26);
      final mid = toLatLng(slerp(ecef(a), ecef(b), 0.5));
      final da = distance(a, mid);
      final db = distance(mid, b);
      expect(da, closeTo(db, 1e-3)); // equidistant
      expect(da + db, closeTo(distance(a, b), 1e-3)); // on the arc
    });
  });

  group('densifyRing', () {
    test('emits segments points per edge and stays finite', () {
      final ring = <Vec3>[
        ecef(const LatLng(1, -1)),
        ecef(const LatLng(1, 1)),
        ecef(const LatLng(-1, 0)),
      ];
      final out = densifyRing(ring, segments: 8);
      expect(out.length, 3 * 8);
      expect(out.every((p) => p.latitude.isFinite && p.longitude.isFinite),
          isTrue);
    });

    test('returns empty for a degenerate ring', () {
      expect(densifyRing(<Vec3>[ecef(const LatLng(0, 0))]), isEmpty);
    });
  });

  group('bandThreshold', () {
    test('is zero for no band and sin(d/R) otherwise', () {
      expect(bandThreshold(0), 0);
      expect(bandThreshold(-5), 0);
      expect(bandThreshold(500), closeTo(sin(500 / earthRadius), 1e-15));
    });
  });

  group('sphericalCell', () {
    final corners = <LatLng>[
      const LatLng(0.2, -0.2),
      const LatLng(0.2, 0.2),
      const LatLng(-0.2, 0.2),
      const LatLng(-0.2, -0.2),
    ];

    test('empty when there are no other points', () {
      final cell = sphericalCell(
        main: const LatLng(0, 0),
        others: const <LatLng>[],
        bandMeters: 0,
        viewportCorners: corners,
      );
      expect(cell.outer, isEmpty);
      expect(cell.core, isEmpty);
    });

    test('outer cell holds the side closer to main', () {
      final cell = sphericalCell(
        main: const LatLng(0, -0.1),
        others: const <LatLng>[LatLng(0, 0.1)],
        bandMeters: 0,
        viewportCorners: corners,
      );
      expect(_inside(cell.outer, const LatLng(0, -0.1)), isTrue);
      expect(_inside(cell.outer, const LatLng(0, 0.1)), isFalse);
    });
  });
}

/// Ray-cast point-in-polygon on lat/lng (x=lng, y=lat). Adequate for the small,
/// dateline/pole-free polygons in these tests.
bool _inside(List<LatLng> poly, LatLng q) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i].longitude, yi = poly[i].latitude;
    final xj = poly[j].longitude, yj = poly[j].latitude;
    final intersect = (yi > q.latitude) != (yj > q.latitude) &&
        q.longitude < (xj - xi) * (q.latitude - yi) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}
