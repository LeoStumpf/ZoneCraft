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

import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../geo/border_areas.dart' show groupRings;
import '../geo/geodesic.dart';

/// Import/export of layers + objects as **GeoJSON** (lossless round-trip, our
/// own format) and **KML** (export only, for Google Earth / Maps interop).
///
/// The data model here is a plain, drift-free intermediate ([ExportData]) so the
/// encoders/decoders are pure Dart and unit-testable. [Repository] assembles it
/// from the database and writes it back into **new** layers.

/// One object inside an exported layer. Only the fields relevant to [kind] are
/// populated; [coords] carries the geometry (a single point for a circle, the
/// point list for the rest).
class ExportObject {
  const ExportObject({
    required this.kind,
    required this.coords,
    this.label,
    this.radiusMeters,
    this.offsetMeters,
    this.mainIndex,
    this.thresholdMeters,
    this.aboveThreshold,
    this.sampleZoom,
    this.inclusionLat,
    this.inclusionLng,
    this.inclusionRadiusMeters,
    this.categoryKey,
    this.iconKey,
    this.manual,
    this.pointLabels,
    this.colorArgb,
    this.rings,
    this.bbox,
    this.osmId,
    this.adminLevel,
    this.colorIndex,
    this.labelLat,
    this.labelLng,
    this.wayIds,
    this.edited,
    this.modeMask,
    this.visibleModeMask,
    this.pointOsmIds,
    this.pointModeMasks,
    this.pointOsmTypes,
    this.heightRings,
    this.generated,
    this.setLabel,
    this.pending,
    this.errorMessage,
  });

  /// One of: circle, subspace, freeline, freearea, height, poi, borderarea.
  ///
  /// Three v1/v2 kinds no longer exist and are **translated on read** by
  /// [importFromGeoJson]: `plane` becomes a two-point `subspace`, `transitstop`
  /// a box-sourced `poi`, and `track` is skipped (the type was dropped).
  final String kind;

  /// The object's geometry as a flat point list. For a `borderarea` — the one
  /// kind whose geometry is multi-ring — this is only the first ring; [rings]
  /// carries all of it, and is what the importer reads.
  final List<LatLng> coords;
  final String? label;

  /// The element's colour override, if it has one. Null means it follows its
  /// layer, and stays following it on the far side of an import — the auto
  /// shade is derived from the layer, so it is not a thing to carry across.
  final int? colorArgb;

  // circle / height: radius of the circle (height uses it as its bound);
  // poi: the search radius of a radius import (absent on a box import, whose
  // radius is derived from its box, and 0 on a manual set)
  final double? radiusMeters;
  // freeline / freearea
  final double? offsetMeters;
  // freeline: the inclusion circle that bounds the line to a half-disk (null =
  // derived from the line's extent on import)
  final double? inclusionLat;
  final double? inclusionLng;
  final double? inclusionRadiusMeters;
  // subspace: index into [coords] of the main point
  final int? mainIndex;
  // height: elevation threshold, direction and sample zoom (the generated
  // polygons are derived, not exported — the importer regenerates them)
  final double? thresholdMeters;
  final bool? aboveThreshold;
  final int? sampleZoom;
  // poi: the imported category, and the per-POI names aligned with coords[1..]
  // (coords[0] is the set's search centre; radiusMeters its search radius)
  final String? categoryKey;

  /// poi: a hand-made category's marker icon (a `poiIcons` key), and the flag
  /// saying it *is* hand-made rather than an Overpass import.
  ///
  /// Both travel because the distinction is user-visible and not derivable:
  /// a manual set is editable, accepts hand-placed points and shows no search
  /// area, while an import is a read-only snapshot of what OSM returned. A
  /// manual set that came back as an import would be a silent demotion — and
  /// its centre/radius, which mean nothing, would start being displayed as a
  /// search that never ran.
  final String? iconKey;
  final bool? manual;

  /// poi: the per-point names, aligned with the point coords (`coords[1..]`;
  /// `coords[0]` is the set's centre).
  final List<String?>? pointLabels;

  /// borderarea: the whole multi-ring geometry, outer rings and holes together
  /// with no role flag — exactly as stored, because the painter fills even-odd
  /// (see `BorderAreas.rings`). The GeoJSON encoder groups it into proper
  /// outer+holes polygons on the way out and flattens it back on the way in.
  final List<List<LatLng>>? rings;

