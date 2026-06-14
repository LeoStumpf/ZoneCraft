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

    test('core is the strict cell at the divide; band grows outward', () {
      // Main and one other ~2.2 km apart; the divide sits at the ~1.1 km
      // midpoint. With a 500 m band the solid core ends at the divide and the
      // band extends ~500 m past it (toward the other), never further.
      const main = LatLng(0, 0);
      const others = <LatLng>[LatLng(0, 0.02)]; // ~2.2 km east
      final r = subspaceRegion(
        main: main, others: others, bandMeters: 500, viewportCorners: corners);
      // Just inside the divide (main's side) is solid core.
      expect(inside(r.core, const LatLng(0, 0.009)), isTrue);
      // Just past the divide is in the band (outer) but NOT the solid core.
      expect(inside(r.core, const LatLng(0, 0.011)), isFalse);
      expect(inside(r.outer, const LatLng(0, 0.011)), isTrue);
      // Well past the band (~600 m) is outside the cell entirely.
      expect(inside(r.outer, const LatLng(0, 0.016)), isFalse);
    });

    test('band width is fixed, independent of how near the neighbour is', () {
      // Same 500 m band, neighbours at very different distances: the band must
      // extend the same ~500 m past each divide (uniform halo).
      double bandReach(double otherLng) {
        final r = subspaceRegion(
          main: const LatLng(0, 0),
          others: <LatLng>[LatLng(0, otherLng)],
          bandMeters: 500,
          viewportCorners: corners,
        );
        // Outer's eastern extent minus the divide (at otherLng / 2).
        final east =
            r.outer.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
        return east - otherLng / 2;
      }

      final near = bandReach(0.02); // divide ~1.1 km out
      final far = bandReach(0.08); // divide ~4.4 km out
      expect(near, closeTo(far, 1e-4),
          reason: 'band reach must not depend on neighbour distance');
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
