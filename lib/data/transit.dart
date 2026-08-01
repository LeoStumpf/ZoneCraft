import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../geo/simplify.dart';
import 'geo_import.dart' show stitchComponents;

/// Public-transport routes and stops, fetched **once** from Overpass over a
/// chosen bounding box and then stored offline (the `transit` layer type).
///
/// Shape of the import, verified against the live API:
///
/// * **Pre-flight** — `rel[…](bbox); out tags qt <cap>;` returns ids + tags and
///   no geometry (~200 B/route), so the dialog can show exact per-mode counts
///   and discover offline/rate-limit *before* the multi-megabyte request.
/// * **Geometry** — `rel(id:…)->.r; .r out geom(bbox); node(r.r); out body qt;`
///   The bbox on `out geom` clips member ways to the box (the single biggest
///   payload lever). The second statement resolves stop **positions and names**,
///   which the relation's own node members do not reliably carry.
///
/// Two traps this file exists to encode:
///  1. `out geom(bbox)` puts **`null` placeholders** where a way leaves the box.
///     They must *split* the way into runs — dropping them would fabricate a
///     straight connector across the gap (the same class of bug documented on
///     [stitchComponents]).
///  2. `node(r.r)(bbox)` — recursing **and** bbox-filtering in one statement
///     makes the public instance time out (504). Recurse unfiltered and clip in
///     Dart; the node payload is small.

// --- Mode catalogue ---------------------------------------------------------

/// One transport mode: the OSM `route=` values folded into it, plus how it is
/// drawn when a route carries no `colour` tag of its own.
class TransitMode {
  const TransitMode({
    required this.key,
    required this.label,
    required this.routeValues,
    required this.colorArgb,
    required this.strokeWidth,
    required this.bit,
  });

  /// Stable identifier, persisted in `TransitRoutes.modeKey`.
  final String key;
  final String label;

  /// The OSM `route=` values that map to this mode.
  final List<String> routeValues;

  /// Fallback line colour when the route has no usable `colour` tag.
  final int colorArgb;
  final double strokeWidth;

  /// Positional bit for the persisted mode mask.
  final int bit;
}

/// The supported modes. **Bits are positional and persisted in
/// `TransitSets.modeMask` — append new entries, never reorder.**
const List<TransitMode> transitModes = [
  TransitMode(
    key: 'bus',
    label: 'Bus',
    routeValues: ['bus', 'trolleybus', 'share_taxi'],
    colorArgb: 0xFF1565C0,
    strokeWidth: 2.0,
    bit: 1 << 0,
  ),
  TransitMode(
    key: 'tram',
    label: 'Tram',
    routeValues: ['tram'],
    colorArgb: 0xFFD32F2F,
    strokeWidth: 2.5,
    bit: 1 << 1,
  ),
  TransitMode(
    key: 'subway',
    label: 'Subway',
    routeValues: ['subway'],
    colorArgb: 0xFF1B5E20,
    strokeWidth: 3.5,
    bit: 1 << 2,
  ),
  TransitMode(
    key: 'light_rail',
    label: 'Light rail',
    routeValues: ['light_rail'],
    colorArgb: 0xFF00897B,
    strokeWidth: 3.0,
    bit: 1 << 3,
  ),
  TransitMode(
    key: 'train',
    label: 'Train',
    routeValues: ['train'],
    colorArgb: 0xFF424242,
    strokeWidth: 3.5,
    bit: 1 << 4,
  ),
  TransitMode(
    key: 'monorail',
    label: 'Monorail',
    routeValues: ['monorail'],
    colorArgb: 0xFF6A1B9A,
    strokeWidth: 2.5,
    bit: 1 << 5,
  ),
  TransitMode(
    key: 'ferry',
    label: 'Ferry',
    routeValues: ['ferry'],
    colorArgb: 0xFF0288D1,
    strokeWidth: 2.5,
    bit: 1 << 6,
  ),
];

