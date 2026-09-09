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


/// Generates the SQL that turns SQLite itself into an undo journal.
///
/// Every write to a journalled table fires a trigger that appends the statement
/// which *undoes* that write to [undoLogTable]. Cascades, denormalised counters
/// and layer-wide side effects (`recolourBorderLayer`, `_liftZAbove`) are all
/// just row writes, so they are captured without any of the ~110 repository
/// call sites knowing this file exists. See `data/undo_journal.dart` for the
/// half that reads the log back.
///
/// Everything here is **TEMP**: the log, the gate and the triggers live on the
/// connection, not in the file, so there is no schema version, no migration and
/// no `drift_schemas/` snapshot — and history correctly dies with the process.
/// A *persistent* trigger could not do this at all: it cannot write to a TEMP
/// table (it compiles, then throws `no such table: main._undo_log` on every
/// write), so a file-backed journal would be a different design, not a setting.
///
/// This file is pure — table metadata in, SQL strings out — so
/// `test/undo_triggers_test.dart` can check the whole policy without a database.
library;

import 'package:drift/drift.dart';

/// The journal. `seq` orders every recorded statement; a step is a contiguous
/// range of it.
const undoLogTable = '_undo_log';

/// The recording gate, read by every trigger's `WHEN`. One row, one column.
/// Named `recording` because `on` is a reserved word — `CREATE TEMP TABLE
/// _undo_ctl(on INTEGER)` is a syntax error, not a subtle bug.
const undoCtlTable = '_undo_ctl';

/// Tables deliberately kept out of the journal.
///
/// - `tile_cache`: `getTile` is *a read that writes* (it bumps `lastUsedAt`),
///   so panning the map would fill the log with statements nobody wants back.
/// - `overpass_cache`: a documented dead table.
///
/// `app_settings` is not here because it is journalled — but only partly; see
/// [undoSettingsColumns].
const undoExcludedTables = {'tile_cache', 'overpass_cache'};

/// The settings row is written constantly by things that are not edits:
/// `saveCamera` on every camera change, `updateToolsExpanded`,
/// `updateTransitEndpoint`. Only these three columns are a user's *choice*, so
/// only they are journalled — and the inverse restores only them, or undoing
/// the uncertainty would also rewind your camera.
const undoSettingsColumns = [
  'uncertainty_meters',
  'basemap_visible',
  'basemap_opacity',
];

const _settingsTable = 'app_settings';

String _id(String name) => '"$name"';

/// A SQL string literal: `it's` -> `'it''s'`.
String _lit(String value) => "'${value.replaceAll("'", "''")}'";

/// `quote()` of a column, which is what makes this whole design work: it
/// renders NULL, text (escaped), blobs and — since SQLite 3.38 — REALs at
/// shortest-round-trip precision, so a restored coordinate is bit-identical.
///
/// Two documented losses: `-0.0` comes back as `0.0` (harmless for
/// lat/lng/opacity/offsets), and a TEXT value containing `U+0000` is truncated
/// at the NUL.
String _quote(String row, String column) => 'quote($row.${_id(column)})';

/// The statements that create the journal itself. Run before [undoTriggerSql].
List<String> undoSetupSql() => [
      'CREATE TEMP TABLE IF NOT EXISTS $undoCtlTable('
          'recording INTEGER NOT NULL)',
      'DELETE FROM $undoCtlTable',
      'INSERT INTO $undoCtlTable(recording) VALUES (0)',
      'CREATE TEMP TABLE IF NOT EXISTS $undoLogTable('
          'seq INTEGER PRIMARY KEY AUTOINCREMENT, '
          'tbl TEXT NOT NULL, '
          'op TEXT NOT NULL, '
          'stmt TEXT NOT NULL)',
      'DELETE FROM $undoLogTable',
    ];

