import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Public-transport **stations**, fetched once from Overpass over a chosen
/// bounding box and stored offline (the `transit` layer type).
///
/// ## Why stations only
///
/// This layer used to fetch route relations *with geometry*. Measured against
/// the live API, that is not reliably obtainable: a 25 × 40 km area returned
/// `Dispatcher_Client::request_read_and_idx::timeout` (the public instance
/// **queueing**, not a bad query) on three separate mirrors, and chunking it to
/// 25 routes still failed. Stops, by contrast, are the cheapest thing Overpass
/// does — all of Munich (30 × 33 km) came back in **5.7 s / 3.1 MB**.
///
/// So: one nodes-only query, no relation traversal, no geometry, no line
/// numbers. Each station records **which modes serve it**, which is what the
/// filter needs and what 97 % of Munich's stop nodes tag directly on the node.
///
/// ## The merge matters
///
/// A physical stop is usually several OSM nodes — a `stop_position` per
/// platform plus a `platform` node each. Munich's 8 215 raw nodes are only
/// **3 629 real stations** (Pasing Bahnhof alone is 11 nodes within ~110 m), so
/// [mergeStations] groups by name + proximity and unions their modes. Without
/// it every count and every cluster badge would be roughly double the truth.

// --- Mode catalogue ---------------------------------------------------------

/// One transport mode. [tagKeys] doubles as the set of **stop tag keys** that
/// mark this mode on a node (`bus=yes`, `tram=yes`, …) — PTv2 uses the same
/// vocabulary for stops and routes, so one catalogue serves both.
class TransitMode {
  const TransitMode({
    required this.key,
    required this.label,
    required this.blurb,
    required this.tagKeys,
    required this.colorArgb,
    required this.bit,
    this.isRail = false,
  });

  /// Stable identifier, persisted in the mode masks.
  final String key;
  final String label;

  /// One line saying what this actually is. "Light rail" and "Monorail" mean
  /// nothing to most people, and even Tram/Subway are named differently
  /// region to region — so the filter names the vehicle *and* gives an example.
  final String blurb;

  /// OSM tag keys that mean this mode is served here.
  final List<String> tagKeys;

  /// Swatch colour in the filter sheet.
  final int colorArgb;

  /// Positional bit for the persisted mode masks.
  final int bit;

  /// Whether "Rail only" includes this mode.
  final bool isRail;
}

/// The supported modes. **Bits are positional and persisted in
/// `TransitSets.modeMask`/`visibleModeMask` and `TransitStops.modeMask` —
/// append new entries, never reorder.**
const List<TransitMode> transitModes = [
  TransitMode(
    key: 'bus',
    label: 'Bus',
    blurb: 'Local buses and trolleybuses',
    tagKeys: ['bus', 'trolleybus', 'share_taxi'],
    colorArgb: 0xFF1565C0,
    bit: 1 << 0,
  ),
  TransitMode(
    key: 'tram',
    label: 'Tram',
    blurb: 'Street-running trams / streetcars',
    tagKeys: ['tram'],
    colorArgb: 0xFFD32F2F,
    bit: 1 << 1,
    isRail: true,
  ),
  TransitMode(
    key: 'subway',
    label: 'Subway',
    blurb: 'Metro / underground (U-Bahn)',
    tagKeys: ['subway'],
    colorArgb: 0xFF1B5E20,
    bit: 1 << 2,
    isRail: true,
  ),
  TransitMode(
    key: 'light_rail',
    label: 'Light rail',
    blurb: 'Light rail and metro-like commuter rail',
    tagKeys: ['light_rail'],
    colorArgb: 0xFF00897B,
    bit: 1 << 3,
    isRail: true,
  ),
  TransitMode(
    key: 'train',
    label: 'Train',
    blurb: 'Mainline and suburban trains (S-Bahn, regional, long distance)',
    tagKeys: ['train'],
    colorArgb: 0xFF424242,
    bit: 1 << 4,
    isRail: true,
  ),
  TransitMode(
    key: 'monorail',
    label: 'Monorail',
    blurb: 'Monorail',
    tagKeys: ['monorail'],
    colorArgb: 0xFF6A1B9A,
    bit: 1 << 5,
    isRail: true,
  ),
  TransitMode(
    key: 'ferry',
    label: 'Ferry',
    blurb: 'Passenger ferries and water buses',
    tagKeys: ['ferry'],
    colorArgb: 0xFF0288D1,
    bit: 1 << 6,
  ),
];

