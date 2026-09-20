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

import 'dart:convert';

import 'package:drift/drift.dart'
    show OrderingTerm, Table, TableInfo, Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/data/overpass.dart' show PoiResult;
import 'package:zonecraft/data/poi_sets.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/serialization.dart';
import 'package:zonecraft/data/transit.dart';

/// **Export/import is expected to be the identity.** A file this app writes and
/// reads back has to restore what it saved — every layer, every element, every
/// attribute the UI shows — whether it was the whole database or one layer.
///
/// `serialization_test.dart` round-trips the in-memory model only, so for years
/// nothing looked at the half where the losses actually were: the DB↔model
/// conversion in `Repository.exportData` / `importData`. This file is where the
/// contract is stated, against real rows.
///
/// The strongest assertion here is the **fixed point**: exporting, importing and
/// exporting again must produce byte-identical GeoJSON. Anything the round-trip
/// quietly rewrites — thinned geometry, flattened track segments, missing height
/// fills, a dedup key invented out of a placeholder id — shows up as a diff.
void main() {
  late AppDatabase db;
  late Repository repo;

  setUpAll(() {
    // These tests deliberately open a *second* in-memory database to import
    // into — that is the whole point, and the two never share an executor.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  // --- the fixture: one layer of every type, nothing left at its default ----

  /// Builds all ten layer types, each carrying non-default values for every
  /// attribute that is supposed to survive. Returns layer id by type.
  Future<Map<String, String>> seedEverything() async {
    final ids = <String, String>{};

    // circles — two elements, one with a colour override.
    ids['circles'] = await repo.createLayer(
      name: 'Circles',
      colorArgb: 0xFF2196F3,
    );
    final c1 = await repo.createCircle(
      layerId: _id(ids, 'circles'),
      centerLat: 48.137,
      centerLng: 11.575,
      radiusMeters: 1500,
      label: 'home',
    );
    await repo.setElementColor(ColoredElement.circle, c1, 0xFFEF5350);
    await repo.createCircle(
      layerId: _id(ids, 'circles'),
      centerLat: 48.2,
      centerLng: 11.6,
      radiusMeters: 800,
    );
    await repo.updateLayer(_id(ids, 'circles'), opacity: 0.31);

    // a two-point subspace (what a plane became) — inverted layer.
    ids['nearer'] = await repo.createLayer(
      name: 'Nearer',
      colorArgb: 0xFFEF5350,
      type: 'subspace',
    );
    final half = await repo.createSubspace(
      layerId: _id(ids, 'nearer'),
      label: 'A|B',
    );
    await repo.addSubspacePoint(subspaceId: half, lat: 48.0, lng: 11.0);
    await repo.addSubspacePoint(
      subspaceId: half,
      lat: 48.5,
      lng: 11.9,
      isMain: true,
    );
    await repo.updateLayer(_id(ids, 'nearer'), isInverted: true);

    // subspace — a main point that is not the first, and named seeds.
    ids['subspace'] = await repo.createLayer(
      name: 'Subspace',
      colorArgb: 0xFF66BB6A,
      type: 'subspace',
    );
    final sub = await repo.createSubspace(
      layerId: _id(ids, 'subspace'),
      label: 'cells',
    );
    await repo.addSubspacePoint(
      subspaceId: sub,
      lat: 48.0,
      lng: 11.0,
      label: 'north',
    );
    await repo.addSubspacePoint(subspaceId: sub, lat: 48.1, lng: 11.2);
    await repo.addSubspacePoint(
      subspaceId: sub,
      lat: 47.9,
      lng: 11.1,
      isMain: true,
      label: 'mine',
    );

    // freeline — an offset and an explicit inclusion circle, and vertices
    // closer together than the 10 m import thinning would keep.
    ids['freeline'] = await repo.createLayer(
      name: 'Lines',
      colorArgb: 0xFFAB47BC,
      type: 'freeline',
    );
    final line = await repo.createFreeLine(
      layerId: _id(ids, 'freeline'),
      label: 'the wall',
      inclusionLat: 48.05,
      inclusionLng: 11.1,
      inclusionRadiusMeters: 9000,
    );
    await repo.updateFreeLine(line, offsetMeters: -250);
    await repo.addFreeLinePoints(line, [
      for (var i = 0; i < 12; i++)
        LatLng(48.0 + i * 0.00004, 11.0 + i * 0.00004),
    ]);

    // freearea — likewise dense, plus a positive offset.
    ids['freearea'] = await repo.createLayer(
      name: 'Areas',
      colorArgb: 0xFFFFA726,
      type: 'freearea',
    );
    final area = await repo.createFreeArea(
      layerId: _id(ids, 'freearea'),
      label: 'the park',
    );
    await repo.updateFreeArea(area, offsetMeters: 300);
    await repo.addFreeAreaPoints(area, [
      LatLng(48.00000, 11.00000),
      LatLng(48.00004, 11.00000),
      LatLng(48.00008, 11.00002),
      LatLng(48.00008, 11.00006),
      LatLng(48.00000, 11.00006),
    ]);

    // height — a *generated* region: its fills are what the layer draws.
    ids['height'] = await repo.createLayer(
      name: 'Height',
      colorArgb: 0xFF8D6E63,
      type: 'height',
    );
    final region = await repo.createHeightRegion(
      layerId: _id(ids, 'height'),
      centerLat: 47.42,
      centerLng: 10.98,
      radiusMeters: 12000,
      thresholdMeters: 1850.5,
      aboveThreshold: false,
      sampleZoom: 14,
      label: 'above the treeline',
    );
    await repo.replaceHeightPolygons(region, [
      [LatLng(47.4, 10.9), LatLng(47.45, 10.9), LatLng(47.45, 11.0)],
      [
        LatLng(47.38, 11.02),
        LatLng(47.39, 11.02),
        LatLng(47.39, 11.04),
        LatLng(47.38, 11.04),
      ],
    ]);
    await repo.markHeightGenerated(region);

    // poi — POIs that carry their OSM identity, and one that never had any.
    ids['poi'] = await repo.createLayer(
      name: 'POIs',
      colorArgb: 0xFF00ACC1,
      type: 'poi',
    );
    final poiSet = await repo.createPoiSet(
      layerId: _id(ids, 'poi'),
      source: kPoiSourceRadius,
      categoryKey: 'cafe',
      centerLat: 48.137,
      centerLng: 11.575,
      radiusMeters: 2000,
      label: 'Cafés',
    );
    await repo.fillPoiSet(poiSet, const [
      PoiResult(
        lat: 48.14,
        lng: 11.58,
        categoryKey: 'cafe',
        name: 'Café A',
        osmType: 'node',
        osmId: 240109189,
      ),
      PoiResult(
        lat: 48.13,
        lng: 11.57,
        categoryKey: 'cafe',
        name: null,
        osmType: 'way',
        osmId: 240109189,
      ),
      PoiResult(lat: 48.12, lng: 11.56, categoryKey: 'cafe', name: 'Café C'),
    ]);
    // …and a **hand-made** category on the same layer. A manual set is the one
    // POI set with no query behind it: radius 0, its own icon, and points that
    // never had an OSM identity. All of that has to come back as *manual*, or
    // an editable category silently returns as a read-only import claiming a
    // search that never ran.
    final manualSet = await repo.createPoiSet(
      layerId: _id(ids, 'poi'),
      categoryKey: 'peak',
      centerLat: 48.10,
      centerLng: 11.50,
      radiusMeters: 0,
      label: 'Swimming spots',
      source: kPoiSourceManual,
      iconKey: 'peak',
    );
    await repo.addManualPoiPoint(
      poiSetId: manualSet,
      lat: 48.101,
      lng: 11.501,
      label: 'The rope swing',
    );
    await repo.addManualPoiPoint(poiSetId: manualSet, lat: 48.102, lng: 11.502);

    // …and station imports on a second POI layer: one filled and one that
    // failed (a retry row). Both are box-sourced sets since v27.
    ids['stations'] = await repo.createLayer(
      name: 'Stations',
      colorArgb: 0xFF7E57C2,
      type: 'poi',
    );
    final filled = await repo.createPoiSet(
      layerId: _id(ids, 'stations'),
      source: kPoiSourceBox,
      categoryKey: kTransitStationCategoryKey,
      centerLat: 0,
      centerLng: 0,
      radiusMeters: 0,
      bbox: [48.00, 11.30, 48.30, 11.80],
      modeMask: transitAllModesMask,
      visibleModeMask: transitModeByKey('subway')!.bit,
      label: 'München',
    );
    await repo.fillPoiSet(filled, [
      TransitStationData(
        osmId: 1,
        lat: 48.14,
        lng: 11.46,
        name: 'Pasing Bahnhof',
        modeMask: transitModeByKey('bus')!.bit | transitModeByKey('train')!.bit,
      ).toPoiResult(),
      TransitStationData(
        osmId: 2,
        lat: 48.13,
        lng: 11.57,
        name: 'Marienplatz',
        modeMask: transitModeByKey('subway')!.bit,
      ).toPoiResult(),
    ]);
    final failed = await repo.createPoiSet(
      layerId: _id(ids, 'stations'),
      source: kPoiSourceBox,
      categoryKey: kTransitStationCategoryKey,
      centerLat: 0,
      centerLng: 0,
      radiusMeters: 0,
      bbox: [49.0, 12.0, 49.5, 12.5],
      modeMask: transitModeByKey('train')!.bit,
      visibleModeMask: -1,
      label: 'Regensburg',
    );
    await repo.markPoiImportFailed(failed, 'Overpass was busy');

    // borders — a named import, one area reshaped by hand (so it is a fork),
    // and the display toggles on. Hidden, to prove that survives too.
    ids['borders'] = await repo.createLayer(
      name: 'Borders',
      colorArgb: 0xFF123456,
      type: 'borders',
      borderLevel: '8',
    );
    await repo.updateBorderLayerOptions(
      _id(ids, 'borders'),
      fillAreas: true,
      showNames: true,
    );
    await repo.addBorderSet(
      layerId: _id(ids, 'borders'),
      south: 48.0,
      west: 11.0,
      north: 48.2,
      east: 11.3,
      adminLevel: '8',
      label: 'Around Munich',
      areas: [
        _area(1, 'München', const [100, 101]),
        _area(2, 'Germering', const [100, 102]),
        _area(3, 'Far away', const [900]),
      ],
    );
    final munich = (await repo.watchAllBorderAreas().first).firstWhere(
      (a) => a.osmId == 1,
    );
    await repo.reshapeBorderArea(munich.id, [
      [
        const LatLng(48.0, 11.0),
        const LatLng(48.0, 11.15),
        const LatLng(48.1, 11.15),
        const LatLng(48.1, 11.0),
      ],
    ]);
    await repo.updateBorderArea(munich.id, labelLat: 48.02, labelLng: 11.07);
    await repo.updateLayer(_id(ids, 'borders'), isVisible: false);

    // A folder with several layers in it — the shape that replaced the
    // combined layer. What has to survive is the membership and the folder's
    // own two settings; each member is an ordinary layer and travels as one.
    ids['folder'] = await repo.createFolder(name: 'Everything');
    await repo.updateFolder(_id(ids, 'folder'), isInverted: true);
    ids['inCircles'] = await repo.createLayer(
      name: 'Everything (Circles)',
      colorArgb: 0xFF7E57C2,
    );
    await repo.moveLayerToFolder(_id(ids, 'inCircles'), _id(ids, 'folder'));
    await repo.createCircle(
      layerId: _id(ids, 'inCircles'),
      centerLat: 48.15,
      centerLng: 11.60,
      radiusMeters: 750,
      label: 'in the mix',
    );
    ids['inAreas'] = await repo.createLayer(
      name: 'Everything (Areas)',
      colorArgb: 0xFF7E57C2,
      type: 'freearea',
    );
    await repo.moveLayerToFolder(_id(ids, 'inAreas'), _id(ids, 'folder'));
    final folderArea = await repo.createFreeArea(layerId: _id(ids, 'inAreas'));
    await repo.addFreeAreaPoints(folderArea, const [
      LatLng(48.16, 11.61),
      LatLng(48.17, 11.62),
      LatLng(48.17, 11.60),
    ]);
    ids['inPois'] = await repo.createLayer(
      name: 'Everything (POIs)',
      colorArgb: 0xFF7E57C2,
      type: 'poi',
    );
    await repo.moveLayerToFolder(_id(ids, 'inPois'), _id(ids, 'folder'));
    final folderPoi = await repo.createPoiSet(
      layerId: _id(ids, 'inPois'),
      source: kPoiSourceManual,
      categoryKey: 'star',
      centerLat: 48.15,
      centerLng: 11.60,
      radiusMeters: 0,
      label: 'Favourites',
      iconKey: 'star',
    );
    await repo.addManualPoiPoint(
      poiSetId: folderPoi,
      lat: 48.155,
      lng: 11.605,
      label: 'here',
    );

    return ids;
  }

  // --- the comparison ------------------------------------------------------

  /// The whole database as plain, comparable data: every layer in draw order
  /// with every element and child row under it.
  ///
  /// Read straight from the tables rather than through `exportData`, so this
  /// cannot agree with the exporter by sharing its blind spots. Ids and
  /// timestamps are left out — they are new on the far side by definition —
  /// but the *nullness* of a timestamp is kept, because "generated" and
  /// "reshaped by hand" are exactly that.
  Future<List<Map<String, Object?>>> snapshot() async {
    final layers = await (db.select(
      db.layers,
    )..orderBy([(l) => OrderingTerm(expression: l.sortOrder)])).get();
    // By name, not by id: ids are new on the far side, and the name is what a
    // folder *is* in the file.
    final folders = {
      for (final f in await db.select(db.folders).get()) f.id: f,
    };
    final out = <Map<String, Object?>>[];
    for (final l in layers) {
      final folder = folders[l.folderId];
      out.add({
        'name': l.name,
        'folder': folder?.name,
        'folderVisible': folder?.isVisible,
        'folderInverted': folder?.isInverted,
        'colorArgb': l.colorArgb,
        'type': l.type,
        'isVisible': l.isVisible,
        'isInverted': l.isInverted,
        'opacity': l.opacity,
        'borderLevel': l.borderLevel,
        'borderFillAreas': l.borderFillAreas,
        'borderShowNames': l.borderShowNames,
        'objects': await _objectsOf(db, l),
      });
    }
    return out;
  }

  /// Runs [data] through the file format and back into a **fresh** database,
  /// returning that database's snapshot. `simplify: false` is what the real
  /// import flow passes for a ZoneCraft file.
  Future<List<Map<String, Object?>>> reimport(ExportData data) async {
    final text = exportToGeoJson(data);
    final parsed = importFromGeoJson(text);
    expect(parsed, isNotNull, reason: 'our own export must read back');
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    final freshRepo = Repository(fresh);
    await freshRepo.importData(parsed!, simplify: false);
    final layers = await (fresh.select(
      fresh.layers,
    )..orderBy([(l) => OrderingTerm(expression: l.sortOrder)])).get();
    final folders = {
      for (final f in await fresh.select(fresh.folders).get()) f.id: f,
    };
    final out = <Map<String, Object?>>[];
    for (final l in layers) {
      final folder = folders[l.folderId];
      out.add({
        'name': l.name,
        'folder': folder?.name,
        'folderVisible': folder?.isVisible,
        'folderInverted': folder?.isInverted,
        'colorArgb': l.colorArgb,
        'type': l.type,
        'isVisible': l.isVisible,
        'isInverted': l.isInverted,
        'opacity': l.opacity,
        'borderLevel': l.borderLevel,
        'borderFillAreas': l.borderFillAreas,
        'borderShowNames': l.borderShowNames,
        'objects': await _objectsOf(fresh, l),
      });
    }
    await fresh.close();
    return out;
  }

  // --- the tests -----------------------------------------------------------

  test('the whole database survives an export/import round-trip', () async {
    await seedEverything();
    final before = await snapshot();
    expect(
      before,
      hasLength(12),
      reason:
          'one layer of every type, a second subspace and POI layer '
          '(the shapes planes and transit became), plus three in a folder',
    );

    final after = await reimport(await repo.exportData());
    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(
        after[i],
        before[i],
        reason:
            'layer ${before[i]['name']} (${before[i]['type']}) '
            'did not come back the same',
      );
    }
  });

  test('every layer survives an export/import of that layer alone', () async {
    final ids = await seedEverything();
    final before = await snapshot();

    final layers = await repo.watchLayers().first;
    for (final entry in ids.entries) {
      // `ids` also names the folder, which is not a layer and has no
      // single-layer export of its own — its members carry it.
      final layer = layers.where((l) => l.id == entry.value).firstOrNull;
      if (layer == null) continue;
      final name = layer.name;
      final mine = before.firstWhere((l) => l['name'] == name);
      final after = await reimport(
        await repo.exportData(onlyLayerId: entry.value),
      );
      expect(
        after,
        hasLength(1),
        reason: '${entry.key}: one layer in, one out',
      );
      expect(
        after.single,
        mine,
        reason: 'the single-layer export of ${entry.key} lost something',
      );
    }
  });

  // Draw order (v26) is carried by the file's *feature sequence*, not by a
  // property — exactly how `colorShade` already travels. That only works if the
  // exporter emits back-to-front and the importer assigns z in file order, so
  // the fixed point has to hold after a reorder too, not just from a freshly
  // seeded database where the two happen to coincide.
  test('a reordered layer stays a fixed point, and keeps its stack', () async {
    final ids = await seedEverything();
    final circles = (await repo.watchAllCircles().first)
        .where((c) => c.layerId == _id(ids, 'circles'))
        .toList();
    // Nothing to reorder means nothing is being tested.
    expect(circles.length, greaterThan(1));
    await repo.moveElementZ(
      ColoredElement.circle,
      circles.first.id,
      ZMove.toFront,
    );
    final wanted = [
      for (final c in (await repo.watchAllCircles().first).where(
        (c) => c.layerId == _id(ids, 'circles'),
      ))
        c.radiusMeters,
    ];

    final once = exportToGeoJson(await repo.exportData());
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    final freshRepo = Repository(fresh);
    await freshRepo.importData(importFromGeoJson(once)!, simplify: false);

    // The stack survived: same elements, same order, on the far side. Filtered
    // to the single-type circles layer — `seedEverything` also puts circles on
    // the mixed one, and those are a different stack.
    final freshLayer = (await freshRepo.watchLayers().first).firstWhere(
      (l) => l.type == 'circles',
    );
    final got = [
      for (final c in await freshRepo.watchAllCircles().first)
        if (c.layerId == freshLayer.id) c.radiusMeters,
    ];
    expect(got, wanted);

    final twice = exportToGeoJson(await freshRepo.exportData());
    await fresh.close();
    expect(twice, once);
  });

  test(
    'export is a fixed point: export -> import -> export is identical',
    () async {
      await seedEverything();
      final once = exportToGeoJson(await repo.exportData());

      // Import the file into a fresh database and export *that*.
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      final freshRepo = Repository(fresh);
      await freshRepo.importData(importFromGeoJson(once)!, simplify: false);
      final twice = exportToGeoJson(await freshRepo.exportData());
      await fresh.close();

      // Byte-identical. Anything the round-trip rewrites — thinned geometry,
      // flattened segments, missing height fills, an invented dedup key — is a
      // diff here, on the layer it happened to.
      expect(twice, once);
    },
  );

  test('a hidden layer comes back hidden', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: _id(ids, 'borders'));
    expect(data.layers.single.isVisible, isFalse);
    final after = await reimport(data);
    expect(after.single['isVisible'], isFalse);
  });

  test('a generated height layer comes back drawn, not blank', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: _id(ids, 'height'));
    final o = data.layers.single.objects.single;
    expect(o.generated, isTrue);
    expect(o.heightRings, hasLength(2));
    expect(o.thresholdMeters, 1850.5);
    expect(o.aboveThreshold, isFalse);
    expect(o.sampleZoom, 14);

    final after = await reimport(data);
    final region = _objRows(after.single).single;
    expect(
      region['generated'],
      isTrue,
      reason:
          'an imported height layer that has to be regenerated by hand '
          'draws nothing at all, which is what "the layer is empty" was',
    );
    expect(region['fills'], hasLength(2));
  });

  test(
    'a station import round-trips with its box, filter and retry row',
    () async {
      final ids = await seedEverything();
      final data = await repo.exportData(onlyLayerId: _id(ids, 'stations'));
      final objects = data.layers.single.objects;
      expect(objects, hasLength(2));
      final filled = objects.firstWhere((o) => o.pending != true);
      expect(filled.kind, 'poi');
      expect(filled.bbox, [48.00, 11.30, 48.30, 11.80]);
      expect(filled.coords, hasLength(3), reason: 'box centre + 2 stations');
      expect(filled.pointModeMasks, hasLength(2));
      expect(filled.visibleModeMask, transitModeByKey('subway')!.bit);
      expect(filled.radiusMeters, isNull, reason: 'derived from the box');
      final pending = objects.firstWhere((o) => o.pending == true);
      expect(pending.errorMessage, 'Overpass was busy');
      expect(pending.coords, hasLength(1), reason: 'the box centre only');

      final after = await reimport(data);
      final rows = _objRows(after.single);
      expect(rows, hasLength(2));
      final back = rows.firstWhere((r) => r['label'] == 'München');
      expect(back['source'], kPoiSourceBox);
      expect(back['bbox'], [48.00, 11.30, 48.30, 11.80]);
      expect((back['points']! as List), hasLength(2));
      final retry = rows.firstWhere((r) => r['label'] == 'Regensburg');
      expect(retry['pending'], isTrue);
      expect(retry['lastError'], 'Overpass was busy');
    },
  );

  test('freehand geometry is not thinned by our own round-trip', () async {
    final ids = await seedEverything();
    final before = await snapshot();
    final line = before.firstWhere((l) => l['type'] == 'freeline');
    final vertices = _objRows(line).single['points']! as List;
    expect(vertices, hasLength(12));

    final after = await reimport(
      await repo.exportData(onlyLayerId: _id(ids, 'freeline')),
    );
    expect(
      _objRows(after.single).single['points'],
      hasLength(12),
      reason: 'the 10 m RDP pass belongs to generic files, not to ours',
    );
  });

  test('a generic file is still thinned on import', () async {
    // The other half of the same rule: a GPX full of GPS jitter still gets the
    // RDP pass, which is what `simplify` defaults to.
    final layerId = await repo.createLayer(
      name: 'L',
      colorArgb: 0xFF000000,
      type: 'freeline',
    );
    await repo.mergeIntoLayer(
      layerId,
      ExportLayer(
        name: 'L',
        colorArgb: 0xFF000000,
        type: 'freeline',
        isInverted: false,
        objects: [
          ExportObject(
            kind: 'freeline',
            coords: [
              for (var i = 0; i < 12; i++)
                LatLng(48.0 + i * 0.00004, 11.0 + i * 0.00004),
            ],
          ),
        ],
      ),
    );
    final pts = await repo.watchAllFreeLinePoints().first;
    expect(pts.length, lessThan(12));
  });

  test('imported POIs keep their OSM identity, so a re-import dedups', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: _id(ids, 'poi'));
    // The layer holds two sets: the Overpass import and a hand-made category.
    final o = data.layers.single.objects.firstWhere((o) => o.manual != true);
    expect(o.pointOsmIds, [240109189, 240109189, 0]);
    expect(o.pointOsmTypes, ['node', 'way', null]);

    // Merging the file back into the layer it came from re-creates the sets but
    // adds no *identified* POI: these are the same ones, and node 240109189 is
    // not way 240109189.
    expect(
      await repo.mergeIntoLayer(
        _id(ids, 'poi'),
        data.layers.single,
        simplify: false,
      ),
      2,
    );
    // Scoped to this layer's own sets: the seed also puts a hand-placed POI on
    // the combined layer, which has nothing to do with dedup.
    final setIds = (await repo.watchAllPoiSets().first)
        .where((s) => s.layerId == _id(ids, 'poi'))
        .map((s) => s.id)
        .toSet();
    final points = (await repo.watchAllPoiPoints().first).where(
      (p) => setIds.contains(p.poiSetId),
    );
    expect(
      points.where((p) => p.osmId != null),
      hasLength(2),
      reason: 'the two identified POIs were recognised, not drawn twice',
    );
    // Everything unidentified has nothing to match on and is kept, as always:
    // the import's third POI plus the two hand-placed ones, twice over.
    expect(points.where((p) => p.osmId == null), hasLength(6));
  });

  test('a corrected POI cannot launder itself into "what OSM says"', () async {
    // The anti-laundering property, and the reason the fork travels at all:
    // the point keeps its OSM id, so if the correction arrived silently on
    // somebody else's device, re-import dedup would keep one person's guess
    // over whatever OSM now holds — with nothing anywhere saying so.
    final ids = await seedEverything();
    final layerId = _id(ids, 'poi');
    final setIds = (await repo.watchAllPoiSets().first)
        .where((s) => s.layerId == layerId && !s.isManual)
        .map((s) => s.id)
        .toSet();
    final point = (await repo.watchAllPoiPoints().first).firstWhere(
      (p) => setIds.contains(p.poiSetId) && p.osmId != null,
    );
    await repo.movePoiPoint(
      id: point.id,
      lat: point.lat + 0.001,
      lng: point.lng + 0.001,
    );
    await repo.updatePoiPoint(point.id, name: const Value('On the ground'));

    final data = await repo.exportData(onlyLayerId: layerId);
    final o = data.layers.single.objects.firstWhere((o) => o.manual != true);
    expect(
      o.pointOrigLat,
      isNotNull,
      reason: 'the set holds a corrected point, so the arrays are written',
    );
    expect(o.pointOrigLat!.where((v) => v != null), hasLength(1));
    expect(o.pointOrigNames!.where((v) => v != null), hasLength(1));

    // And it survives the trip: an imported-then-corrected POI arrives still
    // flagged, with what OSM said intact.
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);
    final freshRepo = Repository(fresh);
    await freshRepo.importData(
      importFromGeoJson(exportToGeoJson(data))!,
      simplify: false,
    );
    final restored = (await freshRepo.watchAllPoiPoints().first)
        .where((p) => p.editedAt != null)
        .toList();
    expect(restored, hasLength(1));
    expect(restored.single.name, 'On the ground');
    expect(restored.single.origName, point.name);
    expect(restored.single.origLat, closeTo(point.lat, 1e-9));
  });

  test(
    'an untouched POI import writes nothing new, so v4 files are v5 files',
    () async {
      // The whole reason the three arrays are conditional: a map where nobody
      // corrected anything must export byte-for-byte what it did before, or
      // every existing file stops being a fixed point.
      final ids = await seedEverything();
      final data = await repo.exportData(onlyLayerId: _id(ids, 'poi'));
      for (final o in data.layers.single.objects) {
        expect(o.pointOrigLat, isNull);
        expect(o.pointOrigLng, isNull);
        expect(o.pointOrigNames, isNull);
      }
      expect(exportToGeoJson(data), isNot(contains('pointOrigLat')));
    },
  );

  test('a folder round-trips with its members and its own settings', () async {
    // A folder carries nothing but a name and two switches, and its members
    // are ordinary layers — so what is at risk is the *membership*: coming
    // back at the root would quietly undo the grouping, and coming back with
    // the folder's invert dropped would draw every member the wrong way round.
    await seedEverything();
    final data = await repo.exportData();
    expect(data.folders.map((f) => f.name), contains('Everything'));
    final folder = data.folders.firstWhere((f) => f.name == 'Everything');
    expect(folder.isInverted, isTrue);
    final members = data.layers
        .where((l) => l.folderName == 'Everything')
        .toList();
    expect(members.map((l) => l.type), ['circles', 'freearea', 'poi']);

    final after = await reimport(data);
    final folders = await repo.watchFolders().first;
    final back = folders.firstWhere((f) => f.name == 'Everything');
    expect(back.isInverted, isTrue);
    final layers = await repo.watchLayers().first;
    final inside = layers.where((l) => l.folderId == back.id).toList();
    expect(inside.map((l) => l.type), ['circles', 'freearea', 'poi']);
    expect(
      after.where((l) => l['name'] == 'Everything (Circles)'),
      hasLength(1),
    );
  });

  test('a v3 file\'s combined layer arrives split, inside a folder', () async {
    // The one thing the fixed point does *not* cover: a file this version
    // cannot write. A `mixed` layer becomes one layer per kind it carries, in
    // the order its painter drew them, with the invert moved up to the folder
    // — the same thing the v30 migration does to a database.
    const file = '''
{
  "type": "FeatureCollection",
  "zonecraft": {
    "version": 3,
    "layers": [
      {"name": "Everything", "colorArgb": 42, "type": "mixed",
       "isInverted": true, "opacity": 0.45}
    ]
  },
  "features": [
    {"type": "Feature", "properties": {"kind": "poi", "zonecraftLayer": 0,
      "categoryKey": "star", "radiusMeters": 0, "source": "manual"},
     "geometry": {"type": "Point", "coordinates": [11.6, 48.15]}},
    {"type": "Feature", "properties": {"kind": "circle", "zonecraftLayer": 0,
      "radiusMeters": 500},
     "geometry": {"type": "Point", "coordinates": [11.5, 48.1]}}
  ]
}''';
    final data = importFromGeoJson(file);
    expect(data, isNotNull);
    expect(data!.folders.single.name, 'Everything');
    expect(data.folders.single.isInverted, isTrue);
    // Draw order, not file order: the circle is ground, the POI is a label.
    expect(data.layers.map((l) => l.type), ['circles', 'poi']);
    expect(data.layers.map((l) => l.name), [
      'Everything (Circles)',
      'Everything (POIs)',
    ]);
    expect(data.layers.every((l) => l.folderName == 'Everything'), isTrue);
    expect(
      data.layers.every((l) => !l.isInverted),
      isTrue,
      reason: 'the invert moved up to the folder, which flips them',
    );
    expect(data.layers.every((l) => l.colorArgb == 42), isTrue);

    await repo.importData(data, simplify: false);
    final folder = (await repo.watchFolders().first).single;
    final layers = await repo.watchLayers().first;
    expect(layers.where((l) => l.folderId == folder.id), hasLength(2));
  });

  test('a v3 combined layer holding one kind is just that layer', () async {
    const file = '''
{
  "type": "FeatureCollection",
  "zonecraft": {"version": 3, "layers": [
    {"name": "Only POIs", "colorArgb": 9, "type": "mixed", "isInverted": false}
  ]},
  "features": [
    {"type": "Feature", "properties": {"kind": "poi", "zonecraftLayer": 0,
      "categoryKey": "bench", "radiusMeters": 300, "source": "manual"},
     "geometry": {"type": "Point", "coordinates": [11.5, 48.1]}}
  ]
}''';
    final data = importFromGeoJson(file)!;
    expect(data.folders, isEmpty, reason: 'no folder around a single layer');
    expect(data.layers.single.type, 'poi');
    expect(data.layers.single.name, 'Only POIs');
  });

  test(
    'a hand-made POI category comes back hand-made, not as an import',
    () async {
      // The distinction is the whole feature: a manual set is editable, takes
      // hand-placed points and describes no search, while an import is a
      // read-only snapshot. A manual set returning as an import would be a silent
      // demotion — and its radius 0 would start being shown as a search area.
      final ids = await seedEverything();
      final data = await repo.exportData(onlyLayerId: _id(ids, 'poi'));
      final o = data.layers.single.objects.firstWhere((o) => o.manual == true);
      expect(o.iconKey, 'peak');
      expect(o.label, 'Swimming spots');
      expect(o.radiusMeters, 0, reason: '0 is the value, not a missing one');
      expect(o.pointLabels, ['The rope swing', null]);
      expect(
        o.pointOsmIds,
        isNull,
        reason: 'hand-placed points have no upstream to be identified against',
      );

      final after = await reimport(data);
      final sets = _objRows(after.single);
      final manual = sets.firstWhere((s) => s['source'] == kPoiSourceManual);
      expect(manual['iconKey'], 'peak');
      expect(manual['label'], 'Swimming spots');
      expect(manual['radiusMeters'], 0);

      // And the import on the same layer is *not* flagged, which is what stops
      // "manual" from being a field that quietly defaults to true.
      final imported = sets.firstWhere((s) => s['source'] == kPoiSourceRadius);
      expect(imported['categoryKey'], 'cafe');
      expect(imported['iconKey'], isNull);
    },
  );

  test('a failed station import comes back as a retry row', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: _id(ids, 'stations'));
    expect(data.layers.single.objects, hasLength(2));
    final failed = data.layers.single.objects.firstWhere(
      (o) => o.pending == true,
    );
    expect(failed.coords, hasLength(1), reason: 'the box centre, no stations');
    expect(failed.errorMessage, 'Overpass was busy');
    expect(failed.bbox, [49.0, 12.0, 49.5, 12.5]);

    final after = await reimport(data);
    final sets = _objRows(after.single);
    expect(sets, hasLength(2));
    final retry = sets.firstWhere((s) => s['pending'] == true);
    expect(retry['lastError'], 'Overpass was busy');
    expect(retry['label'], 'Regensburg');
  });

  test('a border import keeps its own name and its edited areas', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: _id(ids, 'borders'));
    final munich = data.layers.single.objects.firstWhere(
      (o) => o.label == 'München',
    );
    expect(munich.setLabel, 'Around Munich');
    expect(munich.edited, isTrue);
    expect(munich.labelLat, 48.02);

    final after = await reimport(data);
    final sets = _objRows(after.single);
    expect(sets.single, isA<Map<String, Object?>>());
    expect(sets.single['label'], 'Around Munich');
    final areas = sets.single['areas']! as List;
    final m = areas.firstWhere((a) => (a as Map)['name'] == 'München') as Map;
    expect(m['edited'], isTrue);
    expect(m['labelLat'], 48.02);
  });

  test('border areas with no relation id all survive a re-import', () async {
    // 0 is the placeholder an id-less import is stored with. Treated as a real
    // OSM id it made every such area look like the same relation, so dedup kept
    // one and dropped the rest.
    final layerId = await repo.createLayer(
      name: 'B',
      colorArgb: 0xFF123456,
      type: 'borders',
      borderLevel: '8',
    );
    await repo.addBorderSet(
      layerId: layerId,
      south: 48.0,
      west: 11.0,
      north: 48.2,
      east: 11.3,
      adminLevel: '8',
      areas: [
        _area(0, 'One', const [1]),
        _area(0, 'Two', const [2]),
        _area(0, 'Three', const [3]),
      ],
    );
    final data = await repo.exportData(onlyLayerId: layerId);
    expect(data.layers.single.objects, hasLength(3));
    for (final o in data.layers.single.objects) {
      expect(o.osmId, isNull, reason: '0 is not an OSM id');
    }
    final after = await reimport(data);
    expect(_objRows(after.single).single, isA<Map<String, Object?>>());
    expect(_objRows(after.single).single['areas'], hasLength(3));
  });

  test('a v1 file still imports, with the v1 defaults', () async {
    // Everything shipped before schema v2: no isVisible, a LineString track
    // (a type that no longer exists, so its layer is dropped), a height
    // region with no fills.
    const v1 = '''
{
  "type": "FeatureCollection",
  "zonecraft": {
    "version": 1,
    "layers": [
      {"name": "Old track", "colorArgb": 16711680, "type": "track",
       "isInverted": false},
      {"name": "Old height", "colorArgb": 255, "type": "height",
       "isInverted": false}
    ]
  },
  "features": [
    {"type": "Feature",
     "properties": {"kind": "track", "zonecraftLayer": 0, "label": "hike"},
     "geometry": {"type": "LineString",
                  "coordinates": [[11.0, 48.0], [11.1, 48.1]]}},
    {"type": "Feature",
     "properties": {"kind": "height", "zonecraftLayer": 1,
                    "radiusMeters": 5000, "thresholdMeters": 900},
     "geometry": {"type": "Point", "coordinates": [11.0, 47.5]}}
  ]
}
''';
    final data = importFromGeoJson(v1);
    expect(data, isNotNull);
    expect(
      data!.layers,
      hasLength(1),
      reason: 'the track layer is dropped: the type is gone',
    );
    expect(data.layers.single.type, 'height');
    expect(data.layers.first.isVisible, isNull, reason: 'absent = shown');
    expect(await repo.importData(data), 1);

    final layers = await repo.watchLayers().first;
    expect(layers.every((l) => l.isVisible), isTrue);
    expect(layers.map((l) => l.type), isNot(contains('track')));
    // A v1 height region carried no fills, so it stays ungenerated — the user
    // taps Generate, exactly as before.
    final region = (await repo.watchAllHeightRegions().first).single;
    expect(region.generatedAt, isNull);
    expect(await repo.watchAllHeightPolygons().first, isEmpty);
  });
}

