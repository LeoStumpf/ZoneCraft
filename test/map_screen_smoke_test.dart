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
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/map_controls.dart';
import 'package:zonecraft/ui/map_screen.dart';
import 'package:zonecraft/ui/welcome_sheet.dart';

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

  /// Winds the map down inside the test body, which the binding requires:
  /// it refuses to end a body with a pending timer, and three different
  /// things here leave one.
  ///
  /// * `_hint()` shows a SnackBar, whose auto-dismiss timer is real.
  /// * `UndoJournal` arms an idle timer on every write.
  /// * drift posts a zero-duration timer per query stream when the stream is
  ///   cancelled (`StreamQueryStore.markAsClosed`) — and the streams are only
  ///   cancelled when the `ProviderScope` unmounts, which otherwise happens
  ///   after the body has returned.
  ///
  /// So: pump past the SnackBar, unmount the tree, pump again to let drift's
  /// close timers fire, and stop the journal. The database stays open until
  /// `tearDown` because `MapScreen.dispose()` saves the camera through it.
  Future<void> quiesce(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() => db.undo.dispose());
    await tester.pump();
  }

  /// Fails on a crash, but not on a layout overflow.
  ///
  /// Widget tests lay text out in a placeholder font whose metrics are not the
  /// real one's, so a `Row` that fits on a device can overflow here purely
  /// because the glyphs are wider. That is exactly what happened: this test
  /// reported "RenderFlex overflowed by 56 pixels" for
  /// `MapMode.distance`, and the same mode on a 1080x2340 emulator renders the
  /// banner with room to spare and logs no overflow at all.
  ///
  /// So overflow is filtered rather than asserted. Layout at width and text
  /// scale is checked on a device, where the font is real; what this file is
  /// for is "does the map still build and switch modes without throwing".
  void expectNoCrash(WidgetTester tester, {String? reason}) {
    final error = tester.takeException();
    if (error == null) return;
    final text = error.toString();
    if (text.contains('overflowed')) return;
    fail('${reason ?? 'map screen'}: $error');
  }

  Future<void> pumpMap(WidgetTester tester) async {
    // Hide the base map first. Otherwise `CachedTileProvider` issues real HTTP
    // requests for every visible tile — `package:http` is not stubbed by the
    // test binding — and the test waits on a network that is not there. This
    // is the app's own "Map" layer toggle, so nothing is faked: the map simply
    // renders with no tiles, which is exactly the state it shows offline.
    await Repository(db).updateBasemapVisible(visible: false);
    // Burn the first-run welcome. It is a modal route with a life of its own,
    // it is covered by `welcome_test.dart`, and what this file is about is the
    // map underneath it.
    await Repository(db).noteHintShown(kWelcomeHintKey, limit: 1);

    // A phone-shaped surface; the FAB row's layout depends on width.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    // Not pumpAndSettle: tiles are loading and never will, so nothing settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
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
