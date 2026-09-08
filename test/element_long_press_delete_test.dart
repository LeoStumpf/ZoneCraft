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
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/layer_objects_sheet.dart';

/// Long-press on an Elements row deletes that element.
///
/// The gesture is a *shortcut*, not a second delete path: it must run the same
/// confirm the row's menu entry runs, or a long-press becomes the one place in
/// the app where something disappears without being asked about. Both halves of
/// that are asserted here — the dialog appears, and Cancel really does leave the
/// row alone.
///
/// Driven by a **recording repository** over a never-opened database: a widget
/// test runs inside `FakeAsync`, where a real drift round-trip never completes,
/// and what matters here is which call the sheet makes. `database_test.dart`
/// owns what the call then does to the rows.
void main() {
  late AppDatabase db;
  late _RecordingRepository repo;
  late ProviderContainer container;

  final layer = Layer(
    id: 'L',
    name: 'Around home',
    colorArgb: 0xFF112233,
    isVisible: true,
    sortOrder: 0,
    type: 'circles',
    opacity: 1,
    isInverted: false,
    borderFillAreas: false,
    borderShowNames: false,
    trackStrokeWidth: 4,
    trackMinDistanceMeters: 10,
    createdAt: DateTime.utc(2026),
  );

  final circle = Circle(
    id: 'C1',
    layerId: 'L',
    centerLat: 48.137,
    centerLng: 11.575,
    radiusMeters: 500,
    label: 'Marienplatz',
    createdAt: DateTime.utc(2026),
    colorShade: 0,
    zOrder: 0,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingRepository(db);
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        // The sheet reads its rows through `layerSummariesProvider`, which
        // watches the global row streams; feeding those directly keeps the
        // test off drift's async entirely.
        layersProvider.overrideWith((ref) => Stream.value([layer])),
        circlesProvider.overrideWith((ref) => Stream.value([circle])),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Pumps a screen whose only job is to open the Elements sheet.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showLayerObjects(context, layer),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Marienplatz'), findsOneWidget);
  }

  testWidgets('long-pressing a row asks before deleting', (tester) async {
    await openSheet(tester);

    await tester.longPress(find.text('Marienplatz'));
    await tester.pumpAndSettle();

    // The same confirm the menu entry shows, named after the element.
    expect(find.text('Delete Marienplatz?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(repo.calls, isEmpty, reason: 'nothing is deleted until confirmed');
  });

  testWidgets('confirming the long-press deletes that element', (tester) async {
    await openSheet(tester);

    await tester.longPress(find.text('Marienplatz'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['deleteCircle C1']);
  });

  testWidgets('cancelling the long-press leaves the element alone',
      (tester) async {
    await openSheet(tester);

    await tester.longPress(find.text('Marienplatz'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.text('Marienplatz'), findsOneWidget);
  });

  // The shortcut must not replace the discoverable route: a gesture nothing
  // announces cannot be the only way to reach delete.
  testWidgets('the row menu still offers Delete', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
  });
}

class _RecordingRepository extends Repository {
  _RecordingRepository(super.db);

  final List<String> calls = [];

  @override
  Future<void> deleteCircle(String id) async => calls.add('deleteCircle $id');
}
