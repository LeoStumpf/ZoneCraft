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

import '../state/map_mode.dart';
import 'layer_actions.dart';
import 'map_controls.dart';
import 'object_summary.dart';

/// The Add button's label for a layer type. A nested ternary got unreadable at
/// seven types; this is the same mapping as a switch.
String addFabLabel(String? type) => switch (type) {
  'poi' => 'Add POI',
  'borders' => 'Import borders',
  'subspace' => 'Add subspace',
  'freeline' => 'Add line',
  'freearea' => 'Add area',
  'height' => 'Add height area',
  _ => 'Add circle',
};

/// The right-hand tool column and the bottom row.
///
/// A plain [StatelessWidget] with callbacks, deliberately: it holds no state
/// and reads no providers, so a test can pump it with any combination of flags
/// and press any button without a database, a `ProviderScope` or a map. That
/// is the whole reason for lifting it out of `_MapScreenState`, where it read
/// twenty-three private fields and could only be exercised by building the
/// entire screen.
///
/// **What these buttons are is not here.** `ui/map_controls.dart` is the one
/// catalogue — every name, icon and description — and [unavailableReason]
/// decides which of them can act; both are pure and covered by
/// `test/map_controls_test.dart`. This file is only their arrangement.
///
/// Nothing here resolves *which* layer an action applies to. The map does that
/// at press time, so this widget never needs the row lists or the camera.
class MapFabColumn extends StatelessWidget {
  const MapFabColumn({
    super.key,
    required this.controlState,
    required this.mode,
    required this.toolsExpanded,
    required this.allowsPrefetch,
    required this.downloading,
    required this.locating,
    required this.sharing,
    required this.showingMyLocation,
    required this.hasActiveLayer,
    required this.activeLayerType,
    required this.canDraw,
    required this.canImportFeature,
    required this.canImportNearby,
    required this.quickToggle,
    required this.onUnavailable,
    required this.onDownloadArea,
    required this.onGoToPlace,
    required this.onToggleMyLocation,
    required this.onShareMyLocation,
    required this.onToggleProbe,
    required this.onToggleDistance,
    required this.onToggleDraw,
    required this.onToggleEdit,
    required this.onQuickToggle,
    required this.onImportFeature,
    required this.onImportNearby,
    required this.onToggleAdd,
    required this.onAddAtMapCentre,
    required this.onToggleTools,
  });

  /// What the map knows about itself, for [unavailableReason].
  final MapControlState controlState;
  final MapMode mode;
  final bool toolsExpanded;

  /// Pre-emptive tile fetching is a property of the tile *source*, and the
  /// community OpenStreetMap servers forbid it — so the download button does
  /// not exist rather than being greyed. See `data/tile_source.dart`.
  final bool allowsPrefetch;

  final bool downloading;
  final bool locating;
  final bool sharing;

  /// Whether a position marker is up, which makes Locate me a toggle.
  final bool showingMyLocation;

  final bool hasActiveLayer;

  /// Decides the Add button's icon and wording only.
  final String? activeLayerType;

  final bool canDraw;
  final bool canImportFeature;
  final bool canImportNearby;

  /// The one per-type switch beside Edit, or null when the layer has none.
  final LayerAction? quickToggle;

  /// Says why a control that is only *painted* disabled did nothing.
  ///
  /// A FAB with `onPressed: null` registers no tap recogniser, so a disabled
  /// button cannot explain itself — which is why unavailable controls here
  /// stay live and answer the press in words.
  final void Function(String reason) onUnavailable;

  final VoidCallback onDownloadArea;
  final VoidCallback onGoToPlace;
  final VoidCallback onToggleMyLocation;
  final VoidCallback onShareMyLocation;
  final VoidCallback onToggleProbe;
  final VoidCallback onToggleDistance;
  final VoidCallback onToggleDraw;
  final VoidCallback onToggleEdit;
  final VoidCallback onQuickToggle;
  final VoidCallback onImportFeature;
  final VoidCallback onImportNearby;
  final VoidCallback onToggleAdd;
  final VoidCallback onAddAtMapCentre;
  final VoidCallback onToggleTools;

