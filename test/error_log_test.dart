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


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/error_log.dart';
import 'package:zonecraft/ui/error_screen.dart';

void main() {
  setUp(ErrorLog.instance.clear);
  tearDown(() {
    ErrorLog.instance.clear();
    failureNotifier = null;
  });

  group('ErrorLog', () {
    test('keeps newest first', () {
      ErrorLog.instance.record('first', StackTrace.empty);
      ErrorLog.instance.record('second', StackTrace.empty);
      expect(ErrorLog.instance.entries.first.error, contains('second'));
    });

    // A crash loop must not become a memory leak of its own.
    test('is bounded', () {
      for (var i = 0; i < ErrorLog.maxEntries * 3; i++) {
        ErrorLog.instance.record('boom $i', StackTrace.empty);
      }
      expect(ErrorLog.instance.length, ErrorLog.maxEntries);
      expect(ErrorLog.instance.entries.first.error, contains('boom 59'));
    });

    test('the report names the app version and every entry', () {
      ErrorLog.instance.record('kaboom', StackTrace.empty, context: 'Saving');
      final report = ErrorLog.instance.asReport();
      expect(report, contains('ZoneCraft'));
      expect(report, contains('kaboom'));
      expect(report, contains('Saving'));
    });

    // A 200-frame Flutter stack pasted into an email is unreadable, and the
    // top of it is where the fault is.
    test('a long stack is trimmed rather than pasted whole', () {
      final long = StackTrace.fromString(
        List.generate(80, (i) => '#$i  frame$i').join('\n'),
      );
      ErrorLog.instance.record('deep', long);
      final report = ErrorLog.instance.asReport();
      expect(report, contains('frame0'));
      expect(report, isNot(contains('frame79')));
      expect(report, contains('more frames'));
    });

    test('the context is what a row leads with', () {
      ErrorLog.instance.record('DriftRemoteException: x', StackTrace.empty,
          context: 'Saving the radius');
      expect(ErrorLog.instance.entries.single.summary,
          startsWith('Saving the radius'));
    });
  });

  group('logAsyncFailure', () {
    // The whole point: these futures are deliberately not awaited, so without
    // this the rejection is printed to a stderr no phone user can read and the
    // edit silently does not persist.
    test('records a rejected write instead of losing it', () async {
      logAsyncFailure(Future<void>.error(StateError('disk full')), 'Saving');
      await Future<void>.delayed(Duration.zero);

      expect(ErrorLog.instance.length, 1);
      expect(ErrorLog.instance.entries.single.context, 'Saving');
    });

    test('tells the user, naming what they were doing', () async {
      final seen = <String>[];
      failureNotifier = seen.add;

      logAsyncFailure(
        Future<void>.error(StateError('nope')),
        'Saving the radius',
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen.single, contains('Saving the radius'));
    });

    test('a write that succeeds says nothing at all', () async {
      final seen = <String>[];
      failureNotifier = seen.add;

      logAsyncFailure(Future<void>.value(), 'Saving');
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
      expect(ErrorLog.instance.isEmpty, isTrue);
    });
  });

  group('the screens a user actually sees', () {
    // The failure this replaces: in release, Flutter's default ErrorWidget is
    // a featureless grey rectangle, and MapScreen is the app's `home:` — so
    // that rectangle was the whole app, with no message and no way out.
    testWidgets('AppErrorWidget shows the cause and offers to copy it',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppErrorWidget(
            FlutterErrorDetails(exception: StateError('a broken build')),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('a broken build'), findsOneWidget);
      expect(find.text('Copy details'), findsOneWidget);
    });

    // The reassurance has to come before the technical detail: an empty map is
    // indistinguishable from a deleted one, and the user's instinct — reinstall,
    // or "Clear all data" — is the one action that would actually destroy it.
    testWidgets('DataUnavailableScreen says the data is still there',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DataUnavailableScreen(error: StateError('no such table')),
        ),
      );

      expect(find.textContaining('has not been deleted'), findsOneWidget);
      expect(find.textContaining('do not reinstall'), findsOneWidget);
      expect(find.textContaining('no such table'), findsOneWidget);
    });

    testWidgets('DatabaseRecoveredScreen names where the old file went',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DatabaseRecoveredScreen(
            quarantinedPath: '/data/zonecraft.broken-2026.sqlite',
            error: StateError('corrupt'),
            onContinue: () {},
          ),
        ),
      );

      expect(
        find.text('/data/zonecraft.broken-2026.sqlite'),
        findsOneWidget,
      );
      expect(find.textContaining('do not reinstall'), findsOneWidget);
    });

    testWidgets('the error log screen says so when there is nothing to show',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ErrorLogScreen()),
      );
      expect(
        find.text('Nothing has gone wrong since the app started.'),
        findsOneWidget,
      );
    });

    testWidgets('a recorded error reaches the screen', (tester) async {
      ErrorLog.instance
          .record('DriftRemoteException', StackTrace.empty, context: 'Saving');
      await tester.pumpWidget(const MaterialApp(home: ErrorLogScreen()));

      expect(find.textContaining('Saving'), findsOneWidget);
      expect(find.byTooltip('Copy all'), findsOneWidget);
    });
  });
}
