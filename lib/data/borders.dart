import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A toggleable administrative-boundary level (OSM `admin_level`). Each level is
/// shown only at/above its [minZoom] (coarser borders show when zoomed out;
/// finer ones only when zoomed in) and occupies one [bit] in the packed
/// `AppSettings.borderLevels` mask.
class BorderLevel {
  const BorderLevel({
    required this.key,
    required this.label,
    required this.adminLevel,
    required this.colorArgb,
    required this.minZoom,
    required this.bit,
  });

  final String key;
  final String label;

  /// OSM `admin_level` value, as a string (used in the Overpass query and to
  /// match returned segments).
  final String adminLevel;
  final int colorArgb;
  final double minZoom;
  final int bit;
}

/// The fixed catalogue of border levels. Bits are positional — append, never
/// reorder. The `admin_level`→meaning mapping follows the common OSM scheme,
/// which holds well across most countries (exact sub-levels vary by country).
const borderLevels = <BorderLevel>[
  // minZoom values are tuned so each level's query stays bounded (boundaries
  // get longer/denser the coarser the level, so coarse levels need a smaller
  // viewport before they're cheap enough to fetch).
  BorderLevel(
      key: 'country',
      label: 'Countries',
      adminLevel: '2',
      colorArgb: 0xFFD32F2F,
      minZoom: 6,
      bit: 1 << 0),
  BorderLevel(
      key: 'state',
      label: 'States / provinces',
      adminLevel: '4',
      colorArgb: 0xFFF57C00,
      minZoom: 9,
      bit: 1 << 1),
  BorderLevel(
      key: 'county',
      label: 'Counties / regions',
      adminLevel: '6',
      colorArgb: 0xFF7B1FA2,
      minZoom: 10,
      bit: 1 << 2),
  BorderLevel(
      key: 'city',
      label: 'Cities / municipalities',
      adminLevel: '8',
      colorArgb: 0xFF1976D2,
      minZoom: 12,
      bit: 1 << 3),
  BorderLevel(
      key: 'district',
      label: 'City districts',
      adminLevel: '9',
      colorArgb: 0xFF00897B,
      minZoom: 13,
      bit: 1 << 4),
  BorderLevel(
      key: 'suburb',
      label: 'Suburbs / neighbourhoods',
      adminLevel: '10',
      colorArgb: 0xFF558B2F,
      minZoom: 14,
      bit: 1 << 5),
];

/// The levels enabled in [mask].
Set<BorderLevel> borderLevelsFromMask(int mask) =>
    {for (final l in borderLevels) if (mask & l.bit != 0) l};

/// [mask] with [l] turned on/off.
int borderMaskWith(int mask, BorderLevel l, bool on) =>
    on ? (mask | l.bit) : (mask & ~l.bit);

/// One boundary segment: a polyline and the colour of its level.
class BorderLine {
  const BorderLine({required this.points, required this.colorArgb});

  final List<LatLng> points;
  final int colorArgb;
}

/// Builds the Overpass QL for [levels] within the bbox. For each level it picks
/// the admin-boundary relations overlapping the bbox, takes their member ways
/// clipped to the bbox (so only the segments in view are returned), and tags
/// them with the level via `convert`. Public for testing.
String buildBordersQuery({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<BorderLevel> levels,
}) {
  final bbox = '($south,$west,$north,$east)';
  final buf = StringBuffer('[out:json][timeout:25];');
  for (final l in levels) {
    buf.write('rel["boundary"="administrative"]["admin_level"="${l.adminLevel}"]$bbox;');
    buf.write('way(r)$bbox;');
    buf.write('convert way ::id=id(),::geom=geom(),lvl="${l.adminLevel}";');
    buf.write('out geom;');
  }
  return buf.toString();
}

/// Parses an Overpass response into [BorderLine]s, colouring each by the level
/// recorded in its `lvl` tag. Public for testing; returns empty on any
/// structural surprise rather than throwing.
List<BorderLine> parseBordersResponse(
  String body,
  Iterable<BorderLevel> levels,
) {
  final byLevel = {for (final l in levels) l.adminLevel: l};
  final List<BorderLine> out = [];
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return out;
  }
  if (decoded is! Map) return out;
  final elements = decoded['elements'];
  if (elements is! List) return out;

  for (final e in elements) {
    if (e is! Map) continue;
    final tags = e['tags'];
    final lvl = tags is Map ? tags['lvl'] : null;
    final level = byLevel[lvl];
    if (level == null) continue;

    final pts = _extractPoints(e['geometry']);
    if (pts.length >= 2) {
      out.add(BorderLine(points: pts, colorArgb: level.colorArgb));
    }
  }
  return out;
}

/// Extracts a polyline from either of the two shapes Overpass returns:
/// a GeoJSON `LineString` object `{"coordinates":[[lon,lat],...]}` (produced by
/// `convert ::geom=geom()`), or a plain `out geom` array `[{"lat":..,"lon":..}]`.
List<LatLng> _extractPoints(dynamic geom) {
  final pts = <LatLng>[];
  void add(num? lat, num? lon) {
    final la = lat?.toDouble();
    final lo = lon?.toDouble();
    if (la != null && lo != null && la.isFinite && lo.isFinite) {
      pts.add(LatLng(la, lo));
    }
  }

  if (geom is Map && geom['coordinates'] is List) {
    for (final c in geom['coordinates'] as List) {
      if (c is List && c.length >= 2) add(c[1] as num?, c[0] as num?); // [lon,lat]
    }
  } else if (geom is List) {
    for (final g in geom) {
      if (g is Map) add(g['lat'] as num?, g['lon'] as num?);
    }
  }
  return pts;
}

/// Queries Overpass for administrative borders of the enabled [levels] within
/// the bbox. Zoom-gating/debouncing are the caller's responsibility. Returns
/// the segments on success (empty = none here), or **null** on any
/// network/HTTP/timeout error so the caller can keep the previous borders.
/// Never throws.
Future<List<BorderLine>?> fetchBorders({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<BorderLevel> levels,
  http.Client? client,
}) async {
  final list = levels.toList();
  if (list.isEmpty) return const [];
  final query = buildBordersQuery(
    south: south,
    west: west,
    north: north,
    east: east,
    levels: list,
  );
  final owned = client == null;
  final c = client ?? http.Client();
  try {
    final resp = await c
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          headers: const {
            'User-Agent':
                'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return null;
    return parseBordersResponse(resp.body, list);
  } catch (_) {
    return null;
  } finally {
    if (owned) c.close();
  }
}