  /// One map FAB, painted disabled when it cannot act but still tappable.
  ///
  /// Not `onPressed: null`: that removes the recogniser, so the one moment a
  /// user wants an explanation is the one moment the button cannot give one.
  /// Not `disabledColor` either — a dark grey that on this light row read as
  /// the *lit* state, which is also dark — and not Material's faded fill,
  /// which over white chrome is a blob rather than a greyed button. The
  /// unavailable fill is the deepest paper tier, so it still looks like
  /// chrome while the faded icon says it is off.
  /// [onLongPress], when given, is the reason this builder exists in the shape
  /// it does.
  ///
  /// `FloatingActionButton(tooltip:)` wraps the button in a `Tooltip`, and a
  /// `Tooltip` registers its own long-press recogniser on mobile. That sits
  /// *inside* any `GestureDetector` wrapped around the button, so it wins the
  /// arena — and Add's documented "long-press to place at the map centre"
  /// fallback silently stopped working the day the FABs were given tooltips.
  /// Confirmed on a device: the long press did nothing at all, while the same
  /// gesture on the map raised its menu as it should.
  ///
  /// So when there is a long press, the tooltip goes *outside* the detector
  /// instead: the deeper recogniser wins, the action runs, and the message is
  /// still the button's accessibility label and still shows on hover.
  Widget _fab({
    required String heroTag,
    required String tooltip,
    required VoidCallback onPressed,
    required Widget child,
    String? unavailable,
    bool lit = false,
    VoidCallback? onLongPress,
  }) {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final off = unavailable != null;
        final message = unavailable ?? tooltip;
        final button = FloatingActionButton.small(
          heroTag: heroTag,
          // The reason replaces the description: what it *would* do matters
          // less than why it will not.
          tooltip: onLongPress == null ? message : null,
          backgroundColor: off
              ? scheme.surfaceContainerHighest
              : lit
              ? scheme.primary
              : null,
          foregroundColor: off
              ? scheme.onSurface.withValues(alpha: 0.38)
              : lit
              ? scheme.onPrimary
              : null,
          onPressed: off ? () => onUnavailable(unavailable) : onPressed,
          child: child,
        );

        if (onLongPress == null) return button;
        return Tooltip(
          message: message,
          // Manual: the detector below owns the long press. The message is
          // still read out by a screen reader and still shown on hover.
          triggerMode: TooltipTriggerMode.manual,
          child: GestureDetector(
            onLongPress: off ? () => onUnavailable(unavailable) : onLongPress,
            child: button,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bound to a local so the analyzer can promote it: Dart promotes private
    // final fields, and this one is part of the public API.
    final toggle = quickToggle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (toolsExpanded) ...[
          // Offline download exists only where the tile source allows
          // pre-emptive fetching — not on the community OSM servers.
          // See `data/tile_source.dart`.
          if (allowsPrefetch) ...[
            FloatingActionButton.small(
              heroTag: 'download',
              tooltip: mapControl(MapControlId.download).name,
              onPressed: downloading ? null : onDownloadArea,
              child: downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_for_offline_outlined),
            ),
            const SizedBox(height: 12),
          ],
          // First in the column, because on a fresh install it is
          // the only button that can get you to your own town: the
          // camera starts over southern Germany wherever you are.
          FloatingActionButton.small(
            heroTag: 'goToPlace',
            tooltip: mapControl(MapControlId.goToPlace).name,
            onPressed: onGoToPlace,
            child: Icon(mapControl(MapControlId.goToPlace).icon),
          ),
          const SizedBox(height: 12),
          // (The compass lives on the map itself, top-right, and only
          // while the map is rotated — see the map chrome above.)
          // A toggle, lit while the marker is up, in the shape the
          // probe and distance buttons already use — tapping it again
          // is the only way to put your position away, and the lit
          // state is what says there is something to put away.
          FloatingActionButton.small(
            heroTag: 'locate',
            tooltip: showingMyLocation ? 'Hide my location' : 'Locate me',
            backgroundColor: showingMyLocation
                ? Theme.of(context).colorScheme.primary
                : null,
            foregroundColor: showingMyLocation
                ? Theme.of(context).colorScheme.onPrimary
                : null,
            onPressed: locating ? null : onToggleMyLocation,
            child: locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    showingMyLocation
                        ? Icons.location_disabled
                        : Icons.my_location,
                  ),
          ),
          const SizedBox(height: 12),
          // Next to Locate on purpose: both answer "where am I", one
          // for you and one for the person you are meeting. Any
          // *other* place is shared by long-pressing it.
          FloatingActionButton.small(
            heroTag: 'share',
            tooltip: mapControl(MapControlId.share).name,
            onPressed: sharing ? null : onShareMyLocation,
            child: sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'probe',
            tooltip: mapControl(MapControlId.elevation).name,
            backgroundColor: mode == MapMode.elevation
                ? Theme.of(context).colorScheme.primary
                : null,
            foregroundColor: mode == MapMode.elevation
                ? Theme.of(context).colorScheme.onPrimary
                : null,
            onPressed: onToggleProbe,
            child: const Icon(Icons.terrain),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'distance',
            tooltip: mapControl(MapControlId.distance).name,
            backgroundColor: mode == MapMode.distance
                ? Theme.of(context).colorScheme.primary
                : null,
            foregroundColor: mode == MapMode.distance
                ? Theme.of(context).colorScheme.onPrimary
                : null,
            onPressed: onToggleDistance,
            child: const Icon(Icons.straighten),
          ),
          const SizedBox(height: 12),
          // Freehand layers only: there is nothing to draw into on a
          // circle, a subspace or an import layer.
          if (canDraw) ...[
            FloatingActionButton.small(
              heroTag: 'draw',
              tooltip: mapControl(MapControlId.draw).name,
              backgroundColor: mode == MapMode.draw
                  ? Theme.of(context).colorScheme.primary
                  : null,
              foregroundColor: mode == MapMode.draw
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
              onPressed: () => onToggleDraw(),
              child: const Icon(Icons.gesture),
            ),
            const SizedBox(height: 12),
          ],
        ],
        // Bottom row, left to right: Edit, the per-type quick toggle,
        // up to two import buttons, Add, and finally the tools toggle.
        //
        // The toggle goes **last** because it is the one button that
        // acts on the column above it, and that column is anchored to
        // the right edge: sitting at the left it was the furthest thing
        // on the row from what it opens and closes. Everything here is
        // the same small round button showing only its icon — a label
        // on one of them made that one the odd size out, and with a
        // full row it ran past the edge of the screen.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit mode: while on, a plain tap selects the object under
            // it. Kept outside the collapsible tools group — selecting
            // by tap must always be one press away.
            _fab(
              heroTag: 'editMode',
              tooltip: mode == MapMode.edit
                  ? 'Stop selecting by tap'
                  : 'Select by tapping the map',
              unavailable: unavailableReason(MapControlId.edit, controlState),
              lit: mode == MapMode.edit,
              onPressed: onToggleEdit,
              child: Icon(
                mode == MapMode.edit ? Icons.edit : Icons.edit_outlined,
              ),
            ),
            if (toggle != null) ...[
              const SizedBox(width: 12),
              _fab(
                heroTag: 'quickToggle',
                // Label *and* description: the label alone was the
                // menu entry, ellipsis included, which on a bare icon
                // answered nothing.
                tooltip: '${toggle.label} — ${toggle.description}',
                // Lit while the toggle is on; a plain button for the
                // one that opens a sheet (the station filter).
                lit: toggle.checked ?? false,
                // Two questions, two homes: whether the *map* can use
                // this button (a layer at all, and a visible one) is
                // the catalogue's, and whether the switch itself has
                // anything to act on is the action's — written once
                // there for the menus that print it too.
                unavailable:
                    unavailableReason(MapControlId.quickToggle, controlState) ??
                    toggle.unavailable,
                onPressed: onQuickToggle,
                child: Icon(toggle.icon),
              ),
            ],
            if (canImportFeature) ...[
              const SizedBox(width: 12),
              FloatingActionButton.small(
                heroTag: 'featureImport',
                tooltip: mapControl(MapControlId.featureImport).name,
                // Same flow the layers drawer offers, same arguments:
                // this adds a route to it, it does not fork it. The
                // full layer list is only for the fallback picker (a
                // line asked for from an area layer, or vice versa).
                onPressed: onImportFeature,
                // A globe with a magnifier: this one searches the
                // whole world by name. Its neighbour downloads what is
                // nearby, and a plain magnifier beside it said neither.
                child: const Icon(Icons.travel_explore),
              ),
            ],
            if (canImportNearby) ...[
              const SizedBox(width: 12),
              FloatingActionButton.small(
                heroTag: 'poiImport',
                tooltip: mapControl(MapControlId.osmImport).name,
                // Reached only when the layer holds one of the three
                // types above, which already implies it is non-null.
                // A POI layer has two imports to choose from; the
                // seeding types (circles, subspace) only the one.
                onPressed: onImportNearby,
                child: const Icon(Icons.cloud_download_outlined),
              ),
            ],
            // Add is a sticky *mode*, not an instant create: tapping it
            // arms the map so a tap places the object exactly where you
            // point. Long-press keeps the old one-shot behaviour (place
            // at the map centre, open the editor) as a no-aim fallback.
            const SizedBox(width: 12),
            _fab(
              heroTag: 'add',
              // The words the label used to carry live in the
              // tooltip, and the icon still says which type a tap
              // would place.
              tooltip: mode == MapMode.add
                  ? 'Done'
                  : '${addFabLabel(activeLayerType)} · tap the '
                        'map to place · long-press for the map '
                        'centre',
              lit: mode == MapMode.add,
              unavailable: unavailableReason(MapControlId.add, controlState),
              // `activeLayer` is non-null whenever this runs — the
              // unavailable branch owns the null case — but the two
              // facts sit a hundred lines apart, so this checks
              // rather than asserts.
              onPressed: onToggleAdd,
              onLongPress: hasActiveLayer ? onAddAtMapCentre : null,
              child: Icon(
                mode == MapMode.add
                    ? Icons.check
                    : typeIcon(activeLayerType ?? 'circles'),
              ),
            ),
            const SizedBox(width: 12),
            // Last, and beside the column it governs.
            FloatingActionButton.small(
              heroTag: 'fabsToggle',
              tooltip: toolsExpanded ? 'Hide tools' : 'Show tools',
              onPressed: onToggleTools,
              child: Icon(
                toolsExpanded ? Icons.unfold_less : Icons.unfold_more,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