/// One area of the shape `addBorderSet` takes, with a 4-point square ring.
({
  int osmId,
  String? name,
  double south,
  double west,
  double north,
  double east,
  double labelLat,
  double labelLng,
  int pointCount,
  String rings,
  List<int> wayIds,
})
_area(int id, String name, List<int> wayIds) => (
  osmId: id,
  name: name,
  south: 48.0,
  west: 11.0,
  north: 48.1,
  east: 11.1,
  labelLat: 48.05,
  labelLng: 11.05,
  pointCount: 4,
  rings: '[[[48.0,11.0],[48.0,11.1],[48.1,11.1],[48.1,11.0]]]',
  wayIds: wayIds,
);

// --- reading a layer's elements straight out of the tables -----------------

/// Every element of [layer] as plain data, sorted so two databases holding the
/// same rows compare equal regardless of row order.
/// The seeded layer id for [key]. Throws rather than yielding null, so a
/// renamed seed fails loudly instead of quietly exporting *every* layer.
String _id(Map<String, String> ids, String key) =>
    ids[key] ?? (throw StateError('seedEverything() seeded no "$key" layer'));

/// The object rows of one snapshot layer, typed — `snapshot()` and `reimport()`
/// both yield `Map<String, Object?>` rows under `objects`.
/// (Distinct from [_rows], which reads a Drift table.)
List<Map<String, Object?>> _objRows(Map<String, Object?> layer) =>
    (layer['objects']! as List).cast<Map<String, Object?>>();

