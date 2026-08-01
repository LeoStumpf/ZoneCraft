import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// Parsing of **external** geometry files (not ZoneCraft's own tagged GeoJSON)
/// so tracks/areas drawn in other apps can be imported. Supports generic
/// GeoJSON, KML, KMZ (zipped KML) and GPX. The output is a flat list of
/// [ImportedFeature]s that the UI routes into freehand line/area layers.
///
/// Pure Dart (no Flutter/drift deps) so it stays unit-testable.

/// Whether a feature's geometry reads naturally as an open line or a closed
/// area. Callers may still coerce one into the other (a closed line into an
/// area, or vice versa) depending on the target layer.
enum GeometryKind { line, area }

/// One geometry extracted from an imported file.
class ImportedFeature {
  const ImportedFeature({
    required this.kind,
    required this.coords,
    this.label,
  });

  final GeometryKind kind;
  final List<LatLng> coords;
  final String? label;
}

/// Parses [bytes] of an external geometry file into features, choosing the
/// format from [filename]'s extension (falling back to content sniffing).
/// Returns an empty list when nothing usable is found; throws only on a
/// genuinely corrupt archive.
List<ImportedFeature> parseExternalGeometry(String filename, Uint8List bytes) {
  final ext = filename.toLowerCase().split('.').last;
  switch (ext) {
    case 'geojson':
    case 'json':
      return parseGeoJsonGeometry(utf8.decode(bytes, allowMalformed: true));
    case 'kml':
      return parseKml(utf8.decode(bytes, allowMalformed: true));
    case 'kmz':
      return parseKmz(bytes);
    case 'gpx':
      return parseGpx(utf8.decode(bytes, allowMalformed: true));
    default:
      // Unknown extension: sniff. KML/GPX are XML; GeoJSON is JSON.
      final text = utf8.decode(bytes, allowMalformed: true).trimLeft();
      if (text.startsWith('{') || text.startsWith('[')) {
        return parseGeoJsonGeometry(text);
      }
      if (text.contains('<kml')) return parseKml(text);
      if (text.contains('<gpx')) return parseGpx(text);
      return const [];
  }
}

// --- GeoJSON ----------------------------------------------------------------

/// Parses generic GeoJSON, pulling every LineString/Polygon (and their Multi*
/// variants) as features. Unlike `importFromGeoJson` in serialization.dart this
/// ignores the `zonecraft` extension and accepts any standards-compliant file.
List<ImportedFeature> parseGeoJsonGeometry(String text) {
  Object? root;
  try {
    root = jsonDecode(text);
  } catch (_) {
    return const [];
  }
  final out = <ImportedFeature>[];
  void handleGeometry(Map geom, String? label) {
    final type = geom['type'];
    final c = geom['coordinates'];
    switch (type) {
      case 'LineString':
        final ring = _coordList(c);
        if (ring.length >= 2) {
          out.add(ImportedFeature(
              kind: GeometryKind.line, coords: ring, label: label));
        }
      case 'MultiLineString':
        if (c is List) {
          for (final line in c) {
            final ring = _coordList(line);
            if (ring.length >= 2) {
              out.add(ImportedFeature(
                  kind: GeometryKind.line, coords: ring, label: label));
            }
          }
        }
      case 'Polygon':
        final ring = _polygonOuter(c);
        if (ring.length >= 3) {
          out.add(ImportedFeature(
              kind: GeometryKind.area, coords: ring, label: label));
        }
      case 'MultiPolygon':
        if (c is List) {
          for (final poly in c) {
            final ring = _polygonOuter(poly);
            if (ring.length >= 3) {
              out.add(ImportedFeature(
                  kind: GeometryKind.area, coords: ring, label: label));
            }
          }
        }
      case 'GeometryCollection':
        final geoms = geom['geometries'];
        if (geoms is List) {
          for (final g in geoms) {
            if (g is Map) handleGeometry(g, label);
          }
        }
    }
  }

  void handle(Object? node) {
    if (node is! Map) return;
    final type = node['type'];
    if (type == 'FeatureCollection') {
      final feats = node['features'];
      if (feats is List) {
        for (final f in feats) {
          handle(f);
        }
      }
    } else if (type == 'Feature') {
      final geom = node['geometry'];
      final label = (node['properties'] as Map?)?['name'] as String?;
      if (geom is Map) handleGeometry(geom, label);
    } else if (type is String) {
      handleGeometry(node, null); // bare geometry
    }
  }

  handle(root);
  return out;
}

