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
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/map_mode.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/circle_editor.dart';
import 'package:zonecraft/ui/map_screen.dart';

import 'support/map_harness.dart';
import 'support/seed.dart';

/// Turning the phone, and looking at the whole world or one street.
///
/// Rotation is a resize to Flutter — the activity is not recreated
/// (`configChanges` in the manifest) — so nothing *should* be lost. These pin
/// that: a mode, an open editor, the drawer, a sheet and a move in progress
/// all survive a turn and a turn back, the camera stays on the same place,
/// and nothing is reported while the layout changes under them.
///
/// The zoom sweep draws every layer type, inverted where it can be and with
/// a wide uncertainty band, at the map's two limits: zoom 2 (the whole world,
/// where a 500 m band is under a pixel and an inverted fill is nearly the
/// whole screen) and zoom 19 (where a circle is far bigger than the screen
/// and every ring is clipped to the viewport).
void main() {
  const portrait = TestScreen(
    'pixel4a',
    Size(393, 851),
    padding: EdgeInsets.only(top: 24, bottom: 24),
  );
  const landscape = TestScreen(
    'pixel4a landscape',
    Size(851, 393),
    padding: EdgeInsets.only(left: 32, bottom: 16),
  );

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MapScreen)));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Portrait → landscape → portrait, checking [holds] after each turn.
  Future<void> turn(
    WidgetTester tester,
    String state,
    void Function(String when) holds,
  ) async {
    final errors = await collectErrors(() async {
      for (final (step, screen) in [
        ('after turning to landscape', landscape),
        ('after turning back', portrait),
      ]) {
        applyScreen(tester, screen);
        await settle(tester);
        holds('$state, $step');
      }
    });
    expect(
      errors,
      isEmpty,
      reason: '$state while turning:\n${describeErrors(errors)}',
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('a turn keeps the mode, the editor, the drawer, a sheet and a '
      'move', (tester) async {
    late SeededMap seeded;
    await tester.runAsync(() async => seeded = await seedAllTypes(db));
    await pumpMap(tester, db, screen: portrait);
    await settle(tester);
    final c = container(tester);
    final centre = c.read(mapCenterProvider);

    // A mode.
    c.read(mapModeProvider.notifier).set(MapMode.add);
    await settle(tester);
    await turn(tester, 'Add mode', (when) {
      expect(c.read(mapModeProvider), MapMode.add, reason: when);
    });
    c.read(mapModeProvider.notifier).set(MapMode.view);

    // An editor.
    c.read(selectedCircleProvider.notifier).select(seeded.ids['circle']);
    await settle(tester);
    expect(find.byType(CircleEditorSheet), findsOneWidget);
    await turn(tester, 'circle editor', (when) {
      expect(find.byType(CircleEditorSheet), findsOneWidget, reason: when);
    });

    // A POI move in progress.
    c.read(selectedCircleProvider.notifier).select(null);
    c.read(selectedPoiPointProvider.notifier).select(seeded.ids['poi']);
    await settle(tester);
    c
        .read(pointMoveProvider.notifier)
        .start(seeded.ids['poi']!, const LatLng(48.142, 11.58));
    await settle(tester);
    await turn(tester, 'POI move', (when) {
      expect(c.read(pointMoveProvider), isNotNull, reason: when);
    });
    c.read(pointMoveProvider.notifier).cancel();
    c.read(selectedPoiPointProvider.notifier).select(null);
    await settle(tester);

    // The drawer.
    final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await settle(tester);
    await turn(tester, 'drawer', (when) {
      expect(scaffold.isDrawerOpen, isTrue, reason: when);
    });
    scaffold.closeDrawer();
    await settle(tester);

    // A modal sheet (the layer sheet, off the active-layer chip).
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_ActiveLayerChip',
      ),
    );
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    await turn(tester, 'layer sheet', (when) {
      expect(find.byType(BottomSheet), findsOneWidget, reason: when);
    });

    // And the camera never moved.
    final after = c.read(mapCenterProvider);
    if (centre != null && after != null) {
      expect(after.latitude, closeTo(centre.latitude, 1e-6));
      expect(after.longitude, closeTo(centre.longitude, 1e-6));
    }
    await quiesce(tester, db);
  });

  for (final screen in [portrait, landscape]) {
    for (final zoom in [2.0, 19.0]) {
      for (final lng in [11.575, 179.9]) {
        testWidgets('every type draws at zoom $zoom, lng $lng: $screen', (
          tester,
        ) async {
          await tester.runAsync(() async {
            final seeded = await seedAllTypes(db);
            final repo = Repository(db);
            // Inverted where invert means something, with a wide band.
            for (final layer in seeded.layers) {
              if (const {
                'circles',
                'subspace',
                'freeline',
                'freearea',
              }.contains(layer.type)) {
                await repo.updateLayer(layer.id, isInverted: true);
              }
            }
            await repo.updateUncertainty(500);
            // lng 179.9 puts the antimeridian on screen at zoom 2.
            await repo.saveCamera(48.137, lng, zoom);
          });
          final errors = await collectErrors(() async {
            await pumpMap(tester, db, screen: screen);
            await settle(tester);
          });
          expect(errors, isEmpty, reason: describeErrors(errors));
          expect(tester.takeException(), isNull);
          // The camera really is where the sweep says it is.
          final camera = MapCamera.of(
            tester.element(
              find
                  .descendant(
                    of: find.byType(FlutterMap),
                    matching: find.byWidgetPredicate((_) => true),
                  )
                  .last,
            ),
          );
          expect(camera.zoom, closeTo(zoom, 0.01));
          await quiesce(tester, db);
        });
      }
    }
  }
}
