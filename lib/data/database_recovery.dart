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

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'error_log.dart';

/// The outcome of opening the database at startup.
class DatabaseOpenResult {
  const DatabaseOpenResult(this.database, {this.quarantinedPath, this.error});

  final AppDatabase database;

  /// Where the unreadable file was moved, if it had to be. Null on the normal
  /// path, which is every launch but the broken one.
  final String? quarantinedPath;

  /// What went wrong with the old file, kept so the user can report it.
  final Object? error;

  bool get recovered => quarantinedPath != null;
}

/// Opens the database, and if it cannot be opened, moves it aside and opens a
/// fresh one rather than leaving the app dead.
///
/// The migration chain is 31 versions of append-only blocks, several of them
/// raw destructive DDL (`DROP TABLE planes`, the v19 drop/recreate of the
/// transit tables, the v30 `DELETE FROM layers`). There was no `try` anywhere
/// near them and no `validateDatabaseSchema`, so a single throw on a user's
/// device meant every query failed — on that launch and on every launch after
/// it, because the same migration ran again and failed the same way. An app in
/// that state cannot be fixed from inside the app: even "Clear all data" goes
/// through a repository that needs a working database.
///
/// Quarantine rather than delete, always. The file is the user's entire map and
/// is very often still readable by something else — `sqlite3 .recover`, or a
/// later build of ZoneCraft that fixes the migration. Deleting it to get the
/// app running again would be trading their data for our convenience.
Future<DatabaseOpenResult> openDatabaseSafely() async {
  var db = AppDatabase();
  try {
    await _probe(db);
    return DatabaseOpenResult(db);
    // Anything at all: a failed migration, a corrupt page, a read-only file,
    // a disk with nothing left on it. What it was matters for the report, not
    // for the decision — the file is unusable and the app must still start.
    // ignore: avoid_catches_without_on_clauses
  } catch (e, s) {
    ErrorLog.instance.record(e, s, context: 'Opening the database');
    // The handle is unusable but may still hold the file open; on Android a
    // rename would otherwise fail with the old connection still attached.
    try {
      await db.close();
      // Closing a database that failed to open throws about as often as not,
      // and the rename below is what actually matters.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Deliberately empty: see above.
    }

    final moved = await _quarantine();
    db = AppDatabase();
    // If a *fresh* file cannot be created either, the problem is not the data
    // — no disk space, no permission — and pretending otherwise would put the
    // user in a loop of losing their map for nothing. Let it reach the error
    // screen with the original cause.
    await _probe(db);
    return DatabaseOpenResult(db, quarantinedPath: moved, error: e);
  }
}

/// Forces drift to open the file and run `onUpgrade`/`beforeOpen` *here*,
/// where it can be caught, instead of lazily under the first widget that
/// happens to read a provider.
Future<void> _probe(AppDatabase db) async {
  await db.customSelect('SELECT 1').get();
}

/// Renames the database and its sidecars out of the way.
///
/// The `-wal` and `-shm` files have to move with it: leaving a write-ahead log
/// next to a brand-new database of the same name is how you corrupt the
/// replacement too.
Future<String?> _quarantine() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final base = '${dir.path}/zonecraft.sqlite';
    final target = '${dir.path}/zonecraft.broken-$stamp.sqlite';

    String? moved;
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('$base$suffix');
      if (f.existsSync()) {
        f.renameSync('$target$suffix');
        moved ??= target;
      }
    }
    return moved;
    // A missing file, a read-only directory, a platform channel that is not
    // there under test — none of which should stop the fresh database opening.
    // ignore: avoid_catches_without_on_clauses
  } catch (e, s) {
    // Nothing to move, or no permission to move it. The caller opens a fresh
    // database either way; it just cannot tell the user where the old one went.
    ErrorLog.instance.record(e, s, context: 'Setting the old database aside');
    return null;
  }
}