/// Outer ring of a GeoJSON Polygon (a list of linear rings); drops the repeated
/// closing vertex.
List<LatLng> _polygonOuter(Object? coords) {
  if (coords is! List || coords.isEmpty || coords.first is! List) {
    return const [];
  }
  final ring = _coordList(coords.first);
  _dropClosing(ring);
  return ring;
}

List<LatLng> _coordList(Object? raw) {
  if (raw is! List) return const [];
  final out = <LatLng>[];
  for (final e in raw) {
    final p = _coordPair(e);
    if (p != null) out.add(p);
  }
  return out;
}

LatLng? _coordPair(Object? pair) {
  if (pair is! List || pair.length < 2) return null;
  final lng = (pair[0] as num?)?.toDouble();
  final lat = (pair[1] as num?)?.toDouble();
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return null;
  return LatLng(lat, lng);
}

// --- KML / KMZ --------------------------------------------------------------

/// Extracts LineStrings and Polygon outer rings from a KML document. A
/// Placemark's `<name>` becomes the feature label.
List<ImportedFeature> parseKml(String text) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(text);
  } catch (_) {
    return const [];
  }
  final out = <ImportedFeature>[];

  for (final placemark in doc.findAllElements('Placemark')) {
    final label = placemark
        .findElements('name')
        .firstOrNull
        ?.innerText
        .trim();
    for (final ls in placemark.findAllElements('LineString')) {
      final ring = _kmlCoords(ls.findElements('coordinates').firstOrNull);
      if (ring.length >= 2) {
        out.add(ImportedFeature(
            kind: GeometryKind.line, coords: ring, label: label));
      }
    }
    for (final poly in placemark.findAllElements('Polygon')) {
      // Outer boundary only (holes are dropped for v1).
      final outer = poly.findAllElements('outerBoundaryIs').firstOrNull;
      final coordsEl = (outer ?? poly)
          .findAllElements('coordinates')
          .firstOrNull;
      final ring = _kmlCoords(coordsEl);
      _dropClosing(ring);
      if (ring.length >= 3) {
        out.add(ImportedFeature(
            kind: GeometryKind.area, coords: ring, label: label));
      }
    }
  }
  return out;
}

/// Unzips a KMZ archive and parses the first `.kml` entry it contains.
List<ImportedFeature> parseKmz(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return const [];
  }
  // Prefer doc.kml, else the first .kml entry.
  ArchiveFile? kml;
  for (final f in archive.files) {
    if (!f.isFile) continue;
    if (f.name.toLowerCase().endsWith('.kml')) {
      kml = f;
      if (f.name.toLowerCase() == 'doc.kml') break;
    }
  }
  if (kml == null) return const [];
  return parseKml(utf8.decode(kml.content as List<int>, allowMalformed: true));
}

/// Parses a KML `<coordinates>` element: whitespace-separated `lng,lat[,alt]`
/// tuples.
List<LatLng> _kmlCoords(XmlElement? el) {
  if (el == null) return const [];
  final out = <LatLng>[];
  for (final tuple in el.innerText.split(RegExp(r'\s+'))) {
    if (tuple.isEmpty) continue;
    final parts = tuple.split(',');
    if (parts.length < 2) continue;
    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lng == null || lat == null || !lat.isFinite || !lng.isFinite) continue;
    out.add(LatLng(lat, lng));
  }
  return out;
}

// --- GPX --------------------------------------------------------------------

/// Extracts track segments (`<trkseg>`) and routes (`<rte>`) from a GPX file as
/// line features.
List<ImportedFeature> parseGpx(String text) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(text);
  } catch (_) {
    return const [];
  }
  final out = <ImportedFeature>[];

  for (final trk in doc.findAllElements('trk')) {
    final label = trk.findElements('name').firstOrNull?.innerText.trim();
    for (final seg in trk.findAllElements('trkseg')) {
      final pts = _gpxPoints(seg.findElements('trkpt'));
      if (pts.length >= 2) {
        out.add(ImportedFeature(
            kind: GeometryKind.line, coords: pts, label: label));
      }
    }
  }
  for (final rte in doc.findAllElements('rte')) {
    final label = rte.findElements('name').firstOrNull?.innerText.trim();
    final pts = _gpxPoints(rte.findElements('rtept'));
    if (pts.length >= 2) {
      out.add(ImportedFeature(
          kind: GeometryKind.line, coords: pts, label: label));
    }
  }
  return out;
}