/// `route=` value → mode, built once from [transitModes].
final Map<String, TransitMode> _modeByRouteValue = {
  for (final m in transitModes)
    for (final v in m.routeValues) v: m,
};

/// Mode by its [TransitMode.key], or null.
TransitMode? transitModeByKey(String key) =>
    transitModes.where((m) => m.key == key).firstOrNull;

Set<TransitMode> transitModesFromMask(int mask) =>
    {for (final m in transitModes) if (mask & m.bit != 0) m};

int transitMaskWith(int mask, TransitMode m, bool on) =>
    on ? (mask | m.bit) : (mask & ~m.bit);

int transitMaskOf(Iterable<TransitMode> modes) =>
    modes.fold(0, (acc, m) => acc | m.bit);

// --- Result models (drift-free, isolate-safe) --------------------------------

/// A route as the pre-flight sees it: identity and tags, no geometry.
class TransitRouteHead {
  const TransitRouteHead({
    required this.osmId,
    required this.modeKey,
    this.ref,
    this.name,
    this.operatorName,
    this.colourHex,
  });

  final int osmId;
  final String modeKey;
  final String? ref;
  final String? name;
  final String? operatorName;
  final String? colourHex;

  /// The resolved line colour, or null to fall back to the mode palette.
  int? get colorArgb => parseOsmColour(colourHex);
}

/// A fully fetched route: its head plus geometry runs and the stops it serves.
class TransitRouteData {
  const TransitRouteData({
    required this.head,
    required this.parts,
    required this.stopOsmIds,
    this.truncated = false,
  });

  final TransitRouteHead head;

  /// Connected runs of the route's geometry. Several parts mean the route has
  /// genuine gaps (branches, loops, or pieces severed by the bbox clip) — they
  /// are kept apart on purpose, never bridged.
  final List<List<LatLng>> parts;

  /// OSM node ids of the stops, in ride order.
  final List<int> stopOsmIds;

  /// Whether the point cap trimmed this route's geometry.
  final bool truncated;

  int get pointCount =>
      parts.fold(0, (acc, p) => acc + p.length);
}

/// A stop: an OSM node with a position and (usually) a name.
class TransitStopData {
  const TransitStopData({
    required this.osmId,
    required this.lat,
    required this.lng,
    this.name,
  });

  final int osmId;
  final double lat;
  final double lng;
  final String? name;
}

/// The outcome of an Overpass request: the parsed value, or a **user-facing**
/// reason it failed.
///
/// A bare `null` (the contract the POI/border clients use) can't distinguish
/// "you're offline" from "the public instance is shedding load", and the public
/// instance answers a perfectly good query with **504** often enough that
/// telling the user to check their connection would usually be a lie.
class TransitOutcome<T> {
  const TransitOutcome.ok(T this.value) : message = null;
  const TransitOutcome.failed(String this.message) : value = null;

  final T? value;
  final String? message;

  bool get ok => message == null;
}

/// Everything one import produced.
class TransitFetchResult {
  const TransitFetchResult({required this.routes, required this.stops});

  final List<TransitRouteData> routes;

  /// Deduped by OSM node id, already clipped to the requested box.
  final List<TransitStopData> stops;

  bool get isEmpty => routes.isEmpty;
}

// --- Caps -------------------------------------------------------------------

/// Routes returned by the pre-flight before the list is truncated.
const int transitPreflightCap = 500;

/// Routes actually imported. A city centre with every mode on lands well under
/// this; the cap is what stops a careless 40 km box from a 50 MB response.
const int transitRouteCap = 250;

/// Points kept per route after simplification.
const int transitPointCap = 4000;

/// Bodies above this are refused outright rather than decoded.
const int transitMaxResponseBytes = 24 * 1024 * 1024;

/// Warn above this bbox diagonal; block above [transitMaxDiagonalMeters].
const double transitWarnDiagonalMeters = 15000;
const double transitMaxDiagonalMeters = 50000;

