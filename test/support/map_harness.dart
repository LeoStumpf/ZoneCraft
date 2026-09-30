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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/map_screen.dart';
import 'package:zonecraft/ui/welcome_sheet.dart';

/// A screen to lay the app out on: a logical size and a text scale.
///
/// [padding] stands in for the system bars (and, in landscape, a camera
/// cutout on one side), in logical pixels, because a control that fits the
/// screen but sits under the navigation bar is as unreachable as one that
/// overflows it.
class TestScreen {
  const TestScreen(
    this.name,
    this.size, {
    this.textScale = 1.0,
    this.padding = EdgeInsets.zero,
  });

  final String name;
  final Size size;
  final double textScale;
  final EdgeInsets padding;

  bool get isLandscape => size.width > size.height;

  TestScreen scaled(double scale) =>
      TestScreen(name, size, textScale: scale, padding: padding);

  @override
  String toString() =>
      '$name ${size.width.toInt()}x${size.height.toInt()} '
      '@${textScale}x';
}

/// Applies [screen] to the test view; undone by `addTearDown`.
void applyScreen(WidgetTester tester, TestScreen screen) {
  const dpr = 2.75;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = screen.size * dpr;
  final p = FakeViewPadding(
    left: screen.padding.left * dpr,
    top: screen.padding.top * dpr,
    right: screen.padding.right * dpr,
    bottom: screen.padding.bottom * dpr,
  );
  tester.view.padding = p;
  tester.view.viewPadding = p;
  tester.platformDispatcher.textScaleFactorTestValue = screen.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Everything [FlutterError.reportError] said while [body] ran.
///
/// `tester.takeException()` keeps only the first error, and a second one
/// fails the test with "multiple exceptions" that name neither; a layout
/// sweep wants the whole list, worded, so the failure says *which* row
/// overflowed on *which* screen.
Future<List<FlutterErrorDetails>> collectErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// One line per error, the part that names the widget and the amount.
String describeErrors(List<FlutterErrorDetails> errors) => errors
    .map((e) {
      final lines = e.toString().split('\n');
      final summary = lines.firstWhere(
        (l) => l.contains('overflowed') || l.contains('Exception'),
        orElse: () => lines.first,
      );
      final creator = lines.firstWhere(
        (l) => l.contains('file:///') && l.contains('/lib/'),
        orElse: () => '',
      );
      return '${summary.trim()} ${creator.trim()}';
    })
    .toSet()
    .join('\n');

/// The map screen on an in-memory database, with no network and no welcome.
///
/// The basemap is hidden: `CachedTileProvider` would otherwise issue real
/// HTTP for every tile, which the test binding does not stub. That is the
/// app's own "Map" toggle, so nothing is faked — the map renders as it does
/// offline.
Future<void> pumpMap(
  WidgetTester tester,
  AppDatabase db, {
  TestScreen? screen,
}) async {
  await Repository(db).updateBasemapVisible(visible: false);
  await Repository(db).noteHintShown(kWelcomeHintKey, limit: 1);
  applyScreen(tester, screen ?? const TestScreen('pixel4a', Size(393, 851)));
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

/// Winds the map down inside the test body, which the binding requires.
///
/// Three things leave timers behind: `_hint()`'s SnackBar, `UndoJournal`'s
/// idle timer, and drift's zero-duration close timer per query stream, which
/// only fires once the `ProviderScope` unmounts. So: pump past the SnackBar,
/// unmount, pump again, stop the journal. The database stays open until
/// `tearDown` because `MapScreen.dispose()` saves the camera through it.
Future<void> quiesce(WidgetTester tester, AppDatabase db) async {
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() => db.undo.dispose());
  await tester.pump();
}
