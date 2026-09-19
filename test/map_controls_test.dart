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

  group('unavailableReason', () {
    // A fresh install: one empty circle layer, nothing drawn, nothing to select.
    const fresh = MapControlState(
      hasActiveLayer: true,
      activeLayerType: 'circles',
      activeLayerVisible: true,
      anythingSelectable: false,
    );
    const working = MapControlState(
      hasActiveLayer: true,
      activeLayerType: 'circles',
      activeLayerVisible: true,
      anythingSelectable: true,
    );

    test('a fresh map greys the one button this file can answer for', () {
      // Edit is the map's own question: is there anything, anywhere, a tap
      // could reach. Whether the quick toggle has something to act on is a
      // fact about the layer's contents, so it is
      // `layerActionUnavailable`'s — see layer_actions_test.
      final greyed = [
        for (final id in MapControlId.values)
          if (unavailableReason(id, fresh) != null) id,
      ];
      expect(greyed, [MapControlId.edit]);
    });

    test('adding one element brings it back', () {
      for (final id in MapControlId.values) {
        expect(unavailableReason(id, working), isNull, reason: id.name);
      }
    });

    test('a hidden layer greys the toggle even when it holds things', () {
      // Its whole effect is visual, so on a hidden layer it is as inert as on
      // an empty one — and for a reason the user cannot otherwise guess.
      const hidden = MapControlState(
        hasActiveLayer: true,
        activeLayerType: 'circles',
          activeLayerVisible: false,
        anythingSelectable: true,
      );
      expect(
        unavailableReason(MapControlId.quickToggle, hidden),
        contains('hidden'),
      );
      // Add stays live: it really does create the element. Not seeing it is a
      // different complaint with a different fix.
      expect(unavailableReason(MapControlId.add, hidden), isNull);
    });

    test('with no layer at all, Add says so', () {
      const none = MapControlState(
        hasActiveLayer: false,
        activeLayerType: null,
          activeLayerVisible: false,
        anythingSelectable: false,
      );
      expect(unavailableReason(MapControlId.add, none), contains('No layer'));
      expect(
        unavailableReason(MapControlId.quickToggle, none),
        contains('No layer'),
      );
    });

    test('the controls that always work never grey out', () {
      // Whatever the state, these do something: they open a thing, or they
      // act on the map rather than on a layer.
      const always = [
        MapControlId.layers,
        MapControlId.tools,
        MapControlId.osmImport,
        MapControlId.featureImport,
        MapControlId.locate,
        MapControlId.elevation,
        MapControlId.distance,
      ];
      for (final state in [fresh, working]) {
        for (final id in always) {
          expect(unavailableReason(id, state), isNull, reason: id.name);
        }
      }
    });

    test('a reason is a sentence naming a remedy, not a fault', () {
      for (final id in MapControlId.values) {
        final reason = unavailableReason(id, fresh);
        if (reason == null) continue;
        expect(reason, endsWith('.'), reason: id.name);
        expect(reason.length, greaterThan(20), reason: '${id.name} too terse');
        // "Unavailable" tells nobody anything; every one of these has to point
        // somewhere.
        expect(
          RegExp(r'first|menu|Turn it on').hasMatch(reason),
          isTrue,
          reason: '${id.name} does not say what to do about it',
        );
      }
    });
  });
}
