import 'dart:convert';

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
  });

  /// Stable identifier (also used to pick the marker icon in the UI).
  final String key;
  final String label;
  final String tagKey;
  final String tagValue;

  /// Single-bit mask for this category in the persisted set.
  final int bit;
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
      bit: 1 << 5),
  PoiCategory(
      key: 'restaurant',
      label: 'Restaurants',
      tagKey: 'amenity',
      tagValue: 'restaurant',
      bit: 1 << 6),
  PoiCategory(
      key: 'pharmacy',
      label: 'Pharmacies',
      tagKey: 'amenity',
      tagValue: 'pharmacy',
      bit: 1 << 7),
];

/// The categories enabled in [mask].
Set<PoiCategory> poiCategoriesFromMask(int mask) =>
    {for (final c in poiCategories) if (mask & c.bit != 0) c};

/// [mask] with [c] turned on/off.
int poiMaskWith(int mask, PoiCategory c, bool on) =>
    on ? (mask | c.bit) : (mask & ~c.bit);

/// One resolved POI: a position and the [categoryKey] that matched it.
class PoiResult {
  const PoiResult({
    required this.lat,
    required this.lng,
    required this.categoryKey,
  });

  final double lat;
  final double lng;
  final String categoryKey;
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
    if (tags is Map) {
      for (final c in categories) {
        if (tags[c.tagKey] == c.tagValue) {
          matched = c;
          break;
        }
      }
    }
    if (matched == null) continue; // unknown element -> skip
    out.add(PoiResult(lat: lat, lng: lng, categoryKey: matched.key));
  }
  return out;
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