const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
const String _userAgent = 'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)';

// --- Colour -----------------------------------------------------------------

/// The ~20 CSS colour names that actually turn up in OSM `colour` tags.
const Map<String, int> _namedColours = {
  'red': 0xFFFF0000,
  'blue': 0xFF0000FF,
  'green': 0xFF008000,
  'yellow': 0xFFFFFF00,
  'orange': 0xFFFFA500,
  'purple': 0xFF800080,
  'brown': 0xFFA52A2A,
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'grey': 0xFF808080,
  'gray': 0xFF808080,
  'cyan': 0xFF00FFFF,
  'magenta': 0xFFFF00FF,
  'lime': 0xFF00FF00,
  'navy': 0xFF000080,
  'teal': 0xFF008080,
  'olive': 0xFF808000,
  'maroon': 0xFF800000,
  'silver': 0xFFC0C0C0,
  'pink': 0xFFFFC0CB,
};

/// Parses an OSM `colour` tag into an opaque ARGB value, or null when it isn't
/// something we can draw with (`rgb(…)`, a localised word, junk).
///
/// Accepts `#RRGGBB`, `#RGB`, the same without the `#`, and the colour names
/// above. Near-white results are darkened so a line stays visible on the map.
int? parseOsmColour(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  final named = _namedColours[s];
  if (named != null) return _ensureVisible(named);
  final hex = s.startsWith('#') ? s.substring(1) : s;
  if (!RegExp(r'^[0-9a-f]+$').hasMatch(hex)) return null;
  final String full;
  if (hex.length == 6) {
    full = hex;
  } else if (hex.length == 3) {
    // #f00 -> ff0000
    full = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  } else {
    return null;
  }
  final v = int.tryParse(full, radix: 16);
  if (v == null) return null;
  return _ensureVisible(0xFF000000 | v);
}

/// Darkens near-white colours 25 % so a `colour=white` line doesn't vanish into
/// the basemap.
int _ensureVisible(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  // Rec. 601 luma is plenty for a legibility check.
  final luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  if (luma <= 0.9) return argb;
  int dim(int c) => (c * 0.75).round().clamp(0, 255);
  return 0xFF000000 | (dim(r) << 16) | (dim(g) << 8) | dim(b);
}

// --- Geometry encoding ------------------------------------------------------

/// Encodes a polyline to the compact `[[lat,lng],…]` JSON stored in
/// `TransitRouteParts.points` (the same shape [encodeBorderLines] uses).
///
/// A row per vertex — the convention every other object type follows — would put
/// ~75 000 rows through the global streams for one city import.
String encodeLatLngs(List<LatLng> points) =>
    jsonEncode([for (final p in points) [p.latitude, p.longitude]]);

/// Decodes [encodeLatLngs]. Returns empty on any structural surprise rather
/// than throwing.
List<LatLng> decodeLatLngs(String json) {
  final out = <LatLng>[];
  final dynamic decoded;
  try {
    decoded = jsonDecode(json);
  } catch (_) {
    return out;
  }
  if (decoded is! List) return out;
  for (final pair in decoded) {
    if (pair is! List || pair.length < 2) continue;
    final la = _num(pair[0]);
    final lo = _num(pair[1]);
    if (la == null || lo == null || !la.isFinite || !lo.isFinite) continue;
    out.add(LatLng(la, lo));
  }
  return out;
}

// --- Queries ----------------------------------------------------------------

String _routeRegex(Iterable<TransitMode> modes) =>
    '^(${[for (final m in modes) ...m.routeValues].join('|')})\$';

/// The pre-flight: route ids + tags within the bbox, no geometry.
///
/// `out tags` is the whole verbosity level — **not** `out ids tags`; Overpass's
/// levels (`ids|skel|body|tags|meta`) are mutually exclusive and `tags` already
/// includes the id.
String buildTransitCountQuery({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<TransitMode> modes,
}) {
  final list = modes.toList();
  return '[out:json][timeout:25];'
      'rel["type"="route"]["route"~"${_routeRegex(list)}"]'
      '($south,$west,$north,$east);'
      'out tags qt $transitPreflightCap;';
}

