import 'database.dart';

/// The ten object-type strings a `Layers.type` can hold, plus [kMixedType].
///
/// These are the persisted format — a layer's type is stored as one of these
/// strings — so they may be added to but never renamed.
const kCircles = 'circles';
const kPlanes = 'planes';
const kSubspace = 'subspace';
const kFreeLine = 'freeline';
const kFreeArea = 'freearea';
const kHeight = 'height';
const kTrack = 'track';
const kPoi = 'poi';
const kTransit = 'transit';
const kBorders = 'borders';

/// A layer that holds several object types at once.
const kMixedType = 'mixed';

/// What a mixed layer may hold, **in draw order** (bottom first).
///
/// The order is the answer to "what happens when a circle and a POI share a
/// layer": the region composite is ground, a track is a line drawn on it, and
/// markers are labels that have to stay legible on top. It is deliberately
/// fixed rather than per-element — no element table has a z-order column, and
/// nothing in the request needs one. Region-vs-region overlap keeps its own
/// existing rule (the painter's colour groups, newest last).
///
/// **`borders` is excluded.** `Layers.borderLevel` is a per-layer property and
/// "no two neighbours share a colour" is only meaningful within one admin
/// level — areas of different levels nest rather than tile. A border area's
/// existing "Convert to freehand area" is the way into a mixed layer.
const kMixedContentTypes = <String>[
  kCircles,
  kPlanes,
  kSubspace,
  kFreeLine,
  kFreeArea,
  kHeight,
  kTrack,
  kTransit,
  kPoi,
];

/// Every type a *layer* can be, including mixed. Used by the new-layer picker
/// and by tests that want to be exhaustive.
const kAllLayerTypes = <String>[
  kCircles,
  kPlanes,
  kSubspace,
  kFreeLine,
  kFreeArea,
  kHeight,
  kTrack,
  kPoi,
  kTransit,
  kBorders,
  kMixedType,
];

/// Whether [layer] may hold objects of [type].
///
/// **The one predicate.** Every `layer.type == 'x'` in the app goes through
/// here, for the same reason `transitStationVisible` exists: when the rule
/// lived in two places the copies disagreed, and what was drawn stopped
/// matching what could be tapped. A painter, a hit test and an exporter that
/// each decide for themselves which rows belong to a layer is exactly that
/// failure waiting to happen again.
bool layerHolds(Layer layer, String type) => layerTypeHolds(layer.type, type);

/// [layerHolds] on a bare type string, for callers that have no row.
bool layerTypeHolds(String layerType, String type) => layerType == kMixedType
    ? kMixedContentTypes.contains(type)
    : layerType == type;

/// The types [layer] may hold, in draw order. One element for a single-type
/// layer; [kMixedContentTypes] for a mixed one.
List<String> layerContentTypes(Layer layer) =>
    layerContentTypesOf(layer.type);

/// [layerContentTypes] on a bare type string.
List<String> layerContentTypesOf(String layerType) =>
    layerType == kMixedType ? kMixedContentTypes : <String>[layerType];

/// Whether a layer of [layerType] can be turned into a mixed one.
///
/// Everything except `borders` (whose areas would lose the admin level that
/// makes their colouring meaningful) and a layer that already is mixed.
bool canBecomeMixed(String layerType) =>
    layerType != kMixedType && kMixedContentTypes.contains(layerType);
