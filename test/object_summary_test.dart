import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/object_summary.dart';

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

  /// `createdAt` defaults to the current second, so objects created in one test
  /// tie and fall back to the (arbitrary but stable) id tie-break. Stamp
  /// distinct times when the assertion is about ordering.
  Future<void> stampCircle(String id, DateTime at) =>
      (db.update(db.circles)..where((c) => c.id.equals(id)))
          .write(CirclesCompanion(createdAt: Value(at)));

  test('formatMeters switches unit at 1 km', () {
    expect(formatMeters(0), '0 m');
    expect(formatMeters(999), '999 m');
    expect(formatMeters(1500), '1.50 km');
    expect(formatMeters(42000), '42 km');
    expect(formatMeters(double.nan), '—');
  });

  test('formatElevationMeters groups thousands and marks negatives', () {
    expect(formatElevationMeters(2962), '2,962 m');
    expect(formatElevationMeters(-12), '−12 m');
  });

  test('circle rows: label wins, otherwise a positional name', () async {
    final layerId = await repo.createLayer(name: 'C', colorArgb: 0xFF0000FF);
    final first = await repo.createCircle(
        layerId: layerId, centerLat: 48.1, centerLng: 11.5, radiusMeters: 500);
    final second = await repo.createCircle(
        layerId: layerId,
        centerLat: 48.2,
        centerLng: 11.6,
        radiusMeters: 2000,
        label: 'Home');
    await stampCircle(first, DateTime.utc(2026, 1, 1));
    await stampCircle(second, DateTime.utc(2026, 1, 2));

    final rows = summariseLayer(
      await layerById(layerId),
      circles: await db.select(db.circles).get(),
    );

    expect(rows.map((r) => r.title), ['Circle 1', 'Home']);
    expect(rows.first.subtitle, '500 m radius');
    expect(rows.last.subtitle, '2.00 km radius');
    expect(rows.first.ref.kind, ObjectKind.circle);
    expect(rows.first.ref.layerId, layerId);
    // Eight ring points, so the camera can frame the whole disc.
    expect(rows.first.fitPoints.length, 8);
    expect(rows.first.center.latitude, closeTo(48.1, 1e-9));
  });

  test('plane rows report the near side and frame both foci', () async {
    final layerId =
        await repo.createLayer(name: 'P', colorArgb: 0xFF00FF00, type: 'planes');
    await repo.createPlane(
        layerId: layerId,
        aLat: 48.0,
        aLng: 11.0,
        bLat: 48.4,
        bLng: 11.8,
        nearA: false);

    final rows = summariseLayer(
      await layerById(layerId),
      planes: await db.select(db.planes).get(),
    );

    expect(rows.single.title, 'Plane 1');
    expect(rows.single.subtitle, 'Nearer side: B');
    expect(rows.single.fitPoints.length, 2);
    expect(rows.single.center.latitude, closeTo(48.2, 1e-9));
  });

  test('subspace rows count points and centre on the main point', () async {
    final layerId = await repo.createLayer(
        name: 'S', colorArgb: 0xFF00FFFF, type: 'subspace');
    final id = await repo.createSubspace(layerId: layerId);
    await repo.addSubspacePoint(
        subspaceId: id, lat: 48.0, lng: 11.0, isMain: true);
    await repo.addSubspacePoint(subspaceId: id, lat: 49.0, lng: 12.0);

    final rows = summariseLayer(
      await layerById(layerId),
      subspaces: await db.select(db.subspaces).get(),
      subspacePoints: await db.select(db.subspacePoints).get(),
    );

    expect(rows.single.subtitle, '2 points');
    expect(rows.single.center.latitude, closeTo(48.0, 1e-9));
    expect(rows.single.fitPoints.length, 2);
  });

  test('freeline rows frame the inclusion circle, not the raw extent',
      () async {
    final layerId = await repo.createLayer(
        name: 'L', colorArgb: 0xFFFF0000, type: 'freeline');
    // A "river" spanning ~7° of longitude, bounded to a 1 km circle.
    final id = await repo.createFreeLine(
      layerId: layerId,
      inclusionLat: 48.0,
      inclusionLng: 11.0,
      inclusionRadiusMeters: 1000,
    );
    await repo.addFreeLinePoint(freeLineId: id, lat: 48.0, lng: 8.0);
    await repo.addFreeLinePoint(freeLineId: id, lat: 48.0, lng: 15.0);

    final rows = summariseLayer(
      await layerById(layerId),
      freeLines: await db.select(db.freeLines).get(),
      freeLinePoints: await db.select(db.freeLinePoints).get(),
    );

    expect(rows.single.subtitle, '2 points');
    expect(rows.single.center.longitude, closeTo(11.0, 1e-9));
    // Every framing point stays within ~1 km of the inclusion centre — the
    // 7°-wide raw extent must not leak into the camera fit.
    for (final p in rows.single.fitPoints) {
      expect((p.longitude - 11.0).abs(), lessThan(0.05));
      expect((p.latitude - 48.0).abs(), lessThan(0.05));
    }
  });

  test('freeline subtitle mentions a non-zero offset', () async {
    final layerId = await repo.createLayer(
        name: 'L', colorArgb: 0xFFFF0000, type: 'freeline');
    final id = await repo.createFreeLine(layerId: layerId);
    await repo.addFreeLinePoint(freeLineId: id, lat: 48.0, lng: 11.0);
    await repo.addFreeLinePoint(freeLineId: id, lat: 48.1, lng: 11.1);
    await repo.updateFreeLine(id, offsetMeters: -250);

    final rows = summariseLayer(
      await layerById(layerId),
      freeLines: await db.select(db.freeLines).get(),
      freeLinePoints: await db.select(db.freeLinePoints).get(),
    );

    expect(rows.single.subtitle, '2 points · offset 250 m');
  });

  test('height rows show the band, radius and generation state', () async {
    final layerId = await repo.createLayer(
        name: 'H', colorArgb: 0xFF888888, type: 'height');
    final id = await repo.createHeightRegion(
      layerId: layerId,
      centerLat: 47.0,
      centerLng: 11.0,
      radiusMeters: 5000,
      thresholdMeters: 2500,
    );

    var rows = summariseLayer(
      await layerById(layerId),
      heightRegions: await db.select(db.heightRegions).get(),
    );
    expect(rows.single.subtitle, 'above 2,500 m · 5.00 km · not generated');

    await repo.markHeightGenerated(id);
    rows = summariseLayer(
      await layerById(layerId),
      heightRegions: await db.select(db.heightRegions).get(),
    );
    expect(rows.single.subtitle, 'above 2,500 m · 5.00 km');
  });

  test('poi set rows count their stored POIs', () async {
    final layerId =
        await repo.createLayer(name: 'POI', colorArgb: 0xFF123456, type: 'poi');
    final id = await repo.createPoiSet(
      layerId: layerId,
      categoryKey: 'bench',
      centerLat: 48.0,
      centerLng: 11.0,
      radiusMeters: 800,
      label: 'Benches',
    );
    await repo.addPoiPoints(id, [
      (lat: 48.001, lng: 11.001, name: 'A'),
      (lat: 48.002, lng: 11.002, name: null),
    ]);

    final rows = summariseLayer(
      await layerById(layerId),
      poiSets: await db.select(db.poiSets).get(),
      poiPoints: await db.select(db.poiPoints).get(),
    );

    expect(rows.single.title, 'Benches');
    expect(rows.single.subtitle, '2 POIs · within 800 m');
    expect(rows.single.ref.kind, ObjectKind.poiSet);
  });

  test('updatePoiSet renames a set and clears the name with null', () async {
    final layerId =
        await repo.createLayer(name: 'POI', colorArgb: 0xFF123456, type: 'poi');
    final id = await repo.createPoiSet(
      layerId: layerId,
      categoryKey: 'bench',
      centerLat: 48.0,
      centerLng: 11.0,
      radiusMeters: 800,
      label: 'Benches',
    );

    await repo.updatePoiSet(id, label: const Value('Seating'));
    var set = await (db.select(db.poiSets)..where((s) => s.id.equals(id)))
        .getSingle();
    expect(set.label, 'Seating');
    // The search circle is immutable — only the name changed.
    expect(set.radiusMeters, 800);

    await repo.updatePoiSet(id, label: const Value(null));
    set = await (db.select(db.poiSets)..where((s) => s.id.equals(id)))
        .getSingle();
    expect(set.label, isNull);

    final rows = summariseLayer(
      await layerById(layerId),
      poiSets: await db.select(db.poiSets).get(),
    );
    expect(rows.single.title, 'POI set 1');
  });

  test('an object with no points still yields a usable focus point', () async {
    final layerId = await repo.createLayer(
        name: 'S', colorArgb: 0xFF00FFFF, type: 'subspace');
    await repo.createSubspace(layerId: layerId);

    final rows = summariseLayer(
      await layerById(layerId),
      subspaces: await db.select(db.subspaces).get(),
      subspacePoints: await db.select(db.subspacePoints).get(),
    );

    expect(rows.single.subtitle, '0 points');
    expect(rows.single.fitPoints, hasLength(1));
  });

  test('transit rows summarise the import, not individual stations', () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final setId = await repo.createPendingTransitSet(
      layerId: layerId,
      south: 48.10,
      west: 11.50,
      north: 48.15,
      east: 11.60,
      modeMask: transitAllModesMask,
      visibleModeMask: transitAllModesMask,
      label: 'Centre',
    );
    await repo.fillTransitSet(setId, [
      (
        osmId: 9,
        lat: 48.11,
        lng: 11.51,
        name: 'A',
        modeMask: transitModeByKey('subway')!.bit,
        nodeCount: 3,
        routeRef: null,
      ),
    ]);

    final rows = summariseLayer(
      await layerById(layerId),
      transitSets: await db.select(db.transitSets).get(),
      transitStops: await db.select(db.transitStops).get(),
    );

    expect(rows, hasLength(1));
    expect(rows.single.title, 'Centre');
    expect(rows.single.ref.kind, ObjectKind.transitSet);
    expect(rows.single.isPending, isFalse);
    expect(rows.single.subtitle, startsWith('1 station · '));
    expect(rows.single.subtitle, contains('imported '));
    // "Zoom to" frames the box that was imported — exactly what was fetched.
    expect(rows.single.fitPoints, hasLength(2));
    expect(rows.single.fitPoints.first.latitude, closeTo(48.10, 1e-9));
    expect(rows.single.fitPoints.last.longitude, closeTo(11.60, 1e-9));
  });

  test('an import that never finished reads as a retry row', () async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final setId = await repo.createPendingTransitSet(
      layerId: layerId,
      south: 48.10,
      west: 11.50,
      north: 48.15,
      east: 11.60,
      modeMask: transitAllModesMask,
      visibleModeMask: transitAllModesMask,
    );
    await repo.markTransitImportFailed(setId, 'Overpass is busy');

    final rows = summariseLayer(
      await layerById(layerId),
      transitSets: await db.select(db.transitSets).get(),
    );
    expect(rows.single.isPending, isTrue);
    expect(rows.single.title, contains("didn't finish"));
    expect(rows.single.subtitle, contains('Overpass is busy'));
    expect(rows.single.subtitle, contains('tap to try again'));
  });

  test('typeIcon knows the transit type', () {
    expect(typeIcon('transit'), isNot(typeIcon('unknown-type')));
  });

  group('borders elements list the areas, not the imports', () {
    /// Seeds a borders layer holding [names] as areas of one import.
    Future<Layer> seed(List<String?> names) async {
      final layerId = await repo.createLayer(
          name: 'Districts',
          colorArgb: 0xFF000000,
          type: 'borders',
          borderLevel: '9');
      await repo.addBorderSet(
        layerId: layerId,
        south: 48.0,
        west: 11.0,
        north: 48.3,
        east: 11.8,
        adminLevel: '9',
        areas: [
          for (var i = 0; i < names.length; i++)
            (
              osmId: i + 1,
              name: names[i],
              south: 48.1,
              west: 11.5,
              north: 48.2,
              east: 11.6,
              labelLat: 48.15,
              labelLng: 11.55,
              pointCount: 42,
              rings: '[[[48.1,11.5],[48.1,11.6],[48.2,11.6]]]',
              wayIds: <int>[i + 1],
            ),
        ],
      );
      return (await repo.watchLayers().first).firstWhere((l) => l.id == layerId);
    }

    Future<List<ObjectSummary>> rowsFor(Layer layer) async => summariseLayer(
          layer,
          borderSets: await repo.watchAllBorderSets().first,
          borderAreas: await repo.watchAllBorderAreas().first,
        );

    test('rows are the areas, named and sorted by name', () async {
      final layer = await seed(['Schwabing', 'Maxvorstadt', 'Altstadt-Lehel']);
      final rows = await rowsFor(layer);
      expect(rows.map((r) => r.title),
          ['Altstadt-Lehel', 'Maxvorstadt', 'Schwabing']);
      expect(rows.first.ref.kind, ObjectKind.borderArea);
      expect(rows.first.subtitle, contains('42 points'));
    });

    test('the ref points at the AREA, so rename/delete hit one district',
        () async {
      final layer = await seed(['Maxvorstadt']);
      final rows = await rowsFor(layer);
      final areas = await repo.watchAllBorderAreas().first;
      expect(rows.single.ref.id, areas.single.id);
      expect(rows.single.ref.id, isNot(areas.single.setId));
    });

    test('unnamed areas sort last and get a positional name', () async {
      final layer = await seed([null, 'Named']);
      final rows = await rowsFor(layer);
      expect(rows.first.title, 'Named');
      expect(rows.last.title, startsWith('Area '));
    });

    test('areas of another layer are not listed', () async {
      final mine = await seed(['Mine']);
      await seed(['Theirs']);
      expect((await rowsFor(mine)).map((r) => r.title), ['Mine']);
    });

    test('the row frames the area itself, so Zoom to lands on it', () async {
      final layer = await seed(['Maxvorstadt']);
      final rows = await rowsFor(layer);
      expect(rows.single.fitPoints, hasLength(2));
      expect(rows.single.fitPoints.first.latitude, 48.1);
      expect(rows.single.fitPoints.last.longitude, 11.6);
    });
  });
}
