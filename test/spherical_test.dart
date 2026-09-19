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
      expect(cell.outer, hasLength(1));
      expect(_inside(cell.outer.single, const LatLng(0, -0.1)), isTrue);
      expect(_inside(cell.outer.single, const LatLng(0, 0.1)), isFalse);
    });

    test('a divide that is exactly a meridian is a vertical edge', () {
      // Two points on one parallel: the bisector is the meridian between them,
      // a step in the per-longitude parametrisation. The cell must end at it,
      // not be smeared across a column.
      final cell = sphericalCell(
        main: const LatLng(0, -0.1),
        others: const <LatLng>[LatLng(0, 0.1)],
        bandMeters: 0,
        viewportCorners: corners,
      );
      final ring = cell.core.single;
      final maxLng = ring.map((p) => p.longitude).reduce(max);
      expect(maxLng, closeTo(0, 0.4 / 4096 + 1e-9));
      expect(_inside(ring, const LatLng(0.15, -0.001)), isTrue);
      expect(_inside(ring, const LatLng(0.15, 0.001)), isFalse);
    });

    test('a steep divide is traced, not cut across', () {
      // Nearly the same latitude: the great circle is almost a meridian, so
      // the divide climbs through the box within a sliver of longitude. Every
      // point of the ring's divide edge must still lie on the true bisector.
      const main = LatLng(20, 0);
      const other = LatLng(20.001, 0.2);
      final cell = sphericalCell(
        main: main,
        others: const [other],
        bandMeters: 0,
        viewportCorners: const [
          LatLng(30, -10),
          LatLng(30, 10),
          LatLng(10, 10),
          LatLng(10, -10),
        ],
      );
      final ring = cell.core.single;
      var onDivide = 0;
      for (final p in ring) {
        final onBox =
            p.latitude == 30 ||
            p.latitude == 10 ||
            p.longitude == -10 ||
            p.longitude == 10;
        if (onBox) continue;
        onDivide++;
        final dm = distance(main, p), dOther = distance(other, p);
        expect((dm - dOther).abs(), lessThan(50), reason: 'vertex $p');
      }
      expect(onDivide, greaterThan(8));
    });

    test('the world-wide box yields the hemisphere in two seam pieces', () {
      // A world box (continuous longitudes, Mercator-clamped latitudes) cuts
      // a hemisphere whose divide leaves through the top and bottom edges at
      // the antimeridian seam: one piece at each end of the longitude range.
      // Both must come back. Two points on one parallel make the divide a
      // meridian pair, the sharpest such case.
      const main = LatLng(48.0, 11.9);
      const other = LatLng(48.0, 11.7);
      final cell = sphericalCell(
        main: main,
        others: const [other],
        bandMeters: 0,
        viewportCorners: const [
          LatLng(85.05, -179.99),
          LatLng(85.05, 179.99),
          LatLng(-85.05, 179.99),
          LatLng(-85.05, -179.99),
        ],
      );
      expect(cell.core, hasLength(2));
      bool inAny(LatLng q) => cell.core.any((r) => _inside(r, q));
      // Main's cell is the lune east of 11.8 up to −168.2: both sides of the
      // seam, and nothing west of the divide.
      expect(inAny(const LatLng(-40, 60)), isTrue);
      expect(inAny(const LatLng(-30, 170)), isTrue); // near New Zealand
      expect(inAny(const LatLng(-30, -175)), isTrue); // across the seam
      expect(inAny(const LatLng(60, 11.7)), isFalse); // closer to other
      expect(inAny(const LatLng(-40, -60)), isFalse);
      expect(inAny(const LatLng(80, -160)), isFalse);
      for (final r in cell.core) {
        for (var i = 0; i < r.length; i++) {
          final a = r[i], b = r[(i + 1) % r.length];
          expect((a.longitude - b.longitude).abs(), lessThan(180));
        }
      }
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
    final intersect =
        (yi > q.latitude) != (yj > q.latitude) &&
        q.longitude < (xj - xi) * (q.latitude - yi) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}
