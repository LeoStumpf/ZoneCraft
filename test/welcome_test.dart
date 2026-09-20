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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/ui/layer_actions.dart';
import 'package:zonecraft/ui/welcome_sheet.dart';

void main() {
  group('the welcome shows once', () {
    late AppDatabase db;
    late Repository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = Repository(db);
    });
    tearDown(() => db.close());

    // Once, not the usual three. A tip that explains a button earns repeating
    // — you meet the button again. A statement of what the app is *for* is
    // read or dismissed, and returning on the second launch reads as the app
    // not trusting you.
    test('a fresh install is told, and only the first time', () async {
      expect(await repo.noteHintShown(kWelcomeHintKey, limit: 1), isTrue);
      expect(await repo.noteHintShown(kWelcomeHintKey, limit: 1), isFalse);
      expect(await repo.noteHintShown(kWelcomeHintKey, limit: 1), isFalse);
    });

    test('"Show all tips again" brings it back', () async {
      await repo.noteHintShown(kWelcomeHintKey, limit: 1);
      await repo.resetHints();
      expect(await repo.noteHintShown(kWelcomeHintKey, limit: 1), isTrue);
    });

    // Switching tips off must not burn the showing: the count is spent only on
    // a tip actually shown, so turning them back on resumes where it left off.
    test('with tips off it is not shown, and not spent either', () async {
      await repo.updateHintsEnabled(enabled: false);
      expect(await repo.noteHintShown(kWelcomeHintKey, limit: 1), isFalse);

      await repo.updateHintsEnabled(enabled: true);
      expect(await repo.noteHintShown(kWelcomeHintKey, limit: 1), isTrue);
    });
  });

  testWidgets('the welcome says what the app is for, not what buttons do',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showWelcomeSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sentence that lived only in README.md.
    expect(find.textContaining('deduction board'), findsOneWidget);
    // One worked example of the loop, so the idea is concrete.
    expect(find.textContaining('Fill outside'), findsOneWidget);
    // A door to the button guide, which nothing on the map points at.
    expect(find.text('What the buttons do'), findsOneWidget);
  });

  group('the Add-layer menu explains itself', () {
    // This is the one menu a beginner cannot avoid — you need a layer before
    // you can draw anything — and every entry used to be a bare noun with no
    // subtitle at all.
    test('every type says what it is for', () {
      for (final c in kLayerTypeChoices) {
        expect(c.subtitle, isNotNull, reason: '${c.type} has no subtitle');
        expect(c.subtitle!.trim(), isNotEmpty);
      }
    });

    test('the jargon names are gone from the labels', () {
      final labels = kLayerTypeChoices.map((c) => c.label.toLowerCase());
      for (final word in ['subspace', 'poi', 'voronoi']) {
        expect(labels, isNot(contains(word)),
            reason: '"$word" means nothing to a new user');
      }
    });

    test('every shipping layer type is offered exactly once', () {
      final types = kLayerTypeChoices.map((c) => c.type).toList();
      expect(types.toSet(), hasLength(types.length));
      for (final t in kAllLayerTypes) {
        expect(types, contains(t), reason: '$t cannot be created');
      }
    });
  });
}