  /// borderarea / poi: the bounding box of the *import* this element came
  /// from, as `[south, west, north, east]`. For a border area it is what
  /// re-groups areas back into the sets they were fetched in, so an imported
  /// layer keeps the same elements-to-imports structure the sender had. For a
  /// POI set its presence is what *makes* it a station (box) import.
  final List<double>? bbox;

  /// borderarea: the OSM relation id.
  final int? osmId;

  /// borderarea: the OSM `admin_level` of the import this area came from.
  final String? adminLevel;

  // borderarea: the neighbour-distinct palette slot, the name-plate anchor and
  // the member way ids adjacency is computed from.
  final int? colorIndex;
  final double? labelLat;
  final double? labelLng;
  final List<int>? wayIds;

  /// borderarea: true when the outline was **reshaped by hand** and is no
  /// longer what OSM returned (v23). It travels with the file so a shared layer
  /// cannot launder an edited boundary into "what OSM says" on the receiving
  /// device — which, since re-import dedup then keeps this version, is exactly
  /// where it would matter.
  final bool? edited;

  // poi (station import): which station types the import fetched, and which
  // of them are shown.
  final int? modeMask;
  final int? visibleModeMask;

  /// poi: the OSM ids of the points, aligned with `coords[1..]`. It is what
  /// re-import dedup matches on; a point without one simply stays outside the
  /// check rather than being given a made-up identity.
  final List<int>? pointOsmIds;

  /// poi (station import): the per-station mode bits, aligned with
  /// `coords[1..]`.
  final List<int>? pointModeMasks;

  /// poi: the OSM element *type* of each point, paired with [pointOsmIds].
  /// Both halves are needed — ids are unique only within a type — and without
  /// them an imported POI has no identity, so a later import over the same
  /// ground draws it a second time.
  final List<String?>? pointOsmTypes;

  /// height: the **generated** fill rings, exactly as stored. They are derived
  /// from terrain tiles, but deriving them again needs the network and can
  /// disagree with the sender's, so they travel with the region — otherwise an
  /// imported height layer draws nothing at all until someone taps Generate.
  final List<List<LatLng>>? heightRings;

  /// height: whether the region had been generated. Not the same as
  /// `heightRings != null`: a region whose terrain is entirely on one side of
  /// the threshold generates *zero* polygons, and that is a result, not a
  /// pending state.
  final bool? generated;

  /// borderarea: the name of the *import* the area belongs to. The area's own
  /// name is [label]; a set carries its own, and losing it renames the import.
  final String? setLabel;

  // poi: an import that never succeeded — it has no points and shows as a
  // retry row, which is data about a query, so it round-trips as one.
  final bool? pending;
  final String? errorMessage;

  /// Total vertices this object carries — what an export's size is driven by.
  int get pointCount {
    var n = rings == null
        ? coords.length
        : rings!.fold(0, (a, r) => a + r.length);
    final fills = heightRings;
    if (fills != null) n += fills.fold(0, (a, r) => a + r.length);
    return n;
  }
}

/// One exported layer: its display attributes plus its objects.
class ExportLayer {
  const ExportLayer({
    required this.name,
    required this.colorArgb,
    required this.type,
    required this.isInverted,
    required this.objects,
    this.opacity,
    this.borderLevel,
    this.borderFillAreas,
    this.borderShowNames,
    this.isVisible,
  });

  final String name;
  final int colorArgb;

  /// circles | subspace | freeline | freearea | height | poi | borders |
  /// mixed. (A v1/v2 file's `planes` and `transit` read as `subspace` and
  /// `poi`; its `track` layers are dropped.)
  final String type;
  final bool isInverted;
  final List<ExportObject> objects;

  /// Layer opacity in [0, 1]. Null = let the importer apply the default for
  /// [type] (which is what a file written before this field carried).
  final double? opacity;

  /// **`borders` only.** The OSM `admin_level` the layer holds. It is fixed at
  /// creation and one layer holds exactly one level, so it has to travel with
  /// the layer rather than with its areas — and a merge into a layer of a
  /// different level has to be refused.
  final String? borderLevel;

  // `borders` only: the two per-layer display toggles. Null = the defaults.
  final bool? borderFillAreas;
  final bool? borderShowNames;

  /// Whether the layer is shown. Null = shown, which is both the default and
  /// what a file written before this field carried — so only a *hidden* layer
  /// puts a key in the file.
  final bool? isVisible;
}

