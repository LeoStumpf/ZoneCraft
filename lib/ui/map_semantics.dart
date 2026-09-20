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

import '../data/database.dart';

/// What a screen reader says when it reaches the map.
///
/// The map is a `CustomPaint` over raster tiles: it carries no text, no child
/// widgets and therefore no semantics at all, so TalkBack reached it and said
/// nothing. Every *button* around it is labelled (they all have tooltips,
/// which Flutter turns into semantic labels), which made the silence worse —
/// the controls announced themselves perfectly while the thing they act on
/// did not exist.
///
/// Making a canvas navigable is not the answer here, and trying would produce
/// a worse one: a border layer is 119 000 vertices, and a shape announced as
/// "polygon, 119000 points" tells nobody anything. **The app already has an
/// accessible view of the map** — the Elements list
/// (`ui/layer_objects_sheet.dart`), which enumerates every object with its
/// name and its measured size, filed by type, and is built from pure tested
/// functions. So this says what is on the map and points at the list that can
/// read it out, rather than pretending the canvas is a document.
///
/// [layers] is the visible stack, top first, as the drawer shows it.
String mapSemanticLabel(List<Layer> layers) {
  final visible = [
    for (final l in layers)
      if (l.isVisible) l,
  ];

  if (layers.isEmpty) {
    return 'Map. No layers yet. '
        'Open the layers menu to add one.';
  }
  if (visible.isEmpty) {
    return 'Map. ${_plural(layers.length, 'layer')}, all hidden. '
        'Open the layers menu to show one.';
  }

  final names = visible.map((l) => l.name).join(', ');
  final hidden = layers.length - visible.length;
  final hiddenPart = hidden == 0 ? '' : ' ${_plural(hidden, 'layer')} hidden.';

  return 'Map. ${_plural(visible.length, 'layer')} shown: $names.$hiddenPart '
      'The map itself is drawn rather than written, so a screen reader cannot '
      'read the shapes on it. Open the layers menu and choose a layer’s '
      'Elements list to hear what it holds, one item at a time.';
}

String _plural(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';
