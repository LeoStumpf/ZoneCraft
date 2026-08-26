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

import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/ui/transit_import_dialog.dart';

int bit(String key) => transitModeByKey(key)!.bit;

/// Bavaria, the case that motivated a selective import: 511 km across, where
/// train stops are 3 MB and bus stops are 68 MB.
const _bavaria = (south: 47.27, west: 8.97, north: 50.57, east: 13.84);

void main() {
  group('checkBbox', () {
    test('a normal city box is fine for everything', () {
      expect(checkBbox(48.05, 11.35, 48.25, 11.75), BboxVerdict.ok);
    });

    test('unusable numbers are named before anything else', () {
      expect(checkBbox(null, 11.5, 48.2, 11.6), BboxVerdict.malformed);
      expect(checkBbox(double.nan, 11.5, 48.2, 11.6), BboxVerdict.malformed);
      expect(checkBbox(48.2, 11.5, 48.1, 11.6), BboxVerdict.misordered);
      expect(checkBbox(48.1, 11.6, 48.2, 11.5), BboxVerdict.misordered);
    });

    test('an empty selection is refused, not silently imported', () {
      expect(checkBbox(48.05, 11.35, 48.25, 11.75, modeMask: 0),
          BboxVerdict.noModes);
    });

    test('the same box passes for trains and fails for buses', () {
      final b = _bavaria;
      // Trains go through — slowly, hence a warning rather than a refusal:
      // measured at 40 s / 3 MB against the live API.
      expect(
        checkBbox(b.south, b.west, b.north, b.east, modeMask: bit('train')),
        BboxVerdict.warn,
      );
      expect(
        checkBbox(b.south, b.west, b.north, b.east,
            modeMask: bit('train') | bit('bus')),
        BboxVerdict.tooLarge,
      );
    });

    test('a merely large box warns instead of blocking', () {
      // ~100 km across: past bus's warning, well under its limit.
      expect(checkBbox(48.0, 11.0, 48.65, 11.95, modeMask: bit('bus')),
          BboxVerdict.warn);
      expect(checkBbox(48.0, 11.0, 48.65, 11.95, modeMask: bit('train')),
          BboxVerdict.ok);
    });
  });

  group('TransitImportConfig', () {
    test('carries the chosen types alongside the box', () {
      const c = TransitImportConfig(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        modeMask: 5,
      );
      expect(c.modeMask, 5);
      expect(c.diagonalMeters, greaterThan(0));
    });
  });
}
