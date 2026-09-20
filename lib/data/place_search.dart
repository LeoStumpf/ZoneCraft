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

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../app_info.dart';
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
    required this.center,
    required this.areas,
    required this.lines,
    this.category,
    this.type,
  });

  /// Full human label, e.g. "Munich, Bavaria, Germany".
  final String displayName;

  /// Nominatim's own point for the hit. Every result has one, including the
  /// ones with no geometry at all — which is what makes "Go to place" able to
  /// find a landmark or a street address, not just an administrative area.
  final LatLng center;

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

  /// Whether there is a shape to import. Point-only hits are perfectly good
  /// to *navigate* to and impossible to import, so the feature-import dialog
  /// filters on this while "Go to place" does not.
  bool get hasGeometry => pointCount > 0;
}

/// Caps how many candidates Nominatim returns.
const int placeSearchLimit = 12;

/// The geocoder the app uses unless someone points it elsewhere.
const String defaultNominatimHost = 'nominatim.openstreetmap.org';

/// A user-chosen geocoder host, e.g. `nominatim.example.org`. Null — the normal
/// case — means [defaultNominatimHost].
///
/// Process-wide rather than threaded through the search dialog, matching
/// `overpassEndpointOverride`: it is configuration, and every search wants the
/// same answer. `map_screen` pushes the stored value in when settings change.
///
/// The policy is the reason it can be changed at all: "apps must make sure that
/// they can switch the service at our request at any time", and a host only a
/// new APK can move never reaches an install that stops updating.
String? nominatimHostOverride;

/// Builds the Nominatim search URL for [query]. Public for testing.
///
/// `polygon_geojson=1` asks for boundary geometry; `polygon_threshold`
/// simplifies it (in degrees, ~0.0005° ≈ 55 m) so a city border imports as a
/// few hundred points rather than thousands.
///
/// [host] overrides [defaultNominatimHost]. The usage policy asks that "apps
/// must make sure that they can switch the service at our request at any time",
/// and a host that only a new APK can change reaches nobody who does not
/// update — so the address is data, not a literal.
Uri buildPlaceSearchUri(String query, {String? host}) =>
    Uri.https(_host(host), '/search', {
      'q': query,
      'format': 'jsonv2',
      'polygon_geojson': '1',
      'polygon_threshold': '0.0005',
      'limit': '$placeSearchLimit',
      'addressdetails': '0',
    });

/// A blank or whitespace override means "the default", not "no host".
String _host(String? override) {
  for (final candidate in [override, nominatimHostOverride]) {
    final h = candidate?.trim();
    if (h != null && h.isNotEmpty) return h;
  }
  return defaultNominatimHost;
}

/// Parses a Nominatim `jsonv2` response. Returns empty on any structural
/// surprise rather than throwing.
///
/// Point-only hits are **kept**, with empty [PlaceResult.areas]/[lines] and a
/// [PlaceResult.center]. They used to be dropped here, because the only caller
/// imported geometry and a point has none — but that also meant a search for a
/// landmark or a street address came back empty, which is most of what anyone
/// types. Callers that need a shape filter on [PlaceResult.hasGeometry];
/// dropping them here would have put the same filter inside the shared cache.
List<PlaceResult> parsePlaceSearchResponse(String body) {
  final List<PlaceResult> out = [];
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  // Nominatim answers with an error page under load; that is data, not a bug.
  // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return out;
  }
  if (decoded is! List) return out;
  for (final e in decoded) {
    if (e is! Map) continue;
    final geojson = e['geojson'];
    // Reuse the generic GeoJSON parser, which extracts both line and area
    // features from (Multi)LineString / (Multi)Polygon.
    final feats = geojson is Map
        ? parseGeoJsonGeometry(jsonEncode(geojson))
        : const <ImportedFeature>[];
    final areas = [
      for (final f in feats)
        if (f.kind == GeometryKind.area) f.coords,
    ];
    final lines = [
      for (final f in feats)
        if (f.kind == GeometryKind.line) f.coords,
    ];
    // Nominatim sends lat/lon as strings on every hit; the geometry is the
    // fallback for anything that does not, so a result is dropped only when
    // there is no way at all to say where it is.
    final center = _pointOf(e['lat'], e['lon']) ?? _centerOfGeometry(areas, lines);
    if (center == null) continue;

    out.add(PlaceResult(
      displayName: (e['display_name'] as String?)?.trim() ?? 'Unnamed feature',
      center: center,
      areas: areas,
      lines: lines,
      category: e['category'] as String?,
      type: e['type'] as String?,
    ));
  }
  return out;
}

LatLng? _pointOf(Object? lat, Object? lng) {
  final a = double.tryParse('$lat');
  final b = double.tryParse('$lng');
  if (a == null || b == null || !a.isFinite || !b.isFinite) return null;
  return LatLng(a, b);
}

/// The middle of a feature's bounding box.
///
/// Not a centroid: for a ring this is cheaper, and for an L-shaped boundary the
/// true centroid can fall outside the shape entirely, which is a worse place to
/// put the camera than the middle of the box.
LatLng? _centerOfGeometry(
  List<List<LatLng>> areas,
  List<List<LatLng>> lines,
) {
  double? minLat, maxLat, minLng, maxLng;
  for (final ring in [...areas, ...lines]) {
    for (final p in ring) {
      minLat = minLat == null || p.latitude < minLat ? p.latitude : minLat;
      maxLat = maxLat == null || p.latitude > maxLat ? p.latitude : maxLat;
      minLng = minLng == null || p.longitude < minLng ? p.longitude : minLng;
      maxLng = maxLng == null || p.longitude > maxLng ? p.longitude : maxLng;
    }
  }
  if (minLat == null) return null;
  return LatLng((minLat + maxLat!) / 2, (minLng! + maxLng!) / 2);
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
  String? host,
}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];

  // Keyed by host as well as query: two instances can legitimately disagree,
  // and a cached answer from the old one would outlive the switch.
  final key = '${_host(host)}\u0000$q';
  final cached = placeSearchCache.get(key);
  if (cached != null) return cached;

  final owned = client == null;
  final c = client ?? http.Client();
  try {
    final resp = await nominatimPacer.run(
      () => c.get(
        buildPlaceSearchUri(q, host: host),
        headers: const {'User-Agent': zoneCraftUserAgent},
      ).timeout(const Duration(seconds: 30)),
    );
    if (resp.statusCode != 200) return null;
    final parsed = parsePlaceSearchResponse(resp.body);
    placeSearchCache.put(key, parsed);
    return parsed;
  // Any network failure means the search simply has no answer to give.
  // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return null;
  } finally {
    if (owned) c.close();
  }
}
