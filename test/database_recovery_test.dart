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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/database_recovery.dart';
import 'package:zonecraft/data/error_log.dart';

/// Points `getApplicationDocumentsDirectory()` at a scratch folder.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;

  // drift_flutter asks for this too, to place its temp files.
  @override
  Future<String?> getTemporaryPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('zonecraft_recovery');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    ErrorLog.instance.clear();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    ErrorLog.instance.clear();
  });

  File dbFile() => File('${tmp.path}/zonecraft.sqlite');

  // The contract the whole file exists for, and the one it did not actually
  // keep: `main()` awaits this *before* `runApp()`, so anything that escapes
  // here leaves the app with no widget tree at all — no error screen, because
  // `ErrorWidget.builder` needs a tree to build into, and no way to read the
  // in-memory error log. A black screen, on every launch, for ever.
  group('it never throws, because main() has no tree to fall back on', () {
    test(
      'a database that cannot be opened at all yields a result, not a throw',
      () async {
        final result = await openDatabaseSafely(
          openDatabase: () => throw const FileSystemException('no space left'),
        );

        expect(result.database, isNull, reason: 'nothing usable to hand back');
        expect(result.error, isNotNull, reason: 'so the screen can say why');
        expect(result.error.toString(), contains('no space left'));
      },
    );

    test('the ORIGINAL cause survives, not the retry’s', () async {
      var call = 0;
      final result = await openDatabaseSafely(
        openDatabase: () {
          call++;
          throw FileSystemException(call == 1 ? 'the real cause' : 'retry');
        },
      );

      expect(call, 2, reason: 'it tried again after quarantining');
      expect(
        result.error.toString(),
        contains('the real cause'),
        reason: 'the second failure is a symptom; the first is the report',
      );
    });

    test('the failure is recorded, so About can show it', () async {
      await openDatabaseSafely(
        openDatabase: () => throw const FileSystemException('boom'),
      );
      expect(ErrorLog.instance.isEmpty, isFalse);
    });
  });

  group('a healthy database opens untouched', () {
    test('no quarantine, no error, and the file stays put', () async {
      final result = await openDatabaseSafely();
      addTearDown(() => result.database?.close());

      expect(result.database, isNotNull);
      expect(result.recovered, isFalse);
      expect(result.quarantinedPath, isNull);
      expect(dbFile().existsSync(), isTrue);
      expect(tmp.listSync().where((f) => f.path.contains('broken')), isEmpty);
    });
  });

  group('an unreadable database is moved aside, never deleted', () {
    test('garbage in the file is quarantined and a fresh one opens', () async {
      // Not a database. Drift will fail to open it, which is the case a
      // corrupt page or a half-written migration produces on a real device.
      dbFile().writeAsBytesSync(List<int>.filled(4096, 0x7f), flush: true);

      final result = await openDatabaseSafely();
      addTearDown(() => result.database?.close());

      expect(result.database, isNotNull, reason: 'the app must still start');
      expect(result.recovered, isTrue);
      expect(result.quarantinedPath, isNotNull);

      // The point of quarantining rather than deleting: the bytes are still
      // there, because they are the user's entire map and are often still
      // recoverable by something else.
      final moved = File(result.quarantinedPath!);
      expect(moved.existsSync(), isTrue);
      expect(moved.lengthSync(), 4096);
    });

    // Leaving a stale write-ahead log beside a brand-new database of the same
    // name is how you corrupt the replacement too. In practice sqlite3 removes
    // both sidecars itself when the failed handle is closed, so by the time the
    // rename runs there is nothing left to move — measured, not assumed. The
    // loop over the suffixes stays as belt-and-braces for the paths where that
    // cleanup does not happen; what this asserts is the contract either way.
    test('no sidecar of the old database is left beside the new one', () async {
      dbFile().writeAsBytesSync(List<int>.filled(1024, 0x7f), flush: true);
      File('${tmp.path}/zonecraft.sqlite-wal').writeAsStringSync('wal');
      File('${tmp.path}/zonecraft.sqlite-shm').writeAsStringSync('shm');

      final result = await openDatabaseSafely();
      addTearDown(() => result.database?.close());

      for (final suffix in ['-wal', '-shm']) {
        final f = File('${tmp.path}/zonecraft.sqlite$suffix');
        if (f.existsSync()) {
          expect(
            f.readAsStringSync(),
            isNot(anyOf('wal', 'shm')),
            reason: 'a sidecar from the old database survived beside the new',
          );
        }
      }
    });

    test('the fresh database is usable, not just open', () async {
      dbFile().writeAsBytesSync(List<int>.filled(1024, 0x7f), flush: true);

      final result = await openDatabaseSafely();
      final db = result.database!;
      addTearDown(db.close);

      // A real write through the schema the migration chain just built.
      final id = await Repository(db).ensureDefaultLayer();
      expect(id, isNotEmpty);
    });
  });

  group('AppDatabase.forTesting is unaffected', () {
    test('the in-memory constructor still works', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
    });
  });
}