/// The geometry fetch for the routes the pre-flight found.
///
/// `out geom(bbox)` clips member ways to the box; `node(r.r)` is deliberately
/// **not** bbox-filtered (that combination 504s on the public instance) — the
/// stops are clipped in Dart instead.
String buildTransitGeomQuery({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<int> osmIds,
}) {
  final ids = osmIds.join(',');
  return '[out:json][timeout:180];'
      'rel(id:$ids)->.r;'
      '.r out geom($south,$west,$north,$east);'
      'node(r.r);'
      'out body qt;';
}

// --- Parsing ----------------------------------------------------------------

/// A JSON number, or null when the field is missing or the wrong type.
/// `as num?` would *throw* on a String, which would break the never-throws
/// contract every parser here promises.
double? _num(dynamic v) {
  if (v is! num) return null;
  final d = v.toDouble();
  return d.isFinite ? d : null;
}

String? _tag(Map tags, String key) {
  final v = tags[key];
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

TransitRouteHead? _headOf(Map e) {
  final id = _num(e['id'])?.toInt();
  final tags = e['tags'];
  if (id == null || tags is! Map) return null;
  final routeValue = _tag(tags, 'route');
  final mode = routeValue == null ? null : _modeByRouteValue[routeValue];
  if (mode == null) return null; // unknown route= — not a mode we draw
  return TransitRouteHead(
    osmId: id,
    modeKey: mode.key,
    ref: _tag(tags, 'ref'),
    name: _tag(tags, 'name'),
    operatorName: _tag(tags, 'operator'),
    // `color` is a common misspelling in the wild; accept both.
    colourHex: _tag(tags, 'colour') ?? _tag(tags, 'color'),
  );
}

/// Parses the pre-flight response into route heads. Never throws.
List<TransitRouteHead> parseTransitCounts(String body) {
  final out = <TransitRouteHead>[];
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
    if (e is! Map || e['type'] != 'relation') continue;
    final head = _headOf(e);
    if (head != null) out.add(head);
  }
  return out;
}

/// Splits one member way's `geometry` into contiguous runs.
///
/// `out geom(bbox)` emits **`null`** where the way leaves the box, so a clipped
/// way arrives as `[null, null, {…}, {…}, null]`. Each null ends the current
/// run: joining across one would invent a straight line the route never takes.
///
/// Only the `out geom` array shape (`{"lat":…,"lon":…}`) is accepted. The
/// GeoJSON `{"coordinates":[[lon,lat]]}` shape that `convert ::geom=geom()`
/// produces is deliberately **rejected**, not silently swapped — transit never
/// uses `convert`, and a lat/lng swap is invisible until the map is wrong.
List<List<LatLng>> wayRuns(dynamic geometry) {
  final runs = <List<LatLng>>[];
  if (geometry is! List) return runs;
  var current = <LatLng>[];
  void flush() {
    if (current.length >= 2) runs.add(current);
    current = <LatLng>[];
  }

  for (final g in geometry) {
    if (g is! Map) {
      flush(); // a null placeholder (or junk): the way leaves the box here
      continue;
    }
    final la = _num(g['lat']);
    final lo = _num(g['lon']);
    if (la == null || lo == null || !la.isFinite || !lo.isFinite) {
      flush();
      continue;
    }
    current.add(LatLng(la, lo));
  }
  flush();
  return runs;
}

const Set<String> _geometryRoles = {'', 'forward', 'backward'};
const Set<String> _stopRoles = {'stop', 'stop_entry_only', 'stop_exit_only'};
const Set<String> _platformRoles = {
  'platform',
  'platform_entry_only',
  'platform_exit_only',
};

