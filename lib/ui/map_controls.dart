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

/// Every button on the map, named and explained — once.
///
/// The map carries eleven round icon buttons and no labels. That is the right
/// trade for the space (a label on one of them made it the odd size out and ran
/// the row past the edge of the screen), but it leaves eleven symbols that a
/// user has to guess at, and a tooltip only appears on a long press nobody
/// thinks to try.
///
/// So the buttons are catalogued here and the map takes its tooltips from the
/// same list the guide screen prints. Two surfaces, one set of words: a button
/// whose name changes cannot leave the guide describing the old one.
///
/// Only the **static** tooltips come from here. The three buttons that say
/// something a catalogue cannot — Edit naming why it is disabled, Locate saying
/// whether it is on, Add naming the type it would place — keep their own
/// wording, because that text is about the moment rather than the button.
library;

import 'package:flutter/material.dart';

import '../data/layer_types.dart';

/// Where a control sits, which is most of how someone finds it again.
enum MapControlArea {
  /// The row across the top: the drawer, undo/redo, the active layer.
  top('Across the top'),

  /// The column up the right-hand side, hidden by the show/hide button.
  tools('Up the right-hand side'),

  /// The row along the bottom, always present.
  bottom('Along the bottom');

  const MapControlArea(this.title);

  /// The heading the guide prints for this group.
  final String title;
}

/// One control: what it looks like, what it is called, what it does.
class MapControl {
  const MapControl({
    required this.id,
    required this.area,
    required this.icon,
    required this.name,
    required this.what,
    this.sometimes,
  });

  final MapControlId id;
  final MapControlArea area;
  final IconData icon;

  /// The short name, also used as the button's tooltip where it is static.
  final String name;

  /// One line saying what pressing it does.
  final String what;

  /// Why it is sometimes not there at all, for the ones that come and go.
  /// Null when the button is always present.
  final String? sometimes;
}

/// Every control the guide knows about.
enum MapControlId {
  layers,
  undo,
  activeLayer,
  compass,
  download,
  locate,
  share,
  elevation,
  distance,
  draw,
  edit,
  quickToggle,
  featureImport,
  osmImport,
  add,
  tools,
}

