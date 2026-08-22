import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';

import 'generated_migrations/schema.dart';

/// Guards the migration chain, which nothing tested before this.
///
/// `AppDatabase.migration` is twenty append-only blocks deep and one of them
/// (v19) is destructive — it drops and recreates the transit tables because
/// SQLite cannot relax a NOT NULL in place. Until now the only thing exercising
/// any of that was `scripts/build.sh --install` re-installing over the one
/// development phone, i.e. exactly one upgrade path on exactly one database.
///
/// With **six** snapshots (v20 … v25) this now does what one snapshot could not:
/// it opens a real older database, runs the app's own `onUpgrade` against it,
/// and compares the result to the next version's independently-dumped shape. That is what
/// catches a column added to a table class without the matching
/// `if (from < N)` block — the failure mode that only ever showed up on a
/// user's phone, since a fresh install creates the newest schema directly and
/// never runs a migration at all.
///
/// When the schema next changes:
///
/// ```sh
/// dart run drift_dev schema dump lib/data/database.dart drift_schemas/
/// dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
/// ```
///
/// then add the v25 → v26 step below. A snapshot must be taken *before* that
/// version ships; it cannot be reconstructed afterwards.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('the schema the table classes build matches the v25 snapshot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 25);
  });

  test('v20 → today upgrades a real database, and keeps its rows', () async {
    // The v21 change adds POI OSM identity. The thing worth proving is not that
    // the columns appear — `migrateAndValidate` covers the shape — but that a
    // POI stored before v21 survives the upgrade with a *null* identity, since
    // there is nothing to backfill it from and a wrong guess would make dedup
    // silently drop a real POI later.
    final old = await verifier.schemaAt(20);
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type) "
      "VALUES ('l1', 'POIs', 1, 0, 'poi')",
    );
    old.rawDatabase.execute(
      "INSERT INTO poi_sets (id, layer_id, category_key, center_lat, "
      "center_lng, radius_meters) "
      "VALUES ('s1', 'l1', 'cafe', 48.1, 11.5, 800)",
    );
    old.rawDatabase.execute(
      "INSERT INTO poi_points (id, poi_set_id, lat, lng, name, sort_order) "
      "VALUES ('p1', 's1', 48.11, 11.51, 'Café A', 0)",
    );

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    // Validated against the *current* version, not v21: opening a database runs
    // the whole remaining chain, so this is the real "upgrade from an old
    // install" path rather than a snapshot-to-snapshot hop.
    await verifier.migrateAndValidate(db, 25);

    final rows = await db.select(db.poiPoints).get();
    expect(rows, hasLength(1), reason: 'the upgrade must not drop POIs');
    expect(rows.single.name, 'Café A');
    expect(rows.single.osmType, isNull);
    expect(rows.single.osmId, isNull);
  });

  test('v21 → today leaves every existing element on the layer colour', () async {
    // The v22 change adds per-element colours. The promise that matters to
    // someone upgrading is that their map does not change: every migrated row
    // must come out with **no** override and shade **0**, and shade 0 is the
    // layer colour itself (see `ui/element_color.dart`).
    final old = await verifier.schemaAt(21);
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type) "
      "VALUES ('l1', 'Circles', 4278190335, 0, 'circles')",
    );
    old.rawDatabase.execute(
      "INSERT INTO circles (id, layer_id, center_lat, center_lng, "
      "radius_meters, label) VALUES ('c1', 'l1', 48.1, 11.5, 1000, 'Home')",
    );

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 25);

    final circle = (await db.select(db.circles).get()).single;
    expect(circle.label, 'Home', reason: 'the upgrade must not drop circles');
    expect(circle.colorArgb, isNull, reason: 'no override was ever set');
    expect(circle.colorShade, 0, reason: 'shade 0 == the layer colour');
  });

  test('v22 → today leaves every border area marked as untouched OSM geometry',
      () async {
    // The v23 change makes border outlines reshapeable and records when one
    // was. Everything that already exists is by definition *not* reshaped, and
    // that has to survive the upgrade: a stored area wrongly flagged as edited
    // would tell the user their snapshot had been forked when it hadn't.
    final old = await verifier.schemaAt(22);
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type, "
      "border_level) VALUES ('l1', 'Districts', 4278190335, 0, 'borders', '8')",
    );
    old.rawDatabase.execute(
      "INSERT INTO border_sets (id, layer_id, south, west, north, east, "
      "admin_level, fetched_at) VALUES ('s1', 'l1', 48.0, 11.0, 48.2, 11.3, "
      "'8', 1700000000)",
    );
    old.rawDatabase.execute(
      "INSERT INTO border_areas (id, set_id, osm_id, name, south, west, "
      "north, east, label_lat, label_lng, point_count, rings, way_ids) "
      "VALUES ('a1', 's1', 42, 'Maxvorstadt', 48.0, 11.0, 48.1, 11.1, "
      "48.05, 11.05, 4, "
      "'[[[48.0,11.0],[48.0,11.1],[48.1,11.1],[48.1,11.0]]]', '[7]')",
    );

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 25);

    final area = (await db.select(db.borderAreas).get()).single;
    expect(area.name, 'Maxvorstadt', reason: 'the upgrade must not drop areas');
    expect(area.editedAt, isNull, reason: 'null == untouched OSM geometry');
  });

  test('v23 → today gives every existing layer the track defaults', () async {
    // The v24 change adds the `track` type, whose two settings live on *every*
    // layer row. A layer that predates them must come out with the defaults
    // rather than 0.0 — a zero stroke width would draw nothing at all, and the
    // drawer decides whether to show an opacity chip by comparing against
    // `defaultLayerOpacity`, so wrong defaults are visible immediately.
    final old = await verifier.schemaAt(23);
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type) "
      "VALUES ('l1', 'Lines', 4278190335, 0, 'freeline')",
    );

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 25);

    final layer = (await db.select(db.layers).get()).single;
    expect(layer.name, 'Lines', reason: 'the upgrade must not drop layers');
    expect(layer.trackStrokeWidth, 4.0);
    expect(layer.trackMinDistanceMeters, 10.0);
  });


  test('v24 → today leaves every existing POI set an import', () async {
    // The v25 change adds hand-placed POI categories. The distinction is the
    // whole point of the feature: an import is a snapshot of what OSM returned
    // and refuses hand-placed points, so a fetched set that migrated in as
    // `is_manual = 1` would quietly become editable and stop being a record of
    // anything.
    final old = await verifier.schemaAt(24);
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type) "
      "VALUES ('l1', 'POIs', 4278190335, 0, 'poi')",
    );
    old.rawDatabase.execute(
      "INSERT INTO poi_sets (id, layer_id, category_key, center_lat, "
      "center_lng, radius_meters, label) "
      "VALUES ('s1', 'l1', 'cafe', 48.1, 11.5, 1000.0, 'Cafés')",
    );

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 25);

    final set = (await db.select(db.poiSets).get()).single;
    expect(set.label, 'Cafés', reason: 'the upgrade must not drop imports');
    expect(set.isManual, isFalse, reason: 'a fetched set is not hand-made');
    expect(set.iconKey, isNull, reason: 'an import icons itself by category');
  });

  test('a v25 database opens, writes and reads back', () async {
    // `migrateAndValidate` proves the *shape*; this proves the thing opens and
    // the foreign keys the cascade deletes depend on are actually on.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = Repository(db);

    final layerId = await repo.createLayer(name: 'L', colorArgb: 0xFF0000FF);
    await repo.createCircle(
      layerId: layerId,
      centerLat: 48.1,
      centerLng: 11.5,
      radiusMeters: 1000,
    );
    expect(await repo.watchAllCircles().first, hasLength(1));

    // The `PRAGMA foreign_keys = ON` in `beforeOpen` is what makes this cascade;
    // without it the circle would outlive its layer as an orphan row.
    await repo.deleteLayer(layerId);
    expect(await repo.watchAllCircles().first, isEmpty);
  });

  test('every schema version we can build has a snapshot', () {
    // Guards the process, not the code: if `schemaVersion` moves ahead of the
    // newest dumped snapshot, the dump step was skipped and the next release
    // ships an unverifiable migration.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      GeneratedHelper.versions,
      contains(db.schemaVersion),
      reason: 'Schema is at v${db.schemaVersion} but the newest snapshot is '
          'v${GeneratedHelper.versions.last}. Run:\n'
          '  dart run drift_dev schema dump lib/data/database.dart drift_schemas/\n'
          '  dart run drift_dev schema generate drift_schemas/ test/generated_migrations/',
    );
  });
}
