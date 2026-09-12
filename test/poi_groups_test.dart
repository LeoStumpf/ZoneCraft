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

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/data/overpass.dart' show PoiResult;
import 'package:zonecraft/data/poi_sets.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/poi_groups.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  Future<Layer> layerById(String id) =>
      (db.select(db.layers)..where((l) => l.id.equals(id))).getSingle();

  Future<List<PoiTypeGroup>> groupsOf(String layerId) async {
    final points = await db.select(db.poiPoints).get();
    final bySet = <String, List<PoiPoint>>{};
    for (final p in points) {
      (bySet[p.poiSetId] ??= []).add(p);
    }
    return poiTypeGroups(
      layer: await layerById(layerId),
      sets: await db.select(db.poiSets).get(),
      pointsBySet: bySet,
    );
  }

  int bit(String key) => transitModeByKey(key)!.bit;

  Future<String> stationImport(String layerId) => repo.createPoiSet(
        layerId: layerId,
        source: kPoiSourceBox,
        categoryKey: kTransitStationCategoryKey,
        centerLat: 0,
        centerLng: 0,
        radiusMeters: 0,
        bbox: [48.10, 11.50, 48.15, 11.60],
        modeMask: transitAllModesMask,
        visibleModeMask: transitAllModesMask,
      );

  PoiResult station(String name, int id, int modeMask) => PoiResult(
        lat: 48.11,
        lng: 11.51,
        categoryKey: kTransitStationCategoryKey,
        name: name,
        osmType: 'node',
        osmId: id,
        modeMask: modeMask,
      );

  Future<String> radiusImport(String layerId, String category) =>
      repo.createPoiSet(
        layerId: layerId,
        source: kPoiSourceRadius,
        categoryKey: category,
        centerLat: 48.1,
        centerLng: 11.5,
        radiusMeters: 800,
      );

  PoiResult poi(String category, String? name, int id, {double lng = 11.5}) =>
      PoiResult(
        lat: 48.1,
        lng: lng,
        categoryKey: category,
        name: name,
        osmType: 'node',
        osmId: id,
      );

  test('stations are filed under their primary mode, never twice', () async {
    final layerId =
        await repo.createLayer(name: 'T', colorArgb: 0xFF123456, type: 'poi');
    final setId = await stationImport(layerId);
    await repo.fillPoiSet(setId, [
      station('Marienplatz', 1, bit('subway') | bit('bus')),
      station('Odeonsplatz', 2, bit('subway')),
      station('Sendlinger Tor', 3, bit('tram') | bit('bus')),
      station('Stachus', 4, bit('bus')),
      station('Nowhere', 5, 0),
    ]);

    final groups = await groupsOf(layerId);

    // Catalogue order — the same the Stations sheet ticks in — with the
    // mode-less stations last.
    expect(groups.map((g) => g.key), [
      'station:bus',
      'station:tram',
      'station:subway',
      'station:none',
    ]);
    final subway = groups[2];
    expect(subway.kind, PoiGroupKind.station);
    expect(subway.mode!.key, 'subway');
    expect(subway.label, 'Subway');
    expect(subway.setIds, {setId});
    // Alphabetical, and the bus+subway stop is here, not under Bus.
    expect(subway.points.map((p) => p.title), ['Marienplatz', 'Odeonsplatz']);
    expect(subway.points.first.subtitle, 'Bus, Subway');
    expect(subway.points.first.ref.kind, ObjectKind.poiPoint);
    expect(subway.points.first.fitPoints, hasLength(1));
    expect(groups[0].points.map((p) => p.title), ['Stachus']);

    final none = groups.last;
    expect(none.mode, isNull);
    expect(none.icon, Icons.help_outline);
    expect(none.points.single.subtitle, 'No type given');
  });

  test('every group counts the whole layer\'s stations in one section',
      () async {
    final layerId =
        await repo.createLayer(name: 'T', colorArgb: 0xFF123456, type: 'poi');
    final a = await stationImport(layerId);
    await repo.fillPoiSet(a, [station('A', 1, bit('bus'))]);
    final b = await stationImport(layerId);
    await repo.fillPoiSet(b, [station('B', 2, bit('bus'))]);

    final groups = await groupsOf(layerId);

    expect(groups.single.key, 'station:bus');
    expect(groups.single.setIds, {a, b});
    expect(groups.single.points.map((p) => p.title), ['A', 'B']);
  });

  test('two imports of one category merge into one group', () async {
    final layerId =
        await repo.createLayer(name: 'P', colorArgb: 0xFF123456, type: 'poi');
    final first = await radiusImport(layerId, 'cafe');
    await repo.fillPoiSet(first, [poi('cafe', 'Zum Kaffee', 1)]);
    final second = await radiusImport(layerId, 'cafe');
    // The repository drops the duplicate at import time; the group would
    // otherwise hold the place twice.
    await repo.fillPoiSet(
        second, [poi('cafe', 'Zum Kaffee', 1), poi('cafe', 'Aroma', 2)]);
    final other = await radiusImport(layerId, 'restaurant');
    await repo.fillPoiSet(other, [poi('restaurant', null, 3)]);

    final groups = await groupsOf(layerId);

    expect(groups.map((g) => g.key), ['category:cafe', 'category:restaurant']);
    final cafes = groups.first;
    expect(cafes.kind, PoiGroupKind.category);
    expect(cafes.label, 'Cafés');
    expect(cafes.setIds, {first, second});
    expect(cafes.points.map((p) => p.title), ['Aroma', 'Zum Kaffee']);
    expect(cafes.points.first.subtitle, 'Cafés');
    expect(cafes.manualSetId, isNull);
    expect(groups.last.points.single.title, 'Unnamed POI');
    expect(groups.last.points.single.sortName, '');
  });

  test('a hand-made category is its own group, even while empty', () async {
    final layerId =
        await repo.createLayer(name: 'P', colorArgb: 0xFF123456, type: 'poi');
    final empty = await repo.createPoiSet(
      layerId: layerId,
      source: kPoiSourceManual,
      categoryKey: 'pin',
      centerLat: 48.1,
      centerLng: 11.5,
      radiusMeters: 0,
      label: 'Zebra',
    );
    final filled = await repo.createPoiSet(
      layerId: layerId,
      source: kPoiSourceManual,
      categoryKey: 'pin',
      centerLat: 48.1,
      centerLng: 11.5,
      radiusMeters: 0,
      label: 'Apples',
    );
    await repo.addManualPoiPoint(
        poiSetId: filled, lat: 48.1, lng: 11.5, label: 'Granny');
    await repo.addManualPoiPoint(poiSetId: filled, lat: 48.1, lng: 11.5);

    final groups = await groupsOf(layerId);

    expect(groups.map((g) => g.label), ['Apples', 'Zebra']);
    expect(groups.first.kind, PoiGroupKind.manual);
    expect(groups.first.manualSetId, filled);
    expect(groups.first.points.map((p) => p.title), ['Granny', 'Unnamed POI']);
    expect(groups.first.points.first.subtitle, 'Apples');
    expect(groups.last.manualSetId, empty);
    expect(groups.last.points, isEmpty);
  });

  test('a pending import yields no group; other layers are ignored', () async {
    final layerId =
        await repo.createLayer(name: 'P', colorArgb: 0xFF123456, type: 'poi');
    final pending = await radiusImport(layerId, 'cafe');
    await repo.markPoiImportFailed(pending, 'Overpass is busy');
    final otherLayer =
        await repo.createLayer(name: 'Q', colorArgb: 0xFF123456, type: 'poi');
    final theirs = await radiusImport(otherLayer, 'restaurant');
    await repo.fillPoiSet(theirs, [poi('restaurant', 'Theirs', 1)]);

    expect(await groupsOf(layerId), isEmpty);
    expect((await groupsOf(otherLayer)).single.key, 'category:restaurant');
  });

  test('stations first, then categories, then hand-made', () async {
    final layerId = await repo.createLayer(
        name: 'M', colorArgb: 0xFF123456, type: kMixedType);
    await repo.createPoiSet(
      layerId: layerId,
      source: kPoiSourceManual,
      categoryKey: 'pin',
      centerLat: 48.1,
      centerLng: 11.5,
      radiusMeters: 0,
      label: 'Aardvark',
    );
    final cafes = await radiusImport(layerId, 'cafe');
    await repo.fillPoiSet(cafes, [poi('cafe', 'A', 1)]);
    final stations = await stationImport(layerId);
    await repo.fillPoiSet(stations, [station('S', 2, bit('train'))]);

    final groups = await groupsOf(layerId);

    expect(groups.map((g) => g.kind), [
      PoiGroupKind.station,
      PoiGroupKind.category,
      PoiGroupKind.manual,
    ]);
  });

  test('a layer that holds no POIs has no groups', () async {
    final layerId = await repo.createLayer(name: 'C', colorArgb: 0xFF0000FF);
    expect(await groupsOf(layerId), isEmpty);
  });
}