/// Stop tag key → mode, built once from [transitModes].
final Map<String, TransitMode> _modeByTag = {
  for (final m in transitModes)
    for (final v in m.tagKeys) v: m,
};

TransitMode? transitModeByKey(String key) =>
    transitModes.where((m) => m.key == key).firstOrNull;

Set<TransitMode> transitModesFromMask(int mask) =>
    {for (final m in transitModes) if (mask & m.bit != 0) m};

int transitMaskWith(int mask, TransitMode m, bool on) =>
    on ? (mask | m.bit) : (mask & ~m.bit);

int transitMaskOf(Iterable<TransitMode> modes) =>
    modes.fold(0, (acc, m) => acc | m.bit);

/// Every mode's bit — what a fresh import records as "these modes were fetched".
int get transitAllModesMask => transitMaskOf(transitModes);

/// The rail modes, for the filter sheet's "Rail only" shortcut.
int get transitRailMask => transitMaskOf(transitModes.where((m) => m.isRail));

/// Above this imported diagonal, bus stations start out hidden.
const double kTransitBusDefaultMaxMeters = 10000;

/// Which modes a **freshly imported** set shows by default.
///
/// Everything is always *imported* (it is one cheap query), so this only picks
/// what is shown — ticking Bus later never needs a re-import. Buses dominate:
/// 3 147 of Munich's 3 629 stations are bus-only, which swamps a city-wide view
/// but is exactly what you want in a neighbourhood.
int defaultVisibleModes(double diagonalMeters) {
  if (!diagonalMeters.isFinite ||
      diagonalMeters <= kTransitBusDefaultMaxMeters) {
    return transitAllModesMask;
  }
  final bus = transitModeByKey('bus');
  return bus == null ? transitAllModesMask : transitAllModesMask & ~bus.bit;
}

// --- Result models (drift-free, isolate-safe) --------------------------------

/// One station: a position, a name, and which modes serve it.
class TransitStationData {
  const TransitStationData({
    required this.osmId,
    required this.lat,
    required this.lng,
    this.name,
    this.modeMask = 0,
    this.nodeCount = 1,
    this.routeRef,
  });

  /// The OSM node id this station was keyed on (the `station` node when there
  /// was one, else the first merged node) — enough to look it up on osm.org.
  final int osmId;
  final double lat;
  final double lng;
  final String? name;

  /// Bits of the modes serving this station; 0 = the data doesn't say.
  final int modeMask;

  /// How many OSM nodes merged into this station.
  final int nodeCount;

  /// The `route_ref` tag when present (~18 % of stops). Free text, shown as a
  /// hint — never parsed, never relied on, never fetched for.
  final String? routeRef;
}

/// The outcome of an Overpass request: the value, or a **user-facing** reason it
/// failed.
///
/// A bare `null` can't distinguish "you're offline" from "the instance is
/// shedding load", and the public instances answer perfectly good queries with
/// 504 often enough that blaming the connection would usually be a lie.
class TransitOutcome<T> {
  const TransitOutcome.ok(T this.value, {this.endpoint}) : message = null;
  const TransitOutcome.failed(String this.message)
      : value = null,
        endpoint = null;

  final T? value;
  final String? message;

  /// Which endpoint served the request, so the caller can prefer it next time.
  final String? endpoint;

  bool get ok => message == null;
}

// --- Caps -------------------------------------------------------------------

/// Bodies above this are refused rather than decoded. Munich is ~3 MB, so this
/// leaves roughly 8× headroom.
const int transitMaxResponseBytes = 24 * 1024 * 1024;

