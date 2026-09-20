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

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/osm_reports_screen.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  /// Closes the database **inside the test body**, which is where it has to
  /// happen: every drift write arms `UndoJournal`'s idle timer
  /// (`undo_journal.dart:250`), the widget binding asserts no timer is pending
  /// when the body ends, and that check runs before `tearDown`. Closing the
  /// database disposes the journal and cancels it.
  Future<void> settleDb() => db.close();

  Future<void> seedReport() => repo.createOsmReport(
    lat: 48.1,
    lng: 11.5,
    kind: 'movedHere',
    body: 'This bench is about 20 m north of where it is mapped.',
  );

  Future<void> pump(WidgetTester tester, http.Client client) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: OsmReportsScreen(client: client)),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The failure this guards is **irreversible and external**: ZoneCraft cannot
  // delete a note it created on openstreetmap.org, a volunteer has to read and
  // close each one, and a block for abuse lands on the User-Agent — i.e. on
  // every install at once. The daily cap is checked in the same method, and a
  // second call reads it before the first has incremented anything, so the cap
  // is bypassed too.
  testWidgets('two fast taps on Send post exactly one note', (tester) async {
    await seedReport();

    var posts = 0;
    final gate = Completer<void>();
    final client = MockClient((req) async {
      posts++;
      await gate.future; // hold the request open, as a real one would be
      return http.Response('42', 200);
    });

    await pump(tester, client);

    final send = find.widgetWithText(FilledButton, 'Send');
    expect(send, findsOneWidget);

    // **No pump between the taps.** That is what makes this a real double-tap:
    // pumping would rebuild with `_sending` set and remove the button, so the
    // second tap would miss for the wrong reason and the test would pass even
    // against the unguarded code. Both taps have to hit the same frame.
    await tester.tap(send);
    await tester.tap(send);
    await tester.pump();

    gate.complete();
    // Not pumpAndSettle: the sending row shows a LinearProgressIndicator,
    // which animates for ever and never settles. Also long enough to clear
    // osmApiPacer's one-second spacing, so a second request would have had
    // every chance to go out.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    expect(posts, 1, reason: 'a second note is public, permanent and ours');
    await settleDb();
  });

  // Deliberately stops at "is sending" rather than driving the send to
  // completion. `osmApiPacer` is a process-wide singleton that computes its
  // wait from wall-clock `DateTime.now()` (`request_pacer.dart:59`) and then
  // sleeps on a timer the widget binding fakes, and its `_lastStart` survives
  // between tests — so a second widget test that waits for a send to land is
  // at the mercy of how fast the first one ran. The completion half is tested
  // below, against the repository, where there is no clock to fight.
  testWidgets('while sending, the row says so and Send is out of reach', (
    tester,
  ) async {
    await seedReport();
    final client = MockClient((req) async => http.Response('42', 200));

    await pump(tester, client);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Send'),
      findsNothing,
      reason: 'the guard, seen from outside',
    );
    await settleDb();
  });

  // The outbox's whole promise: a failure is not a loss.
  group('what a send leaves behind', () {
    test(
      'a sent report keeps its note number, so it can be found again',
      () async {
        final id = await repo.createOsmReport(
          lat: 48.1,
          lng: 11.5,
          kind: 'movedHere',
          body: 'body',
        );
        await repo.markOsmReportSent(id, 42);

        final row = (await db.select(db.osmReports).get()).single;
        expect(row.noteId, 42);
        expect(row.lastError, isNull);
        await settleDb();
      },
    );

    test('a failed report stays unsent, with the reason recorded', () async {
      final id = await repo.createOsmReport(
        lat: 48.1,
        lng: 11.5,
        kind: 'movedHere',
        body: 'body',
      );
      await repo.markOsmReportFailed(id, 'OpenStreetMap said no');

      final row = (await db.select(db.osmReports).get()).single;
      expect(row.noteId, isNull, reason: 'still in the outbox');
      expect(row.lastError, 'OpenStreetMap said no');
      await settleDb();
    });

    test('the daily cap counts sent reports, not queued ones', () async {
      for (var i = 0; i < 3; i++) {
        final id = await repo.createOsmReport(
          lat: 48.1,
          lng: 11.5,
          kind: 'movedHere',
          body: 'body $i',
        );
        if (i < 2) await repo.markOsmReportSent(id, 100 + i);
      }
      expect(await repo.osmReportsSentSince(const Duration(days: 1)), 2);
      await settleDb();
    });
  });
}
