import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/overpass.dart';
import 'package:zonecraft/ui/poi_icons.dart';
import 'package:zonecraft/ui/poi_layer.dart' show poiIconFor;

void main() {
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
        isManual: manual,
        iconKey: iconKey,
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