/// Warn above this bbox diagonal; block above [transitMaxDiagonalMeters].
/// Munich end-to-end is ~45 km and imports in seconds, so the old 50 km block
/// was far too tight.
const double transitWarnDiagonalMeters = 60000;
const double transitMaxDiagonalMeters = 120000;

/// Nodes sharing a name within this distance become one station. Pasing
/// Bahnhof's 11 nodes span ~110 m, so this has to be generous.
const double transitMergeMeters = 200;

const Distance _distance = Distance(calculator: Haversine());

/// Overpass instances, tried in order. Whichever one is busy is the variable —
/// in testing the main instance refused in 8 s an area that kumi served, and
/// later the roles reversed — so failing over is worth more than retrying.
const List<String> transitEndpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];

const String _userAgent =
    'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)';

// --- Query ------------------------------------------------------------------

/// Every public-transport stop node in the bbox.
///
/// Nodes only, tags only, no relation traversal — deliberately the cheapest
/// shape Overpass offers, which is what makes a whole city importable.
String buildTransitStopsQuery({
  required double south,
  required double west,
  required double north,
  required double east,
}) {
  final bbox = '($south,$west,$north,$east)';
  return '[out:json][timeout:90];'
      '('
      'node["public_transport"="stop_position"]$bbox;'
      'node["public_transport"="station"]$bbox;'
      'node["public_transport"="platform"]$bbox;'
      'node["highway"="bus_stop"]$bbox;'
      'node["railway"~"^(station|halt|tram_stop)\$"]$bbox;'
      ');'
      'out body qt;';
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

/// The modes a stop node declares.
///
/// 97 % of Munich's stops tag this directly (`bus=yes`, `train=yes`, …). For the
/// rest, fall back to what kind of stop it is — a `railway=tram_stop` is a tram
/// stop whether or not anyone wrote `tram=yes`.
int stopModeMask(Map tags) {
  var mask = 0;
  for (final entry in _modeByTag.entries) {
    if (tags[entry.key] == 'yes') mask |= entry.value.bit;
  }
  if (mask != 0) return mask;

  int bitOf(String key) => transitModeByKey(key)?.bit ?? 0;
  switch (_tag(tags, 'railway')) {
    case 'tram_stop':
      return bitOf('tram');
    case 'station':
    case 'halt':
      return bitOf('train');
  }
  if (_tag(tags, 'highway') == 'bus_stop') return bitOf('bus');
  // Genuinely unspecified — kept as a station rather than dropped, so nothing
  // disappears silently; the filter groups these under "No type given".
  return 0;
}

/// One stop node before merging. Public only so [mergeStations] is testable.
class TransitStopNode {
  const TransitStopNode({
    required this.osmId,
    required this.lat,
    required this.lng,
    this.name,
    this.modeMask = 0,
    this.isStation = false,
    this.routeRef,
  });

  final int osmId;
  final double lat;
  final double lng;
  final String? name;
  final int modeMask;

  /// `public_transport=station` — the mapped centre of a group, which beats an
  /// average of platform positions.
  final bool isStation;
  final String? routeRef;
}

/// Parses an Overpass stops response into merged stations.
///
/// Never throws. Returns **null** when the body could not be understood at all,
/// so a malformed response stays distinguishable from a genuinely empty area
/// (the old code conflated the two and reported "nothing found here").
List<TransitStationData>? parseTransitStations(String body) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  final elements = decoded['elements'];
  if (elements is! List) return null;

  final raw = <TransitStopNode>[];
  for (final e in elements) {
    if (e is! Map || e['type'] != 'node') continue;
    final id = _num(e['id'])?.toInt();
    final lat = _num(e['lat']);
    final lng = _num(e['lon']);
    if (id == null || lat == null || lng == null) continue;
    final tags = e['tags'];
    final t = tags is Map ? tags : const {};
    raw.add(TransitStopNode(
      osmId: id,
      lat: lat,
      lng: lng,
      name: _tag(t, 'name'),
      modeMask: stopModeMask(t),
      isStation: _tag(t, 'public_transport') == 'station',
      routeRef: _tag(t, 'route_ref'),
    ));
  }
  return mergeStations(raw);
}

