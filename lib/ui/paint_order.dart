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

import 'dart:ui' show Color;

/// Splits [items] — already in draw order, front last — into the paint passes
/// the region engine runs: **maximal runs of consecutive same-colour elements**.
///
/// Colour groups used to be global: every green element in one pass, the passes
/// ordered by their newest member. That cannot express green → blue → green,
/// which is the first thing anyone hits after moving one of two same-coloured
/// circles behind a third. Runs can. Two adjacent same-colour elements still
/// share a pass and union flat — the invariant the whole compositing engine
/// exists for — and a different colour placed between them simply splits the
/// run in two.
///
/// Total path-ops work is unchanged, because each pass still unions only its
/// own members; what grows is the number of draw calls, and only for a layer
/// whose colours actually alternate.
List<({Color color, List<T> items})> colorRuns<T>(
  List<T> items,
  Color Function(T) colorOf,
) {
  final runs = <({Color color, List<T> items})>[];
  int? currentKey;
  for (final it in items) {
    final color = colorOf(it);
    final key = color.toARGB32();
    if (runs.isEmpty || key != currentKey) {
      runs.add((color: color, items: <T>[it]));
      currentKey = key;
    } else {
      runs.last.items.add(it);
    }
  }
  return runs;
}
