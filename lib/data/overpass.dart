import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// A toggleable map-POI category (OSMAnd-style). Each maps to one OSM tag and
/// occupies one [bit] in the packed `AppSettings.poiCategories` mask.
class PoiCategory {
  const PoiCategory({
    required this.key,
    required this.label,
    required this.tagKey,
    required this.tagValue,
    required this.bit,
    this.seedable = false,
  });

  /// Stable identifier (also used to pick the marker icon in the UI).
  final String key;
  final String label;
  final String tagKey;
  final String tagValue;

  /// Single-bit mask for this category in the persisted set.
  final int bit;

  /// Whether this category should be offered when seeding circle/subspace
  /// layers from nearby POIs. Only named places (cafés, hospitals, …) are
  /// useful there; ubiquitous unnamed furniture (benches, bins, …) is not.
  final bool seedable;
}

/// The fixed catalogue of POI categories. Bits are positional, so the order
/// here is part of the persisted format — append new entries, never reorder.
const poiCategories = <PoiCategory>[
  PoiCategory(
      key: 'bench',
      label: 'Benches',
      tagKey: 'amenity',
      tagValue: 'bench',
      bit: 1 << 0),
  PoiCategory(
      key: 'post_box',
      label: 'Post boxes',
      tagKey: 'amenity',
      tagValue: 'post_box',
      bit: 1 << 1),
  PoiCategory(
      key: 'drinking_water',
      label: 'Drinking water',
      tagKey: 'amenity',
      tagValue: 'drinking_water',
      bit: 1 << 2),
  PoiCategory(
      key: 'toilets',
      label: 'Toilets',
      tagKey: 'amenity',
      tagValue: 'toilets',
      bit: 1 << 3),
  PoiCategory(
      key: 'waste_basket',
      label: 'Waste baskets',
      tagKey: 'amenity',
      tagValue: 'waste_basket',
      bit: 1 << 4),
  PoiCategory(
      key: 'cafe',
      label: 'Cafés',
      tagKey: 'amenity',
      tagValue: 'cafe',
      bit: 1 << 5,
      seedable: true),
  PoiCategory(
      key: 'restaurant',
      label: 'Restaurants',
      tagKey: 'amenity',
      tagValue: 'restaurant',
      bit: 1 << 6,
      seedable: true),
  PoiCategory(
      key: 'pharmacy',
      label: 'Pharmacies',
      tagKey: 'amenity',
      tagValue: 'pharmacy',
      bit: 1 << 7,
      seedable: true),
  PoiCategory(
      key: 'library',
      label: 'Libraries',
      tagKey: 'amenity',
      tagValue: 'library',
      bit: 1 << 8,
      seedable: true),
  PoiCategory(
      key: 'aquarium',
      label: 'Aquariums',
      tagKey: 'tourism',
      tagValue: 'aquarium',
      bit: 1 << 9,
      seedable: true),
  PoiCategory(
      key: 'zoo',
      label: 'Zoos',
      tagKey: 'tourism',
      tagValue: 'zoo',
      bit: 1 << 10,
      seedable: true),
  PoiCategory(
      key: 'golf_course',
      label: 'Golf courses',
      tagKey: 'leisure',
      tagValue: 'golf_course',
      bit: 1 << 11,
      seedable: true),
  PoiCategory(
      key: 'consulate',
      label: 'Foreign consulates',
      tagKey: 'office',
      tagValue: 'diplomatic',
      bit: 1 << 12,
      seedable: true),
  PoiCategory(
      key: 'transit_station',
      label: 'Transit stations',
      tagKey: 'public_transport',
      tagValue: 'station',
      bit: 1 << 13,
      seedable: true),
  PoiCategory(
      key: 'hospital',
      label: 'Hospitals',
      tagKey: 'amenity',
      tagValue: 'hospital',
      bit: 1 << 14,
      seedable: true),
  PoiCategory(
      key: 'cinema',
      label: 'Movie theatres',
      tagKey: 'amenity',
      tagValue: 'cinema',
      bit: 1 << 15,
      seedable: true),
];

/// The categories offered when seeding circle/subspace layers — named places
/// only. See [PoiCategory.seedable].
final seedablePoiCategories =
    poiCategories.where((c) => c.seedable).toList(growable: false);

/// The categories enabled in [mask].
Set<PoiCategory> poiCategoriesFromMask(int mask) =>
    {for (final c in poiCategories) if (mask & c.bit != 0) c};

/// [mask] with [c] turned on/off.
int poiMaskWith(int mask, PoiCategory c, bool on) =>
    on ? (mask | c.bit) : (mask & ~c.bit);

/// One resolved POI: a position, the [categoryKey] that matched it, and the
/// OSM `name` tag when present (used to label imported objects).
class PoiResult {
  const PoiResult({
    required this.lat,
    required this.lng,
    required this.categoryKey,
    this.name,
  });

