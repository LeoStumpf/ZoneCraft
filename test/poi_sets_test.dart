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

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/overpass.dart' show poiCategories;
import 'package:zonecraft/data/poi_sets.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/transit.dart' show transitStationVisible;
import 'package:zonecraft/geo/border_areas.dart' show outerRings;

/// The one drawn == tappable predicate for POI markers, and the helpers that
/// tell the three kinds of set apart. `hit_test_test.dart` proves the painter
/// and the hit test read the same function; this proves the function.
void main() {
  PoiSet set(String source, {int visible = -1}) => PoiSet(
        id: 's',
        layerId: 'l',
        categoryKey: 'x',
        centerLat: 48,
        centerLng: 11,
        radiusMeters: 1,
        createdAt: DateTime(2026),
        colorShade: 0,
        zOrder: 0,
        source: source,
        south: source == kPoiSourceBox ? 47.9 : null,
        west: source == kPoiSourceBox ? 10.9 : null,
        north: source == kPoiSourceBox ? 48.1 : null,
        east: source == kPoiSourceBox ? 11.1 : null,
        modeMask: source == kPoiSourceBox ? 3 : 0,
        visibleModeMask: visible,
      );
  PoiPoint point(int modeMask) => PoiPoint(
        id: 'p',
        poiSetId: 's',
        lat: 48,
        lng: 11,
        sortOrder: 0,
        createdAt: DateTime(2026),
        modeMask: modeMask,
      );

  group('poiPointVisible', () {
    test('a station import follows transitStationVisible exactly', () {
      for (final station in [0, 1, 2, 3]) {
        for (final visible in [0, 1, 2, 3]) {
          expect(
            poiPointVisible(point(station), set(kPoiSourceBox, visible: visible)),
            transitStationVisible(station, visible),
            reason: 'station $station, visible $visible',
          );
        }
      }
    });

    test('a radius or hand-made set never filters', () {
      // Whatever the mask columns hold — they are defaults there — a café
      // draws. Gating on `p.modeMask != 0` instead would hide every mode-less
      // point of a station import under "hide all", but *also* every ordinary
      // POI whenever the set's filter happened to be 0.
      for (final source in [kPoiSourceRadius, kPoiSourceManual]) {
        for (final visible in [0, -1]) {
          expect(poiPointVisible(point(0), set(source, visible: visible)),
              isTrue, reason: '$source, visible $visible');
        }
      }
    });

    test('a point whose set is gone is not drawn', () {
      expect(poiPointVisible(point(1), null), isFalse);
    });
  });

  group('PoiSetKind', () {
    test('the three sources are told apart', () {
      final manual = set(kPoiSourceManual);
      expect((manual.isManual, manual.isImport, manual.isStationImport),
          (true, false, false));
      final radius = set(kPoiSourceRadius);
      expect((radius.isManual, radius.isImport, radius.isStationImport),
          (false, true, false));
      final box = set(kPoiSourceBox);
      expect((box.isManual, box.isImport, box.isStationImport),
          (false, true, true));
    });

    test('only an import can be pending, and only until fetched', () {
      expect(set(kPoiSourceManual).isPending, isFalse);
      expect(set(kPoiSourceRadius).isPending, isTrue);
      expect(set(kPoiSourceRadius).copyWith(fetchedAt: Value(DateTime(2026)))
          .isPending, isFalse);
    });

    test('only a box set has a box', () {
      expect(set(kPoiSourceBox).bbox, [47.9, 10.9, 48.1, 11.1]);
      expect(set(kPoiSourceRadius).bbox, isNull);
    });
  });

  test('the station category key names a real catalogue entry', () {
    // A migrated transit layer and a radius import of "Transit stations"
    // share this key, so it has to exist in the catalogue the radius import
    // reads its label and icon from.
    expect(poiCategories.map((c) => c.key), contains(kTransitStationCategoryKey));
  });

  test('boxCoveringRadiusMeters is half the diagonal', () {
    final r = boxCoveringRadiusMeters(
        south: 48.0, west: 11.0, north: 48.0, east: 11.0);
    expect(r, 0);
    final wide = boxCoveringRadiusMeters(
        south: 48.0, west: 11.0, north: 48.1, east: 11.1);
    // ~11 km on the ground for a 0.1° × 0.1° box at 48°N, halved.
    expect(wide, closeTo(6650, 200));
  });

  group('height region rings', () {
    late AppDatabase db;
    late Repository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = Repository(db);
    });
    tearDown(() => db.close());

    test('come back in stored order, and empty before generation', () async {
      final layerId =
          await repo.createLayer(name: 'H', colorArgb: 1, type: 'height');
      final region = await repo.createHeightRegion(
        layerId: layerId,
        centerLat: 47.5,
        centerLng: 11.0,
        radiusMeters: 5000,
        thresholdMeters: 900,
      );
      expect(await repo.heightRegionRings(region), isEmpty);

      const rings = [
        [LatLng(47.4, 10.9), LatLng(47.4, 11.1), LatLng(47.6, 11.1),
          LatLng(47.6, 10.9)],
        [LatLng(47.45, 10.95), LatLng(47.45, 11.05), LatLng(47.55, 11.05)],
      ];
      await repo.replaceHeightPolygons(region, rings);
      final back = await repo.heightRegionRings(region);
      expect(back, hasLength(2));
      expect(back.first, hasLength(4));
      expect(back.last, hasLength(3));
      expect(back.first.first.latitude, 47.4);
      expect(await repo.heightRegionRings('nope'), isEmpty);
    });

    test('converting keeps outer contours and drops holes', () {
      // The rule the conversion flow applies (`outerRings`): a "below" fill
      // is a disk with the mountains cut out, and only the disk survives.
      const disk = [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1), LatLng(1, 0)];
      const hole = [
        LatLng(0.4, 0.4), LatLng(0.4, 0.6), LatLng(0.6, 0.6), LatLng(0.6, 0.4),
      ];
      const exclave = [LatLng(2, 2), LatLng(2, 3), LatLng(3, 3)];
      final kept = outerRings([disk, hole, exclave]);
      expect(kept, hasLength(2));
      expect(kept, contains(disk));
      expect(kept, contains(exclave));
    });
  });
}
