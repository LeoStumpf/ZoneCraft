import 'dart:convert';

import 'package:drift/drift.dart'
    show OrderingTerm, Table, TableInfo, Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/overpass.dart' show PoiResult;
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
    ids['circles'] =
        await repo.createLayer(name: 'Circles', colorArgb: 0xFF2196F3);
    final c1 = await repo.createCircle(
        layerId: ids['circles']!,
        centerLat: 48.137,
        centerLng: 11.575,
        radiusMeters: 1500,
        label: 'home');
    await repo.setElementColor(ColoredElement.circle, c1, 0xFFEF5350);
    await repo.createCircle(
        layerId: ids['circles']!,
        centerLat: 48.2,
        centerLng: 11.6,
        radiusMeters: 800);
    await repo.updateLayer(ids['circles']!, opacity: 0.31);

    // planes — inverted layer.
    ids['planes'] = await repo.createLayer(
        name: 'Planes', colorArgb: 0xFFEF5350, type: 'planes');
    await repo.createPlane(
        layerId: ids['planes']!,
        aLat: 48.0,
        aLng: 11.0,
        bLat: 48.5,
        bLng: 11.9,
        nearA: false,
        label: 'A|B');
    await repo.updateLayer(ids['planes']!, isInverted: true);

    // subspace — a main point that is not the first, and named seeds.
    ids['subspace'] = await repo.createLayer(
        name: 'Subspace', colorArgb: 0xFF66BB6A, type: 'subspace');
    final sub =
        await repo.createSubspace(layerId: ids['subspace']!, label: 'cells');
    await repo.addSubspacePoint(
        subspaceId: sub, lat: 48.0, lng: 11.0, label: 'north');
    await repo.addSubspacePoint(subspaceId: sub, lat: 48.1, lng: 11.2);
    await repo.addSubspacePoint(
        subspaceId: sub, lat: 47.9, lng: 11.1, isMain: true, label: 'mine');

    // freeline — an offset and an explicit inclusion circle, and vertices
    // closer together than the 10 m import thinning would keep.
    ids['freeline'] = await repo.createLayer(
        name: 'Lines', colorArgb: 0xFFAB47BC, type: 'freeline');
    final line = await repo.createFreeLine(
      layerId: ids['freeline']!,
      label: 'the wall',
      inclusionLat: 48.05,
      inclusionLng: 11.1,
      inclusionRadiusMeters: 9000,
    );
    await repo.updateFreeLine(line, offsetMeters: -250);
    await repo.addFreeLinePoints(line, [
      for (var i = 0; i < 12; i++) LatLng(48.0 + i * 0.00004, 11.0 + i * 0.00004),
    ]);

    // freearea — likewise dense, plus a positive offset.
    ids['freearea'] = await repo.createLayer(
        name: 'Areas', colorArgb: 0xFFFFA726, type: 'freearea');
    final area =
        await repo.createFreeArea(layerId: ids['freearea']!, label: 'the park');
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
        name: 'Height', colorArgb: 0xFF8D6E63, type: 'height');
    final region = await repo.createHeightRegion(
      layerId: ids['height']!,
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

    // track — two segments (a recording with a pause) and non-default options.
    ids['track'] =
        await repo.createLayer(name: 'Track', colorArgb: 0xFF26A69A, type: 'track');
    await repo.updateTrackLayerOptions(ids['track']!,
        strokeWidth: 7.5, minDistanceMeters: 25);
    final track = await repo.ensureTrackForLayer(ids['track']!);
    await repo.updateTrack(track, label: const Value('morning run'));
    await repo.addTrackPoints(
      track,
      [
        for (var i = 0; i < 8; i++)
          LatLng(48.10 + i * 0.00003, 11.50 + i * 0.00003),
      ],
      segmentIndex: 0,
    );
    await repo.addTrackPoints(
      track,
      [LatLng(48.30, 11.70), LatLng(48.31, 11.71), LatLng(48.32, 11.70)],
      segmentIndex: 1,
    );
    // A segment of one point: the recorder got a fix and then nothing before
    // the next gap. It draws no line, but it is a real recorded position and
    // it moves the track's bounds — found on a real device database, where an
    // import dropped it.
    await repo.addTrackPoints(track, [LatLng(48.40, 11.90)], segmentIndex: 2);

    // poi — POIs that carry their OSM identity, and one that never had any.
    ids['poi'] =
        await repo.createLayer(name: 'POIs', colorArgb: 0xFF00ACC1, type: 'poi');
    final poiSet = await repo.createPoiSet(
      layerId: ids['poi']!,
      categoryKey: 'cafe',
      centerLat: 48.137,
      centerLng: 11.575,
      radiusMeters: 2000,
      label: 'Cafés',
    );
    await repo.addPoiPoints(poiSet, const [
      PoiResult(
          lat: 48.14,
          lng: 11.58,
          categoryKey: 'cafe',
          name: 'Café A',
          osmType: 'node',
          osmId: 240109189),
      PoiResult(
          lat: 48.13,
          lng: 11.57,
          categoryKey: 'cafe',
          name: null,
          osmType: 'way',
          osmId: 240109189),
      PoiResult(lat: 48.12, lng: 11.56, categoryKey: 'cafe', name: 'Café C'),
    ]);
    // …and a **hand-made** category on the same layer. A manual set is the one
    // POI set with no query behind it: radius 0, its own icon, and points that
    // never had an OSM identity. All of that has to come back as *manual*, or
    // an editable category silently returns as a read-only import claiming a
    // search that never ran.
    final manualSet = await repo.createPoiSet(
      layerId: ids['poi']!,
      categoryKey: 'peak',
      centerLat: 48.10,
      centerLng: 11.50,
      radiusMeters: 0,
      label: 'Swimming spots',
      isManual: true,
      iconKey: 'peak',
    );
    await repo.addManualPoiPoint(
        poiSetId: manualSet, lat: 48.101, lng: 11.501, label: 'The rope swing');
    await repo.addManualPoiPoint(
        poiSetId: manualSet, lat: 48.102, lng: 11.502);

    // transit — one filled import and one that failed (a retry row).
    ids['transit'] = await repo.createLayer(
        name: 'Transit', colorArgb: 0xFF7E57C2, type: 'transit');
    final filled = await repo.createPendingTransitSet(
      layerId: ids['transit']!,
      south: 48.00,
      west: 11.30,
      north: 48.30,
      east: 11.80,
      modeMask: transitAllModesMask,
      visibleModeMask: transitModeByKey('subway')!.bit,
      label: 'München',
    );
    await repo.fillTransitSet(filled, [
      (
        osmId: 1,
        lat: 48.14,
        lng: 11.46,
        name: 'Pasing Bahnhof',
        modeMask:
            transitModeByKey('bus')!.bit | transitModeByKey('train')!.bit,
        nodeCount: 31,
        routeRef: null,
      ),
      (
        osmId: 2,
        lat: 48.13,
        lng: 11.57,
        name: 'Marienplatz',
        modeMask: transitModeByKey('subway')!.bit,
        nodeCount: 4,
        routeRef: 'U3;U6',
      ),
    ]);
    final failed = await repo.createPendingTransitSet(
      layerId: ids['transit']!,
      south: 49.0,
      west: 12.0,
      north: 49.5,
      east: 12.5,
      modeMask: transitModeByKey('train')!.bit,
      visibleModeMask: -1,
      label: 'Regensburg',
    );
    await repo.markTransitImportFailed(failed, 'Overpass was busy');

    // borders — a named import, one area reshaped by hand (so it is a fork),
    // and the display toggles on. Hidden, to prove that survives too.
    ids['borders'] = await repo.createLayer(
        name: 'Borders',
        colorArgb: 0xFF123456,
        type: 'borders',
        borderLevel: '8');
    await repo.updateBorderLayerOptions(ids['borders']!,
        fillAreas: true, showNames: true);
    await repo.addBorderSet(
      layerId: ids['borders']!,
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
    final munich = (await repo.watchAllBorderAreas().first)
        .firstWhere((a) => a.osmId == 1);
    await repo.reshapeBorderArea(munich.id, [
      [
        const LatLng(48.0, 11.0),
        const LatLng(48.0, 11.15),
        const LatLng(48.1, 11.15),
        const LatLng(48.1, 11.0),
      ],
    ]);
    await repo.updateBorderArea(munich.id, labelLat: 48.02, labelLng: 11.07);
    await repo.updateLayer(ids['borders']!, isVisible: false);

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
    final layers = await (db.select(db.layers)
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)]))
        .get();
    final out = <Map<String, Object?>>[];
    for (final l in layers) {
      out.add({
        'name': l.name,
        'colorArgb': l.colorArgb,
        'type': l.type,
        'isVisible': l.isVisible,
        'isInverted': l.isInverted,
        'opacity': l.opacity,
        'borderLevel': l.borderLevel,
        'borderFillAreas': l.borderFillAreas,
        'borderShowNames': l.borderShowNames,
        'trackStrokeWidth': l.trackStrokeWidth,
        'trackMinDistanceMeters': l.trackMinDistanceMeters,
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
    final layers = await (fresh.select(fresh.layers)
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)]))
        .get();
    final out = <Map<String, Object?>>[];
    for (final l in layers) {
      out.add({
        'name': l.name,
        'colorArgb': l.colorArgb,
        'type': l.type,
        'isVisible': l.isVisible,
        'isInverted': l.isInverted,
        'opacity': l.opacity,
        'borderLevel': l.borderLevel,
        'borderFillAreas': l.borderFillAreas,
        'borderShowNames': l.borderShowNames,
        'trackStrokeWidth': l.trackStrokeWidth,
        'trackMinDistanceMeters': l.trackMinDistanceMeters,
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
    expect(before, hasLength(10), reason: 'one layer of every type');

    final after = await reimport(await repo.exportData());
    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(after[i], before[i],
          reason: 'layer ${before[i]['name']} (${before[i]['type']}) '
              'did not come back the same');
    }
  });

  test('every layer survives an export/import of that layer alone', () async {
    final ids = await seedEverything();
    final before = await snapshot();

    for (final entry in ids.entries) {
      final mine = before.firstWhere((l) => l['type'] == entry.key);
      final after = await reimport(await repo.exportData(onlyLayerId: entry.value));
      expect(after, hasLength(1), reason: '${entry.key}: one layer in, one out');
      expect(after.single, mine,
          reason: 'the single-layer export of ${entry.key} lost something');
    }
  });

  test('export is a fixed point: export -> import -> export is identical',
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
  });

  test('a hidden layer comes back hidden', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: ids['borders']!);
    expect(data.layers.single.isVisible, isFalse);
    final after = await reimport(data);
    expect(after.single['isVisible'], isFalse);
  });

  test('a generated height layer comes back drawn, not blank', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: ids['height']!);
    final o = data.layers.single.objects.single;
    expect(o.generated, isTrue);
    expect(o.heightRings, hasLength(2));
    expect(o.thresholdMeters, 1850.5);
    expect(o.aboveThreshold, isFalse);
    expect(o.sampleZoom, 14);

    final after = await reimport(data);
    final region = (after.single['objects'] as List).single as Map;
    expect(region['generated'], isTrue,
        reason: 'an imported height layer that has to be regenerated by hand '
            'draws nothing at all, which is what "the layer is empty" was');
    expect(region['fills'], hasLength(2));
  });

  test("a track's pauses survive as breaks, not as a straight jump", () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: ids['track']!);
    final o = data.layers.single.objects.single;
    expect(o.segments, hasLength(3));
    expect(o.segments!.first, hasLength(8));
    expect(o.segments!.last, hasLength(1), reason: 'a lone fix is still data');

    // A MultiLineString, so every other tool draws the break too.
    final gj = jsonDecode(exportToGeoJson(data)) as Map<String, dynamic>;
    expect(
      ((gj['features'] as List).single as Map)['geometry']['type'],
      'MultiLineString',
    );

    final after = await reimport(data);
    final track = (after.single['objects'] as List).single as Map;
    final segs = (track['points'] as List)
        .map((p) => (p as Map)['segmentIndex'])
        .toSet();
    expect(segs, hasLength(3));
  });

  test('freehand geometry is not thinned by our own round-trip', () async {
    final ids = await seedEverything();
    final before = await snapshot();
    final line = before.firstWhere((l) => l['type'] == 'freeline');
    final vertices =
        ((line['objects'] as List).single as Map)['points'] as List;
    expect(vertices, hasLength(12));

    final after = await reimport(await repo.exportData(onlyLayerId: ids['freeline']!));
    expect(((after.single['objects'] as List).single as Map)['points'],
        hasLength(12),
        reason: 'the 10 m RDP pass belongs to generic files, not to ours');
  });

  test('a generic file is still thinned on import', () async {
    // The other half of the same rule: a GPX full of GPS jitter still gets the
    // RDP pass, which is what `simplify` defaults to.
    final layerId = await repo.createLayer(
        name: 'L', colorArgb: 0xFF000000, type: 'freeline');
    await repo.mergeIntoLayer(
      layerId,
      ExportLayer(
        name: 'L',
        colorArgb: 0xFF000000,
        type: 'freeline',
        isInverted: false,
        objects: [
          ExportObject(kind: 'freeline', coords: [
            for (var i = 0; i < 12; i++)
              LatLng(48.0 + i * 0.00004, 11.0 + i * 0.00004),
          ]),
        ],
      ),
    );
    final pts = await repo.watchAllFreeLinePoints().first;
    expect(pts.length, lessThan(12));
  });

  test('imported POIs keep their OSM identity, so a re-import dedups',
      () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: ids['poi']!);
    // The layer holds two sets: the Overpass import and a hand-made category.
    final o = data.layers.single.objects
        .firstWhere((o) => o.manual != true);
    expect(o.pointOsmIds, [240109189, 240109189, 0]);
    expect(o.pointOsmTypes, ['node', 'way', null]);

    // Merging the file back into the layer it came from re-creates the sets but
    // adds no *identified* POI: these are the same ones, and node 240109189 is
    // not way 240109189.
    expect(await repo.mergeIntoLayer(ids['poi']!, data.layers.single,
        simplify: false), 2);
    final points = await repo.watchAllPoiPoints().first;
    expect(points.where((p) => p.osmId != null), hasLength(2),
        reason: 'the two identified POIs were recognised, not drawn twice');
    // Everything unidentified has nothing to match on and is kept, as always:
    // the import's third POI plus the two hand-placed ones, twice over.
    expect(points.where((p) => p.osmId == null), hasLength(6));
  });

  test('a hand-made POI category comes back hand-made, not as an import',
      () async {
    // The distinction is the whole feature: a manual set is editable, takes
    // hand-placed points and describes no search, while an import is a
    // read-only snapshot. A manual set returning as an import would be a silent
    // demotion — and its radius 0 would start being shown as a search area.
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: ids['poi']!);
    final o = data.layers.single.objects.firstWhere((o) => o.manual == true);
    expect(o.iconKey, 'peak');
    expect(o.label, 'Swimming spots');
    expect(o.radiusMeters, 0, reason: '0 is the value, not a missing one');
    expect(o.pointLabels, ['The rope swing', null]);
    expect(o.pointOsmIds, isNull,
        reason: 'hand-placed points have no upstream to be identified against');

    final after = await reimport(data);
    final sets = after.single['objects'] as List;
    final manual = sets.firstWhere((s) => (s as Map)['isManual'] == true) as Map;
    expect(manual['iconKey'], 'peak');
    expect(manual['label'], 'Swimming spots');
    expect(manual['radiusMeters'], 0);

    // And the import on the same layer is *not* flagged, which is what stops
    // "manual" from being a field that quietly defaults to true.
    final imported =
        sets.firstWhere((s) => (s as Map)['isManual'] == false) as Map;
    expect(imported['categoryKey'], 'cafe');
    expect(imported['iconKey'], isNull);
  });

  test('a failed transit import comes back as a retry row', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: ids['transit']!);
    expect(data.layers.single.objects, hasLength(2));
    final failed =
        data.layers.single.objects.firstWhere((o) => o.pending == true);
    expect(failed.coords, isEmpty);
    expect(failed.errorMessage, 'Overpass was busy');
    expect(failed.bbox, [49.0, 12.0, 49.5, 12.5]);

    final after = await reimport(data);
    final sets = after.single['objects'] as List;
    expect(sets, hasLength(2));
    final retry = sets.firstWhere((s) => (s as Map)['pending'] == true) as Map;
    expect(retry['lastError'], 'Overpass was busy');
    expect(retry['label'], 'Regensburg');
  });

  test('a border import keeps its own name and its edited areas', () async {
    final ids = await seedEverything();
    final data = await repo.exportData(onlyLayerId: ids['borders']!);
    final munich =
        data.layers.single.objects.firstWhere((o) => o.label == 'München');
    expect(munich.setLabel, 'Around Munich');
    expect(munich.edited, isTrue);
    expect(munich.labelLat, 48.02);

    final after = await reimport(data);
    final sets = after.single['objects'] as List;
    expect(sets.single, isA<Map>());
    expect((sets.single as Map)['label'], 'Around Munich');
    final areas = (sets.single as Map)['areas'] as List;
    final m = areas.firstWhere((a) => (a as Map)['name'] == 'München') as Map;
    expect(m['edited'], isTrue);
    expect(m['labelLat'], 48.02);
  });

  test('border areas with no relation id all survive a re-import', () async {
    // 0 is the placeholder an id-less import is stored with. Treated as a real
    // OSM id it made every such area look like the same relation, so dedup kept
    // one and dropped the rest.
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
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
    expect((after.single['objects'] as List).single, isA<Map>());
    expect(
      ((after.single['objects'] as List).single as Map)['areas'],
      hasLength(3),
    );
  });

  test('a v1 file still imports, with the v1 defaults', () async {
    // Everything shipped before schema v2: no isVisible, a LineString track,
    // a height region with no fills.
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
    expect(data!.layers, hasLength(2));
    expect(data.layers.first.isVisible, isNull, reason: 'absent = shown');
    expect(await repo.importData(data), 2);

    final layers = await repo.watchLayers().first;
    expect(layers.every((l) => l.isVisible), isTrue);
    // A v1 track is one unbroken segment.
    final pts = await repo.watchAllTrackPoints().first;
    expect(pts.map((p) => p.segmentIndex).toSet(), {0});
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
}) _area(int id, String name, List<int> wayIds) => (
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
Future<List<Map<String, Object?>>> _objectsOf(
    AppDatabase db, Layer layer) async {
  final out = <Map<String, Object?>>[];
  switch (layer.type) {
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
    case 'planes':
      for (final p in await _rows(db, db.planes, layer.id)) {
        out.add({
          'a': [p.aLat, p.aLng],
          'b': [p.bLat, p.bLng],
          'nearA': p.nearA,
          'label': p.label,
          'colorArgb': p.colorArgb,
          'colorShade': p.colorShade,
        });
      }
    case 'subspace':
      final pts = await (db.select(db.subspacePoints)
            ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();
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
      final pts = await (db.select(db.freeLinePoints)
            ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();
      for (final l in await _rows(db, db.freeLines, layer.id)) {
        out.add({
          'label': l.label,
          'offsetMeters': l.offsetMeters,
          'inclusion': [l.inclusionLat, l.inclusionLng, l.inclusionRadiusMeters],
          'colorArgb': l.colorArgb,
          'colorShade': l.colorShade,
          'points': [
            for (final p in pts.where((p) => p.freeLineId == l.id))
              [p.lat, p.lng],
          ],
        });
      }
    case 'freearea':
      final pts = await (db.select(db.freeAreaPoints)
            ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();
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
    case 'track':
      final pts = await (db.select(db.trackPoints)
            ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();
      for (final t in await _rows(db, db.tracks, layer.id)) {
        final mine = pts.where((p) => p.trackId == t.id).toList();
        // Segment *numbering* is a running counter, so compare the breaks the
        // painter reads rather than the ids they happen to have.
        final ranks = <int, int>{};
        for (final p in mine) {
          ranks.putIfAbsent(p.segmentIndex, () => ranks.length);
        }
        out.add({
          'label': t.label,
          'colorArgb': t.colorArgb,
          'colorShade': t.colorShade,
          'bounds': [t.south, t.west, t.north, t.east],
          'points': [
            for (final p in mine)
              {
                'at': [p.lat, p.lng],
                'segmentIndex': ranks[p.segmentIndex],
              },
          ],
        });
      }
    case 'height':
      final polys = await (db.select(db.heightPolygons)
            ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();
      final pts = await (db.select(db.heightPolygonPoints)
            ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();
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
      final pts = await (db.select(db.poiPoints)
            ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
          .get();
      for (final s in await _rows(db, db.poiSets, layer.id)) {
        out.add({
          'categoryKey': s.categoryKey,
          'at': [s.centerLat, s.centerLng],
          'radiusMeters': s.radiusMeters,
          'label': s.label,
          'colorArgb': s.colorArgb,
          'colorShade': s.colorShade,
          // v25: hand-made categories. In the snapshot, so the whole-database
          // round-trip catches a manual set coming back as an import without
          // anyone having to write a test for it.
          'isManual': s.isManual,
          'iconKey': s.iconKey,
          'points': [
            for (final p in pts.where((p) => p.poiSetId == s.id))
              {
                'at': [p.lat, p.lng],
                'name': p.name,
                'osmType': p.osmType,
                'osmId': p.osmId,
              },
          ],
        });
      }
    case 'transit':
      final stops = await db.select(db.transitStops).get();
      for (final t in await _rows(db, db.transitSets, layer.id)) {
        out.add({
          'box': [t.south, t.west, t.north, t.east],
          'modeMask': t.modeMask,
          'visibleModeMask': t.visibleModeMask,
          'label': t.label,
          'pending': t.fetchedAt == null,
          'lastError': t.lastError,
          'stationCount': t.stationCount,
          'nodeCount': t.nodeCount,
          'colorArgb': t.colorArgb,
          'colorShade': t.colorShade,
          'stops': _sorted([
            for (final x in stops.where((x) => x.setId == t.id))
              {
                'osmId': x.osmId,
                'at': [x.lat, x.lng],
                'name': x.name,
                'modeMask': x.modeMask,
                'nodeCount': x.nodeCount,
                'routeRef': x.routeRef,
              },
          ]),
        });
      }
    case 'borders':
      final sets = await (db.select(db.borderSets)
            ..where((s) => s.layerId.equals(layer.id)))
          .get();
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
  return _sorted(out);
}

/// A layer's element rows, in insertion order (which is what `colorShade`
/// counts and what the export writes).
Future<List<D>> _rows<T extends Table, D>(
    AppDatabase db, TableInfo<T, D> table, String layerId) async {
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