Future<List<Map<String, Object?>>> _objectsOf(
  AppDatabase db,
  Layer layer,
) async {
  final out = <Map<String, Object?>>[];
  // Mirrors the app: a combined layer is snapshotted one content type at a
  // time, so the round-trip covers every table it holds rather than none.
  for (final type in layerContentTypesOf(layer.type)) {
    switch (type) {
      case 'circles':
        for (final c in await _rows(db, db.circles, layer.id)) {
          out.add({
            'lat': c.centerLat,
            'lng': c.centerLng,
            'radiusMeters': c.radiusMeters,
            'label': c.label,
            'colorArgb': c.colorArgb,
            'colorShade': c.colorShade,
          });
        }
      case 'subspace':
        final pts = await (db.select(
          db.subspacePoints,
        )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
        for (final s in await _rows(db, db.subspaces, layer.id)) {
          out.add({
            'label': s.label,
            'colorArgb': s.colorArgb,
            'colorShade': s.colorShade,
            'points': [
              for (final p in pts.where((p) => p.subspaceId == s.id))
                {
                  'at': [p.lat, p.lng],
                  'isMain': p.isMain,
                  'label': p.label,
                },
            ],
          });
        }
      case 'freeline':
        final pts = await (db.select(
          db.freeLinePoints,
        )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
        for (final l in await _rows(db, db.freeLines, layer.id)) {
          out.add({
            'label': l.label,
            'offsetMeters': l.offsetMeters,
            'inclusion': [
              l.inclusionLat,
              l.inclusionLng,
              l.inclusionRadiusMeters,
            ],
            'colorArgb': l.colorArgb,
            'colorShade': l.colorShade,
            'points': [
              for (final p in pts.where((p) => p.freeLineId == l.id))
                [p.lat, p.lng],
            ],
          });
        }
      case 'freearea':
        final pts = await (db.select(
          db.freeAreaPoints,
        )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
        for (final a in await _rows(db, db.freeAreas, layer.id)) {
          out.add({
            'label': a.label,
            'offsetMeters': a.offsetMeters,
            'colorArgb': a.colorArgb,
            'colorShade': a.colorShade,
            'points': [
              for (final p in pts.where((p) => p.freeAreaId == a.id))
                [p.lat, p.lng],
            ],
          });
        }
      case 'height':
        final polys = await (db.select(
          db.heightPolygons,
        )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
        final pts = await (db.select(
          db.heightPolygonPoints,
        )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
        for (final r in await _rows(db, db.heightRegions, layer.id)) {
          out.add({
            'at': [r.centerLat, r.centerLng],
            'radiusMeters': r.radiusMeters,
            'thresholdMeters': r.thresholdMeters,
            'aboveThreshold': r.aboveThreshold,
            'sampleZoom': r.sampleZoom,
            'label': r.label,
            'colorArgb': r.colorArgb,
            'colorShade': r.colorShade,
            'generated': r.generatedAt != null,
            'fills': [
              for (final poly in polys.where((p) => p.heightRegionId == r.id))
                [
                  for (final p in pts.where((x) => x.polygonId == poly.id))
                    [p.lat, p.lng],
                ],
            ],
          });
        }
      case 'poi':
        final pts = await (db.select(
          db.poiPoints,
        )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
        for (final s in await _rows(db, db.poiSets, layer.id)) {
          out.add({
            'categoryKey': s.categoryKey,
            'at': [s.centerLat, s.centerLng],
            'radiusMeters': s.radiusMeters,
            'label': s.label,
            'colorArgb': s.colorArgb,
            'colorShade': s.colorShade,
            // v25/v27: the kind of set. In the snapshot, so the whole-database
            // round-trip catches a manual set coming back as an import — or a
            // station import coming back as a radius one — without anyone
            // having to write a test for it.
            'source': s.source,
            'iconKey': s.iconKey,
            'bbox': s.bbox,
            'modeMask': s.modeMask,
            'visibleModeMask': s.visibleModeMask,
            'pending': s.isPending,
            'lastError': s.lastError,
            'points': [
              for (final p in pts.where((p) => p.poiSetId == s.id))
                {
                  'at': [p.lat, p.lng],
                  'name': p.name,
                  'osmType': p.osmType,
                  'osmId': p.osmId,
                  'modeMask': p.modeMask,
                },
            ],
          });
        }
      case 'borders':
        final sets = await (db.select(
          db.borderSets,
        )..where((s) => s.layerId.equals(layer.id))).get();
        final areas = await db.select(db.borderAreas).get();
        for (final s in sets) {
          out.add({
            'box': [s.south, s.west, s.north, s.east],
            'adminLevel': s.adminLevel,
            'label': s.label,
            'areaCount': s.areaCount,
            'pointCount': s.pointCount,
            'areas': _sorted([
              for (final a in areas.where((a) => a.setId == s.id))
                {
                  'osmId': a.osmId,
                  'name': a.name,
                  'colorIndex': a.colorIndex,
                  'bounds': [a.south, a.west, a.north, a.east],
                  'labelLat': a.labelLat,
                  'labelLng': a.labelLng,
                  'pointCount': a.pointCount,
                  'rings': a.rings,
                  'wayIds': a.wayIds,
                  'edited': a.editedAt != null,
                  'colorArgb': a.colorArgb,
                },
            ]),
          });
        }
    }
  }
  return _sorted(out);
}

/// A layer's element rows, in insertion order (which is what `colorShade`
/// counts and what the export writes).
Future<List<D>> _rows<T extends Table, D>(
  AppDatabase db,
  TableInfo<T, D> table,
  String layerId,
) async {
  final rows = await db
      .customSelect(
        'SELECT * FROM ${table.actualTableName} WHERE layer_id = ? '
        'ORDER BY rowid',
        variables: [Variable<String>(layerId)],
        readsFrom: {table},
      )
      .get();
  return [for (final r in rows) await table.map(r.data)];
}

/// Content-sorted, so two databases holding the same rows in a different
/// physical order still compare equal.
List<Map<String, Object?>> _sorted(List<Map<String, Object?>> items) {
  final copy = [...items];
  copy.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  return copy;
}
