import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'overpass_client.dart';

/// Administrative **areas**, fetched once from Overpass over a chosen bounding
/// box and stored offline (the `borders` layer type).
///
/// ## Why whole relations
///
/// This used to be a global, viewport-following overlay that asked for member
/// ways clipped to the view (`way(r)(bbox)`). That can only ever draw loose
/// **lines**: a clipped way has no interior side, so nothing can be filled, and
/// nothing can be named. Getting a fillable area means fetching the *whole*
/// relation with `out geom;` and cutting it down on the device — which is what
/// `geo/border_areas.dart` does, keeping only the part inside the box.
///
/// ## What the measurements say
///
/// Live Overpass, `rel["boundary"="administrative"]["admin_level"=L](bbox);
/// out geom;`:
///
/// | level | box | result |
/// |---|---|---|
/// | cities (8) | 28 × 37 km, Munich | 54 areas, 34 579 pts, 1.9 MB / 2 s |
/// | counties (6) | 55 km, Munich | 8 areas, 38 853 pts, 2.0 MB / 2 s |
/// | districts (9) | 15 km, Munich | 25 areas, 9 312 pts, 0.6 MB / 2.8 s |
/// | states (4) | 110 km, Munich | 1 area, 119 238 pts, 6.2 MB / 3.6 s |
/// | states (4) | 511 km, Bavaria | **504** on two instances |
/// | countries (2) | 20 km on the DE/AT border | 3 areas, 334 196 pts, 17.3 MB |
/// | suburbs (10) | 15 km, Munich | **504** on all three, three attempts |
///
/// Two things follow. The cost is driven by the *boundaries you touch*, not the
/// box — a 20 km box on a national border downloads whole countries — so each
/// level carries its own [BorderLevel.maxDiagonalMeters]. And level 10 is
/// simply not obtainable from the public instances in a dense city, so its copy
/// says so rather than pretending a smaller box would help.

/// One administrative level (an OSM `admin_level`) a borders layer can hold.
///
/// The `admin_level`→meaning mapping follows the common OSM scheme, which holds
/// well across most countries (exact sub-levels vary by country).
class BorderLevel {
  const BorderLevel({
    required this.key,
    required this.label,
    required this.adminLevel,
    required this.blurb,
    required this.maxDiagonalMeters,
  });

  /// Stable identifier used by the level picker.
  final String key;
  final String label;

  /// OSM `admin_level` value, as a string — what goes into the query and what
  /// is persisted on `Layers.borderLevel` / `BorderSets.adminLevel`.
  final String adminLevel;

  /// What this level actually means, plus what it costs. Shown in the picker
  /// and in the import dialog, because "Countries" reads cheap and is the most
  /// expensive thing here.
  final String blurb;

  /// The widest box this level may be imported over, and (at half of it) where
  /// the import dialog starts warning. Measured, not guessed — see the table in
  /// this file's header.
  final double maxDiagonalMeters;

  double get warnDiagonalMeters => maxDiagonalMeters / 2;
}

/// The fixed catalogue of levels, coarse to fine.
const borderLevels = <BorderLevel>[
  BorderLevel(
    key: 'country',
    label: 'Countries',
    adminLevel: '2',
    blurb: 'National borders. A whole country comes down for any box that '
        'touches it — 17 MB on the German/Austrian border — so keep it small.',
    maxDiagonalMeters: 60000,
  ),
  BorderLevel(
    key: 'state',
    label: 'States / provinces',
    adminLevel: '4',
    blurb: 'Federal states, provinces, regions. One state is ~120 000 points; '
        'a box spanning several is refused rather than left to time out.',
    maxDiagonalMeters: 150000,
  ),
  BorderLevel(
    key: 'county',
    label: 'Counties / districts',
    adminLevel: '6',
    blurb: 'Counties, Landkreise, départements — the tier above municipalities.',
    maxDiagonalMeters: 120000,
  ),
  BorderLevel(
    key: 'city',
    label: 'Cities / municipalities',
    adminLevel: '8',
    blurb: 'Towns and municipalities: the tier that tiles the map completely. '
        'Munich and its 54 neighbours import in about two seconds.',
    maxDiagonalMeters: 80000,
  ),
  BorderLevel(
    key: 'district',
    label: 'City districts',
    adminLevel: '9',
    blurb: 'Boroughs / Stadtbezirke inside a city. Cheap, but only mapped in '
        'cities that use them.',
    maxDiagonalMeters: 80000,
  ),
  BorderLevel(
    key: 'suburb',
    label: 'Suburbs / neighbourhoods',
    adminLevel: '10',
    blurb: 'Neighbourhoods. The public Overpass instances refused every attempt '
        'at this level over Munich — expect it to fail in a dense city.',
    maxDiagonalMeters: 60000,
  ),
];

BorderLevel? borderLevelByAdminLevel(String? adminLevel) =>
    borderLevels.where((l) => l.adminLevel == adminLevel).firstOrNull;

BorderLevel? borderLevelByKey(String key) =>
    borderLevels.where((l) => l.key == key).firstOrNull;

// --- Caps -------------------------------------------------------------------

/// Bodies above this are refused rather than decoded. A country-level box is
/// legitimately 17 MB, so this leaves room for a bad one without pretending a
/// 100 MB response could be parsed on a phone.
const int borderMaxResponseBytes = 48 * 1024 * 1024;

/// Overpass's own budget for the query, and how long we wait for it. Border
/// relations are big but not slow (the worst measured was 5.6 s), so this is
/// generous rather than tuned.
const Duration borderQueryTimeout = Duration(seconds: 120);
const Duration borderRequestTimeout = Duration(seconds: 150);

