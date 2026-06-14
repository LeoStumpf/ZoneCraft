import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/subspace.dart';

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

  group('subspaceRegion', () {
    final corners = <LatLng>[
      const LatLng(0.2, -0.2),
      const LatLng(0.2, 0.2),
      const LatLng(-0.2, 0.2),
      const LatLng(-0.2, -0.2),
    ];

    test('outer cell matches "main is the closest of N" geodesically', () {
      const main = LatLng(0, 0);
      const others = <LatLng>[
        LatLng(0, 0.12), // east
        LatLng(0, -0.12), // west
        LatLng(0.12, 0), // north
        LatLng(-0.12, 0), // south
      ];
      final r = subspaceRegion(
        main: main,
        others: others,
        bandMeters: 0,
        viewportCorners: corners,
      );
      expect(r.outer.length, greaterThanOrEqualTo(3));

      var checked = 0;
      for (var gi = 1; gi < 12; gi++) {
        for (var gj = 1; gj < 12; gj++) {
          final p = LatLng(-0.18 + 0.36 * gi / 12, -0.18 + 0.36 * gj / 12);
          final dMain = distance(p, main);
          var dOther = double.infinity;
          for (final o in others) {
            final d = distance(p, o);
            if (d < dOther) dOther = d;
          }
          if ((dMain - dOther).abs() < 2000) continue; // near a divide
          expect(inside(r.outer, p), dMain < dOther,
              reason: 'at $p  dMain=$dMain dOther=$dOther');
          checked++;
        }
      }
      expect(checked, greaterThan(20));
    });

    test('band never engulfs a neighbouring point (clamped per bisector)', () {
      // Two points ~2.2 km apart with a huge 100 km band. Unclamped, the outer
      // cell would balloon far past the other point; clamped, the other point
      // must stay outside the main point's region.
      const main = LatLng(0, 0);
      const others = <LatLng>[LatLng(0, 0.02)]; // ~2.2 km east
      final r = subspaceRegion(
        main: main,
        others: others,
        bandMeters: 100000, // 100 km, dwarfs the 2.2 km gap
        viewportCorners: corners,
      );
      // Clamped, the cell stops at the neighbour: a point just *past* it is out.
      expect(inside(r.outer, const LatLng(0, 0.024)), isFalse,
          reason: 'the cell must not extend past the neighbouring site');
      expect(inside(r.outer, main), isTrue);
    });

    test('far points beyond the nearest-N cap do not change a tight cell', () {
      // Four close neighbours define a tiny cell; add many far points that
      // (being masked) must not alter it once the cap drops them.
      const main = LatLng(0, 0);
      final near = <LatLng>[
        const LatLng(0, 0.01),
        const LatLng(0, -0.01),
        const LatLng(0.01, 0),
        const LatLng(-0.01, 0),
      ];
      final far = <LatLng>[
        for (var i = 0; i < 60; i++) LatLng(0.15, -0.15 + 0.005 * i),
      ];
      final justNeighbours = subspaceRegion(
        main: main, others: near, bandMeters: 0, viewportCorners: corners);
      final withFar = subspaceRegion(
        main: main, others: [...near, ...far], bandMeters: 0,
        viewportCorners: corners);
      // The tiny cell is unchanged: a sample just inside stays inside both.
      const probe = LatLng(0.002, 0.002);
      expect(inside(justNeighbours.outer, probe),
          inside(withFar.outer, probe));
    });

    test('empty when there are no other points', () {
      final r = subspaceRegion(
        main: const LatLng(0, 0),
        others: const <LatLng>[],
        bandMeters: 0,
        viewportCorners: corners,
      );
      expect(r.outer, isEmpty);
      expect(r.core, isEmpty);
    });

    test('coincident point yields empty rings', () {
      final r = subspaceRegion(
        main: const LatLng(0, 0),
        others: const <LatLng>[LatLng(0, 0)],
        bandMeters: 0,
        viewportCorners: corners,
      );
      expect(r.outer, isEmpty);
      expect(r.core, isEmpty);
    });
  });
}
