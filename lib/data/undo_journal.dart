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

import 'dart:async';

import 'package:drift/drift.dart';

import 'database.dart';
import 'undo_triggers.dart';

/// How long a step stays open after the last write before it seals itself.
///
/// Every editor in this app writes **live** — per keystroke, per slider tick,
/// and at 20 fps while a handle is dragged — so one repository call per undo
/// step would mean thirteen presses of Back to take back a typed label. This is
/// the backstop that turns a burst of writes into one step; the deterministic
/// boundaries ([sealStep], called when a sheet closes or the mode changes) are
/// what normally ends one first.
const kUndoIdle = Duration(milliseconds: 600);

/// At most this many steps are remembered; the oldest are pruned first.
const kUndoMaxSteps = 50;

/// Total journal budget. A step that would blow it on its own clears the whole
/// history instead — see [_prune].
const kUndoMaxBytes = 32 * 1024 * 1024;

/// One undoable action: a contiguous range of [undoLogTable] plus what to call
/// it. `first`/`last` are inclusive `seq` values.
class UndoStep {
  const UndoStep({
    required this.first,
    required this.last,
    required this.label,
  });

  final int first;
  final int last;
  final String label;
}

/// What the buttons need to render.
class UndoState {
  const UndoState({this.undoLabel, this.redoLabel});

  final String? undoLabel;
  final String? redoLabel;

  bool get canUndo => undoLabel != null;
  bool get canRedo => redoLabel != null;
}

/// Reads back the journal that `undo_triggers.dart` fills, as two stacks of
/// [UndoStep].
///
/// The load-bearing trick is that **undo and redo are one routine**: replaying a
/// step's statements happens with recording still on, so the statements that
/// replay itself produces are exactly the inverse step, and land on the other
/// stack. There is no separate redo log and no second code path to keep honest.
///
/// Everything is session-scoped: the log is a TEMP table, so closing the app
/// forgets the history, which is what an undo stack should do.
class UndoJournal {
  UndoJournal(this._db);

  final AppDatabase _db;

  final _undo = <UndoStep>[];
  final _redo = <UndoStep>[];
  final _changes = StreamController<UndoState>.broadcast();

  StreamSubscription<void>? _writes;
  Timer? _idle;

  /// Everything in the log with `seq` greater than this belongs to the step
  /// that is currently open. Sealing a step advances it.
  int _barrier = 0;

  /// Set while [undo]/[redo] are replaying, so the writes they make are not
  /// mistaken for a new user action.
  bool _replaying = false;

  /// Set by [group]: while non-null, [sealStep] does nothing and the step takes
  /// this name however long it runs.
  String? _group;

  bool _installed = false;
  bool _disposed = false;

  /// [suspended] nests — `clearAll` calls `ensureDefaultLayer`, which suspends
  /// too — so recording only comes back when the outermost scope ends.
  int _suspendDepth = 0;

  Stream<UndoState> get changes => _changes.stream;

  UndoState get state => UndoState(
        undoLabel: _undo.isEmpty ? null : _undo.last.label,
        redoLabel: _redo.isEmpty ? null : _redo.last.label,
      );

  /// Creates the journal tables and the triggers, then starts watching for
  /// writes. Called from `AppDatabase`'s `beforeOpen`, which drift guarantees
  /// runs before any other statement.
  Future<void> install() async {
    for (final statement in undoSetupSql()) {
      await _db.customStatement(statement);
    }
    for (final table in _db.allTables) {
      for (final statement in undoTriggerSql(table)) {
        await _db.customStatement(statement);
      }
    }
    _installed = true;
    await setRecording(recording: true);
  }

  /// Subscribes to drift's write notifications, which is all the idle timer
  /// needs — the log itself says what was written and in which order.
  ///
  /// Deliberately **not** done inside [install]. That runs from `beforeOpen`,
  /// and on a real device the database lives on a background isolate, where a
  /// subscription taken during the open handshake does not survive it — leaving
  /// every write silently unnoticed and only the explicitly sealed steps
  /// working. Called once from `undoJournalProvider`, after the database is up.
  void startWatching() {
    unawaited(_writes?.cancel());
    _writes = _db.tableUpdates().listen((_) => _touched());
  }