/// A whole export: the ordered layers (bottom-to-top draw order).
class ExportData {
  const ExportData(this.layers);
  final List<ExportLayer> layers;

  int get objectCount =>
      layers.fold(0, (sum, l) => sum + l.objects.length);

  /// Total vertices across every object — the number an export's file size
  /// tracks, and what the "this will be a big file" warning is measured on. A
  /// single state boundary is ~119 000 points on its own.
  int get pointCount => layers.fold(
      0, (sum, l) => sum + l.objects.fold(0, (a, o) => a + o.pointCount));
}

// --- GeoJSON ----------------------------------------------------------------

/// Current schema version stamped into the `zonecraft` extension member.
///
/// v2 added: layer `isVisible`; `height` fill rings (`heightRings`/`generated`);
/// per-segment `track` geometry (`MultiLineString`); POI `pointOsmTypes` beside
/// the reused `pointOsmIds`; per-point `pointLabels` on a `subspace`; a border
/// area's `setLabel`; and `pending`/`errorMessage` for a transit import that
/// never succeeded. Every one of them is optional, so a v1 file still reads.
///
/// v3 removed three kinds: `plane` (now a two-point `subspace`), `transitstop`
/// (now a `poi` carrying `bbox`, `modeMask`, `visibleModeMask`,
/// `pointModeMasks`, `pending`, `errorMessage`) and `track` (dropped). The
/// reader translates a v1/v2 file's kinds and layer types on the way in
/// ([importFromGeoJson]); `nearA`, `pointNodeCounts`, `pointRouteRefs`,
/// `trackStrokeWidth` and `trackMinDistanceMeters` are no longer written.
const int geoJsonSchemaVersion = 3;

/// Serialises [data] to a pretty-printed GeoJSON `FeatureCollection`. Each object
/// becomes a `Feature`; layer attributes ride in a non-standard top-level
/// `zonecraft` member (ignored by generic GeoJSON readers) and each feature
/// references its layer by index in `properties.zonecraftLayer`.
String exportToGeoJson(ExportData data) {
  final features = <Map<String, dynamic>>[];
  for (var li = 0; li < data.layers.length; li++) {
    for (final o in data.layers[li].objects) {
      features.add(_objectToFeature(o, li));
    }
  }
  final root = <String, dynamic>{
    'type': 'FeatureCollection',
    'zonecraft': {
      'version': geoJsonSchemaVersion,
      'layers': [
        for (final l in data.layers)
          {
            'name': l.name,
            'colorArgb': l.colorArgb,
            'type': l.type,
            'isInverted': l.isInverted,
            if (l.opacity != null) 'opacity': l.opacity,
            if (l.borderLevel != null) 'borderLevel': l.borderLevel,
            if (l.borderFillAreas != null) 'borderFillAreas': l.borderFillAreas,
            if (l.borderShowNames != null) 'borderShowNames': l.borderShowNames,
            // Only a hidden layer writes a key: absent means shown, which is
            // what every v1 file means too.
            if (l.isVisible == false) 'isVisible': false,
          },
      ],
    },
    'features': features,
  };
  return const JsonEncoder.withIndent('  ').convert(root);
}

