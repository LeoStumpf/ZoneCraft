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

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/map_mode.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/about_screen.dart';
import 'package:zonecraft/data/borders.dart';
import 'package:zonecraft/data/shared_point.dart';
import 'package:zonecraft/ui/border_import_dialog.dart';
import 'package:zonecraft/ui/confirm_delete.dart';
import 'package:zonecraft/ui/edit_value_dialog.dart';
import 'package:zonecraft/ui/element_color_dialog.dart';
import 'package:zonecraft/ui/feature_search_dialog.dart';
import 'package:zonecraft/ui/go_to_place_dialog.dart';
import 'package:zonecraft/ui/import_actions.dart';
import 'package:zonecraft/ui/layer_actions.dart';
import 'package:zonecraft/ui/poi_category_dialog.dart';
import 'package:zonecraft/ui/poi_import_dialog.dart';
import 'package:zonecraft/ui/share_place.dart';
import 'package:zonecraft/ui/transit_import_dialog.dart';
import 'package:zonecraft/ui/layer_objects_sheet.dart';
import 'package:zonecraft/ui/map_controls.dart';
import 'package:zonecraft/ui/map_controls_screen.dart';
import 'package:zonecraft/ui/map_screen.dart';
import 'package:zonecraft/ui/osm_reports_screen.dart';
import 'package:zonecraft/ui/service_policy_screen.dart';
import 'package:zonecraft/ui/settings_screen.dart';
import 'package:zonecraft/ui/theme.dart';
import 'package:zonecraft/ui/welcome_sheet.dart';

import 'support/map_harness.dart';
import 'support/seed.dart';

