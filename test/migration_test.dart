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
/// What this can and cannot do **today** matters, so be precise about it. With
/// a single snapshot (v20) there is no earlier version to migrate *from*, so
/// this does not yet prove that any `if (from < N)` block is correct. What it
/// does prove is that the schema the table classes describe still matches the
/// snapshot on disk, and that the snapshot exists for the version the app
/// claims to be at. That is the tripwire: the next schema change fails these
/// tests until a new snapshot is dumped, and dumping it is the step that makes
/// a real step-verification possible.
///
/// So when the schema next changes:
///
/// ```sh
/// dart run drift_dev schema dump lib/data/database.dart drift_schemas/
/// dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
/// ```
///
/// then add `verifier.migrateAndValidate(db, 21)` here — with two snapshots it
/// genuinely walks v20 → v21 and compares the result against v21's own shape,
/// which is what catches a column added to a table class without the matching
/// migration block. A snapshot must be taken *before* that version ships; it
/// cannot be reconstructed afterwards.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('the schema the table classes build matches the v20 snapshot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 20);
  });

  test('a v20 database opens, writes and reads back', () async {
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