Map<String, dynamic> _objectToFeature(ExportObject o, int layerIndex) {
  final props = <String, dynamic>{
    'kind': o.kind,
    'zonecraftLayer': layerIndex,
    if (o.label != null) 'label': o.label,
    if (o.radiusMeters != null) 'radiusMeters': o.radiusMeters,
    if (o.offsetMeters != null) 'offsetMeters': o.offsetMeters,
    if (o.mainIndex != null) 'mainIndex': o.mainIndex,
    if (o.thresholdMeters != null) 'thresholdMeters': o.thresholdMeters,
    if (o.aboveThreshold != null) 'aboveThreshold': o.aboveThreshold,
    if (o.sampleZoom != null) 'sampleZoom': o.sampleZoom,
    if (o.inclusionLat != null) 'inclusionLat': o.inclusionLat,
    if (o.inclusionLng != null) 'inclusionLng': o.inclusionLng,
    if (o.inclusionRadiusMeters != null)
      'inclusionRadiusMeters': o.inclusionRadiusMeters,
    if (o.categoryKey != null) 'categoryKey': o.categoryKey,
    if (o.iconKey != null) 'iconKey': o.iconKey,
    if (o.manual != null) 'manual': o.manual,
    if (o.pointLabels != null) 'pointLabels': o.pointLabels,
    if (o.colorArgb != null) 'colorArgb': o.colorArgb,
    if (o.bbox != null) 'bbox': o.bbox,
    if (o.osmId != null) 'osmId': o.osmId,
    if (o.adminLevel != null) 'adminLevel': o.adminLevel,
    if (o.colorIndex != null) 'colorIndex': o.colorIndex,
    if (o.labelLat != null) 'labelLat': o.labelLat,
    if (o.labelLng != null) 'labelLng': o.labelLng,
    if (o.wayIds != null) 'wayIds': o.wayIds,
    if (o.edited != null) 'edited': o.edited,
    if (o.modeMask != null) 'modeMask': o.modeMask,
    if (o.visibleModeMask != null) 'visibleModeMask': o.visibleModeMask,
    if (o.pointOsmIds != null) 'pointOsmIds': o.pointOsmIds,
    if (o.pointModeMasks != null) 'pointModeMasks': o.pointModeMasks,
    if (o.pointOsmTypes != null) 'pointOsmTypes': o.pointOsmTypes,
    // A height region's fills stay in `properties`, not in the geometry: the
    // centre is the region, the fills are what was generated from it, and a
    // reader that knows neither still gets the point it always got.
    if (o.heightRings != null) 'heightRings': _ringArray(o.heightRings!),
    if (o.generated != null) 'generated': o.generated,
    if (o.setLabel != null) 'setLabel': o.setLabel,
    if (o.pending != null) 'pending': o.pending,
    if (o.errorMessage != null) 'errorMessage': o.errorMessage,
  };
  final Map<String, dynamic> geometry;
  switch (o.kind) {
    case 'circle':
    case 'height':
      geometry = o.coords.isEmpty
          ? {'type': 'Point', 'coordinates': <double>[]}
          : {'type': 'Point', 'coordinates': _pt(o.coords.first)};
    case 'freeline':
      geometry = {
        'type': 'LineString',
        'coordinates': [for (final c in o.coords) _pt(c)],
      };
    case 'subspace':
    case 'poi':
      geometry = {
        'type': 'MultiPoint',
        'coordinates': [for (final c in o.coords) _pt(c)],
      };
    case 'freearea':
      geometry = {
        'type': 'Polygon',
        'coordinates': [
          // A ring is closed by repeating its first vertex. Guarded because an
          // encoder must never throw: one point-less row would otherwise fail
          // the whole export with "No element".
          if (o.coords.isNotEmpty)
            [for (final c in o.coords) _pt(c), _pt(o.coords.first)],
        ],
      };
    case 'borderarea':
      // MultiPolygon, not Polygon: an area with exclaves has several *outer*
      // rings, and a Polygon's rings after the first mean holes — Berchtesgaden
      // would read as a hole in its own mainland. [groupRings] recovers which
      // is which; the importer flattens it back, so the round-trip is exact
      // even where the grouping guessed.
      geometry = {
        'type': 'MultiPolygon',
        'coordinates': [
          for (final poly in groupRings(o.rings ?? [o.coords]))
            [for (final ring in poly) _closedRing(ring)],
        ],
      };
    default:
      geometry = {'type': 'GeometryCollection', 'geometries': <dynamic>[]};
  }
  return {'type': 'Feature', 'properties': props, 'geometry': geometry};
}

List<double> _pt(LatLng p) => [p.longitude, p.latitude];

/// A list of closed linear rings, for the ring lists that ride in `properties`
/// rather than in a feature's geometry (a height region's fills).
List<List<List<double>>> _ringArray(List<List<LatLng>> rings) =>
    [for (final r in rings) if (r.isNotEmpty) _closedRing(r)];

/// A GeoJSON linear ring: the vertices with the first repeated at the end.
List<List<double>> _closedRing(List<LatLng> ring) =>
    [for (final c in ring) _pt(c), _pt(ring.first)];

