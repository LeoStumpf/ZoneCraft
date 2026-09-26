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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:zonecraft/data/borders.dart' show borderLevels;
import 'package:zonecraft/state/import_preview.dart';
import 'package:zonecraft/ui/border_import_dialog.dart';
import 'package:zonecraft/ui/poi_import_dialog.dart';
import 'package:zonecraft/ui/transit_import_dialog.dart';

/// The import sheets exist to answer "how big is that, on the ground?" *before*
/// the request goes out — a POI radius used to be a bare number with nothing
/// to compare it against, and "too much data — pick a smaller radius" arrived
/// only after the fetch came back. All three now take a box.
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
    // The same box the station and border sheets take: all three imports ask
    // "which part of the map?" the same way.
    final initial = LatLngBounds(
      const LatLng(48.10, 11.50),
      const LatLng(48.12, 11.53),
    );

    PoiImportSheet sheet({
      ValueChanged<LatLngBounds?>? onPreview,
      ValueChanged<PoiImportConfig?>? onDone,
      bool circles = false,
    }) => PoiImportSheet(
      initial: initial,
      needsCircleRadius: circles,
      allCategories: false,
      onPreview: onPreview ?? (_) {},
      onDone: onDone ?? (_) {},
    );

    // The sheet caps itself at half the screen and scrolls the rest.
    Future<void> tapButton(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pump();
      await t.tap(f);
    }

    testWidgets('previews its starting box as soon as it opens', (t) async {
      final seen = <LatLngBounds?>[];
      await pump(t, sheet(onPreview: seen.add));
      await t.pump(); // the post-frame callback
      expect(seen.last?.south, closeTo(48.10, 1e-4));
      expect(seen.last?.east, closeTo(11.53, 1e-4));
    });

    testWidgets('reports every edit, and null when unusable', (t) async {
      final seen = <LatLngBounds?>[];
      await pump(t, sheet(onPreview: seen.add));
      final north = find.widgetWithText(TextFormField, 'North');

      await t.enterText(north, '48.15');
      expect(seen.last?.north, closeTo(48.15, 1e-9));

      // South above north: the box comes down rather than drawing an area
      // that will be refused.
      await t.enterText(north, '48.00');
      expect(seen.last, isNull);

      await t.enterText(north, '');
      expect(seen.last, isNull);
    });

    testWidgets('a box too large to import cannot be imported', (t) async {
      PoiImportConfig? got;
      await pump(t, sheet(onDone: (c) => got = c));
      // ~55 km corner to corner: past the 50 km ceiling.
      await t.enterText(find.widgetWithText(TextFormField, 'North'), '48.60');
      await t.pump();
      expect(find.textContaining('too large'), findsOneWidget);
      await tapButton(t, find.widgetWithText(FilledButton, 'Import'));
      await t.pump();
      expect(got, isNull);
    });

    // In a comma-decimal locale the keyboard types "48,15"; the fields go
    // through `parseDecimal`, never `double.parse`.
    testWidgets('accepts a comma decimal and hands back the box', (t) async {
      PoiImportConfig? got;
      await pump(t, sheet(onDone: (c) => got = c));
      await t.enterText(find.widgetWithText(TextFormField, 'North'), '48,15');
      await tapButton(t, find.widgetWithText(FilledButton, 'Import'));
      await t.pump();

      expect(got, isNotNull);
      expect(got!.box.north, closeTo(48.15, 1e-9));
      expect(got!.box.west, closeTo(11.50, 1e-9));
      expect(got!.circleRadiusMeters, isNull);
    });

    testWidgets('cancelling answers exactly once, with null', (t) async {
      final answers = <PoiImportConfig?>[];
      await pump(t, sheet(onDone: answers.add));
      await tapButton(t, find.widgetWithText(TextButton, 'Cancel'));
      await t.pump();
      expect(answers, [null]);
    });
  });

  group('checkPoiBbox', () {
    test('sizes a box against the 50 km ceiling', () {
      expect(checkPoiBbox(48.10, 11.50, 48.12, 11.53), PoiBboxVerdict.ok);
      // ~30 km across: allowed, with a warning.
      expect(checkPoiBbox(48.0, 11.4, 48.2, 11.7), PoiBboxVerdict.warn);
      expect(checkPoiBbox(48.0, 11.0, 48.5, 11.5), PoiBboxVerdict.tooLarge);
      expect(checkPoiBbox(48.2, 11.5, 48.1, 11.6), PoiBboxVerdict.misordered);
      expect(checkPoiBbox(null, 11.5, 48.1, 11.6), PoiBboxVerdict.malformed);
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

  // Two overlapping imports are reachable: a picked file previews (the drawer
  // path passes a `ref`) while a file shared in from another app arrives on
  // resume. Replacing the state without answering the displaced offer left its
  // `decision` future hanging for ever — so that import never ran *and* never
  // cleaned up, because its `finally { clear() }` was unreachable.
  group('a displaced import is answered, not abandoned', () {
    PendingImport make(String summary) => PendingImport(
      summary: summary,
      lines: const [],
      circles: const [],
      bounds: LatLngBounds(const LatLng(0, 0), const LatLng(1, 1)),
    );

    test('offering a second import answers the first', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingImportProvider.notifier);

      final first = make('first');
      notifier.offer(first);
      final second = make('second');
      notifier.offer(second);

      // Would hang for ever without the fix.
      expect(
        await first.decision.timeout(const Duration(seconds: 1)),
        isFalse,
        reason: 'the user is looking at the new offer, not this one',
      );
      expect(container.read(pendingImportProvider)?.summary, 'second');
    });

    test('clearing an unanswered import answers it too', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingImportProvider.notifier);

      final only = make('only');
      notifier.offer(only);
      notifier.clear();

      expect(await only.decision.timeout(const Duration(seconds: 1)), isFalse);
    });

    test('an answered import keeps its answer', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingImportProvider.notifier);

      final keep = make('keep me');
      notifier.offer(keep);
      keep.answer(keep: true);
      notifier.clear();

      expect(
        await keep.decision.timeout(const Duration(seconds: 1)),
        isTrue,
        reason: 'clear() must not overwrite a decision already made',
      );
    });
  });
}