/// Every surface of the app, at every size it will meet, at every text scale.
///
/// The layout bugs this app has shipped — the yellow-and-black overflow
/// stripes, the bottom rows a sheet clipped at a large font, the FAB row that
/// ran off a Pixel 4a — were all found by hand, after the fact, because the
/// one test that pumped the map filtered overflow out (the placeholder test
/// font made it unreliable). `flutter_test_config.dart` now loads Roboto, so an
/// overflow here is one a device would draw.
///
/// Landscape is swept as a peer of portrait, not an afterthought: the app has
/// never locked orientation, and from Android 16 the system ignores a lock on
/// any display 600 dp or wider anyway, so a tablet *will* show it sideways.
///
/// Two failures are checked:
/// * **overflow** — any `FlutterError` reported while a state was up;
/// * **unreachable** — a map control whose box leaves the safe area (under a
///   system bar, a cutout, or off the screen), which no stripe reports.
void main() {
  // Logical sizes. 320 wide is a small phone, and also what a 393 dp phone
  // becomes at the largest "Display size".
  const bars = EdgeInsets.only(top: 24, bottom: 24);
  const sideCutout = EdgeInsets.only(left: 32, bottom: 16);
  const screens = [
    TestScreen('small phone', Size(320, 568), padding: bars),
    TestScreen('pixel4a', Size(393, 851), padding: bars),
    TestScreen('pixel4a landscape', Size(851, 393), padding: sideCutout),
    TestScreen('short landscape', Size(640, 360), padding: sideCutout),
    TestScreen('tablet', Size(800, 1280), padding: bars),
    TestScreen('tablet landscape', Size(1280, 800), padding: bars),
  ];
  const scales = [1.0, 1.3, 2.0];

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Every screen at the linear scales, and the phones and a tablet once more
  // with Android 14's nonlinear curve at its largest setting.
  final matrix = [
    for (final base in screens)
      for (final scale in scales) base.scaled(scale),
    for (final base in [screens[0], screens[1], screens[3], screens[4]])
      base.scaled(2.0, nonLinear: true),
  ];
  for (final screen in matrix) {
    {
      testWidgets('map chrome fits: $screen', (tester) async {
        final problems = <String>[];
        await _sweep(tester, problems, 'fresh map', () async {
          await pumpMap(tester, db, screen: screen);
        });
        final container = _container(tester);
        for (final mode in MapMode.values) {
          await _sweep(tester, problems, 'mode ${mode.name}', () async {
            container.read(mapModeProvider.notifier).set(mode);
            await _settle(tester);
          });
          _checkReachable(tester, screen, problems, 'mode ${mode.name}');
          _checkNoOverlap(tester, problems, 'mode ${mode.name}');
        }
        container.read(mapModeProvider.notifier).set(MapMode.view);
        await _sweep(tester, problems, 'captions off', () async {
          await tester.runAsync(
            () => Repository(db).updateFabCaptions(enabled: false),
          );
          await _settle(tester);
        });
        _checkReachable(tester, screen, problems, 'captions off');
        await _sweep(tester, problems, 'tools collapsed', () async {
          await tester.runAsync(
            () => Repository(db).updateToolsExpanded(expanded: false),
          );
          await _settle(tester);
        });
        _checkReachable(tester, screen, problems, 'tools collapsed');
        await quiesce(tester, db);
        _report(problems);
      });

      testWidgets('editors and sheets fit: $screen', (tester) async {
        final problems = <String>[];
        late SeededMap seeded;
        await tester.runAsync(() async => seeded = await seedAllTypes(db));
        await _sweep(tester, problems, 'seeded map', () async {
          await pumpMap(tester, db, screen: screen);
          await _settle(tester);
        });
        _checkReachable(tester, screen, problems, 'seeded map');
        final container = _container(tester);

        for (final (name, select) in seeded.selections) {
          await _sweep(tester, problems, 'editor $name', () async {
            _clearSelection(container);
            select(container);
            await _settle(tester);
          });
          _checkSheetScrolls(tester, problems, 'editor $name');
        }
        _clearSelection(container);
        await _settle(tester);

        final context = tester.element(find.byType(MapScreen));
        await _sweep(tester, problems, 'drawer', () async {
          tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
          await _settle(tester);
        });
        await _dismiss(tester);

        await _sweep(tester, problems, 'layer sheet', () async {
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_ActiveLayerChip',
            ),
          );
          await _settle(tester);
          await _scrollToEnd(tester);
        });
        _checkSheetScrolls(tester, problems, 'layer sheet');
        await _dismiss(tester);

        await _sweep(tester, problems, 'credits', () async {
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_MapAttribution',
            ),
          );
          await _settle(tester);
          await _scrollToEnd(tester);
        });
        _checkSheetScrolls(tester, problems, 'credits');
        _checkLastButtonReachable(tester, problems, 'credits');
        await _dismiss(tester);

        for (final layer in seeded.layers) {
          await _sweep(tester, problems, 'elements ${layer.type}', () async {
            unawaited(showLayerObjects(context, layer));
            await _settle(tester);
          });
          await _dismiss(tester);
        }

        await _sweep(tester, problems, 'welcome', () async {
          unawaited(showWelcomeSheet(context));
          await _settle(tester);
        });
        _checkSheetScrolls(tester, problems, 'welcome');
        await _dismiss(tester);

        final pages = <String, Widget>{
          'settings': const SettingsScreen(),
          'about': const AboutScreen(),
          'servers and limits': const ServicePolicyScreen(),
          'button guide': const MapControlsScreen(),
          'osm outbox': const OsmReportsScreen(),
        };
        for (final MapEntry(key: name, value: page) in pages.entries) {
          await _sweep(tester, problems, 'screen $name', () async {
            unawaited(
              Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page)),
            );
            await _settle(tester);
            await _scrollToEnd(tester);
          });
          await _sweep(tester, problems, 'screen $name (pop)', () async {
            Navigator.of(context).pop();
            await _settle(tester);
          });
        }

        await quiesce(tester, db);
        _report(problems);
      });

      testWidgets('dialogs and forms fit: $screen', (tester) async {
        final problems = <String>[];
        applyScreen(tester, screen);
        late BuildContext context;
        late WidgetRef ref;
        Widget? slot;
        late StateSetter setSlot;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              builder: (_, child) => withScreenScaler(screen, child!),
              home: StatefulBuilder(
                builder: (_, setState) {
                  setSlot = setState;
                  return Consumer(
                    builder: (c, r, _) {
                      context = c;
                      ref = r;
                      return Scaffold(
                        body: const SizedBox.expand(),
                        bottomSheet: slot,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
        late Layer layer;
        await tester.runAsync(() async {
          final repo = Repository(db);
          final id = await repo.createLayer(
            name: 'Kindergartens within walking distance of the old town',
            colorArgb: 0xFF2196F3,
          );
          layer = (await db.select(db.layers).get()).firstWhere(
            (l) => l.id == id,
          );
        });

        const blue = Color(0xFF2196F3);
        final dialogs = <String, void Function()>{
          'confirm delete': () => confirmDelete(
            context,
            title: 'Delete "Kindergartens within walking distance"?',
          ),
          'position': () => showPositionDialog(
            context,
            lat: 48.137,
            lng: 11.575,
            canPublish: true,
          ),
          'export choice': () =>
              askExportChoice(context, title: 'Export all layers'),
          'freeline radius': () =>
              askFreeLineRadius(context, defaultMeters: 2000),
          'element colour': () => showElementColorDialog(
            context,
            title: 'Kindergartens within walking distance',
            current: blue,
            following: true,
            layerColor: blue,
            shadeIndex: 2,
          ),
          'border level': () => showBorderLevelPicker(context),
          'opacity': () => showOpacityDialog(
            context,
            title: 'Transparency',
            value: 0.5,
            onChanged: (_) {},
          ),
          'layer colour': () => pickLayerColor(context, ref, layer),
          'poi category': () => showPoiCategoryDialog(context),
          'share name': () => showShareNameDialog(
            context,
            const SharedPoint(lat: 48.137, lng: 11.575),
          ),
          'go to place': () => showGoToPlaceDialog(context),
          'feature search': () => showFeatureSearchDialog(context),
        };
        for (final MapEntry(key: name, value: open) in dialogs.entries) {
          await _sweep(tester, problems, 'dialog $name', () async {
            open();
            await _settle(tester);
            await _scrollToEnd(tester);
          });
          _checkLastButtonReachable(tester, problems, 'dialog $name');
          await _dismiss(tester);
        }

        final box = LatLngBounds(
          const LatLng(48.10, 11.50),
          const LatLng(48.17, 11.62),
        );
        final forms = <String, Widget>{
          'poi import': PoiImportSheet(
            initial: box,
            needsCircleRadius: true,
            allCategories: true,
            onPreview: (_) {},
            onDone: (_) {},
          ),
          'station import': TransitImportSheet(
            initial: box,
            onPreview: (_) {},
            onDone: (_) {},
          ),
          'border import': BorderImportSheet(
            initial: box,
            level: borderLevels.first,
            onPreview: (_) {},
            onDone: (_) {},
          ),
        };
        for (final MapEntry(key: name, value: form) in forms.entries) {
          await _sweep(tester, problems, 'form $name', () async {
            setSlot(() => slot = form);
            await _settle(tester);
            await _scrollToEnd(tester);
          });
          _checkLastButtonReachable(tester, problems, 'form $name');
          setSlot(() => slot = null);
          await _settle(tester);
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() => db.undo.dispose());
        _report(problems);
      });
    }
  }
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MapScreen)));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _dismiss(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
  if (navigator.canPop()) navigator.pop();
  await _settle(tester);
}