List<LatLng> _gpxPoints(Iterable<XmlElement> pts) {
  final out = <LatLng>[];
  for (final p in pts) {
    final lat = double.tryParse(p.getAttribute('lat') ?? '');
    final lng = double.tryParse(p.getAttribute('lon') ?? '');
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) continue;
    out.add(LatLng(lat, lng));
  }
  return out;
}

// --- shared -----------------------------------------------------------------

const _stitchDistance = Distance(calculator: Haversine());

/// Endpoints within this many metres are treated as a **shared node** — the same
/// feature continuing — and joined. A larger gap means a *separate* feature, so
/// we never fabricate a straight connector across it (see [stitchPolylines]).
const double _maxStitchGapMeters = 50.0;

/// Joins line [parts] into a single ordered polyline by chaining only parts whose
/// endpoints effectively coincide (a shared OSM node, ≤ [_maxStitchGapMeters]),
/// reversing parts as needed. A feature split into many *contiguous* member ways
/// — e.g. a river's main channel — stitches into one continuous divide, so it
/// imports as a single freehand line filling one clean side.
///
/// Genuinely **disconnected** parts (a river's separate side channels, canals,
/// island splits) are NOT wired together with a fabricated straight jump —
/// doing so used to inject false "cuts" that broke the freehand-line region.
/// Instead the parts form separate connected runs and the **longest** run (by
/// geodesic length — the main channel) is returned. Returns empty if no part has
/// ≥2 points.
///
/// Callers that need *every* run — a branching route, or the pieces a bbox clip
/// severed — want [stitchComponents] instead; throwing away all but the longest
/// would silently delete half of such a track.
List<LatLng> stitchPolylines(List<List<LatLng>> parts) =>
    stitchComponents(parts).firstOrNull ?? const [];

/// Every connected run the [parts] form, longest (by geodesic length) first.
///
/// Parts are chained only across (near-)shared endpoints (≤
/// [_maxStitchGapMeters]), reversing as needed; a larger gap ends the run and
/// starts a new component. See [stitchPolylines] for why a gap is never bridged.
List<List<LatLng>> stitchComponents(List<List<LatLng>> parts) {
  final remaining = <List<LatLng>>[
    for (final p in parts) if (p.length >= 2) List<LatLng>.of(p),
  ];
  if (remaining.isEmpty) return const [];

  double gap(LatLng a, LatLng b) => _stitchDistance.as(LengthUnit.Meter, a, b);

  final components = <List<LatLng>>[];
  while (remaining.isNotEmpty) {
    // Start each component from the longest remaining part for a stable spine.
    remaining.sort((a, b) => b.length.compareTo(a.length));
    final path = remaining.removeAt(0);
    var grew = true;
    while (grew && remaining.isNotEmpty) {
      grew = false;
      final head = path.first, tail = path.last;
      var best = double.infinity;
      var bestIdx = -1;
      var atTail = true, reverse = false;
      for (var i = 0; i < remaining.length; i++) {
        final s = remaining[i];
        // tail→s.first: append; tail→s.last: append reversed;
        // head→s.last: prepend; head→s.first: prepend reversed.
        final cands = <(double, bool, bool)>[
          (gap(tail, s.first), true, false),
          (gap(tail, s.last), true, true),
          (gap(head, s.last), false, false),
          (gap(head, s.first), false, true),
        ];
        for (final (d, at, rev) in cands) {
          if (d < best) {
            best = d;
            bestIdx = i;
            atTail = at;
            reverse = rev;
          }
        }
      }
      // Only extend across a (near-)shared node; a larger gap ends this run.
      if (bestIdx >= 0 && best <= _maxStitchGapMeters) {
        var s = remaining.removeAt(bestIdx);
        if (reverse) s = s.reversed.toList();
        if (atTail) {
          path.addAll(s);
        } else {
          path.insertAll(0, s);
        }
        grew = true;
      }
    }
    components.add(path);
  }

  double lengthMeters(List<LatLng> line) {
    var total = 0.0;
    for (var i = 1; i < line.length; i++) {
      total += gap(line[i - 1], line[i]);
    }
    return total;
  }

  components.sort((a, b) => lengthMeters(b).compareTo(lengthMeters(a)));
  return components;
}

/// Drops a ring's repeated closing vertex (first == last) if present.
void _dropClosing(List<LatLng> ring) {
  if (ring.length >= 2 &&
      ring.first.latitude == ring.last.latitude &&
      ring.first.longitude == ring.last.longitude) {
    ring.removeLast();
  }
}
