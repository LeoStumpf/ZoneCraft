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

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a plain map tap does. Exactly one mode is active at a time, which is
/// what makes "a tap can't do something I didn't ask for" enforceable: the
/// default [view] mode routes taps nowhere, so panning and pinching a map full
/// of big regions never pops an editor.
///
/// Lives in Riverpod (not the map's `State`) because the layers drawer has to
/// reset it when the user picks an element to edit, and because it makes the
/// probe/distance mutual exclusion structural instead of hand-written.
/// Deliberately **not** persisted — a sticky Add mode surviving a relaunch
/// would be a footgun, and it needs no schema change.
enum MapMode {
  /// Default. A tap does nothing at all: no select, no create, no deselect.
  /// Objects are still reachable by long-press (and via the Elements list).
  view,

  /// A tap selects the object under it (active layer only); a tap on empty map
  /// deselects. Long-press keeps its "add/insert a point here" context menu.
  edit,

  /// A tap places a new object of the active layer's type. Sticky: the mode
  /// stays armed so several objects can be dropped in a row.
  add,

  /// One finger **draws** a freehand line/area instead of panning the map;
  /// panning and zooming move to two fingers. Sticky like [add], and offered
  /// only for the two freehand layer types.
  draw,

  /// A tap reads the terrain elevation at that point.
  elevation,

  /// The first two taps set the endpoints of a distance/bearing measurement.
  distance,
}

class MapModeNotifier extends Notifier<MapMode> {
  @override
  MapMode build() => MapMode.view;

  void set(MapMode mode) => state = mode;

  /// Toggle behaviour for a mode button: pressing the active mode's button
  /// returns to [MapMode.view].
  void toggle(MapMode mode) => state = state == mode ? MapMode.view : mode;
}

final mapModeProvider = NotifierProvider<MapModeNotifier, MapMode>(
  MapModeNotifier.new,
);