/// The stop node ids of one relation, in member (= ride) order.
///
/// PTv2 data uses `stop*` roles; older PTv1 data only has `platform*`, and some
/// routes have bare node members — fall back through all three so a route is
/// never left stopless when the data is merely old.
List<int> _stopIds(List members) {
  List<int> pick(bool Function(String role) accept) {
    final seen = <int>{};
    final ids = <int>[];
    for (final m in members) {
      if (m is! Map || m['type'] != 'node') continue;
      final role = m['role'] is String ? m['role'] as String : '';
      if (!accept(role)) continue;
      final ref = _num(m['ref'])?.toInt();
      if (ref == null || !seen.add(ref)) continue;
      ids.add(ref);
    }
    return ids;
  }

  var ids = pick(_stopRoles.contains);
  if (ids.isEmpty) ids = pick(_platformRoles.contains);
  if (ids.isEmpty) ids = pick((r) => r.isEmpty);
  return ids;
}

/// Parses the geometry response into routes + stops.
///
/// Pure and drift-free so it can run in a `compute()` isolate — a 2–20 MB
/// `jsonDecode` on the UI thread is guaranteed jank. Never throws; returns an
/// empty result on any structural surprise.
TransitFetchResult parseTransitResponse(
  String body, {
  required double south,
  required double west,
  required double north,
  required double east,
}) {
  const empty = TransitFetchResult(routes: [], stops: []);
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return empty;
  }
  if (decoded is! Map) return empty;
  final elements = decoded['elements'];
  if (elements is! List) return empty;

  // Pass 1: the standalone nodes carry the stop positions and names.
  final nodes = <int, TransitStopData>{};
  for (final e in elements) {
    if (e is! Map || e['type'] != 'node') continue;
    final id = _num(e['id'])?.toInt();
    final la = _num(e['lat']);
    final lo = _num(e['lon']);
    if (id == null || la == null || lo == null) continue;
    if (!la.isFinite || !lo.isFinite) continue;
    // The recursion is unfiltered (see buildTransitGeomQuery); clip here.
    if (la < south || la > north || lo < west || lo > east) continue;
    final tags = e['tags'];
    nodes[id] = TransitStopData(
      osmId: id,
      lat: la,
      lng: lo,
      name: tags is Map ? _tag(tags, 'name') : null,
    );
  }

  // Pass 2: the relations.
  final routes = <TransitRouteData>[];
  final usedStops = <int>{};
  for (final e in elements) {
    if (e is! Map || e['type'] != 'relation') continue;
    final head = _headOf(e);
    final members = e['members'];
    if (head == null || members is! List) continue;

    final runs = <List<LatLng>>[];
    for (final m in members) {
      if (m is! Map || m['type'] != 'way') continue;
      final role = m['role'] is String ? m['role'] as String : '';
      if (!_geometryRoles.contains(role)) continue; // platforms aren't the line
      runs.addAll(wayRuns(m['geometry']));
    }
    // Rejoin the runs into as few connected components as the data allows —
    // genuine gaps stay separate parts rather than being bridged.
    var parts = stitchComponents(runs)
        .map((p) => simplifyLine(p, kImportSimplifyMeters))
        .where((p) => p.length >= 2)
        .toList();

    var truncated = false;
    var total = parts.fold<int>(0, (a, p) => a + p.length);
    if (total > transitPointCap) {
      // Keep whole parts, longest first, until the cap is reached.
      final kept = <List<LatLng>>[];
      var used = 0;
      for (final p in parts) {
        if (used + p.length > transitPointCap) continue;
        kept.add(p);
        used += p.length;
      }
      parts = kept;
      total = used;
      truncated = true;
    }

    final stopIds = [
      for (final id in _stopIds(members))
        if (nodes.containsKey(id)) id,
    ];
    if (parts.isEmpty && stopIds.isEmpty) continue; // nothing of it is in view
    usedStops.addAll(stopIds);
    routes.add(TransitRouteData(
      head: head,
      parts: parts,
      stopOsmIds: stopIds,
      truncated: truncated,
    ));
  }

  return TransitFetchResult(
    routes: routes,
    stops: [for (final id in usedStops) nodes[id]!],
  );
}

