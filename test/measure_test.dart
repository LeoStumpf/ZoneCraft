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
import 'package:zonecraft/geo/measure.dart';

void main() {
  group('polylineLengthMeters', () {
    test('one degree along the equator is ~111 km', () {
      final m = polylineLengthMeters([const LatLng(0, 0), const LatLng(0, 1)]);
      expect(m, closeTo(111319, 111319 * 0.001));
    });

    test('sums every segment', () {
      final m = polylineLengthMeters([
        const LatLng(0, 0),
        const LatLng(0, 1),
        const LatLng(0, 2),
      ]);
      expect(m, closeTo(2 * 111319, 2 * 111319 * 0.001));
    });

    test('fewer than two points is zero', () {
      expect(polylineLengthMeters(const []), 0);
      expect(polylineLengthMeters([const LatLng(48, 11)]), 0);
    });

    test('skips a non-finite point instead of returning NaN', () {
      final m = polylineLengthMeters([
        const LatLng(0, 0),
        LatLng(double.nan, 0.5),
        const LatLng(0, 1),
      ]);
      expect(m, closeTo(111319, 111319 * 0.001));
    });
  });

  group('polygonAreaSquareMeters', () {
    // 0.01° × 0.01° at 48° N: 1113 m tall, 1113 · cos 48° ≈ 745 m wide.
    const square = [
      LatLng(48.00, 11.00),
      LatLng(48.00, 11.01),
      LatLng(48.01, 11.01),
      LatLng(48.01, 11.00),
    ];
    const expected = 1113.2 * 745.0;

    test('a small square at mid latitude', () {
      expect(polygonAreaSquareMeters(square), closeTo(expected, expected * 0.01));
    });

    test('orientation does not matter', () {
      expect(
        polygonAreaSquareMeters(square.reversed.toList()),
        closeTo(polygonAreaSquareMeters(square), 1e-6),
      );
    });

    test('a repeated closing vertex changes nothing', () {
      expect(
        polygonAreaSquareMeters([...square, square.first]),
        closeTo(polygonAreaSquareMeters(square), 1e-6),
      );
    });

    test('fewer than three distinct points is zero', () {
      expect(polygonAreaSquareMeters(const []), 0);
      expect(polygonAreaSquareMeters(square.sublist(0, 2)), 0);
      expect(
        polygonAreaSquareMeters([square[0], square[1], square[0]]),
        0,
      );
    });
  });
}
