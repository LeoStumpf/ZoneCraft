import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/overpass.dart' show PoiResult;
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/serialization.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/geo/border_areas.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  test('v2 schema: layer carries type and isInverted with defaults', () async {
    final id = await repo.createLayer(name: 'L', colorArgb: 0xFF0000FF);
    final layer = await (db.select(db.layers)..where((l) => l.id.equals(id)))
        .getSingle();
    expect(layer.type, 'circles');
    expect(layer.isInverted, isFalse);

    await repo.updateLayer(id, isInverted: true);
    final updated = await (db.select(db.layers)..where((l) => l.id.equals(id)))
        .getSingle();
    expect(updated.isInverted, isTrue);
  });

  test('planes table CRUD works', () async {
    final layerId =
        await repo.createLayer(name: 'P', colorArgb: 0xFF00FF00, type: 'planes');
    final planeId = await repo.createPlane(
      layerId: layerId,
      aLat: 48.1,
      aLng: 11.5,
      bLat: 48.2,
      bLng: 11.6,
    );
    var planes = await repo.watchAllPlanes().first;
    expect(planes, hasLength(1));
    expect(planes.single.nearA, isTrue);

    await repo.updatePlane(planeId, nearA: false);
    planes = await repo.watchAllPlanes().first;
    expect(planes.single.nearA, isFalse);

    // Deleting the layer cascades to its planes.
    await repo.deleteLayer(layerId);
    expect(await repo.watchAllPlanes().first, isEmpty);
  });

  test('subspace points: CRUD, single main, ordering, layer cascade', () async {
    final layerId = await repo.createLayer(
        name: 'S', colorArgb: 0xFF112233, type: 'subspace');
    final subId = await repo.createSubspace(layerId: layerId);
    final p1 = await repo.addSubspacePoint(
        subspaceId: subId, lat: 48.1, lng: 11.5, isMain: true);
    final p2 =
        await repo.addSubspacePoint(subspaceId: subId, lat: 48.2, lng: 11.6);

    var pts = await repo.watchAllSubspacePoints().first;
    expect(pts, hasLength(2));
    expect(pts.map((p) => p.sortOrder), [0, 1]); // appended in order
    expect(pts.where((p) => p.isMain).map((p) => p.id), [p1]);

    // setMainPoint keeps exactly one main.
    await repo.setMainPoint(subId, p2);
    pts = await repo.watchAllSubspacePoints().first;
    expect(pts.where((p) => p.isMain).map((p) => p.id), [p2]);

    await repo.deleteSubspacePoint(p1);
    expect(await repo.watchAllSubspacePoints().first, hasLength(1));

    // Deleting the layer cascades to the subspace and its points.
    await repo.deleteLayer(layerId);
    expect(await repo.watchAllSubspaces().first, isEmpty);
    expect(await repo.watchAllSubspacePoints().first, isEmpty);
  });

  test('import simplifies heavy freeline/freearea geometry', () async {
    // A 50-point meridian (all collinear on a great circle) and a padded square.
    final densLine = [for (var i = 0; i < 50; i++) LatLng(48.0 + i * 0.001, 11.0)];
    final squareRing = <LatLng>[];
    const corners = [
      LatLng(48.0, 11.0),
      LatLng(48.0, 11.02),
      LatLng(48.02, 11.02),
      LatLng(48.02, 11.0),
    ];
    for (var e = 0; e < 4; e++) {
      final c0 = corners[e];
      final c1 = corners[(e + 1) % 4];
      for (var k = 0; k < 5; k++) {
        squareRing.add(LatLng(
          c0.latitude + (c1.latitude - c0.latitude) * k / 5,
          c0.longitude + (c1.longitude - c0.longitude) * k / 5,
        ));
      }
    }

    await repo.importData(ExportData([
      ExportLayer(
        name: 'line',
        colorArgb: 0xFF00FF00,
        type: 'freeline',
        isInverted: false,
        objects: [ExportObject(kind: 'freeline', coords: densLine)],
      ),
      ExportLayer(
        name: 'area',
        colorArgb: 0xFF0000FF,
        type: 'freearea',
        isInverted: false,
        objects: [ExportObject(kind: 'freearea', coords: squareRing)],
      ),
    ]));

    final linePts = await repo.watchAllFreeLinePoints().first;
    expect(linePts, hasLength(2)); // collinear -> just the endpoints
    final areaPts = await repo.watchAllFreeAreaPoints().first;
    expect(areaPts.length, lessThan(squareRing.length)); // corners only (~4)
    expect(areaPts.length, greaterThanOrEqualTo(3));
  });

  test('combineLayers re-points objects into the target and deletes the source',
      () async {
    final a = await repo.createLayer(name: 'A', colorArgb: 0xFF0000FF);
    final b = await repo.createLayer(name: 'B', colorArgb: 0xFF00FF00);
    await repo.createCircle(
        layerId: a, centerLat: 48.1, centerLng: 11.5, radiusMeters: 100);
    await repo.createCircle(
        layerId: a, centerLat: 48.2, centerLng: 11.6, radiusMeters: 200);
    await repo.createCircle(
        layerId: b, centerLat: 48.3, centerLng: 11.7, radiusMeters: 300);

    await repo.combineLayers(sourceId: a, targetId: b);

    // Source layer gone, target remains.
    final layers = await repo.watchLayers().first;
    expect(layers.map((l) => l.id), [b]);
    // All three circles now belong to the target.
    final circles = await repo.watchAllCircles().first;
    expect(circles, hasLength(3));
    expect(circles.every((c) => c.layerId == b), isTrue);
  });

  test('combineLayers keeps child rows and rejects a type mismatch', () async {
    final a = await repo.createLayer(
        name: 'LineA', colorArgb: 0xFF0000FF, type: 'freeline');
    final b = await repo.createLayer(
        name: 'LineB', colorArgb: 0xFF00FF00, type: 'freeline');
    final lineA = await repo.createFreeLine(layerId: a);
    await repo.addFreeLinePoints(
        lineA, [const LatLng(48.0, 11.0), const LatLng(48.1, 11.1)]);
    final lineB = await repo.createFreeLine(layerId: b);
    await repo.addFreeLinePoints(
        lineB, [const LatLng(49.0, 12.0), const LatLng(49.1, 12.1)]);

    await repo.combineLayers(sourceId: a, targetId: b);

    final lines = await repo.watchAllFreeLines().first;
    expect(lines, hasLength(2));
    expect(lines.every((l) => l.layerId == b), isTrue);
    // Child points followed their parent line (4 total, intact).
    expect(await repo.watchAllFreeLinePoints().first, hasLength(4));

    // A different-type target is rejected.
    final circleLayer = await repo.createLayer(name: 'C', colorArgb: 0xFF112233);
    expect(
      () => repo.combineLayers(sourceId: b, targetId: circleLayer),
      throwsArgumentError,
    );
  });

  test('settings default to 500 and persist updates', () async {
    expect((await repo.watchSettings().first).uncertaintyMeters, 500);
    await repo.updateUncertainty(250);
    expect((await repo.watchSettings().first).uncertaintyMeters, 250);
  });

  test('layer opacity defaults per type and updates', () async {
    // Region layers default to a translucent fill; POI layers to fully opaque.
    final region = await repo.createLayer(name: 'L', colorArgb: 0xFF0000FF);
    final poi =
        await repo.createLayer(name: 'P', colorArgb: 0xFF00FF00, type: 'poi');
    Future<Layer> row(String id) =>
        (db.select(db.layers)..where((l) => l.id.equals(id))).getSingle();
    expect((await row(region)).opacity, kDefaultRegionLayerOpacity);
    expect((await row(poi)).opacity, 1.0);

    await repo.updateLayer(region, opacity: 1.0);
    final updated = await row(region);
    expect(updated.opacity, 1.0);
    // Opacity edits must not disturb the other attributes.
    expect(updated.colorArgb, 0xFF0000FF);
    expect(updated.isVisible, isTrue);
  });

  test('base-map settings default to visible/opaque and persist', () async {
    final initial = await repo.watchSettings().first;
    expect(initial.basemapVisible, isTrue);
    expect(initial.basemapOpacity, 1.0);
    await repo.updateUncertainty(600);
    await repo.updateBasemapVisible(false);
    await repo.updateBasemapOpacity(0.3);
    final saved = await repo.watchSettings().first;
    expect(saved.basemapVisible, isFalse);
    expect(saved.basemapOpacity, 0.3);
    // Base-map edits share the settings row — must not clobber uncertainty.
    expect(saved.uncertaintyMeters, 600);
  });

  test('clearAll wipes objects, resets settings, re-seeds a layer', () async {
    final layerId = await repo.createLayer(name: 'L', colorArgb: 0xFF0000FF);
    await repo.createCircle(
      layerId: layerId,
      centerLat: 48.1,
      centerLng: 11.5,
      radiusMeters: 100,
    );
    await repo.updateUncertainty(0);
    await repo.saveCamera(48.1, 11.5, 12);

    final seededId = await repo.clearAll();

    // Exactly one fresh layer, no objects left.
    final layers = await repo.watchLayers().first;
    expect(layers, hasLength(1));
    expect(layers.single.id, seededId);
    expect(await repo.watchAllCircles().first, isEmpty);
    expect(await repo.watchAllPlanes().first, isEmpty);

    // Settings revert to defaults: uncertainty 500, camera null.
    final settings = await repo.watchSettings().first;
    expect(settings.uncertaintyMeters, 500);
    expect(settings.poiCategories, 0);
    expect(settings.lastLat, isNull);
    expect(settings.lastZoom, isNull);
  });

  test('camera is null by default and persists, independent of uncertainty',
      () async {
    final initial = await repo.watchSettings().first;
    expect(initial.lastLat, isNull);
    expect(initial.lastZoom, isNull);

    await repo.updateUncertainty(500);
    await repo.saveCamera(48.137, 11.575, 12.5);
    final saved = await repo.watchSettings().first;
    expect(saved.lastLat, 48.137);
    expect(saved.lastLng, 11.575);
    expect(saved.lastZoom, 12.5);
    // saveCamera must not clobber the uncertainty (both live in the same row).
    expect(saved.uncertaintyMeters, 500);
  });

  test('poi sets: CRUD, layer-delete cascade and combineLayers', () async {
    final a = await repo.createLayer(name: 'A', colorArgb: 1, type: 'poi');
    final b = await repo.createLayer(name: 'B', colorArgb: 2, type: 'poi');
    final sid = await repo.createPoiSet(
      layerId: a,
      categoryKey: 'cafe',
      centerLat: 48.1,
      centerLng: 11.5,
      radiusMeters: 1500,
      label: 'Cafés',
    );
    await repo.addPoiPoints(sid, [
      PoiResult(lat: 48.11, lng: 11.51, categoryKey: 'cafe', name: 'Café A'),
      PoiResult(lat: 48.09, lng: 11.49, categoryKey: 'cafe', name: null),
    ]);
    expect((await repo.watchAllPoiSets().first).length, 1);
    expect((await repo.watchAllPoiPoints().first).length, 2);

    // Combine moves the set (and, via its FK, the points) to the target.
    await repo.combineLayers(sourceId: a, targetId: b);
    final sets = await repo.watchAllPoiSets().first;
    expect(sets.single.layerId, b);
    expect((await repo.watchAllPoiPoints().first).length, 2);

    // Deleting the layer cascades sets -> points away.
    await repo.deleteLayer(b);
    expect(await repo.watchAllPoiSets().first, isEmpty);
    expect(await repo.watchAllPoiPoints().first, isEmpty);
  });

  test('poi layer survives an export/import round-trip', () async {
    final layerId =
        await repo.createLayer(name: 'POIs', colorArgb: 3, type: 'poi');
    final sid = await repo.createPoiSet(
      layerId: layerId,
      categoryKey: 'bench',
      centerLat: 48.0,
      centerLng: 11.0,
      radiusMeters: 800,
      label: 'Benches',
    );
    await repo.addPoiPoints(sid, [
      PoiResult(lat: 48.001, lng: 11.001, categoryKey: 'bench', name: 'Park bench'),
      PoiResult(lat: 47.999, lng: 10.999, categoryKey: 'bench', name: null),
    ]);

    final data = await repo.exportData(onlyLayerId: layerId);
    expect(data.layers.single.type, 'poi');
    final o = data.layers.single.objects.single;
    expect(o.kind, 'poi');
    expect(o.categoryKey, 'bench');
    expect(o.radiusMeters, 800);
    expect(o.coords.length, 3); // centre + 2 POIs
    expect(o.pointLabels, ['Park bench', null]);

    // Import into a fresh layer and check the stored rows.
    final n = await repo.importData(data);
    expect(n, 1);
    final sets = await repo.watchAllPoiSets().first;
    expect(sets.length, 2);
    final imported = sets.firstWhere((s) => s.id != sid);
    expect(imported.categoryKey, 'bench');
    expect(imported.radiusMeters, 800);
    final pts = (await repo.watchAllPoiPoints().first)
        .where((p) => p.poiSetId == imported.id)
        .toList();
    expect(pts.length, 2);
    expect(pts.map((p) => p.name).toSet(), {'Park bench', null});
  });

  // --- transit (schema v19: stations only) ------------------------------------

  Future<String> seedTransit(String layerId, {bool pendingOnly = false}) async {
    final setId = await repo.createPendingTransitSet(
      layerId: layerId,
      south: 48.00,
      west: 11.30,
      north: 48.30,
      east: 11.80,
      modeMask: transitAllModesMask,
      visibleModeMask: defaultVisibleModes(45000),
      label: 'München',
    );
    if (pendingOnly) return setId;
    await repo.fillTransitSet(setId, [
      (
        osmId: 1,
        lat: 48.14,
        lng: 11.46,
        name: 'Pasing Bahnhof',
        modeMask: transitModeByKey('bus')!.bit |
            transitModeByKey('train')!.bit |
            transitModeByKey('tram')!.bit,
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
      (
        osmId: 3,
        lat: 48.11,
        lng: 11.52,
        name: 'Irgendwo',
        modeMask: transitModeByKey('bus')!.bit,
        nodeCount: 2,
        routeRef: null,
      ),
    ]);
    return setId;
  }

  test('an import stores stations with their modes and counts', () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final setId = await seedTransit(layerId);

    final set = (await repo.watchAllTransitSets().first).single;
    expect(set.id, setId);
    expect(set.label, 'München');
    expect(set.fetchedAt, isNotNull, reason: 'a filled import is not pending');
    expect(set.lastError, isNull);
    expect(set.stationCount, 3);
    expect(set.nodeCount, 37); // 31 + 4 + 2 raw OSM nodes merged
    // A city-sized box starts with bus hidden.
    expect(set.visibleModeMask & transitModeByKey('bus')!.bit, 0);

    final stops = await repo.watchAllTransitStops().first;
    expect(stops, hasLength(3));
    final pasing = stops.firstWhere((s) => s.name == 'Pasing Bahnhof');
    expect(pasing.nodeCount, 31);
    expect(
      pasing.modeMask,
      transitModeByKey('bus')!.bit |
          transitModeByKey('train')!.bit |
          transitModeByKey('tram')!.bit,
    );
    expect(stops.firstWhere((s) => s.name == 'Marienplatz').routeRef, 'U3;U6');
  });

  test('a failed import stays as a pending set you can retry', () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final setId = await seedTransit(layerId, pendingOnly: true);
    await repo.markTransitImportFailed(setId, 'Overpass is busy');

    var set = (await repo.watchAllTransitSets().first).single;
    expect(set.fetchedAt, isNull, reason: 'null fetchedAt == not imported yet');
    expect(set.lastError, 'Overpass is busy');
    expect(set.stationCount, 0);
    // The box is remembered, so the retry knows exactly what to ask for.
    expect(set.south, 48.00);
    expect(set.east, 11.80);

    // Retrying fills it in and clears the error.
    await repo.fillTransitSet(setId, [
      (
        osmId: 9,
        lat: 48.1,
        lng: 11.5,
        name: 'Later',
        modeMask: transitModeByKey('tram')!.bit,
        nodeCount: 1,
        routeRef: null,
      ),
    ]);
    set = (await repo.watchAllTransitSets().first).single;
    expect(set.fetchedAt, isNotNull);
    expect(set.lastError, isNull);
    expect(set.stationCount, 1);
  });

  test('refilling replaces the stations rather than duplicating them',
      () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final setId = await seedTransit(layerId);
    await repo.fillTransitSet(setId, [
      (
        osmId: 1,
        lat: 48.1,
        lng: 11.5,
        name: 'Only one now',
        modeMask: 0,
        nodeCount: 1,
        routeRef: null,
      ),
    ]);
    expect(await repo.watchAllTransitStops().first, hasLength(1));
  });

  test('deleting the layer cascades to sets and stations', () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    await seedTransit(layerId);
    await repo.deleteLayer(layerId);
    expect(await repo.watchAllTransitSets().first, isEmpty);
    expect(await repo.watchAllTransitStops().first, isEmpty);
  });

  test('setTransitVisibleModes writes the filter', () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final setId = await seedTransit(layerId);

    await repo.setTransitVisibleModes([setId], transitRailMask);
    final set = (await repo.watchAllTransitSets().first).single;
    expect(set.visibleModeMask, transitRailMask);
    expect(set.visibleModeMask & transitModeByKey('bus')!.bit, 0);

    // An empty id list is a no-op, not "hide everything everywhere".
    await repo.setTransitVisibleModes(const [], 0);
    expect((await repo.watchAllTransitSets().first).single.visibleModeMask,
        transitRailMask);
  });

  test('combining transit layers keeps both imports', () async {
    // combineLayers' `default` re-points *circles*, then deletes the source —
    // a type without its own case loses everything to the cascade.
    final a = await repo.createLayer(
        name: 'A', colorArgb: 0xFF111111, type: 'transit');
    final b = await repo.createLayer(
        name: 'B', colorArgb: 0xFF222222, type: 'transit');
    await seedTransit(a);
    await seedTransit(b);

    await repo.combineLayers(sourceId: a, targetId: b);

    final sets = await repo.watchAllTransitSets().first;
    expect(sets, hasLength(2), reason: 'the combined-away import must survive');
    expect(sets.every((s) => s.layerId == b), isTrue);
    expect(await repo.watchAllTransitStops().first, hasLength(6));
  });

  test('a transit layer is created fully opaque', () async {
    final id = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final layer =
        await (db.select(db.layers)..where((l) => l.id.equals(id))).getSingle();
    expect(layer.opacity, 1.0);
    expect(defaultLayerOpacity('transit'), 1.0);
    expect(defaultLayerOpacity('circles'), kDefaultRegionLayerOpacity);
  });

  test('a transit layer survives an export/import round-trip', () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    await seedTransit(layerId);

    final data = await repo.exportData(onlyLayerId: layerId);
    final objects = data.layers.single.objects;
    expect(objects, hasLength(1));
    final o = objects.single;
    expect(o.kind, 'transitstop');
    expect(o.coords, hasLength(3));
    expect(o.pointLabels, contains('Pasing Bahnhof'));
    // The station attributes the painter and the filter sheet need.
    expect(o.pointOsmIds, hasLength(3));
    expect(o.bbox, [48.00, 11.30, 48.30, 11.80]);
    expect(o.modeMask, isNotNull);
    // Borders-only layer options don't ride along on a transit layer.
    expect(data.layers.single.borderFillAreas, isNull);
    expect(data.layers.single.borderShowNames, isNull);
    // No line geometry exists any more.
    expect(objects.where((x) => x.kind == 'transitline'), isEmpty);

    // Still readable as plain named points by any other tool.
    final gj = jsonDecode(exportToGeoJson(data)) as Map<String, dynamic>;
    final kinds = {
      for (final f in gj['features'] as List)
        (f as Map)['geometry']['type'] as String,
    };
    expect(kinds, {'MultiPoint'});
    expect(exportToKml(data), contains('Pasing Bahnhof'));

    // Re-importing rebuilds the import, its box and its stations.
    expect(await repo.importData(data), 1);
    final fresh = (await repo.watchLayers().first)
        .firstWhere((l) => l.type == 'transit' && l.id != layerId);
    final set = (await repo.watchAllTransitSets().first)
        .firstWhere((t) => t.layerId == fresh.id);
    expect(set.south, 48.00);
    expect(set.east, 11.80);
    expect(set.modeMask, o.modeMask);
    expect(set.visibleModeMask, o.visibleModeMask);
    expect(set.stationCount, 3);
    final stops = (await repo.watchAllTransitStops().first)
        .where((x) => x.setId == set.id)
        .toList();
    expect(stops, hasLength(3));
    final pasing = stops.firstWhere((x) => x.name == 'Pasing Bahnhof');
    expect(pasing.nodeCount, 31);
    expect(pasing.modeMask, isNot(0));
    expect(
      stops.firstWhere((x) => x.name == 'Marienplatz').routeRef,
      'U3;U6',
    );
  });

  test('a transit export without station ids still refuses to re-import',
      () async {
    // Every export written before the round-trip landed is this file: the
    // station id is the row's identity, and there is nothing to invent it from.
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    await seedTransit(layerId);
    final data = await repo.exportData(onlyLayerId: layerId);
    final o = data.layers.single.objects.single;
    final stripped = ExportData([
      ExportLayer(
        name: 'Old file',
        colorArgb: 0xFF123456,
        type: 'transit',
        isInverted: false,
        objects: [
          ExportObject(
            kind: 'transitstop',
            coords: o.coords,
            pointLabels: o.pointLabels,
          ),
        ],
      ),
    ]);
    expect(await repo.importData(stripped), 0);
  });

  // --- borders (schema v20) ---------------------------------------------------

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
  }) borderArea(int id, String name, [List<int> wayIds = const []]) => (
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

  /// Two municipalities sharing way 100, plus a detached third — enough for the
  /// colouring to have something to say.
  Future<({String setId, ImportTally tally})> seedBordersResult(
    String layerId, {
    String? label,
  }) =>
      repo.addBorderSet(
        layerId: layerId,
        south: 48.0,
        west: 11.0,
        north: 48.2,
        east: 11.3,
        adminLevel: '8',
        label: label,
        areas: [
          borderArea(1, 'München', [100, 101]),
          borderArea(2, 'Germering', [100, 102]),
          borderArea(3, 'Far away', [900]),
        ],
      );

  Future<String> seedBorders(String layerId, {String? label}) async =>
      (await seedBordersResult(layerId, label: label)).setId;

  Future<ImportTally> seedBordersTally(String layerId) async =>
      (await seedBordersResult(layerId)).tally;

  test('an import stores areas with their geometry and counts', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    final setId = await seedBorders(layerId, label: 'Around Munich');

    final set = (await repo.watchAllBorderSets().first).single;
    expect(set.id, setId);
    expect(set.label, 'Around Munich');
    expect(set.adminLevel, '8');
    expect(set.areaCount, 3);
    expect(set.pointCount, 12);
    expect(set.fetchedAt, isNotNull);
    // The box is stored as-is: it is also the clip rect the geometry was cut to.
    expect(set.south, 48.0);
    expect(set.east, 11.3);

    final areas = await repo.watchAllBorderAreas().first;
    expect(areas, hasLength(3));
    final munich = areas.firstWhere((a) => a.osmId == 1);
    expect(munich.name, 'München');
    expect(decodeRings(munich.rings).single, hasLength(4));
    expect(jsonDecode(munich.wayIds), [100, 101]);
  });

  test('importing colours neighbours differently', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await seedBorders(layerId);

    final areas = await repo.watchAllBorderAreas().first;
    final byId = {for (final a in areas) a.osmId: a.colorIndex};
    // 1 and 2 share way 100, so they must differ; 3 shares nothing.
    expect(byId[1], isNot(byId[2]));
    for (final c in byId.values) {
      expect(c, inInclusiveRange(0, kBorderColorCount - 1));
    }
  });

  test('a second overlapping import is recoloured against the first', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await seedBorders(layerId);
    // A fourth area bordering both 1 and 2, imported separately.
    await repo.addBorderSet(
      layerId: layerId,
      south: 48.0,
      west: 11.0,
      north: 48.2,
      east: 11.3,
      adminLevel: '8',
      areas: [
        (
          osmId: 4,
          name: 'Neighbour of both',
          south: 48.0,
          west: 11.0,
          north: 48.1,
          east: 11.1,
          labelLat: 48.05,
          labelLng: 11.05,
          pointCount: 3,
          rings: '[[[48.0,11.0],[48.0,11.1],[48.1,11.1]]]',
          wayIds: [101, 102],
        ),
      ],
    );

    final areas = await repo.watchAllBorderAreas().first;
    final byId = {for (final a in areas) a.osmId: a.colorIndex};
    expect(byId[4], isNot(byId[1]), reason: 'they share way 101');
    expect(byId[4], isNot(byId[2]), reason: 'they share way 102');
  });

  test('deleting a set removes its areas and recolours the rest', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    final setId = await seedBorders(layerId);
    await repo.deleteBorderSet(setId);
    expect(await repo.watchAllBorderSets().first, isEmpty);
    expect(await repo.watchAllBorderAreas().first, isEmpty);
  });

  test('deleting the layer cascades to sets and areas', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await seedBorders(layerId);
    await repo.deleteLayer(layerId);
    expect(await repo.watchAllBorderSets().first, isEmpty);
    expect(await repo.watchAllBorderAreas().first, isEmpty);
  });

  test('a borders layer records its level and its two display toggles',
      () async {
    final id = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '4');
    Future<Layer> row() =>
        (db.select(db.layers)..where((l) => l.id.equals(id))).getSingle();

    var layer = await row();
    expect(layer.borderLevel, '4');
    expect(layer.borderFillAreas, isFalse);
    expect(layer.borderShowNames, isFalse);
    // Region-like: it has an area fill, even though it starts unfilled.
    expect(layer.opacity, kDefaultRegionLayerOpacity);

    await repo.updateBorderLayerOptions(id, fillAreas: true);
    layer = await row();
    expect(layer.borderFillAreas, isTrue);
    expect(layer.borderShowNames, isFalse, reason: 'one toggle at a time');

    await repo.updateBorderLayerOptions(id, showNames: true);
    layer = await row();
    expect(layer.borderFillAreas, isTrue);
    expect(layer.borderShowNames, isTrue);

    // Other layer types never carry a level.
    final circles = await repo.createLayer(name: 'C', colorArgb: 0xFF000000);
    expect(
      (await (db.select(db.layers)..where((l) => l.id.equals(circles)))
              .getSingle())
          .borderLevel,
      isNull,
    );
  });

  test('combining borders layers keeps both imports and re-resolves the seam',
      () async {
    // combineLayers' `default` re-points *circles*, then deletes the source —
    // a type without its own case loses everything to the cascade.
    final a = await repo.createLayer(
        name: 'A', colorArgb: 0xFF111111, type: 'borders', borderLevel: '8');
    final b = await repo.createLayer(
        name: 'B', colorArgb: 0xFF222222, type: 'borders', borderLevel: '8');
    await seedBorders(a);
    await repo.addBorderSet(
      layerId: b,
      south: 48.0,
      west: 11.0,
      north: 48.2,
      east: 11.3,
      adminLevel: '8',
      areas: [
        (
          osmId: 5,
          name: 'Shares way 100',
          south: 48.0,
          west: 11.0,
          north: 48.1,
          east: 11.1,
          labelLat: 48.05,
          labelLng: 11.05,
          pointCount: 3,
          rings: '[[[48.0,11.0],[48.0,11.1],[48.1,11.1]]]',
          wayIds: [100],
        ),
      ],
    );

    await repo.combineLayers(sourceId: a, targetId: b);

    final sets = await repo.watchAllBorderSets().first;
    expect(sets, hasLength(2), reason: 'the combined-away import must survive');
    expect(sets.every((s) => s.layerId == b), isTrue);
    final byId = {
      for (final x in await repo.watchAllBorderAreas().first)
        x.osmId: x.colorIndex,
    };
    expect(byId[5], isNot(byId[1]), reason: 'they share way 100');
  });

  test('borders layers of different levels refuse to combine', () async {
    final a = await repo.createLayer(
        name: 'A', colorArgb: 0xFF111111, type: 'borders', borderLevel: '8');
    final b = await repo.createLayer(
        name: 'B', colorArgb: 0xFF222222, type: 'borders', borderLevel: '4');
    await expectLater(
      repo.combineLayers(sourceId: a, targetId: b),
      throwsArgumentError,
    );
  });

  test('an area can be renamed, deleted and read back as rings', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '9');
    await seedBorders(layerId);

    final areas = await repo.watchAllBorderAreas().first;
    final munich = areas.firstWhere((a) => a.osmId == 1);

    // The rings come back decoded, which is what "convert to freehand" needs.
    final rings = await repo.borderAreaRings(munich.id);
    expect(rings, hasLength(1));
    expect(rings.single, hasLength(4));
    expect(await repo.borderAreaRings('nope'), isEmpty);

    // Renaming a row renames the area, because the row *is* the area.
    await repo.updateBorderArea(munich.id, name: const Value('Renamed'));
    expect(
      (await repo.watchAllBorderAreas().first)
          .firstWhere((a) => a.id == munich.id)
          .name,
      'Renamed',
    );

    // Deleting one area leaves the other two, and the set behind them.
    await repo.deleteBorderArea(munich.id);
    final left = await repo.watchAllBorderAreas().first;
    expect(left, hasLength(2));
    expect(left.map((a) => a.osmId), isNot(contains(1)));
    expect(await repo.watchAllBorderSets().first, hasLength(1));
  });

  test('deleting an area recolours the neighbours it was constraining',
      () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await seedBorders(layerId);
    final before = await repo.watchAllBorderAreas().first;
    await repo.deleteBorderArea(before.firstWhere((a) => a.osmId == 1).id);
    // Germering no longer borders anything, so it may take colour 0 again.
    final after = await repo.watchAllBorderAreas().first;
    expect(after.map((a) => a.colorIndex), everyElement(0));
  });

  test('a borders layer survives an export/import round-trip', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await seedBorders(layerId, label: 'Around Munich');
    await repo.updateBorderLayerOptions(layerId,
        fillAreas: true, showNames: true);

    final data = await repo.exportData(onlyLayerId: layerId);
    final exported = data.layers.single;
    expect(exported.type, 'borders');
    // The Elements list names areas, so the export does too.
    expect(exported.objects, hasLength(3));
    expect(exported.borderLevel, '8');
    expect(exported.borderFillAreas, isTrue);
    expect(exported.borderShowNames, isTrue);
    final munich = exported.objects.firstWhere((o) => o.label == 'München');
    expect(munich.kind, 'borderarea');
    expect(munich.osmId, 1);
    expect(munich.adminLevel, '8');
    expect(munich.wayIds, [100, 101]);
    expect(munich.rings, hasLength(1));
    expect(munich.rings!.single, hasLength(4));
    expect(munich.bbox, [48.0, 11.0, 48.2, 11.3]); // the set's box, not the area's

    // Multi-ring geometry needs a MultiPolygon; nothing else in the format has
    // one.
    final gj = jsonDecode(exportToGeoJson(data)) as Map<String, dynamic>;
    final kinds = {
      for (final f in gj['features'] as List)
        (f as Map)['geometry']['type'] as String,
    };
    expect(kinds, {'MultiPolygon'});
    expect(exportToKml(data), contains('München'));

    // Round-trip through the file format, not just the in-memory model.
    final reread = importFromGeoJson(exportToGeoJson(data))!;
    expect(await repo.importData(reread), 3);
    final fresh = (await repo.watchLayers().first)
        .firstWhere((l) => l.type == 'borders' && l.id != layerId);
    expect(fresh.borderLevel, '8');
    expect(fresh.borderFillAreas, isTrue);
    expect(fresh.borderShowNames, isTrue);
    // The three areas regrouped into the one import they were fetched in.
    final sets = (await repo.watchAllBorderSets().first)
        .where((x) => x.layerId == fresh.id)
        .toList();
    expect(sets, hasLength(1));
    expect(sets.single.adminLevel, '8');
    expect(sets.single.south, 48.0);
    expect(sets.single.east, 11.3);
    expect(sets.single.areaCount, 3);
    expect(sets.single.pointCount, 12);
    final areas = (await repo.watchAllBorderAreas().first)
        .where((a) => a.setId == sets.single.id)
        .toList();
    expect(areas, hasLength(3));
    expect(areas.map((a) => a.name).toSet(), {'München', 'Germering', 'Far away'});
    final m = areas.firstWhere((a) => a.name == 'München');
    expect(m.osmId, 1);
    expect(m.pointCount, 4);
    expect(m.labelLat, 48.05);
    expect(await repo.borderAreaRings(m.id), hasLength(1));
    // Neighbours still differ: München and Germering share way 100.
    final g = areas.firstWhere((a) => a.name == 'Germering');
    expect(m.colorIndex, isNot(g.colorIndex));
  });

  test('re-importing a borders file into its own layer adds nothing', () async {
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await seedBorders(layerId);
    final data = await repo.exportData(onlyLayerId: layerId);
    // Same relation ids, same layer — the dedup a re-fetch makes applies to a
    // file just as much.
    expect(await repo.mergeIntoLayer(layerId, data.layers.single), 0);
    expect(await repo.watchAllBorderAreas().first, hasLength(3));
    expect(await repo.watchAllBorderSets().first, hasLength(1));
  });

  test('a borders file refuses to merge into another admin level', () async {
    final eight = await repo.createLayer(
        name: 'B8', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await seedBorders(eight);
    final four = await repo.createLayer(
        name: 'B4', colorArgb: 0xFF123456, type: 'borders', borderLevel: '4');
    final data = await repo.exportData(onlyLayerId: eight);
    await expectLater(
      repo.mergeIntoLayer(four, data.layers.single),
      throwsArgumentError,
    );
  });

  test('exported multi-ring areas come back with every ring', () async {
    // An area with a hole and an exclave: the GeoJSON encoder has to split it
    // into two polygons, and flattening has to give the rings back unchanged.
    final layerId = await repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');
    await repo.addBorderSet(
      layerId: layerId,
      south: 48.0,
      west: 11.0,
      north: 49.0,
      east: 12.0,
      adminLevel: '8',
      areas: [
        (
          osmId: 7,
          name: 'Holey',
          south: 48.0,
          west: 11.0,
          north: 49.0,
          east: 12.0,
          labelLat: 48.5,
          labelLng: 11.5,
          pointCount: 12,
          rings: encodeRings([
            // Outer.
            [LatLng(48.0, 11.0), LatLng(48.0, 11.6), LatLng(48.6, 11.6),
             LatLng(48.6, 11.0)],
            // Hole inside it.
            [LatLng(48.2, 11.2), LatLng(48.2, 11.4), LatLng(48.4, 11.4),
             LatLng(48.4, 11.2)],
            // Detached exclave.
            [LatLng(48.8, 11.8), LatLng(48.8, 11.9), LatLng(48.9, 11.9),
             LatLng(48.9, 11.8)],
          ]),
          wayIds: <int>[1],
        ),
      ],
    );

    final data = await repo.exportData(onlyLayerId: layerId);
    final gj = jsonDecode(exportToGeoJson(data)) as Map<String, dynamic>;
    final geom = ((gj['features'] as List).single as Map)['geometry'] as Map;
    expect(geom['type'], 'MultiPolygon');
    final polys = geom['coordinates'] as List;
    expect(polys, hasLength(2), reason: 'the exclave is its own polygon');
    expect((polys.first as List), hasLength(2), reason: 'outer + its hole');

    final reread = importFromGeoJson(exportToGeoJson(data))!;
    expect(await repo.importData(reread), 1);
    final fresh = (await repo.watchLayers().first)
        .firstWhere((l) => l.type == 'borders' && l.id != layerId);
    final sets = (await repo.watchAllBorderSets().first)
        .where((x) => x.layerId == fresh.id)
        .toList();
    final area = (await repo.watchAllBorderAreas().first)
        .firstWhere((a) => a.setId == sets.single.id);
    final rings = await repo.borderAreaRings(area.id);
    expect(rings, hasLength(3), reason: 'outer, hole and exclave all survive');
    expect(rings.expand((r) => r).length, 12);
    expect(area.pointCount, 12);
  });

  // --- re-import dedup (schema v21) -------------------------------------------

  /// Overlapping imports used to store the same element twice, so it was drawn
  /// twice: the reported symptom was a suburb rendering doubled where two
  /// border boxes met. Identity is `type/id`, scoped to the **layer**, and the
  /// first copy wins.

  group('borders dedup', () {
    Future<String> layer() => repo.createLayer(
        name: 'B', colorArgb: 0xFF123456, type: 'borders', borderLevel: '8');

    test('an overlapping second import stores only what is new', () async {
      final layerId = await layer();
      await seedBorders(layerId);
      // The same three relations plus one genuinely new one — exactly what an
      // overlapping box returns, since whole relations come down each time.
      final second = await repo.addBorderSet(
        layerId: layerId,
        south: 48.0,
        west: 11.0,
        north: 48.2,
        east: 11.3,
        adminLevel: '8',
        areas: [
          borderArea(1, 'München'),
          borderArea(2, 'Germering'),
          borderArea(3, 'Far away'),
          borderArea(4, 'Dachau'),
        ],
      );

      expect(second.tally.added, 1);
      expect(second.tally.skipped, 3);
      final areas = await repo.watchAllBorderAreas().first;
      expect(areas.map((a) => a.osmId).toList()..sort(), [1, 2, 3, 4]);
      expect(areas.where((a) => a.osmId == 1), hasLength(1),
          reason: 'München must not be stored twice');
    });

    test('the set records only the areas it actually kept', () async {
      final layerId = await layer();
      await seedBorders(layerId);
      final second = await repo.addBorderSet(
        layerId: layerId,
        south: 48.0,
        west: 11.0,
        north: 48.2,
        east: 11.3,
        adminLevel: '8',
        areas: [borderArea(1, 'München'), borderArea(9, 'New')],
      );
      final set = (await repo.watchAllBorderSets().first)
          .firstWhere((s) => s.id == second.setId);
      expect(set.areaCount, 1);
      expect(set.pointCount, 4, reason: 'points follow the kept areas');
    });

    test('another layer may deliberately hold the same areas', () async {
      final a = await layer();
      final b = await layer();
      await seedBorders(a);
      final second = await seedBordersTally(b);
      expect(second.skipped, 0,
          reason: 'dedup is per layer — two layers holding Munich is a '
              'legitimate thing to want');
    });

    test('an import of nothing but duplicates is reported, not silent',
        () async {
      final layerId = await layer();
      await seedBorders(layerId);
      final second = await seedBordersTally(layerId);
      expect(second.added, 0);
      expect(second.skipped, 3);
      expect(second.allSkipped, isTrue);
    });
  });

  group('transit dedup', () {
    ({
      int osmId,
      double lat,
      double lng,
      String? name,
      int modeMask,
      int nodeCount,
      String? routeRef,
    }) stop(int id, String name) => (
          osmId: id,
          lat: 48.1,
          lng: 11.5,
          name: name,
          modeMask: 1,
          nodeCount: 1,
          routeRef: null,
        );

    Future<String> pendingSet(String layerId) => repo.createPendingTransitSet(
          layerId: layerId,
          south: 48.0,
          west: 11.0,
          north: 48.2,
          east: 11.3,
          modeMask: -1,
          visibleModeMask: -1,
        );

    test('a station already on the layer is not stored again', () async {
      final layerId =
          await repo.createLayer(name: 'T', colorArgb: 1, type: 'transit');
      final first = await pendingSet(layerId);
      await repo.fillTransitSet(first, [stop(1, 'Pasing'), stop(2, 'Laim')]);

      final second = await pendingSet(layerId);
      final tally = await repo
          .fillTransitSet(second, [stop(2, 'Laim'), stop(3, 'Hbf')]);

      expect(tally.added, 1);
      expect(tally.skipped, 1);
      final stops = await repo.watchAllTransitStops().first;
      expect(stops.map((s) => s.osmId).toList()..sort(), [1, 2, 3]);
    });

    test('a retry of the same set does not dedup against itself', () async {
      // The set is refilled in place, so its own previous rows must not count
      // as "already here" — otherwise every retry would import nothing.
      final layerId =
          await repo.createLayer(name: 'T', colorArgb: 1, type: 'transit');
      final setId = await pendingSet(layerId);
      await repo.fillTransitSet(setId, [stop(1, 'Pasing'), stop(2, 'Laim')]);

      final again = await repo
          .fillTransitSet(setId, [stop(1, 'Pasing'), stop(2, 'Laim')]);

      expect(again.added, 2);
      expect(again.skipped, 0);
      expect(await repo.watchAllTransitStops().first, hasLength(2));
    });

    test('the stored counts follow what was kept', () async {
      final layerId =
          await repo.createLayer(name: 'T', colorArgb: 1, type: 'transit');
      await repo.fillTransitSet(await pendingSet(layerId), [stop(1, 'Pasing')]);
      final second = await pendingSet(layerId);
      await repo.fillTransitSet(second, [stop(1, 'Pasing'), stop(2, 'Laim')]);

      final set = (await repo.watchAllTransitSets().first)
          .firstWhere((s) => s.id == second);
      expect(set.stationCount, 1);
      expect(set.nodeCount, 1);
    });
  });

  group('poi dedup', () {
    Future<String> setOn(String layerId) => repo.createPoiSet(
          layerId: layerId,
          categoryKey: 'cafe',
          centerLat: 48.1,
          centerLng: 11.5,
          radiusMeters: 1500,
        );

    PoiResult poi(String type, int id, String name) => PoiResult(
          lat: 48.1,
          lng: 11.5,
          categoryKey: 'cafe',
          name: name,
          osmType: type,
          osmId: id,
        );

    test('the same OSM element is stored once per layer', () async {
      final layerId =
          await repo.createLayer(name: 'P', colorArgb: 1, type: 'poi');
      await repo.addPoiPoints(
          await setOn(layerId), [poi('node', 1, 'A'), poi('node', 2, 'B')]);

      final tally = await repo.addPoiPoints(
          await setOn(layerId), [poi('node', 2, 'B'), poi('node', 3, 'C')]);

      expect(tally.added, 1);
      expect(tally.skipped, 1);
      expect(await repo.watchAllPoiPoints().first, hasLength(3));
    });

    test('a node and a way sharing an id are different things', () async {
      // Ids repeat across element types, so identity has to be type + id.
      // Keying on the id alone would silently drop the way.
      final layerId =
          await repo.createLayer(name: 'P', colorArgb: 1, type: 'poi');
      final tally = await repo.addPoiPoints(await setOn(layerId), [
        poi('node', 240109189, 'A café'),
        poi('way', 240109189, 'A café building'),
      ]);

      expect(tally.added, 2);
      expect(tally.skipped, 0);
    });

    test('POIs with no OSM identity are always kept', () async {
      // Rows written before v21, and anything imported from a file, carry no
      // id. Guessing one from coordinates would merge two genuinely different
      // POIs that share a doorway, so they simply sit outside the check.
      final layerId =
          await repo.createLayer(name: 'P', colorArgb: 1, type: 'poi');
      const anonymous = PoiResult(lat: 48.1, lng: 11.5, categoryKey: 'cafe');
      final tally =
          await repo.addPoiPoints(await setOn(layerId), [anonymous, anonymous]);

      expect(tally.added, 2);
      expect(tally.skipped, 0);
    });

    test('duplicates inside one response are collapsed too', () async {
      final layerId =
          await repo.createLayer(name: 'P', colorArgb: 1, type: 'poi');
      final tally = await repo.addPoiPoints(
          await setOn(layerId), [poi('node', 7, 'A'), poi('node', 7, 'A')]);

      expect(tally.added, 1);
      expect(tally.skipped, 1);
    });

    test('sort order stays contiguous after a skip', () async {
      // It indexes what was kept, not what was offered — a gap would reorder
      // the markers against the list.
      final layerId =
          await repo.createLayer(name: 'P', colorArgb: 1, type: 'poi');
      await repo.addPoiPoints(await setOn(layerId), [poi('node', 1, 'A')]);
      await repo.addPoiPoints(await setOn(layerId),
          [poi('node', 1, 'A'), poi('node', 2, 'B'), poi('node', 3, 'C')]);

      final second = (await repo.watchAllPoiSets().first).last;
      final pts = (await repo.watchAllPoiPoints().first)
          .where((p) => p.poiSetId == second.id)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(pts.map((p) => p.sortOrder), [0, 1]);
    });
  });
}