/// Merges raw stop nodes into stations: same **name**, within
/// [transitMergeMeters] of the station's extent, become one station whose modes
/// are the union.
///
/// Distance is measured to the station's **bounding box**, not its centre. A
/// big terminus legitimately spans hundreds of metres (München Hbf's platforms
/// run ~500 m), and measuring from a drifting mean would split its far end off
/// into a phantom second station.
///
/// Unnamed nodes never merge — there is nothing to match on, and they are rare
/// (28 of Munich's 8 215).
///
/// A uniform grid indexes candidates and the 3×3 neighbourhood is scanned, so a
/// pair straddling a cell boundary still merges (the trick
/// `screen_cluster.dart` uses in screen space). A station is re-indexed into
/// every cell it grows into, so a long one stays findable from either end.
List<TransitStationData> mergeStations(List<TransitStopNode> raw) {
  const dLat = transitMergeMeters / 111320;
  final out = <_Station>[];
  final grid = <int, List<int>>{};

  int cellKey(int x, int y) => x * 1000003 ^ y;
  (int, int) cellOf(double lat, double lng) {
    final cosLat = math.cos(lat * math.pi / 180).abs();
    final dLng = cosLat < 1e-6 ? dLat : dLat / cosLat;
    return ((lng / dLng).floor(), (lat / dLat).floor());
  }

  void index(int stationIndex, double lat, double lng) {
    final (cx, cy) = cellOf(lat, lng);
    final bucket = grid.putIfAbsent(cellKey(cx, cy), () => []);
    if (!bucket.contains(stationIndex)) bucket.add(stationIndex);
  }

  for (final s in raw) {
    final (cx, cy) = cellOf(s.lat, s.lng);

    _Station? target;
    if (s.name != null) {
      outer:
      for (var ox = -1; ox <= 1; ox++) {
        for (var oy = -1; oy <= 1; oy++) {
          for (final i in grid[cellKey(cx + ox, cy + oy)] ?? const <int>[]) {
            final cand = out[i];
            if (cand.name != s.name) continue;
            if (cand.distanceTo(s.lat, s.lng) <= transitMergeMeters) {
              target = cand;
              break outer;
            }
          }
        }
      }
    }

    if (target != null) {
      target.add(s);
      index(out.indexOf(target), s.lat, s.lng);
      continue;
    }
    out.add(_Station(s));
    index(out.length - 1, s.lat, s.lng);
  }

  return [for (final s in out) s.toData()];
}

/// A station under construction.
class _Station {
  _Station(TransitStopNode first)
      : name = first.name,
        osmId = first.osmId,
        lat = first.lat,
        lng = first.lng,
        mask = first.modeMask,
        routeRef = first.routeRef,
        _sumLat = first.lat,
        _sumLng = first.lng,
        _south = first.lat,
        _north = first.lat,
        _west = first.lng,
        _east = first.lng,
        _anchored = first.isStation,
        nodeCount = 1;

  final String? name;
  int osmId;
  double lat;
  double lng;
  int mask;
  String? routeRef;
  int nodeCount;

  double _sumLat;
  double _sumLng;

  /// The extent of the merged nodes — candidates are measured against this, not
  /// against the centre, so a long platform doesn't split.
  double _south, _north, _west, _east;

  /// Whether the position came from a `public_transport=station` node.
  bool _anchored;

  /// Ground distance from this station's extent to a point (0 when inside).
  double distanceTo(double pLat, double pLng) {
    final clampedLat = pLat.clamp(_south, _north);
    final clampedLng = pLng.clamp(_west, _east);
    final d = _distance.as(LengthUnit.Meter, LatLng(clampedLat, clampedLng),
        LatLng(pLat, pLng));
    return d.isFinite ? d : double.infinity;
  }

