# Database and migrations

The app's whole state is one SQLite database managed by
[Drift](https://drift.simonbinder.eu/), at **schema v31**. Tables: `layers` and `folders`;
one table per region type plus its point table (`circles`, `subspaces` +
`subspace_points`, `free_lines` + `free_line_points`, `free_areas` + `free_area_points`,
`height_regions` + `height_polygons` + `height_polygon_points`); the two imports
(`poi_sets` + `poi_points`, `border_sets` + `border_areas`); `tile_cache`; `app_settings`;
`ui_hints` (the tip counters); `osm_reports` (the outbox); and `overpass_cache`, a dead
table kept for old databases.

## Migrations are append-only

`lib/data/database.dart`'s `onUpgrade` is a sequence of `if (from < N)` blocks, one per
version, and a block is never edited once its version has shipped — a user's database can be
at any version, and every block between theirs and the current one runs in order. Two
blocks *drop* tables: v19 dropped abandoned transit-route tables, and v27 folded the old
`planes` and `transit` layer types into `subspace` and `poi` (rows retyped, ids kept) and
dropped `tracks` with its data. v30 split every old `mixed` layer into one layer per kind it
held, inside a folder when that was more than one. v31 added the four `poi_points`
correction columns and the outbox, purely additively.

Installing with `scripts/build.sh --install` (adb `-r`) keeps the app's data, so every
install on the developer phone exercises the migration path on a real map.

## Every schema version has a snapshot

`drift_schemas/drift_schema_v20.json … v31.json` are dumps of each version, and
`test/migration_test.dart` opens a database at every one of them, migrates it to the
current version and checks the result — including the data v27 and v30 move around. **A
snapshot cannot be reconstructed after the version ships**, so any schema change must dump a
new one and the test fails until it exists:

```sh
dart run build_runner build      # regenerate database.g.dart
dart run drift_dev schema dump lib/data/database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

Two things bite here: column defaults must be **literals** in the table definition
(`schema generate` copies the expression verbatim, and a named constant does not exist in
the generated test code), and after a failed codegen run `dart run build_runner clean`
before trying again.

## Undo is in the database

Every table except the tile cache, the hint counters and the outbox (`undoExcludedTables`
in `lib/data/undo_triggers.dart`) is journalled by SQLite triggers; the journal is replayed
by `lib/data/undo_journal.dart`. Editors write live — per keystroke, per slider tick — so a burst of writes
within 600 ms is one step, and closing a sheet or changing mode seals one; 50 steps or 32 MB,
whichever comes first.

## Two dead columns and a dead table

`app_settings.transportOverlay` / `.borderLevels` and the `overpass_cache` table belong to
features that became layer types. They are documented as dead and left in place: dropping a
column in SQLite is a table rebuild, and a migration that only removes is one that can only
lose.

## The GeoJSON format is a fixed point

The export (`lib/data/serialization.dart`, format schema **v5**) is FeatureCollection GeoJSON
with a `zonecraft` block for what GeoJSON cannot say. The contract is that

```
export → import → export
```

is **byte-identical**, and `test/export_roundtrip_test.dart` asserts exactly that against
real rows of all seven types, whole-map and per-layer. Anything the database stores and the
UI shows has to survive the trip: a hidden layer stays hidden, a ground-height region travels
*with* its generated fill rings (regenerating needs the network, and the layer draws nothing
until it happens), a POI keeps its `osmType`/`osmId` (the dedup identity — without it a
re-import draws everything twice), a station import keeps its box and mode masks, a border
area keeps its import label, a failed import comes back as its retry row, a layer in a folder
comes back in it, and a hand-corrected POI carries both its correction *flag* and the
original values — because the row keeps its OSM id, a file whose corrections arrived
silently would launder one person's guess into "what OSM says" on the next device.

Deliberately **not** preserved: `createdAt`, a border set holding zero areas (the format has
no representation of a set), and the original `editedAt`/`fetchedAt` instants — the flag
travels, the timestamp is new.

There is one export routine (`Repository.exportData({onlyLayerId})`) and one import routine
for both scopes, so a per-layer file and a whole-map file differ only in how many layers they
hold; and foreign files are RDP-thinned on import while ZoneCraft's own are not
(`simplify: !fromZonecraft`), because thinning what the app itself wrote would change shapes
on every round-trip. The reader still translates a v1/v2 file's retired `plane`, `transitstop`
and `mixed` kinds; `track` objects are skipped.
