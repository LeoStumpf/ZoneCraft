import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geo_import.dart';

/// Looks up named places (cities, districts, countries, parks…) by name via
/// OpenStreetMap's Nominatim geocoder, returning their **boundary polygons** so
/// an administrative area can be imported as a freehand area. Pure-ish: the HTTP
/// call is the only side effect, and the parsing is split out for testing.

/// One geocoder hit that carries an importable polygon. [rings] are the outer
/// rings (a multipolygon yields more than one), each already stripped of its
/// repeated closing vertex.
class PlaceResult {
  const PlaceResult({
    required this.displayName,
    required this.rings,
    this.category,
    this.type,
  });

  /// Full human label, e.g. "Munich, Bavaria, Germany".
  final String displayName;

  /// Outer rings of the place's polygon(s).
  final List<List<LatLng>> rings;

  /// OSM `class`/`category`, e.g. `boundary`, `place`, `leisure`.
  final String? category;

  /// OSM `type`, e.g. `administrative`, `city`, `park`.
  final String? type;

  /// A short name for layers/objects: the first comma-separated segment.
  String get shortName => displayName.split(',').first.trim();

  /// Total vertices across all rings (shown so the user knows how heavy the
  /// import will be).
  int get pointCount => rings.fold(0, (n, r) => n + r.length);
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

/// Parses a Nominatim `jsonv2` response, keeping only hits with polygon
/// geometry. Returns empty on any structural surprise rather than throwing.
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
    // Reuse the generic GeoJSON parser to extract polygon outer rings.
    final feats = parseGeoJsonGeometry(jsonEncode(geojson));
    final rings = [
      for (final f in feats)
        if (f.kind == GeometryKind.area) f.coords,
    ];
    if (rings.isEmpty) continue;
    out.add(PlaceResult(
      displayName: (e['display_name'] as String?)?.trim() ?? 'Unnamed place',
      rings: rings,
      category: e['category'] as String?,
      type: e['type'] as String?,
    ));
  }
  return out;
}

/// Searches Nominatim for [query]. Returns the polygon-bearing matches on
/// success (possibly empty), or **null** on any network/HTTP/timeout error.
/// Never throws.
Future<List<PlaceResult>?> searchPlaces(
  String query, {
  http.Client? client,
}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final owned = client == null;
  final c = client ?? http.Client();
  try {
    final resp = await c.get(
      buildPlaceSearchUri(q),
      headers: const {
        'User-Agent': 'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)',
      },
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return null;
    return parsePlaceSearchResponse(resp.body);
  } catch (_) {
    return null;
  } finally {
    if (owned) c.close();
  }
}
