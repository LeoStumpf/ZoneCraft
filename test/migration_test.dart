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
/// With **two** snapshots (v20, v21) this now does what one snapshot could not:
/// it opens a real v20 database, runs the app's own `onUpgrade` against it, and
/// compares the result to v21's independently-dumped shape. That is what
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
/// then add the v21 → v22 step below. A snapshot must be taken *before* that
/// version ships; it cannot be reconstructed afterwards.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('the schema the table classes build matches the v21 snapshot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 21);
  });

  test('v20 → v21 upgrades a real database, and keeps its rows', () async {
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
    await verifier.migrateAndValidate(db, 21);

    final rows = await db.select(db.poiPoints).get();
    expect(rows, hasLength(1), reason: 'the upgrade must not drop POIs');
    expect(rows.single.name, 'Café A');
    expect(rows.single.osmType, isNull);
    expect(rows.single.osmId, isNull);
  });

  test('a v21 database opens, writes and reads back', () async {
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