/// The catalogue, in the order the guide lists them: top, then the tool
/// column, then the bottom row — reading the screen the way the eye does.
const List<MapControl> mapControls = [
  MapControl(
    id: MapControlId.layers,
    area: MapControlArea.top,
    icon: Icons.menu,
    name: 'Layers',
    what: 'Opens the list of layers: add, hide, reorder, recolour, delete.',
  ),
  MapControl(
    id: MapControlId.undo,
    area: MapControlArea.top,
    icon: Icons.undo,
    name: 'Undo and redo',
    what: 'Takes back the last change, or puts it back. Each names the step '
        'it would undo.',
    sometimes: 'Hidden while the tools are hidden.',
  ),
  MapControl(
    id: MapControlId.activeLayer,
    area: MapControlArea.top,
    icon: Icons.layers_outlined,
    name: 'The active layer',
    what: 'Names the layer everything else acts on. Tap it for that layer’s '
        'settings, or to switch to another.',
    sometimes: 'Hidden while the tools are hidden.',
  ),
  MapControl(
    id: MapControlId.compass,
    area: MapControlArea.top,
    icon: Icons.navigation,
    name: 'Compass',
    what: 'Points to north. Tap to turn the map back upright.',
    sometimes: 'Only while the map is rotated.',
  ),
  MapControl(
    id: MapControlId.download,
    area: MapControlArea.tools,
    icon: Icons.download_for_offline_outlined,
    name: 'Download this area',
    what: 'Stores the map around you for use with no reception.',
    sometimes: 'Only in a build pointed at a map provider whose terms allow '
        'downloading ahead. Never on OpenStreetMap’s own servers.',
  ),
  MapControl(
    id: MapControlId.locate,
    area: MapControlArea.tools,
    icon: Icons.my_location,
    name: 'Locate me',
    what: 'Finds where you are and marks it, with the ground height there. '
        'Press again to take the mark away.',
  ),
  MapControl(
    id: MapControlId.share,
    area: MapControlArea.tools,
    icon: Icons.ios_share,
    name: 'Share my location',
    what: 'Sends where you are to another app.',
  ),
  MapControl(
    id: MapControlId.elevation,
    area: MapControlArea.tools,
    icon: Icons.terrain,
    name: 'Measure elevation',
    what: 'Tap anywhere afterwards to read the height of the ground there.',
  ),
  MapControl(
    id: MapControlId.distance,
    area: MapControlArea.tools,
    icon: Icons.straighten,
    name: 'Measure distance',
    what: 'Tap two points afterwards for the distance and bearing between '
        'them.',
  ),
  MapControl(
    id: MapControlId.draw,
    area: MapControlArea.tools,
    icon: Icons.gesture,
    name: 'Draw with your finger',
    what: 'Trace a line or an area instead of tapping point by point. '
        'One-finger panning is off while this is on.',
    sometimes: 'Only on a layer that holds lines or areas — and not on a '
        'combined layer, which holds both and so could not tell which you '
        'meant.',
  ),
  MapControl(
    id: MapControlId.edit,
    area: MapControlArea.bottom,
    icon: Icons.edit_outlined,
    name: 'Select by tapping',
    what: 'Turns the map into a chooser: a tap opens whatever you tapped. '
        'Reaches anything you can see, on any visible layer.',
  ),
  MapControl(
    id: MapControlId.quickToggle,
    area: MapControlArea.bottom,
    icon: Icons.select_all,
    name: 'The layer’s own switch',
    what: 'Changes with the layer — see below for the three it can be. Lit '
        'while the switch is on.',
    sometimes: 'Only where the layer has one.',
  ),
  MapControl(
    id: MapControlId.featureImport,
    area: MapControlArea.bottom,
    icon: Icons.travel_explore,
    name: 'Find a place by name',
    what: 'Searches OpenStreetMap for a city, river or coastline and imports '
        'its outline.',
    sometimes: 'Only on a layer that holds lines or areas. Not on a combined '
        'layer: import on the layer that holds the kind, then combine.',
  ),
  MapControl(
    id: MapControlId.osmImport,
    area: MapControlArea.bottom,
    icon: Icons.cloud_download_outlined,
    name: 'Import what is nearby',
    what: 'Fetches places or transit stops from OpenStreetMap into this layer '
        'and keeps them on the device.',
    sometimes: 'Only on layers that can hold imported points. Not on a '
        'combined layer: import on the layer that holds the kind, then '
        'combine.',
  ),
  MapControl(
    id: MapControlId.add,
    area: MapControlArea.bottom,
    icon: Icons.add,
    name: 'Add',
    what: 'Arms the map: the next tap places a new element where you point. '
        'Its icon shows which kind. Long-press to place one at the centre '
        'instead.',
    sometimes: 'Not on a combined layer — that one is filled by merging other '
        'layers into it, not by making things in it.',
  ),
  MapControl(
    id: MapControlId.tools,
    area: MapControlArea.bottom,
    icon: Icons.unfold_less,
    name: 'Hide and show the tools',
    what: 'Clears the screen down to the map: the column above it, the '
        'undo buttons and the layer name all go, and come back.',
  ),
];

/// The catalogue entry for [id]. Every id has exactly one — pinned by a test,
/// because the point of the list is that it cannot fall behind the map.
MapControl mapControl(MapControlId id) =>
    mapControls.firstWhere((c) => c.id == id);

/// Which switch the layer's quick toggle currently is.
///
/// One button with three identities, and each acts on different content — so
/// "can it do anything?" has to be asked per identity, not as "does the layer
/// hold anything at all". It was asked the second way, and on a combined layer
/// holding nothing but POI markers that lit **Fill outside**: pressing it wrote
/// `isInverted` and left the map byte-identical, which is the exact failure
/// [unavailableReason] exists to prevent.
enum QuickToggleKind {
  /// Fill outside / Fill inside. Needs a [kInvertibleTypes] element.
  invert,

  /// A borders layer's Colour areas. Needs an area to colour.
  colourAreas,

  /// The station-type filter. Only offered once a station import exists, so
  /// there is always something for it to act on.
  stations,
}

/// What the map knows about itself when deciding whether a control can act.
///
/// Deliberately small and plain: everything here is already computed in
/// `map_screen`'s build, and keeping it to booleans is what makes
/// [unavailableReason] pure and testable.
class MapControlState {
  const MapControlState({
    required this.hasActiveLayer,
    required this.activeLayerType,
    required this.activeLayerHolds,
    required this.activeLayerVisible,
    required this.anythingSelectable,
    this.quickToggleKind,
    this.quickToggleHolds = true,
  });

  /// False only when there are no layers, or the user chose "no layer".
  final bool hasActiveLayer;

