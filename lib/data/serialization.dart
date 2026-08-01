import 'dart:convert';

import 'package:latlong2/latlong.dart';

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
  });

  /// One of: circle, plane, subspace, freeline, freearea, height, poi.
  final String kind;
  final List<LatLng> coords;
  final String? label;

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
  final List<String?>? pointLabels;
}

/// One exported layer: its display attributes plus its objects.
class ExportLayer {
  const ExportLayer({
    required this.name,
    required this.colorArgb,
    required this.type,
    required this.isInverted,
    required this.objects,
  });

  final String name;
  final int colorArgb;

  /// circles | planes | subspace | freeline | freearea.
  final String type;
  final bool isInverted;
  final List<ExportObject> objects;
}

/// A whole export: the ordered layers (bottom-to-top draw order).
class ExportData {
  const ExportData(this.layers);
  final List<ExportLayer> layers;

  int get objectCount =>
      layers.fold(0, (sum, l) => sum + l.objects.length);
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
  };
  final Map<String, dynamic> geometry;
  switch (o.kind) {
    case 'circle':
    case 'height':
      geometry = {'type': 'Point', 'coordinates': _pt(o.coords.first)};
    case 'plane':
    case 'freeline':
    case 'transitline':
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
    default:
      geometry = {'type': 'GeometryCollection', 'geometries': <dynamic>[]};
  }
  return {'type': 'Feature', 'properties': props, 'geometry': geometry};
}

List<double> _pt(LatLng p) => [p.longitude, p.latitude];

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
  final coords = _readCoords(kind, geom);
  if (coords.isEmpty) return null;
  return ExportObject(
    kind: kind,
    coords: coords,
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
    pointLabels: props['pointLabels'] is List
        ? [
            for (final n in props['pointLabels'] as List)
              n is String ? n : null,
          ]
        : null,
  );
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
    case 'plane':
    case 'freeline':
    // Without this a route would fall into the default and export as a single
    // dot at its first vertex.
    case 'transitline':
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

String _kmlPolygon(List<LatLng> ring) {
  final closed = <LatLng>[...ring, if (ring.isNotEmpty) ring.first];
  return '      <Polygon><outerBoundaryIs><LinearRing><coordinates>'
      '${_coords(closed)}'
      '</coordinates></LinearRing></outerBoundaryIs></Polygon>';
}

String _coords(List<LatLng> pts) => pts.map(_coord).join(' ');
String _coord(LatLng p) => '${p.longitude},${p.latitude},0';

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
