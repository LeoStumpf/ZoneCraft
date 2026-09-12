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

import '../data/database.dart';
import '../data/layer_types.dart';

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

/// The layers that get a bottom-most **uncertainty band** pass, bottom to top.
///
/// Bands are painted by their own widget per layer, stacked below *every*
/// layer's fill widget, so no band is ever drawn over a solid fill — see
/// `RegionPhase`. This picks which layers contribute one:
///
/// * nothing at all when there is no uncertainty to draw, so at 0 m the extra
///   pass disappears and the map is exactly what it was before bands moved;
/// * hidden layers are skipped, as they are for the fill pass;
/// * `borders` is skipped — it is drawn by its own painter and has no band;
/// * so is a layer holding none of the five region types (a pure POI layer
///   paints no region at all).
///
/// The order is [layers]' own order, which is the layers' draw order, so the
/// bands keep the same relative stacking as the fills above them.
List<Layer> bandPassLayers(List<Layer> layers, double uncertaintyMeters) {
  if (uncertaintyMeters <= 0) return const <Layer>[];
  return [
    for (final l in layers)
      if (l.isVisible && !layerHolds(l, kBorders) && layerHoldsRegion(l)) l,
  ];
}

/// True when [layer] holds any of the six types the region painter draws.
bool layerHoldsRegion(Layer layer) =>
    kRegionContentTypes.any((t) => layerHolds(layer, t));

/// The content types [RegionLayer] paints — the ones with an outer/core
/// composite and therefore an uncertainty band. `borders` is not one of them:
/// it is a read-only snapshot with its own painter and no band.
const kRegionContentTypes = <String>[
  kCircles,
  kSubspace,
  kFreeLine,
  kFreeArea,
  kHeight,
];
