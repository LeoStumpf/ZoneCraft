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

import 'database.dart';

/// The seven object-type strings a `Layers.type` can hold.
///
/// These are the persisted format — a layer's type is stored as one of these
/// strings — so they may be added to but never renamed. Three earlier ones
/// are gone: `planes` (v27 folded every plane into a two-point `subspace`),
/// `transit` (v27 merged station imports into `poi`) and `track` (dropped).
/// The GeoJSON reader still maps the first two; the migration retypes rows.
const kCircles = 'circles';
const kSubspace = 'subspace';
const kFreeLine = 'freeline';
const kFreeArea = 'freearea';
const kHeight = 'height';
const kPoi = 'poi';
const kBorders = 'borders';

/// The `mixed` layer type, **retired at schema v30**. A layer holds one kind
/// again; several are grouped with a folder instead (see `ui/layer_tree.dart`),
/// which leaves each of them a layer rather than merging them away.
///
/// The string cannot be deleted: databases older than v30 and exported files
/// older than format v4 still carry it. It is read by exactly two things — the
/// v30 migration and the GeoJSON reader — and both do the same thing with it,
/// splitting the layer into one per kind it actually holds.
const kMixedType = 'mixed';

/// What a `mixed` layer could hold, **in the order its painter drew them**
/// (bottom first): regions are ground, markers are labels on top. Legacy, and
/// load-bearing for exactly that reason — the split stacks the layers it makes
/// in this order, so an upgraded map looks like the one it replaced.
const kMixedContentTypes = <String>[
  kCircles,
  kSubspace,
  kFreeLine,
  kFreeArea,
  kHeight,
  kPoi,
];

/// The types whose elements **can be inverted** — the region kinds whose
/// painter takes the viewport complement when `Layers.isInverted` is set.
///
/// `height` is not one of them even though it draws a region: it renders its
/// stored fill polygons with its own bounded band along the elevation contour
/// and ignores `inverted` entirely (`region_layer._paintHeight`). `poi` and
/// `borders` are markers and many separate areas — neither has a single
/// outside. This is what "Fill outside" needs to find in a layer before it can
/// do anything, and a combined layer may hold none of it while still holding
/// plenty: counting *any* element lit the toggle on a layer of nothing but POI
/// markers, and pressing it wrote `isInverted` and left the map untouched.
const kInvertibleTypes = <String>[
  kCircles,
  kSubspace,
  kFreeLine,
  kFreeArea,
];

/// Every type a *layer* can be. Used by the new-layer picker and by tests that
/// want to be exhaustive.
const kAllLayerTypes = <String>[
  kCircles,
  kSubspace,
  kFreeLine,
  kFreeArea,
  kHeight,
  kPoi,
  kBorders,
];

/// Whether [layer] may hold objects of [type].
///
/// **The one predicate.** Every `layer.type == 'x'` in the app goes through
/// here, for the same reason `transitStationVisible` exists: when the rule
/// lived in two places the copies disagreed, and what was drawn stopped
/// matching what could be tapped. A painter, a hit test and an exporter that
/// each decide for themselves which rows belong to a layer is exactly that
/// failure waiting to happen again.
///
/// One line now that `mixed` is gone, and kept as a function for that reason:
/// the day a layer holds several kinds again, it is one edit rather than forty.
bool layerHolds(Layer layer, String type) => layerTypeHolds(layer.type, type);

/// [layerHolds] on a bare type string, for callers that have no row.
bool layerTypeHolds(String layerType, String type) => layerType == type;

/// The types [layer] may hold, in draw order — one, since v30.
List<String> layerContentTypes(Layer layer) =>
    layerContentTypesOf(layer.type);

/// [layerContentTypes] on a bare type string.
List<String> layerContentTypesOf(String layerType) => <String>[layerType];
