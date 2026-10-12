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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/ui/map_screen.dart';

import 'support/map_harness.dart';

/// The two names the chrome exists to show are shown whole.
///
/// At 320 dp and the largest font the active-layer chip printed "P…" and the
/// drawer's title "L…": both rows fitted — no stripe, nothing for the layout
/// sweep to report — and both said nothing. The chip now takes a line of its
/// own and the drawer's buttons drop under its title when the name would get
/// less than about eight characters' room.
void main() {
  group('activeLayerChipOnOwnLine', () {
    test('a phone at the default font keeps the chip in the row', () {
      expect(
        activeLayerChipOnOwnLine(
          rowWidth: 393 - 16,
          undo: true,
          compass: false,
          nameRoom: 90,
        ),
        isFalse,
      );
    });

    test('320 dp at the largest font gives the chip its own line', () {
      expect(
        activeLayerChipOnOwnLine(
          rowWidth: 320 - 16,
          undo: true,
          compass: false,
          nameRoom: 180,
        ),
        isTrue,
      );
    });

    test('the compass takes its room from the chip', () {
      bool own({required bool compass}) => activeLayerChipOnOwnLine(
        rowWidth: 393 - 16,
        undo: true,
        compass: compass,
        nameRoom: 90,
      );
      expect(own(compass: false), isFalse);
      expect(own(compass: true), isTrue);
    });
  });

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const name = 'POIs 1';
  const bars = EdgeInsets.only(top: 24, bottom: 24);
  final screens = [
    for (final size in const [Size(320, 568), Size(393, 851)])
      for (final scale in const [1.0, 1.3, 2.0])
        TestScreen('phone', size, textScale: scale, padding: bars),
    const TestScreen(
      'phone',
      Size(320, 568),
      textScale: 2.0,
      padding: bars,
      nonLinear: true,
    ),
  ];

  bool cut(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

  for (final screen in screens) {
    testWidgets('the layer name and the drawer title are whole: $screen', (
      tester,
    ) async {
      await Repository(
        db,
      ).createLayer(name: name, colorArgb: 0xFFC62828, type: 'poi');
      final errors = await collectErrors(() async {
        await pumpMap(tester, db, screen: screen);
        await tester.pump();

        final chip = find.text(name);
        expect(chip, findsOneWidget);
        expect(cut(tester, chip), isFalse, reason: 'chip reads "P…"');

        tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final title = find.text('Layers');
        expect(cut(tester, title), isFalse, reason: 'drawer reads "L…"');
      });
      expect(errors, isEmpty, reason: describeErrors(errors));
      await quiesce(tester, db);
    });
  }
}
