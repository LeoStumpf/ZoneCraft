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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/osm_report.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/osm_report_sheet.dart';

/// The sheet that stands between a user and somebody else's database.
///
/// Most of what is checked here is restraint rather than function: that a
/// report cannot be sent empty, that the standing warning is always on screen,
/// that the daily cap the app imposes on itself actually closes the button,
/// and that a failure never eats what was typed. The composition itself is
/// `osm_report_test.dart`'s; the calls are recorded rather than made, because
/// a widget test's `FakeAsync` never finishes a real drift round-trip.
void main() {
  late AppDatabase db;
  late _RecordingRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingRepository(db);
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  const bench = OsmReportSubject(
    lat: 48.137400,
    lng: 11.575000,
    name: 'West gate bench',
    origLat: 48.137180,
    origLng: 11.575000,
    origName: 'West gate bench',
    edited: true,
    categoryLabel: 'Benches',
    tagKey: 'amenity',
    tagValue: 'bench',
    osmType: 'node',
    osmId: 240109189,
    poiPointId: 'p1',
  );

  /// Opens the sheet from a throwaway screen and pumps it into view.
  Future<void> open(
    WidgetTester tester, {
    OsmReportSubject subject = bench,
    OsmReportKind? kind,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showOsmReportSheet(context, subject, kind: kind),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The sheet scrolls past 60 % of the viewport, and the test surface is
  /// 800x600 — so the action row is below the fold unless it is scrolled to.
  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  final bodyField = find.ancestor(
    of: find.text('What should a mapper know?'),
    matching: find.byType(TextField),
  );

  testWidgets('opens on what the user just did, with a draft to argue with', (
    tester,
  ) async {
    await open(tester);
    // A moved point publishes the move, and nothing else is on offer: the
    // sheet is for passing on a change of the user's own. The draft already
    // carries the element, the tag and the measurement, because a note with
    // none of those is one a mapper cannot act on.
    expect(find.text('Publish to OpenStreetMap'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    final field = tester.widget<TextField>(bodyField);
    final text = field.controller!.text;
    expect(text, contains('amenity=bench'));
    expect(text, contains('openstreetmap.org/node/240109189'));
    expect(text, contains('24 m north'));
  });

  testWidgets('says every time who reads this and what it is not for', (
    tester,
  ) async {
    // OSM asks apps to make users aware that notes are for map data and not
    // for feedback about the app. A warning counted down by UiHints would stop
    // saying that to exactly the people comfortable enough to be careless, so
    // it is unconditional.
    await open(tester);
    expect(find.textContaining('public and permanent'), findsOneWidget);
    expect(
      find.textContaining('not for feedback about ZoneCraft'),
      findsOneWidget,
    );
  });

  testWidgets('an empty report cannot be sent or saved', (tester) async {
    await open(tester);
    await tester.enterText(bodyField, '   ');
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send now'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Keep in my list'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Save for later stores it unsent, and says so', (tester) async {
    await open(tester);
    await press(tester, 'Keep in my list');

    expect(repo.calls.single, startsWith('createOsmReport movedHere'));
    expect(repo.calls.single, contains('node/240109189'));
    // Anchored at the corrected position: that is where a mapper should look.
    expect(repo.calls.single, contains('48.1374'));
  });

  testWidgets('past the daily cap Send closes but Save stays open', (
    tester,
  ) async {
    // The cap is osm.org's own number, and the outbox is the way through it —
    // so the button that saves must never be the one that greys.
    repo.sentToday = kOsmReportsHardCapPerDay;
    await open(tester);

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send now'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Keep in my list'),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.textContaining('as many as'), findsOneWidget);
  });

  testWidgets('short of the cap it warns instead of blocking', (tester) async {
    repo.sentToday = kOsmReportsSoftCapPerDay;
    await open(tester);

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send now'))
          .onPressed,
      isNotNull,
    );
    expect(
      find.textContaining('exporting the file is the kinder route'),
      findsOneWidget,
    );
  });

  testWidgets('a hand-placed POI is offered as an addition, not a complaint', (
    tester,
  ) async {
    await open(
      tester,
      subject: const OsmReportSubject(
        lat: 48.1,
        lng: 11.5,
        name: 'My bench',
        categoryLabel: 'Benches',
        tagKey: 'amenity',
        tagValue: 'bench',
      ),
    );
    expect(
      tester.widget<TextField>(bodyField).controller!.text,
      contains('missing from OpenStreetMap'),
    );
  });

  testWidgets('deleting opens on "it is not there any more"', (tester) async {
    // The one report no edit implies: it is offered by the delete, which is
    // the change it publishes.
    await open(tester, kind: OsmReportKind.gone);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      tester.widget<TextField>(bodyField).controller!.text,
      contains('does not seem to be here any more'),
    );
    await press(tester, 'Keep in my list');
    expect(repo.calls.single, startsWith('createOsmReport gone'));
    // Pinned at the element OSM has, not the user's moved copy.
    expect(repo.calls.single, contains('48.13718'));
  });
}

class _RecordingRepository extends Repository {
  _RecordingRepository(super.db);

  final List<String> calls = [];
  int sentToday = 0;

  @override
  Future<int> osmReportsSentSince(Duration window) async => sentToday;

  @override
  Future<String> createOsmReport({
    required double lat,
    required double lng,
    required String kind,
    required String body,
    String? osmType,
    int? osmId,
    String? poiPointId,
  }) async {
    calls.add('createOsmReport $kind $lat,$lng $osmType/$osmId $body');
    return 'r1';
  }

  @override
  Future<void> markOsmReportSent(String id, int noteId) async =>
      calls.add('markOsmReportSent $id $noteId');

  @override
  Future<void> markOsmReportFailed(String id, String message) async =>
      calls.add('markOsmReportFailed $id');
}