const Distance _distance = Distance(calculator: Haversine());

/// The diagonal of a box in metres (NaN when it isn't a usable box).
double borderBoxDiagonalMeters(
    double south, double west, double north, double east) {
  final d = _distance.as(
      LengthUnit.Meter, LatLng(south, west), LatLng(north, east));
  return d.isFinite ? d : double.nan;
}

// --- Query ------------------------------------------------------------------

/// Every administrative relation of [adminLevel] overlapping the bbox, **with
/// its full geometry**.
///
/// `out geom;` on the relations themselves gives each member way's points
/// inline, which is what ring assembly needs; there is no `convert`, no second
/// pass over ways, and no regex — every filter is an equality so Overpass can
/// use its tag index.
String buildBorderAreasQuery({
  required double south,
  required double west,
  required double north,
  required double east,
  required String adminLevel,
}) {
  final bbox = '($south,$west,$north,$east)';
  return '[out:json][timeout:${borderQueryTimeout.inSeconds}];'
      'rel["boundary"="administrative"]["admin_level"="$adminLevel"]$bbox;'
      'out geom;';
}

// --- Result model (drift-free, isolate-safe) --------------------------------

/// One member way of a relation, as Overpass returns it: its id, its role
/// (`outer`/`inner`), and its points.
class BorderWay {
  const BorderWay({
    required this.id,
    required this.role,
    required this.points,
  });

  final int id;

  /// `outer`, `inner`, or '' when the relation didn't say (treated as outer).
  final String role;
  final List<LatLng> points;
}

/// One administrative relation, straight from the API and not yet assembled.
class BorderRelationData {
  const BorderRelationData({
    required this.osmId,
    required this.ways,
    this.name,
  });

  final int osmId;
  final String? name;

  /// The relation's way members, in the order given. Assembly does not rely on
  /// that order — see `geo/border_areas.dart`.
  final List<BorderWay> ways;

  /// The member way ids, which is all adjacency needs.
  List<int> get wayIds => [for (final w in ways) w.id];
}

// --- Parsing ----------------------------------------------------------------

String? _tag(Map tags, String key) {
  final v = tags[key];
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// A JSON number, or null when missing or the wrong type. `as num?` would
/// *throw* on a String, breaking the never-throws contract.
double? _num(dynamic v) {
  if (v is! num) return null;
  final d = v.toDouble();
  return d.isFinite ? d : null;
}

/// Extracts a way's points from either shape Overpass emits: the `out geom`
/// array `[{"lat":..,"lon":..}]`, or a GeoJSON `LineString`
/// `{"coordinates":[[lon,lat],…]}`.
List<LatLng> _points(dynamic geom) {
  final pts = <LatLng>[];
  void add(double? lat, double? lon) {
    if (lat != null && lon != null) pts.add(LatLng(lat, lon));
  }

  if (geom is List) {
    for (final g in geom) {
      if (g is Map) add(_num(g['lat']), _num(g['lon']));
    }
  } else if (geom is Map && geom['coordinates'] is List) {
    for (final c in geom['coordinates'] as List) {
      if (c is List && c.length >= 2) add(_num(c[1]), _num(c[0])); // [lon,lat]
    }
  }
  return pts;
}

/// Parses an Overpass `out geom` response into relations with their member
/// ways.
///
/// Never throws. Returns **null** when the body could not be understood at all,
/// so a malformed response stays distinguishable from a genuinely empty area —
/// the distinction the old overlay conflated into "nothing here".
List<BorderRelationData>? parseBorderRelations(String body) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  final elements = decoded['elements'];
  if (elements is! List) return null;

  final out = <BorderRelationData>[];
  for (final e in elements) {
    if (e is! Map || e['type'] != 'relation') continue;
    final id = _num(e['id'])?.toInt();
    if (id == null) continue;
    final tags = e['tags'];
    final members = e['members'];
    final ways = <BorderWay>[];
    if (members is List) {
      for (final m in members) {
        if (m is! Map || m['type'] != 'way') continue;
        final wid = _num(m['ref'])?.toInt();
        if (wid == null) continue;
        final pts = _points(m['geometry']);
        if (pts.length < 2) continue;
        final role = m['role'];
        ways.add(BorderWay(
          id: wid,
          role: role is String ? role : '',
          points: pts,
        ));
      }
    }
    // A relation with no usable geometry is dropped rather than stored as an
    // empty area — there would be nothing to draw and nothing to name.
    if (ways.isEmpty) continue;
    out.add(BorderRelationData(
      osmId: id,
      name: tags is Map ? _tag(tags, 'name') : null,
      ways: ways,
    ));
  }
  return out;
}

// --- Network ----------------------------------------------------------------

/// Fetches every administrative area of [adminLevel] overlapping the bbox.
///
/// Returns the relations (empty = none there), or a failure carrying a message
/// to show. Never throws.
Future<OverpassOutcome<List<BorderRelationData>>> fetchBorderAreas({
  required double south,
  required double west,
  required double north,
  required double east,
  required String adminLevel,
  http.Client? client,
  String? preferEndpoint,
  OverpassProgressCallback? onProgress,
}) {
  return overpassPost(
    buildBorderAreasQuery(
      south: south,
      west: west,
      north: north,
      east: east,
      adminLevel: adminLevel,
    ),
    client: client,
    timeout: borderRequestTimeout,
    maxBytes: borderMaxResponseBytes,
    oversizeMessage: 'That area returns too much data — the whole of every '
        'boundary it touches has to come down. Pick a smaller box, or a finer '
        'level.',
    preferEndpoint: preferEndpoint,
    onProgress: onProgress,
    parse: parseBorderRelations,
  );
}