  /// Stops the idle timer and the write subscription. Called from
  /// `AppDatabase.close`, because both outlive the database otherwise and a
  /// timer that fires afterwards throws "database has already been closed".
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _installed = false;
    _idle?.cancel();
    await _writes?.cancel();
    await _changes.close();
  }

  Future<void> setRecording({required bool recording}) async {
    if (!_installed) return;
    await _db.customStatement(
      'UPDATE $undoCtlTable SET recording = ${recording ? 1 : 0}',
    );
  }

  /// Runs [body] with the journal switched off, for writes that are not user
  /// actions: seeding the default layer at startup, and `clearAll`, which would
  /// otherwise copy the entire database into memory just to throw it away.
  Future<T> suspended<T>(Future<T> Function() body) async {
    if (_suspendDepth == 0) {
      await sealStep();
      await setRecording(recording: false);
    }
    _suspendDepth++;
    try {
      return await body();
    } finally {
      _suspendDepth--;
      if (_suspendDepth == 0) {
        await _catchUp();
        await setRecording(recording: true);
      }
    }
  }

  /// Runs [body] as exactly one step called [label], however long it takes and
  /// however many writes it makes — an import, or a whole track recording.
  Future<T> group<T>(String label, Future<T> Function() body) async {
    // An inner group joins the outer one rather than splitting it: an import
    // that happens to call another grouped routine is still one action.
    if (_group != null) return body();
    await sealStep();
    _group = label;
    try {
      return await body();
    } finally {
      _group = null;
      await sealStep(label: label);
    }
  }

  /// Opens a group that ends at a later [endGroup] rather than at the end of a
  /// callback — the shape track recording needs, where start and stop are two
  /// separate user actions.
  Future<void> beginGroup(String label) async {
    await sealStep();
    _group = label;
  }

  Future<void> endGroup() async {
    final label = _group;
    _group = null;
    await sealStep(label: label);
  }

  /// Closes the open step, if any, and pushes it onto the undo stack.
  Future<void> sealStep({String? label}) async {
    _idle?.cancel();
    if (!_installed || _replaying || _group != null) return;
    final last = await _maxSeq();
    if (last <= _barrier) return;
    final step = UndoStep(
      first: _barrier + 1,
      last: last,
      label: label ?? await _labelFor(_barrier + 1, last),
    );
    _barrier = last;
    _undo.add(step);
    // A new action always invalidates the forward history. [_invalidateRedo]
    // usually gets there first, but it runs off an async stream event; this is
    // the exact, synchronous statement of the same rule.
    _redo.clear();
    await _prune();
    _emit();
  }

  Future<void> undo() => _apply(from: _undo, to: _redo);

  Future<void> redo() => _apply(from: _redo, to: _undo);

  Future<void> clear() async {
    _idle?.cancel();
    _undo.clear();
    _redo.clear();
    if (_installed) {
      await _db.customStatement('DELETE FROM $undoLogTable');
      _barrier = 0;
    }
    _emit();
  }

  // --- internals ------------------------------------------------------------

  /// A write landed: restart the idle timer, and — if it was a *new* action
  /// rather than our own replay — throw away anything that could have been
  /// redone.
  ///
  /// Drift delivers these events asynchronously, so they can arrive after
  /// [_replaying] has already cleared. A flag alone would therefore let a
  /// replay's own writes look like a fresh edit and wipe the redo stack it just
  /// built. The seq check is what actually decides: [_barrier] is advanced past
  /// every row a replay wrote before this can run, so anything at or below it is
  /// ours.
  void _touched() {
    if (!_installed || _disposed) return;
    if (_group == null && !_replaying) {
      _idle?.cancel();
      _idle = Timer(kUndoIdle, () => unawaited(sealStep()));
    }
    unawaited(_invalidateRedo());
  }

  Future<void> _invalidateRedo() async {
    if (_redo.isEmpty || _replaying || _disposed) return;
    if (await _maxSeq() <= _barrier) return;
    _redo.clear();
    _emit();
  }

  /// Replays the newest step of [from], and pushes the inverse it generates
  /// onto [to].
  Future<void> _apply({
    required List<UndoStep> from,
    required List<UndoStep> to,
  }) async {
    await sealStep();
    if (from.isEmpty) return;
    final step = from.removeLast();
    final rows = await _db
        .customSelect(
          'SELECT tbl, stmt FROM $undoLogTable '
          'WHERE seq BETWEEN ${step.first} AND ${step.last} ORDER BY seq DESC',
        )
        .get();

    _replaying = true;
    try {
      await _db.transaction(() async {
        // A cascading delete logs the parent *before* its children, so replaying
        // in reverse re-inserts children first. Deferring the check to commit is
        // what makes that legal — and it still validates, unlike turning foreign
        // keys off.
        await _db.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final row in rows) {
          // No arguments: drift only bypasses its prepared-statement cache on
          // the no-args path, which is what we want when every statement is
          // unique and would otherwise leak.
          await _db.customStatement(row.read<String>('stmt'));
        }
      });

      // The replay's own trigger writes are the inverse step. Read the range
      // only now: TEMP writes are transactional, so a rollback would have taken
      // its log entries with it.
      final last = await _maxSeq();
      if (last > _barrier) {
        to.add(UndoStep(first: _barrier + 1, last: last, label: step.label));
        _barrier = last;
      }
    } finally {
      _replaying = false;
    }

    // Raw statements are invisible to drift's stream engine, so nothing would
    // repaint without this. The generated `streamUpdateRules` fan a parent out
    // to its children, so notifying the tables we touched is enough.
    final tables = rows.map((r) => r.read<String>('tbl')).toSet();
    _db.notifyUpdates({for (final t in tables) TableUpdate(t)});
    await _prune();
    _emit();
  }

  /// Absorbs anything written while recording was off, so it can never be
  /// mistaken for the start of the next step.
  Future<void> _catchUp() async {
    if (!_installed) return;
    _barrier = await _maxSeq();
  }

  Future<int> _maxSeq() async {
    final row = await _db
        .customSelect('SELECT COALESCE(MAX(seq), 0) AS m FROM $undoLogTable')
        .getSingle();
    return row.read<int>('m');
  }

  /// Drops the oldest steps until the journal is inside its budget. A single
  /// step over budget on its own — a state-sized border import, whose `rings`
  /// blob the log holds a second copy of — clears the history outright: the
  /// stacks have to be contiguous, so a step that cannot be inverted invalidates
  /// everything older than it too.
  Future<void> _prune() async {
    while (_undo.length > kUndoMaxSteps) {
      _undo.removeAt(0);
    }
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(stmt)), 0) AS b FROM $undoLogTable',
        )
        .getSingle();
    if (row.read<int>('b') <= kUndoMaxBytes) return;
    if (_undo.length <= 1) {
      await clear();
      return;
    }
    _undo.removeAt(0);
    await _dropBelow(_undo.first.first);
    await _prune();
  }

  Future<void> _dropBelow(int seq) =>
      _db.customStatement('DELETE FROM $undoLogTable WHERE seq < $seq');

  /// Names a step after the first thing it touched. For a cascade that is the
  /// parent — "Delete layer", not "Delete point" — because the parent's trigger
  /// fires before the children's.
  Future<String> _labelFor(int first, int last) async {
    final row = await _db
        .customSelect(
          'SELECT tbl, op FROM $undoLogTable '
          'WHERE seq BETWEEN $first AND $last ORDER BY seq LIMIT 1',
        )
        .getSingleOrNull();
    if (row == null) return 'Edit';
    final noun = undoNouns[row.read<String>('tbl')] ?? 'change';
    switch (row.read<String>('op')) {
      case 'insert':
        return 'Add $noun';
      case 'delete':
        return 'Delete $noun';
      default:
        return 'Edit $noun';
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(state);
  }
}

/// The noun for [table] in an undo label, or null if it has none — which the
/// guard test in `test/undo_journal_test.dart` treats as a missing decision.
String? undoNounFor(String table) => undoNouns[table];

/// What to call each table in an undo label. Kept beside the journal rather
/// than in the UI because the label is derived from the log row, which is the
/// only description of the action that exists.
const undoNouns = <String, String>{
  'layers': 'layer',
  'circles': 'circle',
  'planes': 'plane',
  'subspaces': 'subspace',
  'subspace_points': 'point',
  'free_lines': 'line',
  'free_line_points': 'point',
  'free_areas': 'area',
  'free_area_points': 'point',
  'tracks': 'track',
  'track_points': 'point',
  'height_regions': 'height region',
  'height_polygons': 'height shape',
  'height_polygon_points': 'point',
  'poi_sets': 'POI category',
  'poi_points': 'POI',
  'transit_sets': 'station import',
  'transit_stops': 'station',
  'border_sets': 'border import',
  'border_areas': 'area',
  'app_settings': 'setting',
};
