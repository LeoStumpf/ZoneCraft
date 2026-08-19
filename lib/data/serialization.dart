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
/// two foci for a plane, the point list for the rest).
class ExportObject {
  const ExportObject({
    required this.kind,
    required this.coords,
    this.label,
    this.radiusMeters,
    this.nearA,
    this.offsetMeters,
    this.mainIndex,
    this.thresholdMeters,
    this.aboveThreshold,
    this.sampleZoom,
    this.inclusionLat,
    this.inclusionLng,
    this.inclusionRadiusMeters,
    this.categoryKey,
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
    this.pointNodeCounts,
    this.pointRouteRefs,
  });

  /// One of: circle, plane, subspace, freeline, freearea, height, poi,
  /// transitstop, borderarea.
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

  // circle / height: radius of the circle (height uses it as its bound)
  final double? radiusMeters;
  // plane
  final bool? nearA;
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

  /// poi / transitstop: the per-point names, aligned with the point coords
  /// (`coords[1..]` for a POI set, `coords` for a transit import).
  final List<String?>? pointLabels;

  /// borderarea: the whole multi-ring geometry, outer rings and holes together
  /// with no role flag — exactly as stored, because the painter fills even-odd
  /// (see `BorderAreas.rings`). The GeoJSON encoder groups it into proper
  /// outer+holes polygons on the way out and flattens it back on the way in.
  final List<List<LatLng>>? rings;

  /// borderarea / transitstop: the bounding box of the *import* this element
  /// came from, as `[south, west, north, east]`. It is what re-groups areas
  /// back into the sets they were fetched in, so an imported layer keeps the
  /// same elements-to-imports structure the sender had.
  final List<double>? bbox;

  /// borderarea: the OSM relation id. transitstop: unused (the stops carry
  /// their own ids in [pointOsmIds]).
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

  // transitstop: which station types the import fetched, and which of them are
  // shown.
  final int? modeMask;
  final int? visibleModeMask;

  /// transitstop: the OSM node ids of the stations, aligned with [coords].
  /// **Required for re-import** — a station row is keyed on its node id, which
  /// is also what re-import dedup matches on, and inventing one would let two
  /// genuinely different stations collide.
  final List<int>? pointOsmIds;

  // transitstop: the per-station mode bits, merged-node counts and `route_ref`
  // hints, all aligned with [coords].
  final List<int>? pointModeMasks;
  final List<int>? pointNodeCounts;
  final List<String?>? pointRouteRefs;

  /// Total vertices this object carries — what an export's size is driven by.
  int get pointCount => rings == null
      ? coords.length
      : rings!.fold(0, (a, r) => a + r.length);
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
  });

  final String name;
  final int colorArgb;

  /// circles | planes | subspace | freeline | freearea | height | poi |
  /// transit | borders.
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
const int geoJsonSchemaVersion = 1;

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
    if (o.nearA != null) 'nearA': o.nearA,
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
    if (o.pointNodeCounts != null) 'pointNodeCounts': o.pointNodeCounts,
    if (o.pointRouteRefs != null) 'pointRouteRefs': o.pointRouteRefs,
  };
  final Map<String, dynamic> geometry;
  switch (o.kind) {
    case 'circle':
    case 'height':
      geometry = {'type': 'Point', 'coordinates': _pt(o.coords.first)};
    case 'plane':
    case 'freeline':
      geometry = {
        'type': 'LineString',
        'coordinates': [for (final c in o.coords) _pt(c)],
      };
    case 'subspace':
    case 'poi':
    case 'transitstop':
      geometry = {
        'type': 'MultiPoint',
        'coordinates': [for (final c in o.coords) _pt(c)],
      };
    case 'freearea':
      geometry = {
        'type': 'Polygon',
        'coordinates': [
          [for (final c in o.coords) _pt(c), _pt(o.coords.first)], // closed ring
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
  } catch (_) {
    return null;
  }
  if (root is! Map || root['type'] != 'FeatureCollection') return null;
  final zc = root['zonecraft'];
  if (zc is! Map || zc['layers'] is! List) return null;

  final layerMeta = <ExportLayer>[];
  final buckets = <List<ExportObject>>[];
  for (final l in (zc['layers'] as List)) {
    if (l is! Map) return null;
    layerMeta.add(ExportLayer(
      name: (l['name'] as String?) ?? 'Imported',
      colorArgb: (l['colorArgb'] as num?)?.toInt() ?? 0xFF2196F3,
      type: (l['type'] as String?) ?? 'circles',
      isInverted: l['isInverted'] == true,
      opacity: (l['opacity'] as num?)?.toDouble(),
      borderLevel: l['borderLevel'] as String?,
      borderFillAreas: l['borderFillAreas'] as bool?,
      borderShowNames: l['borderShowNames'] as bool?,
      objects: const [],
    ));
    buckets.add(<ExportObject>[]);
  }

  final features = root['features'];
  if (features is! List) return null;
  for (final f in features) {
    if (f is! Map) continue;
    final obj = _featureToObject(f);
    if (obj == null) continue;
    final idx = ((f['properties'] as Map?)?['zonecraftLayer'] as num?)?.toInt();
    if (idx == null || idx < 0 || idx >= buckets.length) continue;
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
        objects: buckets[i],
      ),
  ]);
}

