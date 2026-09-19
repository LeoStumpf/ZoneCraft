// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
      final intersect =
          (yi > q.latitude) != (yj > q.latitude) &&
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
      expect(r.outer.single.length, greaterThanOrEqualTo(3));

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
          expect(
            inside(r.outer.single, p),
            dMain < dOther,
            reason: 'at $p  dMain=$dMain dOther=$dOther',
          );
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
        main: main,
        others: others,
        bandMeters: 500,
        viewportCorners: corners,
      );
      // Just inside the divide (main's side) is solid core.
      expect(inside(r.core.single, const LatLng(0, 0.009)), isTrue);
      // Just past the divide is in the band (outer) but NOT the solid core.
      expect(inside(r.core.single, const LatLng(0, 0.011)), isFalse);
      expect(inside(r.outer.single, const LatLng(0, 0.011)), isTrue);
      // Well past the band (~600 m) is outside the cell entirely.
      expect(inside(r.outer.single, const LatLng(0, 0.016)), isFalse);
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
        final east = r.outer.single
            .map((p) => p.longitude)
            .reduce((a, b) => a > b ? a : b);
        return east - otherLng / 2;
      }

      final near = bandReach(0.02); // divide ~1.1 km out
      final far = bandReach(0.08); // divide ~4.4 km out
      expect(
        near,
        closeTo(far, 1e-4),
        reason: 'band reach must not depend on neighbour distance',
      );
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
        main: main,
        others: near,
        bandMeters: 0,
        viewportCorners: corners,
      );
      final withFar = subspaceRegion(
        main: main,
        others: [...near, ...far],
        bandMeters: 0,
        viewportCorners: corners,
      );
      // The tiny cell is unchanged: a sample just inside stays inside both.
      const probe = LatLng(0.002, 0.002);
      expect(
        inside(justNeighbours.outer.single, probe),
        inside(withFar.outer.single, probe),
      );
    });

    test('bandInward puts the band inside the divide (for inverted layers)', () {
      // Inverted: the divide is unchanged but the band shrinks the cell inward,
      // so `outer` is the strict cell and `core` is it pulled ~500 m toward main.
      const main = LatLng(0, 0);
      const others = <LatLng>[LatLng(0, 0.02)]; // divide ~1.1 km east
      final r = subspaceRegion(
        main: main,
        others: others,
        bandMeters: 500,
        viewportCorners: corners,
        bandInward: true,
      );
      // `outer` is the strict cell: the divide hasn't moved.
      expect(inside(r.outer.single, const LatLng(0, 0.009)), isTrue);
      expect(inside(r.outer.single, const LatLng(0, 0.011)), isFalse);
      // `core` is shrunk inward: a point just inside the divide is now in the
      // band (outer, not core); only deeper inside is core (the uncoloured hole).
      expect(inside(r.core.single, const LatLng(0, 0.009)), isFalse);
      expect(inside(r.core.single, const LatLng(0, 0.003)), isTrue);
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

  group('subspaceRegion at world zoom', () {
    // The whole drawable world, as the painter's bound hands it in: the
    // Mercator-clamped box with continuous longitudes. Two points 25 km apart
    // near Munich; the "closer to main" cell is then (nearly) a hemisphere.
    const main = LatLng(48.0, 11.7);
    const other = LatLng(48.2, 11.9);
    const world = <LatLng>[
      LatLng(85.05, -179.99),
      LatLng(85.05, 179.99),
      LatLng(-85.05, 179.99),
      LatLng(-85.05, -179.99),
    ];

    bool closerToMain(LatLng q) =>
        distance.as(LengthUnit.Meter, main, q) <
        distance.as(LengthUnit.Meter, other, q);

    bool inAny(List<List<LatLng>> rings, LatLng q) =>
        rings.any((r) => inside(r, q));

    // No edge may jump a world — except a run along the box's top or bottom,
    // which legitimately spans it when the cell holds a pole.
    void expectContinuous(List<List<LatLng>> rings) {
      for (final ring in rings) {
        for (var i = 0; i < ring.length; i++) {
          final a = ring[i], b = ring[(i + 1) % ring.length];
          expect(a.latitude.isFinite && a.longitude.isFinite, isTrue);
          if (a.latitude == b.latitude && a.latitude.abs() == 85.05) continue;
          expect(
            (a.longitude - b.longitude).abs(),
            lessThan(180),
            reason: 'edge $i jumps a world',
          );
        }
      }
    }

    test('the cell is the hemisphere closer to main, not a sliver', () {
      final r = subspaceRegion(
        main: main,
        others: const [other],
        bandMeters: 0,
        viewportCorners: world,
      );
      expect(r.core.fold(0, (n, ring) => n + ring.length), greaterThan(100));
      expectContinuous(r.core);
      // Far away on both sides of the divide, where the old four-corner quad
      // (folded over the pole by the inflation) drew nothing or a strip.
      const sw = LatLng(30, -20); // Canaries: closer to main
      const ne = LatLng(60, 40); // Russia: closer to other
      const far = LatLng(-40, -60); // Patagonia: closer to main
      expect(closerToMain(sw), isTrue);
      expect(closerToMain(far), isTrue);
      expect(closerToMain(ne), isFalse);
      expect(inAny(r.core, sw), isTrue);
      expect(inAny(r.core, far), isTrue);
      expect(inAny(r.core, ne), isFalse);
    });

    test('a bound centred on the Pacific yields rings in its own frame', () {
      // The bound a camera at lng 175 builds: −5…355 in continuous degrees.
      const pacific = <LatLng>[
        LatLng(85.05, -4.99),
        LatLng(85.05, 354.99),
        LatLng(-85.05, 354.99),
        LatLng(-85.05, -4.99),
      ];
      final r = subspaceRegion(
        main: main,
        others: const [other],
        bandMeters: 500,
        viewportCorners: pacific,
      );
      expectContinuous(r.core);
      expectContinuous(r.outer);
      for (final ring in r.core) {
        for (final p in ring) {
          expect(p.longitude, inInclusiveRange(-5.01, 355.01));
        }
      }
      // Munich itself, in that frame, and the far side of the divide.
      expect(inAny(r.core, const LatLng(48.05, 11.6)), isTrue);
      expect(inAny(r.core, const LatLng(48.2, 11.95)), isFalse);
      // The antimeridian is mid-frame here: nothing special happens there.
      // (These are on other's side — the divide, a great circle, passes
      // between Munich's antipode and them.)
      expect(closerToMain(const LatLng(-30, 170)), isFalse);
      expect(inAny(r.core, const LatLng(-30, 170)), isFalse);
      expect(inAny(r.core, const LatLng(-30, 190)), isFalse);
      // ...and Patagonia, in this frame at lng 300, is on main's side.
      expect(inAny(r.core, const LatLng(-40, 300)), isTrue);
    });

    test('the band still hugs the divide across the whole world', () {
      final r = subspaceRegion(
        main: main,
        others: const [other],
        bandMeters: 20000,
        viewportCorners: world,
        bandInward: true,
      );
      // Outer is the strict cell, core is shrunk by 20 km: a point 5 km on
      // main's side of the divide is in outer but not core.
      final mid = LatLng(
        (main.latitude + other.latitude) / 2,
        (main.longitude + other.longitude) / 2,
      );
      final nearMain = distance.offset(mid, 5000, -135);
      expect(inAny(r.outer, nearMain), isTrue);
      expect(inAny(r.core, nearMain), isFalse);
      expect(inAny(r.core, distance.offset(mid, 40000, -135)), isTrue);
    });
  });
}