// --- Network ----------------------------------------------------------------

/// Runs the pre-flight. Returns the route heads (empty = none in this box), or
/// a failure with a message to show. Never throws.
Future<TransitOutcome<List<TransitRouteHead>>> countTransitRoutes({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<TransitMode> modes,
  http.Client? client,
}) async {
  final list = modes.toList();
  if (list.isEmpty) return const TransitOutcome.ok([]);
  return _post(
    buildTransitCountQuery(
      south: south,
      west: west,
      north: north,
      east: east,
      modes: list,
    ),
    client: client,
    timeout: const Duration(seconds: 30),
    parse: parseTransitCounts,
  );
}

/// Fetches geometry + stops for [osmIds] (already capped by the caller).
///
/// The 120 s timeout is a **deliberate** departure from the 30 s the POI and
/// border clients use: a city-wide `out geom` legitimately takes a minute. Don't
/// "fix" it back down.
Future<TransitOutcome<TransitFetchResult>> fetchTransitRoutes({
  required double south,
  required double west,
  required double north,
  required double east,
  required Iterable<int> osmIds,
  http.Client? client,
}) async {
  final ids = osmIds.toList();
  if (ids.isEmpty) {
    return const TransitOutcome.ok(TransitFetchResult(routes: [], stops: []));
  }
  return _post(
    buildTransitGeomQuery(
      south: south,
      west: west,
      north: north,
      east: east,
      osmIds: ids,
    ),
    client: client,
    timeout: const Duration(seconds: 120),
    maxBytes: transitMaxResponseBytes,
    parse: (body) => parseTransitResponse(
      body,
      south: south,
      west: west,
      north: north,
      east: east,
    ),
  );
}

/// The shared Overpass POST.
///
/// Same endpoint and User-Agent as `fetchBorders`/`fetchPois`, and it still
/// never throws — but it reports *why* it failed, and retries once when the
/// public instance is merely busy (a 504/429/503 answer to a valid query is
/// routine there, and this is an explicit, user-initiated action).
Future<TransitOutcome<T>> _post<T>(
  String query, {
  required http.Client? client,
  required Duration timeout,
  required T Function(String body) parse,
  int? maxBytes,
}) async {
  final owned = client == null;
  final c = client ?? http.Client();
  try {
    for (var attempt = 0;; attempt++) {
      final http.Response resp;
      try {
        resp = await c
            .post(
              Uri.parse(_overpassUrl),
              headers: const {'User-Agent': _userAgent},
              body: {'data': query},
            )
            .timeout(timeout);
      } catch (_) {
        return const TransitOutcome.failed(
            'Could not reach Overpass — check your connection.');
      }
      if (resp.statusCode == 200) {
        if (maxBytes != null && resp.bodyBytes.length > maxBytes) {
          return const TransitOutcome.failed(
              'That area returns too much data — pick a smaller box.');
        }
        return TransitOutcome.ok(parse(resp.body));
      }
      if (_transientStatus.contains(resp.statusCode) && attempt == 0) {
        await Future<void>.delayed(_retryDelay);
        continue; // one polite retry, then give up
      }
      if (_transientStatus.contains(resp.statusCode)) {
        return const TransitOutcome.failed(
            'Overpass is busy — try again in a moment.');
      }
      return TransitOutcome.failed(
          'Overpass refused the request (HTTP ${resp.statusCode}).');
    }
  } finally {
    if (owned) c.close();
  }
}

/// Statuses the public instance uses for "I am overloaded", not "your query is
/// wrong" — worth exactly one retry.
const Set<int> _transientStatus = {429, 502, 503, 504};
const Duration _retryDelay = Duration(seconds: 3);