/// Runs [body] and files every error it reported under [state].
Future<void> _sweep(
  WidgetTester tester,
  List<String> problems,
  String state,
  Future<void> Function() body,
) async {
  final errors = await collectErrors(body);
  final taken = tester.takeException();
  if (errors.isNotEmpty) problems.add('[$state]\n${describeErrors(errors)}');
  if (taken != null) problems.add('[$state] $taken');
}

void _report(List<String> problems) {
  if (problems.isEmpty) return;
  fail(problems.join('\n\n'));
}

/// Every map control that is on screen lies inside the safe area.
///
/// A control half under the navigation bar or past a landscape cutout
/// reports no error and cannot be pressed — the failure a stripe never shows.
void _checkReachable(
  WidgetTester tester,
  TestScreen screen,
  List<String> problems,
  String state,
) {
  final safe = Rect.fromLTRB(
    screen.padding.left,
    screen.padding.top,
    screen.size.width - screen.padding.right,
    screen.size.height - screen.padding.bottom,
  ).inflate(0.5);
  final names = {for (final c in mapControls) c.name};
  for (final element in find.byType(Tooltip).evaluate()) {
    final tooltip = element.widget as Tooltip;
    final message = tooltip.message;
    if (message == null || !names.any(message.startsWith)) continue;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.isEmpty) continue;
    if (!safe.contains(rect.topLeft) || !safe.contains(rect.bottomRight)) {
      problems.add('[$state] "$message" at $rect leaves the safe area $safe');
    }
  }
}