/// The three triggers for one table, each preceded by a `DROP … IF EXISTS` so
/// installing twice on one connection is a no-op rather than an error.
///
/// `app_settings` gets only the UPDATE trigger, scoped to [undoSettingsColumns]
/// — its row is created once and never deleted by a user action.
List<String> undoTriggerSql(TableInfo<dynamic, dynamic> table) {
  final name = table.actualTableName;
  if (undoExcludedTables.contains(name)) return const [];

  final settings = name == _settingsTable;
  final all = table.$columns.map((c) => c.name).toList();
  // `$primaryKey`, not a hard-coded `id`: `tile_cache` keys on `url` and
  // `overpass_cache` on `kind`. Both are excluded today, but a generator that
  // assumed `id` would be a trap for whoever journals one later.
  final pk = table.$primaryKey.map((c) => c.name).toList();
  if (pk.isEmpty) return const [];

  String whereOn(String row) => ' WHERE ${_where(row, pk)}';
  final out = <String>[];

  if (!settings) {
    // INSERT -> delete it again.
    final undoInsert = [
      _lit('DELETE FROM ${_id(name)}'),
      _piece(whereOn('new'), 'new', pk),
    ].join(' || ');
    out.addAll(_trigger(
      'undo_${name}_ai',
      'AFTER INSERT ON ${_id(name)}',
      _gate(),
      name,
      'insert',
      undoInsert,
    ));

    // DELETE -> put the whole row back, with its original id, so every
    // reference to it (a selection, an FK child restored next) still resolves.
    final values = <String>[];
    for (var i = 0; i < all.length; i++) {
      if (i > 0) values.add(_lit(','));
      values.add(_quote('old', all[i]));
    }
    final undoDelete = [
      _lit('INSERT INTO ${_id(name)}'
          '(${all.map(_id).join(',')}) VALUES('),
      ...values,
      _lit(')'),
    ].join(' || ');
    out.addAll(_trigger(
      'undo_${name}_bd',
      // BEFORE, because AFTER cannot read the row it is asked to describe.
      'BEFORE DELETE ON ${_id(name)}',
      _gate(),
      name,
      'delete',
      undoDelete,
    ));
  }

  // UPDATE -> restore only the columns that actually changed.
  //
  // This is the difference between a usable feature and an unusable one, not a
  // micro-optimisation. `recolourBorderLayer` rewrites `color_index` on every
  // area in a layer after every border change; restoring all columns would copy
  // each area's `rings` blob into the log with it — measured at 1.19 MB per row
  // against 68 bytes here, in a log that `SQLITE_TEMP_STORE=2` keeps in RAM.
  final tracked = settings
      ? undoSettingsColumns
      : all.where((c) => !pk.contains(c)).toList();
  if (tracked.isEmpty) return out;

  // `IS NOT`, never `<>`: a NULL on either side must count as a change.
  final changed = tracked
      .map((c) => 'new.${_id(c)} IS NOT old.${_id(c)}')
      .join(' OR ');

  // The head always sets the primary key to its own value. That is a no-op as
  // an assignment, and it is what keeps the comma grammar valid when only one
  // column changed.
  final sets = <String>[
    _lit('UPDATE ${_id(name)} SET ${_id(pk.first)}='),
    _quote('old', pk.first),
  ];
  for (final c in tracked) {
    sets.add('CASE WHEN new.${_id(c)} IS NOT old.${_id(c)} '
        "THEN ${_lit(', ${_id(c)}=')} || ${_quote('old', c)} "
        "ELSE '' END");
  }
  sets.add(_piece(whereOn('old'), 'old', pk));

  out.addAll(_trigger(
    'undo_${name}_au',
    'AFTER UPDATE${settings ? ' OF ${undoSettingsColumns.map(_id).join(',')}' : ''} '
        'ON ${_id(name)}',
    // The gate *and* the change test. Drift writes a column whether or not its
    // value differs, and a slider re-writes the same number constantly — without
    // this, a no-op write records `UPDATE t SET "id"=1 WHERE "id"=1`: a
    // statement that does nothing except open an undo step.
    '${_gate()} AND ($changed)',
    name,
    'update',
    sets.join(' || '),
  ));
  return out;
}

String _gate() => '(SELECT recording FROM $undoCtlTable)';

/// `WHERE "a"=' || quote(row."a") || ' AND "b"=' || quote(row."b")`, as a SQL
/// expression fragment.
String _where(String row, List<String> pk) =>
    pk.map((c) => '${_id(c)}=<$c>').join(' AND ');

/// Turns the [_where] sketch into real concatenation against [row].
String _piece(String sketch, String row, List<String> pk) {
  final out = <String>[];
  var rest = sketch;
  for (final c in pk) {
    final marker = '<$c>';
    final i = rest.indexOf(marker);
    out.add(_lit(rest.substring(0, i)));
    out.add(_quote(row, c));
    rest = rest.substring(i + marker.length);
  }
  if (rest.isNotEmpty) out.add(_lit(rest));
  return out.join(' || ');
}

List<String> _trigger(
  String triggerName,
  String on,
  String when,
  String table,
  String op,
  String expression,
) =>
    [
      'DROP TRIGGER IF EXISTS ${_id(triggerName)}',
      'CREATE TEMP TRIGGER ${_id(triggerName)} $on WHEN $when '
          'BEGIN INSERT INTO $undoLogTable(tbl, op, stmt) '
          'VALUES(${_lit(table)}, ${_lit(op)}, $expression); END',
    ];