  void add(TransitStopNode s) {
    mask |= s.modeMask;
    routeRef ??= s.routeRef;
    nodeCount++;
    _sumLat += s.lat;
    _sumLng += s.lng;
    if (s.lat < _south) _south = s.lat;
    if (s.lat > _north) _north = s.lat;
    if (s.lng < _west) _west = s.lng;
    if (s.lng > _east) _east = s.lng;
    if (s.isStation && !_anchored) {
      _anchored = true;
      osmId = s.osmId;
      lat = s.lat;
      lng = s.lng;
    } else if (!_anchored) {
      lat = _sumLat / nodeCount;
      lng = _sumLng / nodeCount;
    }
  }

  TransitStationData toData() => TransitStationData(
        osmId: osmId,
        lat: lat,
        lng: lng,
        name: name,
        modeMask: mask,
        nodeCount: nodeCount,
        routeRef: routeRef,
      );
}

// --- Network ----------------------------------------------------------------

/// Fetches every public-transport station in the bbox.
///
/// Returns the merged stations (empty = none there), or a failure carrying a
/// message to show. Never throws.
Future<TransitOutcome<List<TransitStationData>>> fetchTransitStations({
  required double south,
  required double west,
  required double north,
  required double east,
  http.Client? client,
  String? preferEndpoint,
}) {
  return _post(
    buildTransitStopsQuery(
      south: south,
      west: west,
      north: north,
      east: east,
    ),
    client: client,
    timeout: const Duration(seconds: 120),
    maxBytes: transitMaxResponseBytes,
    preferEndpoint: preferEndpoint,
    parse: parseTransitStations,
  );
}

/// Statuses the public instances use for "I am overloaded", not "your query is
/// wrong". These — and timeouts, and socket errors — fail **over** to the next
/// endpoint; anything else is a query error and is reported as-is.
const Set<int> _transientStatus = {429, 500, 502, 503, 504};

/// POSTs [query] to each endpoint in turn until one answers.
///
/// [parse] returns null when the body is unintelligible, which is reported
/// distinctly from "parsed fine, found nothing".
Future<TransitOutcome<T>> _post<T>(
  String query, {
  required http.Client? client,
  required Duration timeout,
  required T? Function(String body) parse,
  int? maxBytes,
  String? preferEndpoint,
}) async {
  final owned = client == null;
  final c = client ?? http.Client();
  // Try the last endpoint that worked first, then the rest in order.
  final endpoints = <String>[
    if (preferEndpoint != null && transitEndpoints.contains(preferEndpoint))
      preferEndpoint,
    for (final e in transitEndpoints)
      if (e != preferEndpoint) e,
  ];
  var lastTransient = 'Overpass is busy — try again in a moment.';
  try {
    for (final endpoint in endpoints) {
      final http.Response resp;
      try {
        resp = await c
            .post(
              Uri.parse(endpoint),
              headers: const {'User-Agent': _userAgent},
              body: {'data': query},
            )
            .timeout(timeout);
      } catch (_) {
        // A timeout or socket error says nothing about the *query*, so try the
        // next instance rather than blaming the user's connection.
        lastTransient = 'Could not reach Overpass — check your connection, '
            'or try again in a moment.';
        continue;
      }
      if (resp.statusCode == 200) {
        if (maxBytes != null && resp.bodyBytes.length > maxBytes) {
          return const TransitOutcome.failed(
              'That area returns too much data — pick a smaller box.');
        }
        final parsed = parse(resp.body);
        if (parsed == null) {
          return const TransitOutcome.failed(
              'Overpass sent a response we could not read. Try again.');
        }
        return TransitOutcome.ok(parsed, endpoint: endpoint);
      }
      if (_transientStatus.contains(resp.statusCode)) {
        lastTransient = 'Overpass is busy — try again in a moment.';
        continue;
      }
      return TransitOutcome.failed(
          'Overpass refused the request (HTTP ${resp.statusCode}).');
    }
    return TransitOutcome.failed(lastTransient);
  } finally {
    if (owned) c.close();
  }
}
