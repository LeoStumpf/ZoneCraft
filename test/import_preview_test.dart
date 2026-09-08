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
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:zonecraft/data/borders.dart' show borderLevels;
import 'package:zonecraft/ui/border_import_dialog.dart';
import 'package:zonecraft/ui/poi_import_dialog.dart';
import 'package:zonecraft/ui/transit_import_dialog.dart';

/// The import sheets exist to answer "how big is that, on the ground?" *before*
/// the request goes out — a radius used to be a bare number with nothing to
/// compare it against, and "too much data — pick a smaller radius" arrived only
/// after the fetch came back.
///
/// What the map draws is whatever `onPreview` last reported, so these tests are
/// about that callback: it must fire with a usable area, and it must report
/// **null** the moment the entry stops being usable, or the map would keep
/// showing a box the sheet has already refused.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      // No outer scroller: each sheet caps its own height and scrolls
      // inside, which is exactly the arrangement being exercised.
      MaterialApp(home: Scaffold(body: child)),
    );
    await tester.pump();
  }

  group('PoiImportSheet', () {
    testWidgets('previews the default radius as soon as it opens', (t) async {
      final seen = <double?>[];
      await pump(
        t,
        PoiImportSheet(
          needsCircleRadius: false,
          allCategories: false,
          onPreview: seen.add,
          onDone: (_) {},
        ),
      );
      await t.pump(); // the post-frame callback
      expect(seen, isNotEmpty);
      expect(seen.last, 1000, reason: 'the ring is up before the first edit');
    });

    testWidgets('reports every typed radius, and null when unusable',
        (t) async {
      final seen = <double?>[];
      await pump(
        t,
        PoiImportSheet(
          needsCircleRadius: false,
          allCategories: false,
          onPreview: seen.add,
          onDone: (_) {},
        ),
      );
      final field = find.widgetWithText(TextFormField, 'Search radius (m)');

      await t.enterText(field, '2500');
      expect(seen.last, 2500);

      // Past the Overpass ceiling the ring comes down rather than drawing an
      // area that will be refused.
      await t.enterText(field, '90000');
      expect(seen.last, isNull);

      await t.enterText(field, '');
      expect(seen.last, isNull);
    });

    // The validator has always used `parseDecimal`; submit used `double.parse`,
    // so in a comma-decimal locale a *valid* entry threw on Import.
    testWidgets('accepts a comma decimal, the way the validator promises',
        (t) async {
      PoiImportConfig? got;
      await pump(
        t,
        PoiImportSheet(
          needsCircleRadius: false,
          allCategories: false,
          onPreview: (_) {},
          onDone: (c) => got = c,
        ),
      );
      await t.enterText(
          find.widgetWithText(TextFormField, 'Search radius (m)'), '1500,5');
      await t.tap(find.widgetWithText(FilledButton, 'Import'));
      await t.pump();

      expect(got, isNotNull);
      expect(got!.searchRadiusMeters, 1500.5);
    });

    testWidgets('cancelling answers exactly once, with null', (t) async {
      final answers = <PoiImportConfig?>[];
      await pump(
        t,
        PoiImportSheet(
          needsCircleRadius: false,
          allCategories: false,
          onPreview: (_) {},
          onDone: answers.add,
        ),
      );
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pump();
      expect(answers, [null]);
    });
  });

  group('box import sheets', () {
    final initial = LatLngBounds(
      const LatLng(48.10, 11.50),
      const LatLng(48.20, 11.65),
    );

    testWidgets('TransitImportSheet previews its starting box', (t) async {
      final seen = <LatLngBounds?>[];
      await pump(
        t,
        TransitImportSheet(
          initial: initial,
          onPreview: seen.add,
          onDone: (_) {},
        ),
      );
      await t.pump();
      expect(seen.last?.south, closeTo(48.10, 1e-4));
      expect(seen.last?.east, closeTo(11.65, 1e-4));
    });

    testWidgets('a misordered box stops being drawn', (t) async {
      final seen = <LatLngBounds?>[];
      await pump(
        t,
        TransitImportSheet(
          initial: initial,
          onPreview: seen.add,
          onDone: (_) {},
        ),
      );
      // North below south: the sheet refuses it, so the map must stop
      // showing it too.
      await t.enterText(find.widgetWithText(TextFormField, 'North'), '48.00');
      expect(seen.last, isNull);

      await t.enterText(find.widgetWithText(TextFormField, 'North'), '48.30');
      expect(seen.last?.north, closeTo(48.30, 1e-4));
    });

    testWidgets('BorderImportSheet previews and answers once', (t) async {
      final seen = <LatLngBounds?>[];
      final answers = <BorderImportConfig?>[];
      await pump(
        t,
        BorderImportSheet(
          initial: initial,
          level: borderLevels.first,
          onPreview: seen.add,
          onDone: answers.add,
        ),
      );
      await t.pump();
      expect(seen.last?.north, closeTo(48.20, 1e-4));

      // The borders sheet is the tallest of the three, so its buttons can sit
      // below the fold on a test-sized screen.
      final cancel = find.widgetWithText(TextButton, 'Cancel');
      await t.ensureVisible(cancel);
      await t.pumpAndSettle();
      await t.tap(cancel);
      await t.pump();
      expect(answers, [null]);
    });
  });
}
