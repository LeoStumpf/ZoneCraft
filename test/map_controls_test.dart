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
import 'package:zonecraft/ui/map_controls.dart';

/// The guide is only worth having if it cannot fall behind the map.
///
/// Two failures would make it worse than nothing: a button with no entry, so
/// the page quietly omits the one thing somebody came looking for; and two
/// buttons wearing the same icon, which is how Add and Import came to be the
/// same symbol side by side on a POI layer.
void main() {
  test('every control has exactly one entry', () {
    for (final id in MapControlId.values) {
      expect(
        mapControls.where((c) => c.id == id).length,
        1,
        reason: '${id.name} must be described once and only once',
      );
    }
  });

  test('the list describes nothing that is not a control', () {
    expect(mapControls, hasLength(MapControlId.values.length));
  });

  test('no two controls in the same area share an icon', () {
    // The real bug this catches: `typeIcon('poi')` and the OSM-import button
    // were both Icons.travel_explore, so on a POI layer the bottom row showed
    // the same symbol twice, adjacent, doing different things.
    for (final area in MapControlArea.values) {
      final icons = mapControls
          .where((c) => c.area == area)
          .map((c) => c.icon)
          .toList();
      expect(
        icons.toSet(),
        hasLength(icons.length),
        reason: 'two buttons in "${area.title}" look identical',
      );
    }
  });

  test('every entry actually says something', () {
    for (final c in mapControls) {
      expect(c.name, isNotEmpty, reason: c.id.name);
      expect(c.what, isNotEmpty, reason: c.id.name);
      expect(c.what, isNot(c.name),
          reason: '${c.id.name} repeats its own name instead of explaining');
      // The name doubles as a tooltip, so it has to be short enough to read.
      expect(c.name.length, lessThan(30), reason: c.id.name);
    }
  });

  test('every area is used', () {
    for (final area in MapControlArea.values) {
      expect(mapControls.any((c) => c.area == area), isTrue,
          reason: '${area.name} has no controls — the heading would be empty');
    }
  });

  test('mapControl finds each one', () {
    for (final id in MapControlId.values) {
      expect(mapControl(id).id, id);
    }
  });
}
