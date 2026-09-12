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
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/poi_sets.dart';
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
/// With **eight** snapshots (v20 … v27) this now does what one snapshot could not:
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
/// then add the v27 → v28 step below. A snapshot must be taken *before* that
/// version ships; it cannot be reconstructed afterwards.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('the schema the table classes build matches the v27 snapshot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 27);
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
    await verifier.migrateAndValidate(db, 27);

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
    await verifier.migrateAndValidate(db, 27);

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
    await verifier.migrateAndValidate(db, 27);

    final area = (await db.select(db.borderAreas).get()).single;
    expect(area.name, 'Maxvorstadt', reason: 'the upgrade must not drop areas');
    expect(area.editedAt, isNull, reason: 'null == untouched OSM geometry');
  });

  test('v23 → today keeps a layer that never had the track columns', () async {
    // v24 put the track type's two settings on *every* layer row and v27 took
    // them off again. A database from before v24 never gets them at all now —
    // the v24 block no longer adds them, and the v27 drop is guarded — so
    // this is the path where a stray `ALTER TABLE ... DROP COLUMN` on a
    // column that does not exist would throw and brick the upgrade.
    final old = await verifier.schemaAt(23);
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type) "
      "VALUES ('l1', 'Lines', 4278190335, 0, 'freeline')",
    );

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 27);

    final layer = (await db.select(db.layers).get()).single;
    expect(layer.name, 'Lines', reason: 'the upgrade must not drop layers');
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
    await verifier.migrateAndValidate(db, 27);

    final set = (await db.select(db.poiSets).get()).single;
    expect(set.label, 'Cafés', reason: 'the upgrade must not drop imports');
    expect(set.source, kPoiSourceRadius, reason: 'a fetched set is not hand-made');
    expect(set.iconKey, isNull, reason: 'an import icons itself by category');
    expect(set.fetchedAt, isNotNull,
        reason: 'an import that exists was fetched — not a retry row');
  });

  test('v25 → today backfills the stack in the order it already painted', () async {
    // The v26 change gives elements a draw order they never had. The whole
    // promise of the backfill is that an existing map renders *identically*
    // afterwards, so the order it writes has to be the order the painter
    // already used: colour groups ranked by `color_shade`, the per-layer
    // creation counter. Anything else silently restacks somebody's map on
    // upgrade — the one failure this feature can cause and nobody would report
    // as a bug, only as "it looks wrong now".
    final old = await verifier.schemaAt(25);
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type) "
      "VALUES ('l1', 'Circles', 4278190335, 0, 'circles')",
    );
    // Deliberately inserted newest-first, so a migration that just used rowid
    // would get the answer backwards.
    for (final (id, shade) in const [('c3', 2), ('c1', 0), ('c2', 1)]) {
      old.rawDatabase.execute(
        "INSERT INTO circles (id, layer_id, center_lat, center_lng, "
        "radius_meters, created_at, color_shade) "
        "VALUES ('$id', 'l1', 48.1, 11.5, 100.0, 0, $shade)",
      );
    }
    // A second layer proves the rank is per layer, not global: its lone circle
    // must come out at 0, not at 3.
    old.rawDatabase.execute(
      "INSERT INTO layers (id, name, color_argb, sort_order, type) "
      "VALUES ('l2', 'More', 4278190335, 1, 'circles')",
    );
    old.rawDatabase.execute(
      "INSERT INTO circles (id, layer_id, center_lat, center_lng, "
      "radius_meters, created_at, color_shade) "
      "VALUES ('c9', 'l2', 48.1, 11.5, 100.0, 0, 0)",
    );

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 27);

    final rows = await db.select(db.circles).get();
    final z = {for (final c in rows) c.id: c.zOrder};
    expect(z, {'c1': 0, 'c2': 1, 'c3': 2, 'c9': 0});
  });

  test('v26 → v27 folds planes into subspaces, transit into POIs, drops tracks',
      () async {
    // Three types left in one step, and two of them carry data across. The
    // promises: a plane comes back as the *same* half-plane (the near side is
    // the main point), a station import comes back as a box POI set with its
    // stations, filter and retry state intact, a hand-made category stays
    // hand-made, an old radius import does not turn into a retry row, and the
    // track layer is gone rather than left as a ghost of an unknown type.
    final old = await verifier.schemaAt(26);
    final x = old.rawDatabase.execute;
    x("INSERT INTO layers (id, name, color_argb, sort_order, type) "
        "VALUES ('lp', 'Planes', 1, 0, 'planes')");
    x("INSERT INTO planes (id, layer_id, a_lat, a_lng, b_lat, b_lng, near_a, "
        "label, z_order) VALUES ('p1', 'lp', 48.0, 11.0, 48.2, 11.4, 0, "
        "'Half', 3)");
    x("INSERT INTO layers (id, name, color_argb, sort_order, type) "
        "VALUES ('lt', 'Transit', 1, 1, 'transit')");
    x("INSERT INTO transit_sets (id, layer_id, south, west, north, east, "
        "mode_mask, visible_mode_mask, label, fetched_at, station_count, "
        "node_count) VALUES ('t1', 'lt', 48.0, 11.4, 48.3, 11.8, 7, 3, "
        "'Munich', 1700000000, 2, 5)");
    x("INSERT INTO transit_sets (id, layer_id, south, west, north, east, "
        "mode_mask, last_error) VALUES ('t2', 'lt', 48.0, 11.0, 48.1, 11.1, "
        "1, 'Overpass was busy')");
    x("INSERT INTO transit_stops (id, set_id, osm_id, lat, lng, name, "
        "mode_mask, node_count, route_ref) VALUES ('s1', 't1', 42, 48.1, "
        "11.5, 'Pasing', 6, 31, NULL)");
    x("INSERT INTO transit_stops (id, set_id, osm_id, lat, lng, name, "
        "mode_mask, node_count, route_ref) VALUES ('s2', 't1', 0, 48.15, "
        "11.55, NULL, 0, 1, 'U3')");
    x("INSERT INTO layers (id, name, color_argb, sort_order, type) "
        "VALUES ('lq', 'POIs', 1, 2, 'poi')");
    x("INSERT INTO poi_sets (id, layer_id, category_key, center_lat, "
        "center_lng, radius_meters, is_manual, created_at) "
        "VALUES ('m1', 'lq', 'star', 48, 11, 0, 1, 1700000000)");
    x("INSERT INTO poi_sets (id, layer_id, category_key, center_lat, "
        "center_lng, radius_meters, created_at) "
        "VALUES ('r1', 'lq', 'cafe', 48, 11, 800, 1700000000)");
    x("INSERT INTO layers (id, name, color_argb, sort_order, type) "
        "VALUES ('lk', 'Walk', 1, 3, 'track')");
    x("INSERT INTO tracks (id, layer_id) VALUES ('k1', 'lk')");

    final db = AppDatabase.forTesting(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 27);

    // planes: same id, near side is main at sort 0, layer retyped, z kept.
    final sub = (await db.select(db.subspaces).get()).single;
    expect((sub.id, sub.label, sub.zOrder), ('p1', 'Half', 3));
    final pts = await (db.select(db.subspacePoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .get();
    expect(
      [for (final p in pts) (p.lat, p.lng, p.isMain)],
      [(48.2, 11.4, true), (48.0, 11.0, false)],
      reason: 'near_a = 0 means B was the kept side, so B is the main point',
    );
    final types = {
      for (final l in await db.select(db.layers).get()) l.id: l.type,
    };
    expect(types, {'lp': 'subspace', 'lt': 'poi', 'lq': 'poi'},
        reason: 'the track layer is gone, not left as an unknown type');

    // transit: ids kept, source box, bbox + masks, pending row kept pending.
    final sets = {for (final s in await db.select(db.poiSets).get()) s.id: s};
    final t1 = sets['t1']!;
    expect(t1.source, kPoiSourceBox);
    expect(t1.categoryKey, kTransitStationCategoryKey);
    expect((t1.south, t1.west, t1.north, t1.east), (48.0, 11.4, 48.3, 11.8));
    expect((t1.modeMask, t1.visibleModeMask), (7, 3));
    expect(t1.fetchedAt, isNotNull);
    expect(t1.centerLat, closeTo(48.15, 1e-9));
    expect(t1.centerLng, closeTo(11.6, 1e-9));
    expect(
      t1.radiusMeters,
      closeTo(
          boxCoveringRadiusMeters(
              south: 48.0, west: 11.4, north: 48.3, east: 11.8),
          1e-6),
      reason: 'the migration and createPoiSet use the same formula',
    );
    final t2 = sets['t2']!;
    expect(t2.fetchedAt, isNull);
    expect(t2.lastError, 'Overpass was busy');
    final stops = {
      for (final p in await db.select(db.poiPoints).get()) p.id: p,
    };
    final s1 = stops['s1']!;
    expect((s1.poiSetId, s1.osmType, s1.osmId, s1.modeMask, s1.name),
        ('t1', 'node', 42, 6, 'Pasing'));
    expect(stops['s2']!.osmId, isNull, reason: 'osm id 0 is "no identity"');
    expect({s1.sortOrder, stops['s2']!.sortOrder}, {0, 1});

    // poi: is_manual folded into source; an old import is not a retry row.
    expect(sets['m1']!.source, kPoiSourceManual);
    expect(sets['m1']!.fetchedAt, isNull);
    expect(sets['r1']!.source, kPoiSourceRadius);
    expect(sets['r1']!.fetchedAt, sets['r1']!.createdAt);

    // The ids survived, so the cascade still hangs together.
    await Repository(db).deletePoiSet('t1');
    expect(await db.select(db.poiPoints).get(), isEmpty);
  });

  test('a v27 database opens, writes and reads back', () async {
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
