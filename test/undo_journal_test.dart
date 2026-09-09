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

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/undo_journal.dart';
import 'package:zonecraft/data/undo_triggers.dart';

/// The storage half of undo/redo: that SQLite's own triggers record an inverse
/// for every write, and that replaying it restores the database exactly.
///
/// The cases worth having are the ones no call site could get right by hand —
/// a cascading delete (which Dart never sees the contents of), a layer-wide
/// recolour that happens *after* the transaction returns, and the tables that
/// must record nothing at all.
void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
    // Force `beforeOpen`, which is what installs the journal.
    await db.customStatement('SELECT 1');
    // What `undoJournalProvider` does in the app, and for the same reason: the
    // subscription cannot be taken during `beforeOpen`.
    db.undo.startWatching();
    await db.undo.sealStep();
    await db.undo.clear();
  });

  tearDown(() async {
    await db.undo.dispose();
    await db.close();
  });

  Future<String> layer() =>
      repo.createLayer(name: 'L', colorArgb: 0xFF2196F3);

  Future<int> logRows() async {
    final r = await db
        .customSelect('SELECT COUNT(*) AS c FROM $undoLogTable')
        .getSingle();
    return r.read<int>('c');
  }

  Future<String> snapshot(List<String> tables) async {
    final out = StringBuffer();
    for (final t in tables) {
      final rows = await db.customSelect('SELECT * FROM "$t" ORDER BY id').get();
      out.writeln('$t: ${rows.map((r) => r.data).toList()}');
    }
    return out.toString();
  }

  group('recording', () {
    test('startup seeding leaves nothing to undo', () async {
      await repo.ensureDefaultLayer();
      await db.undo.sealStep();
      expect(db.undo.state.canUndo, isFalse);
    });

    test('the tile cache is never journalled', () async {
      await repo.putTile('https://example/1.png', Uint8List.fromList([1, 2]));
      await repo.getTile('https://example/1.png');
      expect(await logRows(), 0);
    });

    test('saveCamera is not an edit; uncertainty is', () async {
      await repo.saveCamera(48, 11, 12);
      expect(await logRows(), 0);
      await repo.updateUncertainty(750);
      expect(await logRows(), 1);
    });

    test('a write that changes nothing opens no step', () async {
      final l = await layer();
      final id = await repo.createCircle(
          layerId: l, centerLat: 48, centerLng: 11, radiusMeters: 500);
      await db.undo.sealStep();
      final before = await logRows();
      await repo.updateCircle(id, radiusMeters: 500);
      expect(await logRows(), before);
    });

    test('clearAll wipes the history instead of recording itself', () async {
      final l = await layer();
      await repo.createCircle(
          layerId: l, centerLat: 48, centerLng: 11, radiusMeters: 500);
      await db.undo.sealStep();
      expect(db.undo.state.canUndo, isTrue);
      await repo.clearAll();
      expect(db.undo.state.canUndo, isFalse);
      expect(await logRows(), 0);
    });
  });

  group('undo and redo', () {
    test('an added circle goes away and comes back with the same id', () async {
      final l = await layer();
      await db.undo.sealStep();
      final id = await repo.createCircle(
          layerId: l, centerLat: 48, centerLng: 11, radiusMeters: 500);
      await db.undo.sealStep();
      expect(db.undo.state.undoLabel, 'Add circle');

      await db.undo.undo();
      expect(await db.select(db.circles).get(), isEmpty);
      expect(db.undo.state.redoLabel, 'Add circle');

      await db.undo.redo();
      final back = await db.select(db.circles).getSingle();
      expect(back.id, id);
      expect(back.radiusMeters, 500);
    });

    test('an edited radius restores bit-exactly', () async {
      final l = await layer();
      final id = await repo.createCircle(
          layerId: l, centerLat: 48.137154321, centerLng: 11.575382716,
          radiusMeters: 1 / 3);
      await db.undo.sealStep();
      await repo.updateCircle(id, radiusMeters: 987.654321);
      await db.undo.sealStep();

      await db.undo.undo();
      final row = await db.select(db.circles).getSingle();
      expect(row.radiusMeters, 1 / 3);
      expect(row.centerLat, 48.137154321);
    });

    test('deleting a layer restores every cascaded child', () async {
      final l = await layer();
      final sub = await repo.createSubspace(layerId: l);
      for (var i = 0; i < 5; i++) {
        await repo.addSubspacePoint(
            subspaceId: sub, lat: 48 + i / 1000, lng: 11 + i / 1000);
      }
      await repo.createCircle(
          layerId: l, centerLat: 48, centerLng: 11, radiusMeters: 500);
      await db.undo.sealStep();

      const tables = ['layers', 'circles', 'subspaces', 'subspace_points'];
      final before = await snapshot(tables);

      await repo.deleteLayer(l);
      await db.undo.sealStep();
      expect(db.undo.state.undoLabel, 'Delete layer');
      expect(await db.select(db.subspacePoints).get(), isEmpty);

      await db.undo.undo();
      expect(await snapshot(tables), before);

      await db.undo.redo();
      expect(await db.select(db.layers).get(), isEmpty);

      await db.undo.undo();
      expect(await snapshot(tables), before);
    });

    test('a new edit clears what could have been redone', () async {
      final l = await layer();
      await db.undo.sealStep();
      await repo.createCircle(
          layerId: l, centerLat: 48, centerLng: 11, radiusMeters: 500);
      await db.undo.sealStep();
      await db.undo.undo();
      expect(db.undo.state.canRedo, isTrue);

      await repo.createCircle(
          layerId: l, centerLat: 49, centerLng: 12, radiusMeters: 100);
      await db.undo.sealStep();
      expect(db.undo.state.canRedo, isFalse);
    });

    test('a group is one step however many writes it makes', () async {
      final l = await layer();
      await db.undo.sealStep();
      await db.undo.group('Import', () async {
        for (var i = 0; i < 10; i++) {
          await repo.createCircle(
              layerId: l, centerLat: 48 + i / 10, centerLng: 11, radiusMeters: 500);
        }
      });
      expect(db.undo.state.undoLabel, 'Import');
      await db.undo.undo();
      expect(await db.select(db.circles).get(), isEmpty);
      // One press took back all ten, leaving only the step before it.
      expect(db.undo.state.undoLabel, 'Add layer');
    });
  });

  test('a step seals itself with no explicit boundary', () async {
    // The regression this exists for: every *other* test seals by hand, and so
    // does most of the UI (a drag ends, a sheet closes, a tap places an
    // object). A write with no such boundary — renaming a layer in the drawer,
    // say — is left entirely to the idle timer, which is fed by
    // `startWatching`. When that subscription was taken inside `beforeOpen` it
    // did not survive the background isolate's open handshake, and those edits
    // silently never reached the stack while every hand-sealed one did.
    await repo.createLayer(name: 'L', colorArgb: 0xFF2196F3);
    expect(db.undo.state.canUndo, isFalse, reason: 'still inside the window');
    await Future<void>.delayed(kUndoIdle + const Duration(milliseconds: 200));
    expect(db.undo.state.undoLabel, 'Add layer');
  });

  test('every table is either journalled or explicitly excluded', () {
    // The guard: adding a table at some future schema version must force a
    // decision about whether its writes are undoable, rather than silently
    // defaulting to "yes" (which would be wrong for another cache) or "no"
    // (which would be a hole in the history nobody notices).
    for (final table in db.allTables) {
      final name = table.actualTableName;
      final triggers = undoTriggerSql(table);
      if (undoExcludedTables.contains(name)) {
        expect(triggers, isEmpty, reason: '$name is excluded');
      } else {
        expect(triggers, isNotEmpty, reason: '$name must be journalled');
        expect(undoNounFor(name), isNot(null),
            reason: '$name needs a noun for its undo label');
      }
    }
  });
}