  final double lat;
  final double lng;
  final String categoryKey;
  final String? name;
}

/// Encodes [pois] to a compact JSON string for the persistent overlay cache.
String encodePoiResults(Iterable<PoiResult> pois) => jsonEncode([
      for (final p in pois)
        {
          'lat': p.lat,
          'lng': p.lng,
          'k': p.categoryKey,
          if (p.name != null) 'n': p.name,
        },
    ]);

/// Decodes the string produced by [encodePoiResults]. Returns empty on any
/// structural surprise rather than throwing.
List<PoiResult> decodePoiResults(String json) {
  final List<PoiResult> out = [];
  final dynamic decoded;
  try {
    decoded = jsonDecode(json);
  } catch (_) {
    return out;
  }
  if (decoded is! List) return out;
  for (final e in decoded) {
    if (e is! Map) continue;
    final lat = (e['lat'] as num?)?.toDouble();
    final lng = (e['lng'] as num?)?.toDouble();
    final k = e['k'];
    final n = e['n'];
    if (lat == null || lng == null || k is! String) continue;
    if (!lat.isFinite || !lng.isFinite) continue;
    out.add(PoiResult(
      lat: lat,
      lng: lng,
      categoryKey: k,
      name: n is String ? n : null,
    ));
  }
  return out;
}

/// Caps how many elements Overpass returns, to respect usage limits and keep
/// the marker layer light.
const int overpassResultCap = 400;

/// Builds the Overpass QL for [categories] within the bbox. Public for testing.
String buildOverpassQuery({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<PoiCategory> categories,
}) {
  final bbox = '($south,$west,$north,$east)';
  final parts = categories
      .map((c) => 'nwr["${c.tagKey}"="${c.tagValue}"]$bbox;')
      .join();
  // `out center` gives ways/relations a single representative point.
  return '[out:json][timeout:25];($parts);out center $overpassResultCap;';
}

/// Parses an Overpass JSON response into [PoiResult]s, tagging each with the
/// matching category from [categories]. Public for testing. Returns empty on
/// any structural surprise rather than throwing.
List<PoiResult> parseOverpassResponse(
  String body,
  Iterable<PoiCategory> categories,
) {
  final List<PoiResult> out = [];
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
    double? lat = (e['lat'] as num?)?.toDouble();
    double? lng = (e['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      final center = e['center'];
      if (center is Map) {
        lat = (center['lat'] as num?)?.toDouble();
        lng = (center['lon'] as num?)?.toDouble();
      }
    }
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) continue;

    final tags = e['tags'];
    PoiCategory? matched;
    String? name;
    if (tags is Map) {
      for (final c in categories) {
        if (tags[c.tagKey] == c.tagValue) {
          matched = c;
          break;
        }
      }
      final n = tags['name'];
      if (n is String && n.trim().isNotEmpty) name = n.trim();
    }
    if (matched == null) continue; // unknown element -> skip
    out.add(PoiResult(
        lat: lat, lng: lng, categoryKey: matched.key, name: name));
  }
  return out;
}

/// Keeps the POIs in [pois] within [radiusMeters] of (centerLat, centerLng),
/// sorted nearest-first and capped to [cap]. Pure and testable; the cap keeps a
/// seeded Voronoi cell (an intersection of N−1 bisectors) and bulk-circle import
/// responsive when a dense category returns hundreds of hits.
List<PoiResult> poisWithinRadius(
  double centerLat,
  double centerLng,
  double radiusMeters,
  Iterable<PoiResult> pois, {
  int cap = 60,
}) {
  final scored = <MapEntry<double, PoiResult>>[];
  for (final p in pois) {
    final d = _haversineMeters(centerLat, centerLng, p.lat, p.lng);
    if (d <= radiusMeters) scored.add(MapEntry(d, p));
  }
  scored.sort((a, b) => a.key.compareTo(b.key));
  return [for (final e in scored.take(cap)) e.value];
}

double _haversineMeters(
    double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Queries the Overpass API for the enabled [categories] within the bbox.
/// Zoom-gating/debouncing are the caller's responsibility.
///
/// Returns the POIs on success (an empty list means "none here"), or **null**
/// on any network/HTTP/timeout error — so the caller can keep the previous
/// markers instead of clearing them when a request is rate-limited or fails.
/// Never throws.
Future<List<PoiResult>?> fetchPois({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<PoiCategory> categories,
  http.Client? client,
}) async {
  final cats = categories.toList();
  if (cats.isEmpty) return const [];
  final query = buildOverpassQuery(
    south: south,
    west: west,
    north: north,
    east: east,
    categories: cats,
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
    if (resp.statusCode != 200) return null; // rate-limited / server error
    return parseOverpassResponse(resp.body, cats);
  } catch (_) {
    return null; // network/timeout
  } finally {
    if (owned) c.close();
  }
}
