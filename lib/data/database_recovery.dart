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

  /// Null when the database could not be opened **at all** — not even a fresh
  /// one. The app still starts; it shows [DataUnavailableScreen] instead of a
  /// map. See [openDatabaseSafely] for why this is nullable rather than a
  /// thrown exception.
  final AppDatabase? database;

  /// Where the unreadable file was moved, if it had to be. Null on the normal
  /// path, which is every launch but the broken one.
  final String? quarantinedPath;

  /// What went wrong, kept so the user can report it. Always the **first**
  /// cause: if the retry fails too, that second failure is a symptom and this
  /// stays the thing worth reading.
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
///
/// **This function never throws.** That is a hard contract, not politeness:
/// `main()` awaits it *before* `runApp()`, so anything escaping here leaves the
/// app with no widget tree at all. `ErrorWidget.builder` needs a tree to build
/// into and the in-memory [ErrorLog] is reachable only through a screen, so the
/// user would get a black window, on every launch, with no way out — the exact
/// unfixable-from-inside state this file exists to prevent, reintroduced one
/// level up. A total failure comes back as a result with a null
/// [DatabaseOpenResult.database] instead.
///
/// [openDatabase] exists so a test can make opening fail on demand; production
/// always uses the real constructor.
Future<DatabaseOpenResult> openDatabaseSafely({
  AppDatabase Function()? openDatabase,
}) async {
  final open = openDatabase ?? AppDatabase.new;

  // Declared outside the try so the failed handle is still reachable in the
  // catch: on Android the quarantine rename fails while the old connection
  // holds the file open.
  AppDatabase? attempt;
  try {
    attempt = open();
    await _probe(attempt);
    return DatabaseOpenResult(attempt);
    // Anything at all: a failed migration, a corrupt page, a read-only file,
    // a disk with nothing left on it. What it was matters for the report, not
    // for the decision — the file is unusable and the app must still start.
    // ignore: avoid_catches_without_on_clauses
  } catch (e, s) {
    ErrorLog.instance.record(e, s, context: 'Opening the database');
    await _closeQuietly(attempt);

    final moved = await _quarantine();
    try {
      final fresh = open();
      await _probe(fresh);
      return DatabaseOpenResult(fresh, quarantinedPath: moved, error: e);
      // A *fresh* file cannot be created either, so the problem is not the
      // data — no disk space, no permission, a read-only app directory. The
      // app starts and says so; `e` is kept rather than this second failure,
      // which is a symptom of it.
      // ignore: avoid_catches_without_on_clauses
    } catch (e2, s2) {
      ErrorLog.instance.record(e2, s2, context: 'Opening a fresh database');
      return DatabaseOpenResult(null, quarantinedPath: moved, error: e);
    }
  }
}

/// Closes a handle that failed to open, if there is one.
///
/// Closing a database that never opened throws about as often as not, and the
/// quarantine rename is what actually matters — but on Android the rename
/// fails while the old connection still holds the file, so it is worth trying.
Future<void> _closeQuietly(AppDatabase? db) async {
  if (db == null) return;
  try {
    await db.close();
    // Closing a handle that never opened throws about as often as not, and
    // the quarantine rename is what actually matters.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    // Deliberately empty: see above.
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