/// Parses a ZoneCraft GeoJSON document back into [ExportData]. Returns null when
/// the text isn't valid GeoJSON or lacks the `zonecraft` extension (i.e. wasn't
/// produced by this app). Throws nothing — callers show a friendly message on
/// null.
ExportData? importFromGeoJson(String text) {
  Object? root;
  try {
    root = jsonDecode(text);
  // An arbitrary file is arbitrary bytes; every failure means the same null,
  // which is what the doc comment above promises.
  // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return null;
  }
  if (root is! Map || root['type'] != 'FeatureCollection') return null;
  final zc = root['zonecraft'];
  if (zc is! Map || zc['layers'] is! List) return null;

  final layerMeta = <ExportLayer>[];
  final buckets = <List<ExportObject>>[];
  // A v1/v2 file may hold layers of types that no longer exist. `planes` and
  // `transit` are retyped (their objects translate, see [_featureToObject]);
  // a `track` layer is dropped outright, so the feature index a file wrote
  // (`zonecraftLayer`) is remapped onto the layers that survive.
  final bucketOfFileLayer = <int?>[];
  for (final l in (zc['layers'] as List)) {
    if (l is! Map) return null;
    final type = legacyLayerType((l['type'] as String?) ?? 'circles');
    if (type == null) {
      bucketOfFileLayer.add(null);
      continue;
    }
    bucketOfFileLayer.add(layerMeta.length);
    layerMeta.add(ExportLayer(
      name: (l['name'] as String?) ?? 'Imported',
      colorArgb: (l['colorArgb'] as num?)?.toInt() ?? 0xFF2196F3,
      type: type,
      isInverted: l['isInverted'] == true,
      opacity: (l['opacity'] as num?)?.toDouble(),
      borderLevel: l['borderLevel'] as String?,
      borderFillAreas: l['borderFillAreas'] as bool?,
      borderShowNames: l['borderShowNames'] as bool?,
      isVisible: l['isVisible'] as bool?,
      objects: const [],
    ));
    buckets.add(<ExportObject>[]);
  }

  final features = root['features'];
  if (features is! List) return null;
  for (final f in features) {
    if (f is! Map<String, dynamic>) continue;
    final obj = _featureToObject(f);
    if (obj == null) continue;
    final fileIdx = ((f['properties'] as Map<String, dynamic>?)?['zonecraftLayer'] as num?)?.toInt();
    if (fileIdx == null || fileIdx < 0 || fileIdx >= bucketOfFileLayer.length) {
      continue;
    }
    final idx = bucketOfFileLayer[fileIdx];
    if (idx == null) continue;
    buckets[idx].add(obj);
  }

  return ExportData([
    for (var i = 0; i < layerMeta.length; i++)
      ExportLayer(
        name: layerMeta[i].name,
        colorArgb: layerMeta[i].colorArgb,
        type: layerMeta[i].type,
        isInverted: layerMeta[i].isInverted,
        opacity: layerMeta[i].opacity,
        borderLevel: layerMeta[i].borderLevel,
        borderFillAreas: layerMeta[i].borderFillAreas,
        borderShowNames: layerMeta[i].borderShowNames,
        isVisible: layerMeta[i].isVisible,
        objects: buckets[i],
      ),
  ]);
}

