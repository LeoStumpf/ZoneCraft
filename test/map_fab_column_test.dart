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
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/state/map_mode.dart';
import 'package:zonecraft/ui/map_controls.dart';
import 'package:zonecraft/ui/map_fab_column.dart';
import 'package:zonecraft/ui/theme.dart';

/// The point of lifting this out of `_MapScreenState`, demonstrated.
///
/// None of these tests has a database, a `ProviderScope`, a map or a network.
/// Until this widget existed the only way to exercise any of it was to build
/// the entire screen — which is why, in a codebase with a thousand tests, not
/// one of them had ever pressed one of these buttons.
void main() {
  /// Everything off, nothing available: the state a fresh install is in.
  Widget host({
    MapMode mode = MapMode.view,
    bool toolsExpanded = true,
    bool allowsPrefetch = false,
    bool downloading = false,
    bool locating = false,
    bool sharing = false,
    bool showingMyLocation = false,
    bool hasActiveLayer = true,
    String? activeLayerType = 'circles',
    bool canDraw = false,
    bool canImportFeature = false,
    bool canImportNearby = false,
    MapControlState? controlState,
    void Function(String)? onUnavailable,
    VoidCallback? onToggleAdd,
    VoidCallback? onToggleEdit,
    VoidCallback? onGoToPlace,
    VoidCallback? onAddAtMapCentre,
    VoidCallback? onToggleTools,
    VoidCallback? onImportNearby,
  }) {
    return MaterialApp(
      theme: zoneCraftLightTheme(),
      home: Scaffold(
        body: MapFabColumn(
          controlState:
              controlState ??
              const MapControlState(
                hasActiveLayer: true,
                activeLayerType: 'circles',
                activeLayerVisible: true,
                anythingSelectable: true,
              ),
          mode: mode,
          toolsExpanded: toolsExpanded,
          allowsPrefetch: allowsPrefetch,
          downloading: downloading,
          locating: locating,
          sharing: sharing,
          showingMyLocation: showingMyLocation,
          hasActiveLayer: hasActiveLayer,
          activeLayerType: activeLayerType,
          canDraw: canDraw,
          canImportFeature: canImportFeature,
          canImportNearby: canImportNearby,
          quickToggle: null,
          onUnavailable: onUnavailable ?? (_) {},
          onDownloadArea: () {},
          onGoToPlace: onGoToPlace ?? () {},
          onToggleMyLocation: () {},
          onShareMyLocation: () {},
          onToggleProbe: () {},
          onToggleDistance: () {},
          onToggleDraw: () {},
          onToggleEdit: onToggleEdit ?? () {},
          onQuickToggle: () {},
          onImportFeature: () {},
          onImportNearby: onImportNearby ?? () {},
          onToggleAdd: onToggleAdd ?? () {},
          onAddAtMapCentre: onAddAtMapCentre ?? () {},
          onToggleTools: onToggleTools ?? () {},
        ),
      ),
    );
  }

  group('what is on screen', () {
    testWidgets('the tool column is there when tools are expanded', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(
        find.byTooltip(mapControl(MapControlId.goToPlace).name),
        findsOneWidget,
      );
      expect(
        find.byTooltip(mapControl(MapControlId.elevation).name),
        findsOneWidget,
      );
    });

    testWidgets('collapsing hides the column but keeps the bottom row', (
      tester,
    ) async {
      await tester.pumpWidget(host(toolsExpanded: false));
      expect(
        find.byTooltip(mapControl(MapControlId.goToPlace).name),
        findsNothing,
      );
      // The toggle itself must survive, or there is no way back.
      expect(find.byTooltip('Show tools'), findsOneWidget);
    });

    // Pre-emptive fetching is a property of the tile source, and the community
    // OpenStreetMap servers forbid it — so the button does not exist rather
    // than being greyed.
    testWidgets('the download button exists only where prefetch is allowed', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(
        find.byTooltip(mapControl(MapControlId.download).name),
        findsNothing,
      );

      await tester.pumpWidget(host(allowsPrefetch: true));
      expect(
        find.byTooltip(mapControl(MapControlId.download).name),
        findsOneWidget,
      );
    });

    testWidgets('the import buttons appear only when the layer can use them', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(
        find.byTooltip(mapControl(MapControlId.osmImport).name),
        findsNothing,
      );
      expect(
        find.byTooltip(mapControl(MapControlId.featureImport).name),
        findsNothing,
      );

      await tester.pumpWidget(
        host(canImportNearby: true, canImportFeature: true),
      );
      expect(
        find.byTooltip(mapControl(MapControlId.osmImport).name),
        findsOneWidget,
      );
      expect(
        find.byTooltip(mapControl(MapControlId.featureImport).name),
        findsOneWidget,
      );
    });

    testWidgets('Add names the type it would place', (tester) async {
      await tester.pumpWidget(host(activeLayerType: 'freearea'));
      expect(addButton('Add area'), findsOneWidget);
    });

    testWidgets('in Add mode the button says Done instead', (tester) async {
      await tester.pumpWidget(host(mode: MapMode.add));
      expect(find.byTooltip('Done'), findsOneWidget);
    });
  });

  group('presses reach the map', () {
    testWidgets('Add', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(host(onToggleAdd: () => pressed++));
      await tester.tap(addButton('Add circle'));
      expect(pressed, 1);
    });

    // This is a regression test for a bug that was shipped. The FAB's own
    // `tooltip:` wraps it in a `Tooltip`, whose long-press recogniser sits
    // *inside* any surrounding `GestureDetector` and therefore wins — so Add's
    // documented "long-press for the map centre" quietly stopped working the
    // day the buttons were given tooltips. Confirmed dead on a device, where
    // the same gesture on the map raised its menu correctly.
    testWidgets('long-pressing Add is the map-centre fallback', (tester) async {
      var centre = 0;
      await tester.pumpWidget(host(onAddAtMapCentre: () => centre++));

      // Pressed by position, exactly as a finger would — not aimed at a
      // particular widget in the tree, so whichever recogniser wins is the
      // one the user gets.
      await tester.longPress(addButton('Add circle'));
      expect(centre, 1, reason: 'the tooltip must not swallow the gesture');
    });

    testWidgets('a normal tap on Add still adds rather than long-presses', (
      tester,
    ) async {
      var taps = 0;
      var centre = 0;
      await tester.pumpWidget(
        host(onToggleAdd: () => taps++, onAddAtMapCentre: () => centre++),
      );
      await tester.tap(addButton('Add circle'));
      expect(taps, 1);
      expect(centre, 0);
    });

    testWidgets('long-press does nothing with no layer', (tester) async {
      var centre = 0;
      await tester.pumpWidget(
        host(hasActiveLayer: false, onAddAtMapCentre: () => centre++),
      );
      expect(
        addLongPressTarget,
        findsNothing,
        reason: 'no layer, so nothing to place',
      );
      await tester.longPress(addButton('Add circle'));
      expect(centre, 0);
    });

    testWidgets('Go to place', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(host(onGoToPlace: () => pressed++));
      await tester.tap(find.byTooltip(mapControl(MapControlId.goToPlace).name));
      expect(pressed, 1);
    });

    testWidgets('the tools toggle', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(host(onToggleTools: () => pressed++));
      await tester.tap(find.byTooltip('Hide tools'));
      expect(pressed, 1);
    });

    testWidgets('import nearby', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        host(canImportNearby: true, onImportNearby: () => pressed++),
      );
      await tester.tap(find.byTooltip(mapControl(MapControlId.osmImport).name));
      expect(pressed, 1);
    });
  });

  // The mechanic the whole "explain the press" design rests on: a FAB with
  // `onPressed: null` registers no tap recogniser, so a disabled button cannot
  // say why it is disabled. Unavailable controls stay live and answer instead.
  group('an unavailable control still answers', () {
    testWidgets('pressing Edit with nothing selectable says why', (
      tester,
    ) async {
      String? said;
      await tester.pumpWidget(
        host(
          controlState: const MapControlState(
            hasActiveLayer: true,
            activeLayerType: 'circles',
            activeLayerVisible: true,
            anythingSelectable: false,
          ),
          onUnavailable: (reason) => said = reason,
          onToggleEdit: () => fail('the real action must not run'),
        ),
      );

      final edit = find.byTooltip(
        unavailableReason(
          MapControlId.edit,
          const MapControlState(
            hasActiveLayer: true,
            activeLayerType: 'circles',
            activeLayerVisible: true,
            anythingSelectable: false,
          ),
        )!,
      );
      expect(edit, findsOneWidget, reason: 'the reason replaces the tooltip');

      await tester.tap(edit);
      expect(said, isNotNull);
      expect(said, isNot(isEmpty));
    });

    testWidgets('an available control runs its action instead', (tester) async {
      var toggled = 0;
      String? said;
      await tester.pumpWidget(
        host(onToggleEdit: () => toggled++, onUnavailable: (r) => said = r),
      );
      await tester.tap(find.byTooltip('Select by tapping the map'));
      expect(toggled, 1);
      expect(said, isNull);
    });
  });

  group('addFabLabel', () {
    test('names every type, and falls back to a circle', () {
      expect(addFabLabel('poi'), 'Add POI');
      expect(addFabLabel('freearea'), 'Add area');
      expect(addFabLabel('borders'), 'Import borders');
      expect(addFabLabel(null), 'Add circle');
      expect(addFabLabel('something new'), 'Add circle');
    });
  });
}

/// The Add button, found by the start of its tooltip — the rest of that
/// sentence explains tap-to-place and the long-press fallback.
Finder addButton(String prefix) => find.byWidgetPredicate(
  (w) => w is Tooltip && (w.message?.startsWith(prefix) ?? false),
);

/// The long-press target. `Tooltip` registers a long-press recogniser of its
/// own on mobile, so whichever of the two is deeper wins the arena — which is
/// the whole reason the Add button nests them the way it does.
final addLongPressTarget = find.byWidgetPredicate(
  (w) => w is GestureDetector && w.onLongPress != null,
);
