import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geo_import.dart';
import 'request_pacer.dart';

/// Looks up named OSM features (places, rivers, roads, parks, boundaries…) by
/// name via OpenStreetMap's Nominatim geocoder, returning their geometry so a
/// feature can be imported into a freehand layer — areas as a freehand **area**,
/// lines (rivers, railways, coastlines…) as a freehand **line**. Pure-ish: the
/// HTTP call is the only side effect, and the parsing is split out for testing.

/// One geocoder hit that carries importable geometry. [areas] are polygon outer
/// rings (a multipolygon yields more than one, each stripped of its repeated
/// closing vertex); [lines] are poly-lines (a multilinestring yields more than
/// one). A hit may have either or both.
class PlaceResult {
  const PlaceResult({
    required this.displayName,
    required this.areas,
    required this.lines,
    this.category,
    this.type,
  });

  /// Full human label, e.g. "Munich, Bavaria, Germany".
  final String displayName;

  /// Outer rings of the feature's polygon(s).
  final List<List<LatLng>> areas;

  /// Poly-lines of the feature's line geometry.
  final List<List<LatLng>> lines;

  /// OSM `class`/`category`, e.g. `boundary`, `waterway`, `highway`, `leisure`.
  final String? category;

  /// OSM `type`, e.g. `administrative`, `river`, `park`.
  final String? type;

  /// Which freehand layer this feature naturally imports into. Areas win when
  /// the feature has both (a river is a line even if a tiny area sneaks in).
  GeometryKind get dominantKind =>
      areas.isNotEmpty ? GeometryKind.area : GeometryKind.line;

  /// A short name for layers/objects: the first comma-separated segment.
  String get shortName => displayName.split(',').first.trim();

  /// Total vertices across all geometry (shown so the user knows how heavy the
  /// import will be).
  int get pointCount =>
      areas.fold(0, (n, r) => n + r.length) +
      lines.fold(0, (n, r) => n + r.length);
}

/// Caps how many candidates Nominatim returns.
const int placeSearchLimit = 12;

/// Builds the Nominatim search URL for [query]. Public for testing.
///
/// `polygon_geojson=1` asks for boundary geometry; `polygon_threshold`
/// simplifies it (in degrees, ~0.0005° ≈ 55 m) so a city border imports as a
/// few hundred points rather than thousands.
Uri buildPlaceSearchUri(String query) =>
    Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'polygon_geojson': '1',
      'polygon_threshold': '0.0005',
      'limit': '$placeSearchLimit',
      'addressdetails': '0',
    });

/// Parses a Nominatim `jsonv2` response, keeping hits that carry line or area
/// geometry (points are dropped). Returns empty on any structural surprise
/// rather than throwing.
List<PlaceResult> parsePlaceSearchResponse(String body) {
  final List<PlaceResult> out = [];
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return out;
  }
  if (decoded is! List) return out;
  for (final e in decoded) {
    if (e is! Map) continue;
    final geojson = e['geojson'];
    if (geojson is! Map) continue;
    // Reuse the generic GeoJSON parser, which extracts both line and area
    // features from (Multi)LineString / (Multi)Polygon.
    final feats = parseGeoJsonGeometry(jsonEncode(geojson));
    final areas = [
      for (final f in feats)
        if (f.kind == GeometryKind.area) f.coords,
    ];
    final lines = [
      for (final f in feats)
        if (f.kind == GeometryKind.line) f.coords,
    ];
    if (areas.isEmpty && lines.isEmpty) continue;
    out.add(PlaceResult(
      displayName: (e['display_name'] as String?)?.trim() ?? 'Unnamed feature',
      areas: areas,
      lines: lines,
      category: e['category'] as String?,
      type: e['type'] as String?,
    ));
  }
  return out;
}

/// Results already fetched this session, so a repeated search costs nothing.
///
/// Nominatim's usage policy requires it — "Results must be cached on your
/// side" — and warns that "clients sending repeatedly the same query may be
/// classified as faulty and blocked". Searching the same name twice is
/// ordinary (type it, look, cancel, reopen, type it again), so this is the
/// difference between normal use and the pattern that gets clients blocked.
///
/// Only successful lookups are stored: a failure is about the network, not
/// about the query, and must not be remembered as an answer.
final QueryCache<List<PlaceResult>> placeSearchCache =
    QueryCache<List<PlaceResult>>();

/// Searches Nominatim for [query]. Returns the geometry-bearing matches on
/// success (possibly empty), or **null** on any network/HTTP/timeout error.
/// Never throws.
///
/// Answers from [placeSearchCache] when it can, and otherwise queues behind
/// [nominatimPacer] so the app cannot exceed the published one-request-per-
/// second ceiling however fast the user taps Search.
Future<List<PlaceResult>?> searchPlaces(
  String query, {
  http.Client? client,
}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];

  final cached = placeSearchCache.get(q);
  if (cached != null) return cached;

  final owned = client == null;
  final c = client ?? http.Client();
  try {
    final resp = await nominatimPacer.run(
      () => c.get(
        buildPlaceSearchUri(q),
        headers: const {
          'User-Agent': 'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)',
        },
      ).timeout(const Duration(seconds: 30)),
    );
    if (resp.statusCode != 200) return null;
    final parsed = parsePlaceSearchResponse(resp.body);
    placeSearchCache.put(q, parsed);
    return parsed;
  } catch (_) {
    return null;
  } finally {
    if (owned) c.close();
  }
}