ExportObject? _featureToObject(Map<String, dynamic> f) {
  final props = f['properties'];
  final geom = f['geometry'];
  if (props is! Map<String, dynamic> || geom is! Map<String, dynamic>) {
    return null;
  }
  final fileKind = props['kind'] as String?;
  if (fileKind == null) return null;
  // The three retired kinds, translated here so the repository only ever sees
  // today's vocabulary.
  if (fileKind == 'track') return null; // the type was dropped
  final kind = switch (fileKind) {
    'plane' => 'subspace',
    'transitstop' => 'poi',
    _ => fileKind,
  };
  final rings = kind == 'borderarea' ? _readRings(geom) : null;
  var coords = rings != null && rings.isNotEmpty
      ? rings.first
      : _readCoords(kind, geom);
  var bbox = _readDoubles(props['bbox'], exactly: 4);
  var mainIndex = (props['mainIndex'] as num?)?.toInt();
  var categoryKey = props['categoryKey'] as String?;
  var pointOsmTypes = _readStrings(props['pointOsmTypes']);
  final pointOsmIds = _readInts(props['pointOsmIds']);
  switch (fileKind) {
    case 'plane':
      // A plane's coords were its two foci and `nearA` said which side was
      // kept; as a subspace the kept side is the main point.
      if (coords.length < 2) return null;
      mainIndex = (props['nearA'] as bool? ?? true) ? 0 : 1;
    case 'transitstop':
      // A transit import's coords were its stations alone; a POI set's start
      // with the set's centre. The box it was fetched over is what marks it
      // as a station import on the way in, so one is derived from the
      // stations when the file carries none — a retry row with neither has
      // nothing to say and is skipped. Every station was an OSM node.
      if (bbox == null) {
        if (coords.isEmpty) return null;
        bbox = _extentOf(coords);
      }
      coords = [
        LatLng((bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2),
        ...coords,
      ];
      categoryKey ??= 'transit_station';
      if (pointOsmIds != null && pointOsmTypes == null) {
        pointOsmTypes = List<String?>.filled(pointOsmIds.length, 'node');
      }
  }
  // A POI import that never succeeded has only its centre — it is a retry
  // row, which describes a query rather than geometry. Every other kind
  // without coordinates is unusable.
  if (coords.isEmpty) return null;
  return ExportObject(
    kind: kind,
    coords: coords,
    rings: rings,
    pointOsmTypes: pointOsmTypes,
    heightRings: _readRingArray(props['heightRings']),
    generated: props['generated'] as bool?,
    setLabel: props['setLabel'] as String?,
    pending: props['pending'] as bool?,
    errorMessage: props['errorMessage'] as String?,
    bbox: bbox,
    osmId: (props['osmId'] as num?)?.toInt(),
    adminLevel: props['adminLevel'] as String?,
    colorIndex: (props['colorIndex'] as num?)?.toInt(),
    labelLat: (props['labelLat'] as num?)?.toDouble(),
    labelLng: (props['labelLng'] as num?)?.toDouble(),
    wayIds: _readInts(props['wayIds']),
    edited: props['edited'] as bool?,
    modeMask: (props['modeMask'] as num?)?.toInt(),
    visibleModeMask: (props['visibleModeMask'] as num?)?.toInt(),
    pointOsmIds: pointOsmIds,
    pointModeMasks: _readInts(props['pointModeMasks']),
    label: props['label'] as String?,
    radiusMeters: (props['radiusMeters'] as num?)?.toDouble(),
    offsetMeters: (props['offsetMeters'] as num?)?.toDouble(),
    mainIndex: mainIndex,
    thresholdMeters: (props['thresholdMeters'] as num?)?.toDouble(),
    aboveThreshold: props['aboveThreshold'] as bool?,
    sampleZoom: (props['sampleZoom'] as num?)?.toInt(),
    inclusionLat: (props['inclusionLat'] as num?)?.toDouble(),
    inclusionLng: (props['inclusionLng'] as num?)?.toDouble(),
    inclusionRadiusMeters: (props['inclusionRadiusMeters'] as num?)?.toDouble(),
    categoryKey: categoryKey,
    iconKey: props['iconKey'] as String?,
    manual: props['manual'] as bool?,
    colorArgb: (props['colorArgb'] as num?)?.toInt(),
    pointLabels: props['pointLabels'] is List
        ? [
            for (final n in props['pointLabels'] as List)
              n is String ? n : null,
          ]
        : null,
  );
}

/// The full ring list of a `borderarea`'s geometry, flattened back to the
/// role-less form the database stores. Accepts a `Polygon` too, so a file
/// hand-edited down to one area still reads.
List<List<LatLng>>? _readRings(Map<String, dynamic> geom) {
  final type = geom['type'];
  final c = geom['coordinates'];
  if (c is! List) return null;
  final polys = switch (type) {
    'MultiPolygon' => [for (final p in c) if (p is List) p],
    'Polygon' => [c],
    _ => const <List<dynamic>>[],
  };
  final out = <List<LatLng>>[];
  for (final poly in polys) {
    for (final r in poly) {
      if (r is! List) continue;
      final ring = _latLngList(r);
      // GeoJSON linear rings repeat the first vertex to close; drop it.
      if (ring.length >= 2 &&
          ring.first.latitude == ring.last.latitude &&
          ring.first.longitude == ring.last.longitude) {
        ring.removeLast();
      }
      if (ring.length >= 3) out.add(ring);
    }
  }
  return out.isEmpty ? null : out;
}

/// A ring list that rode in `properties` rather than in a geometry (a height
/// region's fills). Same closing-vertex rule as a GeoJSON linear ring.
List<List<LatLng>>? _readRingArray(Object? raw) {
  if (raw is! List) return null;
  final out = <List<LatLng>>[];
  for (final r in raw) {
    if (r is! List) continue;
    final ring = _latLngList(r);
    if (ring.length >= 2 &&
        ring.first.latitude == ring.last.latitude &&
        ring.first.longitude == ring.last.longitude) {
      ring.removeLast();
    }
    if (ring.length >= 3) out.add(ring);
  }
  // An empty list is a *result*, not an absence: a height region whose terrain
  // is all on one side of the threshold generates no polygons at all.
  return out;
}

/// `[south, west, north, east]` of [points] — the box a v2 transit export
/// without one is given, so it reads as the station import it was.
List<double> _extentOf(List<LatLng> points) {
  var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
  for (final p in points) {
    if (p.latitude < s) s = p.latitude;
    if (p.latitude > n) n = p.latitude;
    if (p.longitude < w) w = p.longitude;
    if (p.longitude > e) e = p.longitude;
  }
  return [s, w, n, e];
}

List<int>? _readInts(Object? raw) => raw is List
    ? [
        for (final e in raw) (e as num?)?.toInt() ?? 0,
      ]
    : null;

List<String?>? _readStrings(Object? raw) => raw is List
    ? [
        for (final e in raw) e is String ? e : null,
      ]
    : null;

List<double>? _readDoubles(Object? raw, {required int exactly}) {
  if (raw is! List || raw.length != exactly) return null;
  final out = <double>[];
  for (final e in raw) {
    final v = (e as num?)?.toDouble();
    if (v == null || !v.isFinite) return null;
    out.add(v);
  }
  return out;
}

List<LatLng> _readCoords(String kind, Map<String, dynamic> geom) {
  final type = geom['type'];
  final c = geom['coordinates'];
  if (type == 'Point' && c is List) {
    final p = _latLng(c);
    return p == null ? const [] : [p];
  }
  if ((type == 'LineString' || type == 'MultiPoint') && c is List) {
    return _latLngList(c);
  }
  if (type == 'Polygon' && c is List && c.isNotEmpty && c.first is List) {
    final ring = _latLngList(c.first as List<dynamic>);
    // GeoJSON polygons repeat the first vertex to close; drop it.
    if (ring.length >= 2 &&
        ring.first.latitude == ring.last.latitude &&
        ring.first.longitude == ring.last.longitude) {
      ring.removeLast();
    }
    return ring;
  }
  return const [];
}

List<LatLng> _latLngList(List<dynamic> raw) {
  final out = <LatLng>[];
  for (final e in raw) {
    if (e is List) {
      final p = _latLng(e);
      if (p != null) out.add(p);
    }
  }
  return out;
}

LatLng? _latLng(List<dynamic> pair) {
  if (pair.length < 2) return null;
  final lng = (pair[0] as num?)?.toDouble();
  final lat = (pair[1] as num?)?.toDouble();
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return null;
  return LatLng(lat, lng);
}

// --- KML (export only) ------------------------------------------------------

/// Serialises [data] to KML for Google Earth / Maps interop. Each layer becomes
/// a `<Folder>`; objects export their source geometry (circles as a geodesic
/// ring polygon, subspaces as their seed points, freehand line/area as
/// line/polygon, POI sets as one Placemark per point). This is a one-way
/// export — re-import via GeoJSON.
String exportToKml(ExportData data) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
    ..writeln('<Document>');
  for (final layer in data.layers) {
    b
      ..writeln('  <Folder>')
      ..writeln('    <name>${_xml(layer.name)}</name>');
    for (final o in layer.objects) {
      // A POI set is a *collection* of named points, so it becomes one
      // Placemark each rather than one Placemark of many points. coords[0] is
      // the set's centre, not a POI — skip it.
      if (o.kind == 'poi') {
        _kmlPoints(b, o, from: 1);
        continue;
      }
      _kmlPlacemark(b, o);
    }
    b.writeln('  </Folder>');
  }
  b
    ..writeln('</Document>')
    ..writeln('</kml>');
  return b.toString();
}