/// The last thing in an open sheet can be scrolled to and pressed.
///
/// A bottom sheet clips *silently* — no overflow stripe — so a `Column` that
/// is taller than its sheet loses its bottom rows with nothing reported.
void _checkSheetScrolls(
  WidgetTester tester,
  List<String> problems,
  String state,
) {
  final sheets = find.byType(BottomSheet);
  if (sheets.evaluate().isEmpty) return;
  for (final sheet in sheets.evaluate()) {
    final sheetBox = sheet.renderObject! as RenderBox;
    final sheetRect = sheetBox.localToGlobal(Offset.zero) & sheetBox.size;
    final clipped = find.descendant(
      of: find.byWidget(sheet.widget),
      matching: find.byWidgetPredicate((w) => w is Flex || w is Wrap),
    );
    for (final e in clipped.evaluate()) {
      final box = e.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final scrollable = Scrollable.maybeOf(e);
      if (scrollable != null) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.bottom > sheetRect.bottom + 0.5) {
        problems.add(
          '[$state] ${e.widget.runtimeType} ends at ${rect.bottom} below its '
          'sheet (${sheetRect.bottom}) and nothing scrolls it into view',
        );
        return;
      }
    }
  }
}

/// No two pieces of floating map chrome overlap.
///
/// The banners start at a fixed [kBannerTop] under the chrome row; if the row
/// grows (a large font) or a banner stacks up, one pill lands on another and
/// the one underneath can be neither read nor pressed. Nested chrome (a pill
/// inside a pill) is not an overlap.
void _checkNoOverlap(WidgetTester tester, List<String> problems, String state) {
  final rects = <Rect>[
    for (final e in find.byType(MapChrome).evaluate())
      if (e.renderObject case final RenderBox box when box.hasSize)
        box.localToGlobal(Offset.zero) & box.size,
  ];
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      final a = rects[i], b = rects[j];
      final overlap = a.intersect(b);
      if (overlap.width <= 1 || overlap.height <= 1) continue;
      final nested = a.expandToInclude(b) == a || b.expandToInclude(a) == b;
      if (nested) continue;
      problems.add('[$state] map chrome at $a overlaps chrome at $b');
    }
  }
}

/// The last button on screen — a dialog's confirm, a form's Import — can be
/// pressed once everything scrollable has been scrolled to its end.
///
/// A `Column` inside a height-capped box clips its bottom rows without a
/// stripe; a clipped button still has a position, but a hit test at its
/// centre misses, which is what [FinderBase.hitTestable] asks.
void _checkLastButtonReachable(
  WidgetTester tester,
  List<String> problems,
  String state,
) {
  // Inside the topmost dialog or modal sheet when one is up — a button on
  // the page *behind* its barrier is rightly unpressable.
  final modal = find.byWidgetPredicate((w) => w is Dialog || w is BottomSheet);
  final any = find.byWidgetPredicate((w) => w is ButtonStyleButton);
  final buttons = modal.evaluate().isEmpty
      ? any
      : find.descendant(of: modal.last, matching: any);
  if (buttons.evaluate().isEmpty) return;
  final last = buttons.last;
  if (last.hitTestable().evaluate().isEmpty) {
    final label = find
        .descendant(of: last, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .firstOrNull;
    problems.add('[$state] its last button ("$label") cannot be pressed');
  }
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (state.position.axis != Axis.vertical) continue;
    if (!state.position.hasContentDimensions) continue;
    state.position.jumpTo(state.position.maxScrollExtent);
  }
  await tester.pump();
}

void _clearSelection(ProviderContainer c) {
  c.read(selectedCircleProvider.notifier).select(null);
  c.read(selectedSubspaceProvider.notifier).select(null);
  c.read(selectedFreeLineProvider.notifier).select(null);
  c.read(selectedFreeAreaProvider.notifier).select(null);
  c.read(selectedHeightRegionProvider.notifier).select(null);
  c.read(selectedPoiSetProvider.notifier).select(null);
  c.read(selectedPoiPointProvider.notifier).select(null);
  c.read(selectedBorderAreaProvider.notifier).select(null);
}
