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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/overpass.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/ui/poi_icons.dart';
import 'package:zonecraft/ui/poi_layer.dart' show poiIconFor;

void main() {
  group('transitIconFor follows primaryTransitMode', () {
    test('over every mode combination the icon is the primary mode\'s', () {
      final all = transitAllModesMask;
      for (var mask = 0; mask <= all; mask++) {
        final primary = primaryTransitMode(mask);
        expect(
          transitIconFor(mask),
          transitIconFor(primary?.bit ?? 0),
          reason: 'mask $mask',
        );
      }
    });

    test('a subway+bus stop icons as a subway station', () {
      final subway = transitModeByKey('subway')!.bit;
      final bus = transitModeByKey('bus')!.bit;
      expect(transitIconFor(subway | bus), Icons.subway);
      expect(transitIconFor(bus), Icons.directions_bus);
      expect(transitIconFor(0), Icons.directions_transit);
    });
  });

  PoiSet set({String categoryKey = 'cafe', String? iconKey, bool manual = false}) =>
      PoiSet(
        id: 's',
        layerId: 'l',
        categoryKey: categoryKey,
        centerLat: 48.1,
        centerLng: 11.5,
        radiusMeters: manual ? 0 : 800,
        createdAt: DateTime(2026),
        colorShade: 0,
        source: manual ? kPoiSourceManual : kPoiSourceRadius,
        iconKey: iconKey,
        zOrder: 0,
        modeMask: 0,
        visibleModeMask: -1,
      );

  group('the catalogue', () {
    test('every key is unique across groups', () {
      // The key is the persisted format: two groups sharing one would make a
      // stored icon depend on iteration order.
      final keys = <String>[];
      for (final g in poiIconGroups) {
        for (final i in g.icons) {
          keys.add(i.key);
        }
      }
      expect(keys.toSet().length, keys.length);
      expect(poiIcons.length, keys.length);
    });

    test('the default key resolves', () {
      expect(poiIcons.containsKey(kDefaultPoiIconKey), isTrue);
    });

    test('no key is empty and no label is empty', () {
      for (final g in poiIconGroups) {
        expect(g.label, isNotEmpty);
        for (final i in g.icons) {
          expect(i.key, isNotEmpty);
          expect(i.label, isNotEmpty);
        }
      }
    });

    test('the built-in categories offered as shortcuts all have an icon', () {
      // The category dialog offers a shortcut only for categories whose key is
      // in the catalogue; if that intersection were empty the row would render
      // as a mysterious blank.
      final shared =
          poiCategories.where((c) => poiIcons.containsKey(c.key)).toList();
      expect(shared, isNotEmpty);
      for (final c in shared) {
        expect(poiIcons[c.key], isNotNull);
      }
    });
  });

  group('poiSetIcon', () {
    test('an import icons itself from its category', () {
      expect(poiSetIcon(set(categoryKey: 'cafe')), poiIconFor('cafe'));
      expect(poiSetIcon(set(categoryKey: 'hospital')), poiIconFor('hospital'));
    });

    test('a hand-made category icons itself from its own key', () {
      expect(poiSetIcon(set(manual: true, iconKey: 'peak')), poiIcons['peak']);
      // …and its key wins even when categoryKey names a real OSM category,
      // which it does: a manual set stores the icon key in both.
      expect(
        poiSetIcon(set(categoryKey: 'cafe', manual: true, iconKey: 'peak')),
        poiIcons['peak'],
      );
    });

    test('an unknown key falls back rather than throwing', () {
      // A file from a newer version can name an icon this build has never
      // heard of. A generic pin is the honest answer; a crash is not.
      expect(
        poiSetIcon(set(manual: true, iconKey: 'no-such-icon')),
        Icons.place_outlined,
      );
      expect(poiSetIcon(set(categoryKey: 'no-such-category')),
          Icons.place_outlined);
    });
  });
}