void _kmlPlacemark(StringBuffer b, ExportObject o) {
  b.writeln('    <Placemark>');
  if (o.label != null && o.label!.isNotEmpty) {
    b.writeln('      <name>${_xml(o.label!)}</name>');
  }
  if (o.coords.isEmpty && (o.heightRings?.isEmpty ?? true)) {
    // Nothing to draw. A Placemark with no geometry is still valid KML, and
    // an encoder that throws here would fail the whole export.
    b.writeln('    </Placemark>');
    return;
  }
  switch (o.kind) {
    case 'height':
      // The generated fill, when the region has one — that is what the layer
      // actually shows. Without it, the bounding circle is the best available.
      final fills = o.heightRings;
      if (fills != null && fills.isNotEmpty) {
        b.writeln('      <MultiGeometry>');
        for (final ring in fills) {
          b.writeln(_kmlPolygon(ring));
        }
        b.writeln('      </MultiGeometry>');
      } else {
        final ring = geodesicCircle(o.coords.first, o.radiusMeters ?? 0);
        b.writeln(_kmlPolygon(ring.isEmpty ? [o.coords.first] : ring));
      }
    case 'circle':
      final ring = geodesicCircle(o.coords.first, o.radiusMeters ?? 0);
      b.writeln(_kmlPolygon(ring.isEmpty ? [o.coords.first] : ring));
    case 'freearea':
      b.writeln(_kmlPolygon(o.coords));
    case 'borderarea':
      // One `<Polygon>` per outer ring, its holes as inner boundaries — the
      // same grouping the GeoJSON encoder makes, in KML's spelling.
      final polys = groupRings(o.rings ?? [o.coords]);
      if (polys.length == 1) {
        b.writeln(_kmlPolygon(polys.first.first, holes: polys.first.skip(1)));
      } else {
        b.writeln('      <MultiGeometry>');
        for (final poly in polys) {
          b.writeln(_kmlPolygon(poly.first, holes: poly.skip(1)));
        }
        b.writeln('      </MultiGeometry>');
      }
    case 'freeline':
      b.writeln(_kmlLine(o.coords));
    case 'subspace':
      b.writeln('      <MultiGeometry>');
      for (final c in o.coords) {
        b.writeln(
            '        <Point><coordinates>${_coord(c)}</coordinates></Point>');
      }
      b.writeln('      </MultiGeometry>');
    default:
      b.writeln('      <Point><coordinates>'
          '${_coord(o.coords.first)}</coordinates></Point>');
  }
  b.writeln('    </Placemark>');
}

