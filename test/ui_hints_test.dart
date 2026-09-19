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
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';

/// The tips are a teaching aid, and the two ways they can go wrong are both
/// about *counting*: nagging someone who has understood, or falling silent
/// before they have.
///
/// The second is the subtle one. Switching the tips off must not spend their
/// showings — otherwise a user who turns them off for a month and back on gets
/// nothing, having been charged for every press they made in between.
void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });
  tearDown(() => db.close());

  group('counting', () {
    test('shows three times, then never again', () async {
      for (var i = 1; i <= 3; i++) {
        expect(await repo.noteHintShown('a'), isTrue, reason: 'showing $i');
      }
      expect(await repo.noteHintShown('a'), isFalse);
      expect(await repo.noteHintShown('a'), isFalse);
    });

    test('the limit is the caller\'s, so a tip can be made stickier', () async {
      expect(await repo.noteHintShown('a', limit: 1), isTrue);
      expect(await repo.noteHintShown('a', limit: 1), isFalse);
    });

    test('keys are counted apart', () async {
      for (var i = 0; i < 3; i++) {
        await repo.noteHintShown('a');
      }
      expect(await repo.noteHintShown('a'), isFalse);
      expect(await repo.noteHintShown('b'), isTrue,
          reason: 'one exhausted tip must not silence the others');
    });

    test('two taps in the same frame cannot show a fourth time', () async {
      // Both would read the same count outside a transaction.
      final results = await Future.wait([
        repo.noteHintShown('a'),
        repo.noteHintShown('a'),
        repo.noteHintShown('a'),
        repo.noteHintShown('a'),
      ]);
      expect(results.where((shown) => shown).length, 3);
    });
  });

  group('the switch', () {
    test('off silences every tip at once', () async {
      await repo.updateHintsEnabled(enabled: false);
      expect(await repo.noteHintShown('a'), isFalse);
      expect(await repo.noteHintShown('b'), isFalse);
    });

    test('off does not spend a showing', () async {
      // The whole point: turning them off is not the same as using them up.
      await repo.updateHintsEnabled(enabled: false);
      for (var i = 0; i < 10; i++) {
        await repo.noteHintShown('a');
      }
      await repo.updateHintsEnabled(enabled: true);
      for (var i = 1; i <= 3; i++) {
        expect(await repo.noteHintShown('a'), isTrue, reason: 'showing $i');
      }
    });

    test('a fresh install with no settings row still teaches', () async {
      // No row means nobody has chosen anything, which is exactly the user
      // the tips exist for.
      expect(await repo.noteHintShown('a'), isTrue);
    });
  });

  group('starting over', () {
    test('hands every tip back', () async {
      for (var i = 0; i < 3; i++) {
        await repo.noteHintShown('a');
      }
      expect(await repo.noteHintShown('a'), isFalse);

      await repo.resetHints();
      expect(await repo.noteHintShown('a'), isTrue);
    });

    test('also switches them back on', () async {
      await repo.updateHintsEnabled(enabled: false);
      await repo.resetHints();
      expect(await repo.noteHintShown('a'), isTrue);
      expect(
        (await repo.watchSettings().first).hintsEnabled,
        isTrue,
      );
    });
  });
}
