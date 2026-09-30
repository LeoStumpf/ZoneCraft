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
import 'package:zonecraft/state/map_mode.dart';
import 'package:zonecraft/ui/map_controls.dart';
import 'package:zonecraft/ui/map_screen.dart';

import 'support/map_harness.dart' as harness;

/// The first widget test `map_screen.dart` has ever had.
///
/// It is not trying to test the map. It is a **tripwire for extractions**: the
/// file is 6 000 lines in one State class with 51 fields and a 2 000-line
/// `build()`, it is touched by well over half of all commits, and nothing has
/// ever asserted that it renders. Moving anything out of it was therefore
/// unverifiable, which is a large part of why nothing ever was.
///
/// So this asserts the three things an extraction could silently break: the
/// chrome row, the FAB column, and that switching mode does not throw.
///
/// Two platform dependencies need no mocking, which is worth recording because
/// it is not obvious: `_listenForSharedLinks` catches a missing app_links
/// channel explicitly, and `platformFilesSupported` is `Platform.isAndroid`,
/// false under test. Tiles fail to load and that is fine — `TileHealth` treats
/// "could not reach the server" as the ordinary offline case.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpMap(WidgetTester tester) => harness.pumpMap(tester, db);
  Future<void> quiesce(WidgetTester tester) => harness.quiesce(tester, db);

  /// Fails on any error, overflow included.
  ///
  /// Overflow used to be filtered out here: widget tests laid text out in a
  /// placeholder font wider than Roboto, and this test reported a 56 px
  /// overflow for `MapMode.distance` that the device never drew.
  /// `flutter_test_config.dart` now loads the real font, so an overflow here
  /// is one a phone would show — and `visual_robustness_test.dart` sweeps the
  /// same screen across sizes, orientations and text scales.
  void expectNoCrash(WidgetTester tester, {String? reason}) {
    final error = tester.takeException();
    if (error == null) return;
    fail('${reason ?? 'map screen'}: $error');
  }

  testWidgets('a fresh map renders its chrome without throwing', (
    tester,
  ) async {
    await pumpMap(tester);

    expectNoCrash(tester);

    // The drawer button is the way back from everything, so it is the one
    // control that must always be there.
    expect(
      find.byTooltip(mapControl(MapControlId.layers).name),
      findsOneWidget,
    );
    await quiesce(tester);
  });

  testWidgets('the FAB column and the bottom row are both present', (
    tester,
  ) async {
    await pumpMap(tester);

    // Up the right-hand side.
    expect(
      find.byTooltip(mapControl(MapControlId.goToPlace).name),
      findsOneWidget,
    );
    expect(
      find.byTooltip(mapControl(MapControlId.locate).name),
      findsOneWidget,
    );
    // Along the bottom.
    expect(find.byType(FloatingActionButton), findsWidgets);
    expectNoCrash(tester);
    await quiesce(tester);
  });

  testWidgets('the seeded layer shows in the active-layer chip', (
    tester,
  ) async {
    await pumpMap(tester);
    // `seedProvider` creates "Circles 1" on a fresh database.
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Circles'), findsWidgets);
    await quiesce(tester);
  });

  testWidgets('switching mode does not throw', (tester) async {
    await pumpMap(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    );

    for (final mode in MapMode.values) {
      container.read(mapModeProvider.notifier).set(mode);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expectNoCrash(tester, reason: 'mode $mode');
    }
    await quiesce(tester);
  });

  testWidgets('a map with a layer of objects still renders', (tester) async {
    final repo = Repository(db);
    final layerId = await repo.createLayer(
      name: 'Radar',
      colorArgb: 0xFF2196F3,
    );
    await repo.createCircle(
      layerId: layerId,
      centerLat: 48.137,
      centerLng: 11.575,
      radiusMeters: 2000,
    );

    await pumpMap(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expectNoCrash(tester);
    await quiesce(tester);
  });
}
