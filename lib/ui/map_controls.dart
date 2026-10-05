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
    this.caption,
  });

  /// The one word under the button when captions are on (Settings → Button
  /// captions). Null for the chrome across the top, which is not a round
  /// button, and for the layer's own switch, whose word depends on the layer
  /// (see [quickToggleCaption]).
  final String? caption;

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
  goToPlace,
  locate,
  share,
  elevation,
  distance,
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
    what:
        'Takes back the last change, or puts it back. Each names the step '
        'it would undo.',
    sometimes: 'Hidden while the tools are hidden.',
  ),
  MapControl(
    id: MapControlId.activeLayer,
    area: MapControlArea.top,
    icon: Icons.layers_outlined,
    name: 'The active layer',
    what:
        'Names the layer everything else acts on. Tap it for that layer’s '
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
    caption: 'Offline',
    area: MapControlArea.tools,
    icon: Icons.download_for_offline_outlined,
    name: 'Download this area',
    what: 'Stores the map around you for use with no reception.',
    sometimes:
        'Only in a build pointed at a map provider whose terms allow '
        'downloading ahead. Never on OpenStreetMap’s own servers.',
  ),
  MapControl(
    id: MapControlId.goToPlace,
    caption: 'Search',
    area: MapControlArea.tools,
    icon: Icons.search,
    name: 'Go to place',
    what:
        'Type a town, street or landmark and the map moves there. It '
        'searches OpenStreetMap\u2019s own place index and changes nothing '
        'on your map.',
  ),
  MapControl(
    id: MapControlId.locate,
    caption: 'Locate',
    area: MapControlArea.tools,
    icon: Icons.my_location,
    name: 'Locate me',
    what:
        'Finds where you are and marks it, and shows the ground height '
        'there for a few seconds. Press again to take the mark away.',
  ),
  MapControl(
    id: MapControlId.share,
    caption: 'Share',
    area: MapControlArea.tools,
    icon: Icons.ios_share,
    name: 'Share my location',
    what: 'Sends where you are to another app.',
  ),
  MapControl(
    id: MapControlId.elevation,
    caption: 'Height',
    area: MapControlArea.tools,
    icon: Icons.terrain,
    name: 'Measure elevation',
    what: 'Tap anywhere afterwards to read the height of the ground there.',
  ),
  MapControl(
    id: MapControlId.distance,
    caption: 'Distance',
    area: MapControlArea.tools,
    icon: Icons.straighten,
    name: 'Measure distance',
    what:
        'Tap two points afterwards for the distance and bearing between '
        'them.',
  ),
  MapControl(
    id: MapControlId.edit,
    caption: 'Edit',
    area: MapControlArea.bottom,
    icon: Icons.edit_outlined,
    name: 'Edit by tapping',
    what:
        'Turns the map into a chooser: a tap opens whatever you tapped. '
        'Reaches anything you can see, on any visible layer.',
  ),
  MapControl(
    id: MapControlId.quickToggle,
    area: MapControlArea.bottom,
    icon: Icons.select_all,
    name: 'The layer’s own switch',
    what:
        'Changes with the layer — see below for the three it can be. Lit '
        'while the switch is on.',
    sometimes: 'Only where the layer has one.',
  ),
  MapControl(
    id: MapControlId.featureImport,
    caption: 'Import',
    area: MapControlArea.bottom,
    icon: Icons.travel_explore,
    name: 'Import a shape by name',
    what:
        'Type the name of a city, river or coastline: its outline is '
        'fetched from OpenStreetMap and added to this layer.',
    sometimes: 'Only on a layer that holds lines or areas.',
  ),
  MapControl(
    id: MapControlId.osmImport,
    caption: 'Import',
    area: MapControlArea.bottom,
    icon: Icons.cloud_download_outlined,
    name: 'Import places in a box',
    what:
        'Fetches places or stations from OpenStreetMap inside a box you '
        'mark and keeps them on the device — as markers, or on a circle or '
        'subspace layer as circle centres or points.',
    sometimes: 'Only on layers that can hold imported points.',
  ),
  MapControl(
    id: MapControlId.add,
    caption: 'Add',
    area: MapControlArea.bottom,
    icon: Icons.add,
    name: 'Add',
    what:
        'Arms the map: the next tap places a new element of the active '
        'layer’s kind where you point. On a line or area layer it asks '
        'first: point by point, or drawn with your finger. Long-press to '
        'place one at the centre instead.',
  ),
  MapControl(
    id: MapControlId.tools,
    caption: 'Tools',
    area: MapControlArea.bottom,
    icon: Icons.unfold_less,
    name: 'Hide and show the tools',
    what:
        'Clears the screen down to the map: the column above it, the '
        'undo buttons and the layer name all go, and come back.',
  ),
];

/// The caption of the layer's own switch, which is three different switches
/// — named, like the switch itself, by what it makes true. Takes the
/// `LayerActionId`'s name, so this catalogue stays free of the widget layer.
String quickToggleCaption(String actionId) => switch (actionId) {
  'fillAreas' => 'Colours',
  'invert' => 'Outside',
  'stations' => 'Stations',
  _ => 'Switch',
};

/// The catalogue entry for [id]. Every id has exactly one — pinned by a test,
/// because the point of the list is that it cannot fall behind the map.
MapControl mapControl(MapControlId id) =>
    mapControls.firstWhere((c) => c.id == id);

/// What the map knows about itself when deciding whether a control can act.
///
/// Deliberately small and plain: everything here is already computed in
/// `map_screen`'s build, and keeping it to booleans is what makes
/// [unavailableReason] pure and testable.
class MapControlState {
  const MapControlState({
    required this.hasActiveLayer,
    required this.activeLayerType,
    required this.activeLayerVisible,
    required this.anythingSelectable,
  });

  /// False only when there are no layers, or the user chose "no layer".
  final bool hasActiveLayer;

  /// Null when there is no active layer. Decides the noun in the remedy.
  final String? activeLayerType;

  /// Whether the active layer is drawn at all.
  final bool activeLayerVisible;

  /// Whether any *visible* layer holds something a tap could select — the
  /// screen's existing `canEditByTap`.
  final bool anythingSelectable;
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
      // Whether the switch has anything to act on is not asked here: it is a
      // fact about the layer's contents, and one button carries three
      // different switches. `layerActionUnavailable` answers it once, for the
      // map and the two menus alike, and `map_screen` falls back to it.
      return null;

    // Everything else either always works, or is hidden when it cannot.
    case MapControlId.layers:
    case MapControlId.undo:
    case MapControlId.activeLayer:
    case MapControlId.compass:
    case MapControlId.download:
    case MapControlId.goToPlace:
    case MapControlId.locate:
    case MapControlId.share:
    case MapControlId.elevation:
    case MapControlId.distance:
    case MapControlId.featureImport:
    case MapControlId.osmImport:
    case MapControlId.tools:
      return null;
  }
}