/// One `<Placemark>` per coordinate from [from] onward, named from
/// [ExportObject.pointLabels] (which is aligned to `coords[from..]`).
void _kmlPoints(StringBuffer b, ExportObject o, {required int from}) {
  final labels = o.pointLabels ?? const <String?>[];
  for (var i = from; i < o.coords.length; i++) {
    final li = i - from;
    final name = li < labels.length ? labels[li] : null;
    b.writeln('    <Placemark>');
    if (name != null && name.isNotEmpty) {
      b.writeln('      <name>${_xml(name)}</name>');
    }
    b.writeln('      <Point><coordinates>'
        '${_coord(o.coords[i])}</coordinates></Point>');
    b.writeln('    </Placemark>');
  }
}

String _kmlLine(List<LatLng> pts) =>
    '      <LineString><coordinates>${_coords(pts)}</coordinates></LineString>';

String _kmlPolygon(List<LatLng> ring, {Iterable<List<LatLng>> holes = const []}) {
  final b = StringBuffer('      <Polygon>')
    ..write('<outerBoundaryIs><LinearRing><coordinates>')
    ..write(_coords(_closed(ring)))
    ..write('</coordinates></LinearRing></outerBoundaryIs>');
  for (final h in holes) {
    b
      ..write('<innerBoundaryIs><LinearRing><coordinates>')
      ..write(_coords(_closed(h)))
      ..write('</coordinates></LinearRing></innerBoundaryIs>');
  }
  return (b..write('</Polygon>')).toString();
}

List<LatLng> _closed(List<LatLng> ring) =>
    [...ring, if (ring.isNotEmpty) ring.first];

String _coords(List<LatLng> pts) => pts.map(_coord).join(' ');
String _coord(LatLng p) => '${p.longitude},${p.latitude},0';

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// The layer type that holds an [ExportObject.kind].
///
/// The two vocabularies differ — an object is a `circle` while a layer is
/// `circles`, an object is a `poiset` while a layer is `poi` — so anything
/// asking "can this layer hold that object" needs the translation. Null for a
/// kind this build does not know, which a file from a newer version can carry.
String? layerTypeForExportKind(String kind) => switch (kind) {
      'circle' => 'circles',
      'subspace' => 'subspace',
      'freeline' => 'freeline',
      'freearea' => 'freearea',
      'height' => 'height',
      'poi' => 'poi',
      'borderarea' => 'borders',
      _ => null,
    };

/// Today's name for a layer type a v1/v2 file may carry: `planes` became
/// `subspace` and `transit` became `poi` in v27; a `track` layer has no
/// successor and reads as null (dropped). Everything else is itself.
String? legacyLayerType(String type) => switch (type) {
      'planes' => 'subspace',
      'transit' => 'poi',
      'track' => null,
      _ => type,
    };
