import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'overpass_client.dart';

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
/// ## What is imported is chosen up front
///
/// One query is cheap for a city but not for a state, and the cost is almost
/// entirely bus stops: over Bavaria (511 km across) bus nodes are 68 MB and
/// 126 s, train nodes 3 MB and 40 s. So the import dialog asks *which types*,
/// pre-ticked from the box size ([recommendedImportModes]), and a subset is
/// fetched with a much narrower query ([buildTransitStopsQuery]). Each mode
/// carries the widest box it may be asked over ([TransitMode.maxDiagonalMeters]),
/// which is what lets "train stations in all of Bavaria" work while "every bus
/// stop in Bavaria" is refused instead of timing out.
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
    required this.stopSelectors,
    required this.colorArgb,
    required this.bit,
    required this.maxDiagonalMeters,
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

  /// Overpass **node selectors** that find this mode's stops on their own, used
  /// when only some modes are imported. Each is appended to `node` in front of
  /// the bbox, so they must be plain tag filters — and equality filters, not
  /// regexes, so Overpass can use its tag index.
  final List<String> stopSelectors;

  /// Swatch colour in the filter sheet.
  final int colorArgb;

  /// Positional bit for the persisted mode masks.
  final int bit;

  /// The widest box this mode may be imported over, and (at half of it) where
  /// the import dialog starts warning. These are density limits, not opinions:
  /// over all of Bavaria (511 km across) bus stops are **200 941 nodes /
  /// 68 MB / 126 s** — past both [transitMaxResponseBytes] and the request
  /// timeout — while train stops are 8 345 nodes / 3.0 MB / 40 s, and every
  /// other mode is under 1 700 nodes. Node count grows with the *area*, so each
  /// limit is Bavaria's diagonal scaled by √(density relative to bus), anchored
  /// on the 120 km that bus was already capped at.
  final double maxDiagonalMeters;

  double get warnDiagonalMeters => maxDiagonalMeters / 2;

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
    stopSelectors: [
      '["highway"="bus_stop"]',
      '["bus"="yes"]',
      '["trolleybus"="yes"]',
      '["share_taxi"="yes"]',
    ],
    colorArgb: 0xFF1565C0,
    bit: 1 << 0,
    maxDiagonalMeters: 120000,
  ),
  TransitMode(
    key: 'tram',
    label: 'Tram',
    blurb: 'Street-running trams / streetcars',
    tagKeys: ['tram'],
    stopSelectors: ['["railway"="tram_stop"]', '["tram"="yes"]'],
    colorArgb: 0xFFD32F2F,
    bit: 1 << 1,
    maxDiagonalMeters: 800000,
    isRail: true,
  ),
  TransitMode(
    key: 'subway',
    label: 'Subway',
    blurb: 'Metro / underground (U-Bahn)',
    tagKeys: ['subway'],
    stopSelectors: ['["subway"="yes"]', '["station"="subway"]'],
    colorArgb: 0xFF1B5E20,
    bit: 1 << 2,
    maxDiagonalMeters: 1000000,
    isRail: true,
  ),
  TransitMode(
    key: 'light_rail',
    label: 'Light rail',
    blurb: 'Light rail and metro-like commuter rail',
    tagKeys: ['light_rail'],
    stopSelectors: ['["light_rail"="yes"]', '["station"="light_rail"]'],
    colorArgb: 0xFF00897B,
    bit: 1 << 3,
    maxDiagonalMeters: 1000000,
    isRail: true,
  ),
  TransitMode(
    key: 'train',
    label: 'Train',
    blurb: 'Mainline and suburban trains (S-Bahn, regional, long distance)',
    tagKeys: ['train'],
    stopSelectors: [
      '["railway"="station"]',
      '["railway"="halt"]',
      '["train"="yes"]',
    ],
    colorArgb: 0xFF424242,
    bit: 1 << 4,
    maxDiagonalMeters: 600000,
    isRail: true,
  ),
  TransitMode(
    key: 'monorail',
    label: 'Monorail',
    blurb: 'Monorail',
    tagKeys: ['monorail'],
    stopSelectors: ['["monorail"="yes"]', '["station"="monorail"]'],
    colorArgb: 0xFF6A1B9A,
    bit: 1 << 5,
    maxDiagonalMeters: 1000000,
    isRail: true,
  ),
  TransitMode(
    key: 'ferry',
    label: 'Ferry',
    blurb: 'Passenger ferries and water buses',
    tagKeys: ['ferry'],
    stopSelectors: ['["ferry"="yes"]', '["amenity"="ferry_terminal"]'],
    colorArgb: 0xFF0288D1,
    bit: 1 << 6,
    maxDiagonalMeters: 1000000,
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

/// The modes in [mask], named — "Train, Tram" — for a subtitle. Empty mask
/// gives 'nothing'; the full mask gives 'all types'.
String transitModeLabels(int mask) {
  if (mask & transitAllModesMask == transitAllModesMask) return 'all types';
  final names = [for (final m in transitModes) if (mask & m.bit != 0) m.label];
  if (names.isEmpty) return 'nothing';
  return names.join(', ');
}

/// Above this imported diagonal, bus stations start out hidden.
const double kTransitBusDefaultMaxMeters = 10000;

/// Which of the **imported** modes a fresh set shows by default.
///
/// Only ever narrows what was imported (the caller intersects). Buses dominate:
/// 3 147 of Munich's 3 629 stations are bus-only, which swamps a city-wide view
/// but is exactly what you want in a neighbourhood — and unticking them here
/// costs nothing, since they are already stored.
int defaultVisibleModes(double diagonalMeters) {
  if (!diagonalMeters.isFinite ||
      diagonalMeters <= kTransitBusDefaultMaxMeters) {
    return transitAllModesMask;
  }
  final bus = transitModeByKey('bus');
  return bus == null ? transitAllModesMask : transitAllModesMask & ~bus.bit;
}

/// Above this diagonal an import defaults to dropping buses; above
/// [kTransitWideMaxMeters] it defaults to trains alone.
const double kTransitRegionalMaxMeters = 60000;
const double kTransitWideMaxMeters = 150000;

/// Which modes to **fetch** for a box this size — the import dialog's
/// pre-ticked answer, which the user may then narrow or widen.
///
/// Three tiers, from the density measurements on [TransitMode.maxDiagonalMeters]:
/// a city-sized box can afford everything (all of Munich is 5.7 s / 3.1 MB);
/// past that buses are what makes a query expensive, so they drop out; and for
/// a state-sized box only trains are worth asking for — "every bus stop in
/// Bavaria" is 68 MB and does not come back.
int recommendedImportModes(double diagonalMeters) {
  if (!diagonalMeters.isFinite ||
      diagonalMeters <= kTransitRegionalMaxMeters) {
    return transitAllModesMask;
  }
  if (diagonalMeters <= kTransitWideMaxMeters) {
    final bus = transitModeByKey('bus');
    return bus == null ? transitAllModesMask : transitAllModesMask & ~bus.bit;
  }
  return transitModeByKey('train')?.bit ?? transitRailMask;
}

/// The widest / least alarming box the selected modes can be fetched over: the
/// strictest limit among them, because one dense mode is enough to sink the
/// whole query.
double transitMaxDiagonalFor(int mask) => _limitFor(mask, (m) => m.maxDiagonalMeters);

double transitWarnDiagonalFor(int mask) =>
    _limitFor(mask, (m) => m.warnDiagonalMeters);

double _limitFor(int mask, double Function(TransitMode) of) {
  var limit = double.infinity;
  for (final m in transitModes) {
    if (mask & m.bit != 0 && of(m) < limit) limit = of(m);
  }
  // An empty selection has nothing to limit; the dialog blocks it separately.
  return limit.isFinite ? limit : transitModes.first.maxDiagonalMeters;
}

/// The selected modes that a box this size is too big for, worst first — what
/// the dialog names when it refuses, so "too large" always says *for what*.
List<TransitMode> transitModesOverLimit(int mask, double diagonalMeters) {
  final over = [
    for (final m in transitModes)
      if (mask & m.bit != 0 && diagonalMeters > m.maxDiagonalMeters) m,
  ];
  over.sort((a, b) => a.maxDiagonalMeters.compareTo(b.maxDiagonalMeters));
  return over;
}

/// The selected modes this box is merely *large* for — a warning, not a block.
List<TransitMode> transitModesOverWarning(int mask, double diagonalMeters) {
  final over = [
    for (final m in transitModes)
      if (mask & m.bit != 0 &&
          diagonalMeters > m.warnDiagonalMeters &&
          diagonalMeters <= m.maxDiagonalMeters)
        m,
  ];
  over.sort((a, b) => a.warnDiagonalMeters.compareTo(b.warnDiagonalMeters));
  return over;
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

/// The transport moved to `overpass_client.dart` when the borders layer needed
/// the same failover; these names stay so transit's call sites and tests read
/// as before.
typedef TransitOutcome<T> = OverpassOutcome<T>;

/// The shared endpoint list — `AppSettings.transitEndpoint` remembers whichever
/// of these last answered, for *any* import (the column keeps its old name).
const List<String> transitEndpoints = overpassEndpoints;

// --- Caps -------------------------------------------------------------------

/// Bodies above this are refused rather than decoded. Munich is ~3 MB, so this
/// leaves roughly 8× headroom.
const int transitMaxResponseBytes = 24 * 1024 * 1024;

/// The limits when **every** mode is imported — i.e. bus's, the strictest.
/// Selective imports get more room; see [transitMaxDiagonalFor].
double get transitWarnDiagonalMeters =>
    transitWarnDiagonalFor(transitAllModesMask);
double get transitMaxDiagonalMeters =>
    transitMaxDiagonalFor(transitAllModesMask);

/// Overpass's own budget for the query, and how long we wait for it. A wide
/// train-only box is legitimately slow — all of Bavaria took 40 s — so the
/// allowance grows with the box rather than failing something that was going
/// to work.
Duration transitQueryTimeout(double diagonalMeters) =>
    Duration(seconds: diagonalMeters > kTransitRegionalMaxMeters ? 180 : 90);

Duration transitRequestTimeout(double diagonalMeters) =>
    transitQueryTimeout(diagonalMeters) + const Duration(seconds: 30);

/// Nodes sharing a name within this distance become one station. Pasing
/// Bahnhof's 11 nodes span ~110 m, so this has to be generous.
const double transitMergeMeters = 200;

const Distance _distance = Distance(calculator: Haversine());

// --- Query ------------------------------------------------------------------

/// The public-transport stop nodes in the bbox that serve [modeMask].
///
/// Nodes only, tags only, no relation traversal — deliberately the cheapest
/// shape Overpass offers, which is what makes a whole city importable.
///
/// Two shapes, because they answer different questions:
///
/// * **All modes** — the generic `public_transport=*` sweep (plus bus stops and
///   railway stations), which is every stop however it is tagged, including the
///   ~3 % that name no mode at all.
/// * **A subset** — the union of the chosen modes' [TransitMode.stopSelectors],
///   which is far cheaper on a wide box because it never touches the 200 000
///   bus nodes you didn't ask for. It relies on the mode being tagged on the
///   node, which 97 % of Munich's stops do, and picks up the rest through the
///   `railway=`/`highway=` selectors; untagged stops of *unknown* mode are the
///   deliberate loss — you asked for trains, not for "possibly a train".
String buildTransitStopsQuery({
  required double south,
  required double west,
  required double north,
  required double east,
  int modeMask = -1,
  double? diagonalMeters,
}) {
  final bbox = '($south,$west,$north,$east)';
  final all = modeMask & transitAllModesMask == transitAllModesMask;
  final selectors = all
      ? const [
          '["public_transport"="stop_position"]',
          '["public_transport"="station"]',
          '["public_transport"="platform"]',
          '["highway"="bus_stop"]',
          '["railway"="station"]',
          '["railway"="halt"]',
          '["railway"="tram_stop"]',
        ]
      : [
          for (final m in transitModes)
            if (modeMask & m.bit != 0) ...m.stopSelectors,
        ];
  final timeout =
      transitQueryTimeout(diagonalMeters ?? double.nan).inSeconds;
  return '[out:json][timeout:$timeout];'
      '('
      '${[for (final s in selectors) 'node$s$bbox;'].join()}'
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
  // `station=subway` on a `railway=station` node is how a fair few metro
  // stations are tagged. Reading it before the railway fallback keeps them out
  // of a train-only import, which would otherwise inherit them as trains.
  switch (_tag(tags, 'station')) {
    case 'subway':
      return bitOf('subway');
    case 'light_rail':
      return bitOf('light_rail');
    case 'monorail':
      return bitOf('monorail');
  }
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

/// Parses an Overpass stops response into merged stations, keeping only those
/// served by [keepModes].
///
/// The filter runs **after** the merge, so a station is judged on everything
/// known about it: Pasing Bahnhof survives a train-only import even though most
/// of its nodes are bus platforms, and it keeps their bus bit, because that is
/// what the data says. A partial import drops stations whose mode is unknown —
/// with the selective query they are noise; an all-modes import keeps them, and
/// the filter sheet lists them under "No type given".
///
/// Never throws. Returns **null** when the body could not be understood at all,
/// so a malformed response stays distinguishable from a genuinely empty area
/// (the old code conflated the two and reported "nothing found here").
List<TransitStationData>? parseTransitStations(String body,
    {int keepModes = -1}) {
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
  final merged = mergeStations(raw);
  if (keepModes & transitAllModesMask == transitAllModesMask) return merged;
  return [
    for (final s in merged)
      if (s.modeMask & keepModes != 0) s,
  ];
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

/// Fetches the bbox's public-transport stations that serve [modeMask].
///
/// Returns the merged stations (empty = none there), or a failure carrying a
/// message to show. Never throws.
Future<TransitOutcome<List<TransitStationData>>> fetchTransitStations({
  required double south,
  required double west,
  required double north,
  required double east,
  int modeMask = -1,
  http.Client? client,
  String? preferEndpoint,
  OverpassProgressCallback? onProgress,
  OverpassCancel? cancel,
}) {
  final diagonal = _diagonalMeters(south, west, north, east);
  return overpassPost(
    buildTransitStopsQuery(
      south: south,
      west: west,
      north: north,
      east: east,
      modeMask: modeMask,
      diagonalMeters: diagonal,
    ),
    client: client,
    timeout: transitRequestTimeout(diagonal),
    maxBytes: transitMaxResponseBytes,
    oversizeMessage: 'That area returns too much data — pick a smaller box, or '
        'import fewer types (bus stops are the bulk of it).',
    preferEndpoint: preferEndpoint,
    onProgress: onProgress,
    cancel: cancel,
    parse: (body) => parseTransitStations(body, keepModes: modeMask),
  );
}

double _diagonalMeters(
    double south, double west, double north, double east) {
  final d = _distance.as(
      LengthUnit.Meter, LatLng(south, west), LatLng(north, east));
  return d.isFinite ? d : double.nan;
}