ExportObject? _featureToObject(Map f) {
  final props = f['properties'];
  final geom = f['geometry'];
  if (props is! Map || geom is! Map) return null;
  final kind = props['kind'] as String?;
  if (kind == null) return null;
  final rings = kind == 'borderarea' ? _readRings(geom) : null;
  final coords = rings != null && rings.isNotEmpty
      ? rings.first
      : _readCoords(kind, geom);
  if (coords.isEmpty) return null;
  return ExportObject(
    kind: kind,
    coords: coords,
    rings: rings,
    bbox: _readDoubles(props['bbox'], exactly: 4),
    osmId: (props['osmId'] as num?)?.toInt(),
    adminLevel: props['adminLevel'] as String?,
    colorIndex: (props['colorIndex'] as num?)?.toInt(),
    labelLat: (props['labelLat'] as num?)?.toDouble(),
    labelLng: (props['labelLng'] as num?)?.toDouble(),
    wayIds: _readInts(props['wayIds']),
    edited: props['edited'] as bool?,
    modeMask: (props['modeMask'] as num?)?.toInt(),
    visibleModeMask: (props['visibleModeMask'] as num?)?.toInt(),
    pointOsmIds: _readInts(props['pointOsmIds']),
    pointModeMasks: _readInts(props['pointModeMasks']),
    pointNodeCounts: _readInts(props['pointNodeCounts']),
    pointRouteRefs: _readStrings(props['pointRouteRefs']),
    label: props['label'] as String?,
    radiusMeters: (props['radiusMeters'] as num?)?.toDouble(),
    nearA: props['nearA'] as bool?,
    offsetMeters: (props['offsetMeters'] as num?)?.toDouble(),
    mainIndex: (props['mainIndex'] as num?)?.toInt(),
    thresholdMeters: (props['thresholdMeters'] as num?)?.toDouble(),
    aboveThreshold: props['aboveThreshold'] as bool?,
    sampleZoom: (props['sampleZoom'] as num?)?.toInt(),
    inclusionLat: (props['inclusionLat'] as num?)?.toDouble(),
    inclusionLng: (props['inclusionLng'] as num?)?.toDouble(),
    inclusionRadiusMeters: (props['inclusionRadiusMeters'] as num?)?.toDouble(),
    categoryKey: props['categoryKey'] as String?,
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
List<List<LatLng>>? _readRings(Map geom) {
  final type = geom['type'];
  final c = geom['coordinates'];
  if (c is! List) return null;
  final polys = switch (type) {
    'MultiPolygon' => [for (final p in c) if (p is List) p],
    'Polygon' => [c],
    _ => const <List>[],
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

List<LatLng> _readCoords(String kind, Map geom) {
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
    final ring = _latLngList(c.first as List);
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

List<LatLng> _latLngList(List raw) {
  final out = <LatLng>[];
  for (final e in raw) {
    if (e is List) {
      final p = _latLng(e);
      if (p != null) out.add(p);
    }
  }
  return out;
}

LatLng? _latLng(List pair) {
  if (pair.length < 2) return null;
  final lng = (pair[0] as num?)?.toDouble();
  final lat = (pair[1] as num?)?.toDouble();
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return null;
  return LatLng(lat, lng);
}

// --- KML (export only) ------------------------------------------------------

/// Serialises [data] to KML for Google Earth / Maps interop. Each layer becomes
/// a `<Folder>`; objects export their source geometry (circles as a geodesic
/// ring polygon, planes as the A→B segment, subspaces as their seed points,
/// freehand line/area as line/polygon). This is a one-way export — re-import via
/// GeoJSON.
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
      // POI sets and transit stops are *collections* of named points, so they
      // become one Placemark each rather than one Placemark of many points.
      // For a POI set coords[0] is the search centre, not a POI — skip it.
      if (o.kind == 'poi') {
        _kmlPoints(b, o, from: 1);
        continue;
      }
      if (o.kind == 'transitstop') {
        _kmlPoints(b, o, from: 0);
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
  switch (o.kind) {
    case 'circle':
    case 'height':
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
    case 'plane':
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