  /// Null when there is no active layer. Decides the noun in the remedy.
  final String? activeLayerType;

  /// Whether the active layer holds at least one element.
  final bool activeLayerHolds;

  /// Whether the active layer is drawn at all.
  final bool activeLayerVisible;

  /// Whether any *visible* layer holds something a tap could select — the
  /// screen's existing `canEditByTap`.
  final bool anythingSelectable;

  /// Which switch the quick toggle is right now, or null when there is none.
  final QuickToggleKind? quickToggleKind;

  /// Whether the layer holds what **that** switch acts on — a shape to take
  /// the outside of, an area to colour. [activeLayerHolds] is not enough: a
  /// layer can be far from empty and still hold nothing a given switch can
  /// touch. Defaults to true so a state built without it keeps the old
  /// behaviour; `map_screen` always passes it.
  final bool quickToggleHolds;
}

/// Why pressing [id] would do nothing right now, or null when it works.
///
/// This exists because the buttons lie. Pressing "Fill outside" on an empty
/// circle layer lights the button, flips the switch in the layer sheet and
/// writes `isInverted` to the database — and the map is left byte-identical,
/// because the painter returns before the viewport complement is ever taken
/// (`region_layer.dart`, `if (outer == null) return`). A control that reports
/// success and changes nothing is worse than one that is plainly unavailable.
///
/// The answer names a remedy rather than a fault: "add a circle first" is
/// something to do, "invalid state" is not. A control the *layer type* can
/// never use is not handled here — those stay hidden, because "never" is not a
/// thing to wait for.
String? unavailableReason(MapControlId id, MapControlState s) {
  switch (id) {
    case MapControlId.add:
      if (!s.hasActiveLayer) {
        return 'No layer is active — choose one in the layers menu.';
      }
      // Deliberately still available on a *hidden* layer: the element really
      // is created, and not seeing it is a different complaint with its own
      // fix. Only controls whose entire effect is visual are held back for it.
      return null;

    case MapControlId.edit:
      if (!s.anythingSelectable) {
        return 'Nothing to select yet — add or import something first.';
      }
      return null;

    case MapControlId.quickToggle:
      if (!s.hasActiveLayer) {
        return 'No layer is active — choose one in the layers menu.';
      }
      if (!s.activeLayerVisible) {
        return 'This layer is hidden, so nothing it does will show. '
            'Turn it on in the layers menu.';
      }
      if (!s.activeLayerHolds) {
        return 'This layer is empty — ${_fillItWith(s.activeLayerType)}.';
      }
      // The layer holds plenty — just none of what *this* switch acts on.
      if (!s.quickToggleHolds) {
        return switch (s.quickToggleKind) {
          // Only a combined layer can reach this: every other type that
          // offers invert holds nothing *but* invertible elements, so a
          // non-empty one always has a shape. And a combined layer is filled
          // by merging, which is why that is the whole remedy.
          QuickToggleKind.invert =>
            'Fill outside needs a shape to take the outside of — merge in a '
                'layer of circles, lines or areas first.',
          QuickToggleKind.colourAreas =>
            'There are no areas here to colour — import some borders first.',
          QuickToggleKind.stations || null =>
            'This layer holds nothing this switch acts on — add or merge in '
                'something for it first.',
        };
      }
      return null;

    // Everything else either always works, or is hidden when it cannot.
    case MapControlId.layers:
    case MapControlId.undo:
    case MapControlId.activeLayer:
    case MapControlId.compass:
    case MapControlId.download:
    case MapControlId.locate:
    case MapControlId.share:
    case MapControlId.elevation:
    case MapControlId.distance:
    case MapControlId.draw:
    case MapControlId.featureImport:
    case MapControlId.osmImport:
    case MapControlId.tools:
      return null;
  }
}

/// The remedy, in the layer's own noun: what would make it non-empty.
String _fillItWith(String? type) => switch (type) {
      kCircles => 'add a circle first',
      kSubspace => 'add a subspace first',
      kFreeLine => 'draw or add a line first',
      kFreeArea => 'draw or add an area first',
      kHeight => 'add a height area first',
      kPoi => 'import or place some POIs first',
      kBorders => 'import some borders first',
      // A combined layer makes nothing of its own, so the remedy is the one
      // thing that fills it ([layerMakesOwnContent]).
      kMixedType => 'merge another layer into it first',
      _ => 'add something to it first',
    };
