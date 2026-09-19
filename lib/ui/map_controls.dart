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
    sometimes: 'Only on a layer that holds lines or areas.',
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
    sometimes: 'Only on a layer that holds lines or areas.',
  ),
  MapControl(
    id: MapControlId.osmImport,
    area: MapControlArea.bottom,
    icon: Icons.cloud_download_outlined,
    name: 'Import what is nearby',
    what: 'Fetches places or transit stops from OpenStreetMap into this layer '
        'and keeps them on the device.',
    sometimes: 'Only on layers that can hold imported points.',
  ),
  MapControl(
    id: MapControlId.add,
    area: MapControlArea.bottom,
    icon: Icons.add,
    name: 'Add',
    what: 'Arms the map: the next tap places a new element where you point. '
        'Its icon shows which kind. Long-press to place one at the centre '
        'instead.',
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
