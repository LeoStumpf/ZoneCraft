import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../data/borders.dart';
import 'height.dart' show clipToConvex;
import 'simplify.dart';

/// Geometry for the `borders` layer: stitch an OSM relation's member ways into
/// closed rings, cut them down to the imported box, thin them, and colour the
/// areas so no two neighbours match.
///
/// Pure Dart — no Flutter, no drift — so [buildBorderAreas] runs inside a
/// `compute()` isolate (the precedent being `data/height_generator.dart`), and
/// every step here is directly unit-testable.

/// An axis-aligned lat/lng box: the imported area, and the clip rectangle the
/// stored geometry is cut to.
class LatLngBox {
  const LatLngBox({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south, west, north, east;

  LatLng get center => LatLng((south + north) / 2, (west + east) / 2);

  /// The box as a ring, for [clipToConvex].
  List<LatLng> get ring => [
        LatLng(south, west),
        LatLng(south, east),
        LatLng(north, east),
        LatLng(north, west),
      ];

  bool contains(LatLng p) =>
      p.latitude >= south &&
      p.latitude <= north &&
      p.longitude >= west &&
      p.longitude <= east;
}

// --- Ring assembly ----------------------------------------------------------

/// Quantised endpoint key. OSM member ways share *nodes*, so their endpoints are
/// bit-identical; 1e-7° (~1 cm) is far finer than any real gap and far coarser
/// than float noise.
String _key(LatLng p) =>
    '${(p.latitude * 1e7).round()}:${(p.longitude * 1e7).round()}';

/// Stitches [members] into closed rings by matching shared endpoints.
///
/// Outer members come first in the result, inner (hole) members after — but the
/// distinction carries no further, because the painter fills with even-odd
/// parity, where a ring inside another *is* a hole regardless of role or
/// winding. Roles are still honoured during stitching so an outer way never
/// chains onto an inner one.
///
/// Member order and direction are not trusted: ways arrive shuffled and some
/// are reversed relative to the ring. A run that will not close is closed
/// first↔last rather than dropped — a mis-stitched area is a visible wrong
/// edge, a dropped one is a hole in the map with nothing to explain it.
List<List<LatLng>> assembleRings(List<BorderWay> members) {
  final outer = <BorderWay>[];
  final inner = <BorderWay>[];
  for (final w in members) {
    if (w.points.length < 2) continue;
    (w.role == 'inner' ? inner : outer).add(w);
  }
  return [..._stitch(outer), ..._stitch(inner)];
}

List<List<LatLng>> _stitch(List<BorderWay> ways) {
  if (ways.isEmpty) return const [];
  final used = List<bool>.filled(ways.length, false);
  // Endpoint -> the ways touching it. A way appears twice (both ends), and a
  // closed way appears twice under the same key, which is harmless: it is
  // already `used` by the time anything looks it up.
  final byEnd = <String, List<int>>{};
  for (var i = 0; i < ways.length; i++) {
    byEnd.putIfAbsent(_key(ways[i].points.first), () => []).add(i);
    byEnd.putIfAbsent(_key(ways[i].points.last), () => []).add(i);
  }

  final rings = <List<LatLng>>[];
  for (var s = 0; s < ways.length; s++) {
    if (used[s]) continue;
    used[s] = true;
    final ring = <LatLng>[...ways[s].points];
    while (true) {
      final tail = _key(ring.last);
      if (tail == _key(ring.first)) break; // closed
      int? pick;
      for (final ci in byEnd[tail] ?? const <int>[]) {
        if (!used[ci]) {
          pick = ci;
          break;
        }
      }
      if (pick == null) break; // open remnant — closed implicitly below
      used[pick] = true;
      final w = ways[pick];
      final pts = _key(w.points.first) == tail
          ? w.points
          : w.points.reversed.toList();
      ring.addAll(pts.skip(1)); // the shared node is already the tail
    }
    // Rings are stored implicitly closed (no duplicated first vertex), which is
    // what the painter and `simplifyRing` both expect.
    if (ring.length >= 2 && _key(ring.first) == _key(ring.last)) {
      ring.removeLast();
    }
    if (ring.length >= 3) rings.add(ring);
  }
  return rings;
}

// --- Clipping ---------------------------------------------------------------

/// Clips each ring to [box] independently.
///
/// Clipping rings one at a time preserves even-odd parity inside the box: under
/// intersection with the same convex region a point keeps its in/out state for
/// every ring, so a hole stays a hole. Rings that fall entirely outside come
/// back empty and are dropped.
List<List<LatLng>> clipRingsToBox(List<List<LatLng>> rings, LatLngBox box) {
  final clip = box.ring;
  final inside = box.center;
  final out = <List<LatLng>>[];
  for (final ring in rings) {
    if (ring.length < 3) continue;
    final clipped = clipToConvex(ring, clip, inside);
    if (clipped.length >= 3) out.add(clipped);
  }
  return out;
}

// --- Colouring --------------------------------------------------------------

/// How many distinct area colours the painter offers. Four suffice for a planar
/// map and the measured Munich level-8 set needed exactly four; six leaves
/// room for the messy cases (exclaves, areas meeting at a point) without ever
/// having to search.
const int kBorderColorCount = 6;

/// What colouring needs to know about one area: its identity and the member way
/// ids it might share with a neighbour.
class AreaAdjacencyInput {
  const AreaAdjacencyInput({required this.osmId, required this.wayIds});

  final int osmId;
  final List<int> wayIds;
}

/// Assigns each area a palette index such that no two areas sharing a border
/// get the same one, greedy highest-degree-first (Welsh–Powell).
///
/// **Adjacency is a shared OSM way id**, which is exact and free: two
/// administrative areas that touch are mapped as sharing the boundary way
/// between them, so no geometric test is needed (measured on Munich's 54
/// municipalities: 0 isolated areas, max degree 7, 4 colours, 0 conflicts).
///
/// Run over **every area in the layer**, not just one import, so two
/// overlapping imports don't clash along their seam. Deterministic for a given
/// input: ties in degree break on `osmId`.
Map<int, int> assignAreaColors(List<AreaAdjacencyInput> areas) {
  if (areas.isEmpty) return const {};
  // Deduplicate: the same area can be present in two overlapping imports, and
  // it must come out with one colour, not two.
  final byId = <int, Set<int>>{};
  for (final a in areas) {
    byId.putIfAbsent(a.osmId, () => <int>{}).addAll(a.wayIds);
  }

  final areasByWay = <int, List<int>>{};
  for (final e in byId.entries) {
    for (final w in e.value) {
      areasByWay.putIfAbsent(w, () => []).add(e.key);
    }
  }
  final neighbours = <int, Set<int>>{for (final id in byId.keys) id: <int>{}};
  for (final sharers in areasByWay.values) {
    if (sharers.length < 2) continue;
    for (final a in sharers) {
      for (final b in sharers) {
        if (a != b) neighbours[a]!.add(b);
      }
    }
  }

  final order = byId.keys.toList()
    ..sort((a, b) {
      final d = neighbours[b]!.length.compareTo(neighbours[a]!.length);
      return d != 0 ? d : a.compareTo(b);
    });

  final colors = <int, int>{};
  for (final id in order) {
    // Count how many neighbours already hold each colour, so an over-constrained
    // area (more coloured neighbours than the palette has entries) still picks
    // the least conflicting one instead of failing.
    final used = List<int>.filled(kBorderColorCount, 0);
    for (final n in neighbours[id]!) {
      final c = colors[n];
      if (c != null) used[c]++;
    }
    var best = 0;
    for (var c = 1; c < kBorderColorCount; c++) {
      if (used[c] < used[best]) best = c;
    }
    colors[id] = best;
  }
  return colors;
}

// --- Label anchor -----------------------------------------------------------

/// A point inside the area to hang its name plate on.
///
/// The centroid of the largest ring when that lands inside it; otherwise the
/// middle of the widest interior span on the centroid's latitude. That second
/// case is what a C-shaped or coastal municipality needs — its centroid is
/// often in the sea, and a name floating outside its own outline reads as
/// belonging to the neighbour.
LatLng labelAnchor(List<List<LatLng>> rings) {
  final ring = _largestRing(rings);
  if (ring == null) return const LatLng(0, 0);
  final c = _centroid(ring);
  if (_containsPoint(ring, c)) return c;

  // Scanline at the centroid's latitude: take the midpoint of the widest span
  // that is inside the ring.
  final xs = <double>[];
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    if ((a.latitude > c.latitude) == (b.latitude > c.latitude)) continue;
    final t = (c.latitude - a.latitude) / (b.latitude - a.latitude);
    xs.add(a.longitude + t * (b.longitude - a.longitude));
  }
  xs.sort();
  var bestWidth = -1.0;
  var bestLng = c.longitude;
  for (var i = 0; i + 1 < xs.length; i += 2) {
    final w = xs[i + 1] - xs[i];
    if (w > bestWidth) {
      bestWidth = w;
      bestLng = (xs[i] + xs[i + 1]) / 2;
    }
  }
  return LatLng(c.latitude, bestLng);
}

List<LatLng>? _largestRing(List<List<LatLng>> rings) {
  List<LatLng>? best;
  var bestArea = -1.0;
  for (final r in rings) {
    if (r.length < 3) continue;
    final a = _signedArea(r).abs();
    if (a > bestArea) {
      bestArea = a;
      best = r;
    }
  }
  return best;
}

double _signedArea(List<LatLng> ring) {
  var sum = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    sum += a.longitude * b.latitude - b.longitude * a.latitude;
  }
  return sum / 2;
}

/// Area-weighted polygon centroid, falling back to the vertex mean for a
/// degenerate (zero-area) ring.
LatLng _centroid(List<LatLng> ring) {
  final a2 = _signedArea(ring);
  if (a2.abs() < 1e-14) {
    var lat = 0.0, lng = 0.0;
    for (final p in ring) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / ring.length, lng / ring.length);
  }
  var cx = 0.0, cy = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final p = ring[i];
    final q = ring[(i + 1) % ring.length];
    final cross = p.longitude * q.latitude - q.longitude * p.latitude;
    cx += (p.longitude + q.longitude) * cross;
    cy += (p.latitude + q.latitude) * cross;
  }
  return LatLng(cy / (6 * a2), cx / (6 * a2));
}

bool _containsPoint(List<LatLng> ring, LatLng p) {
  var inside = false;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    if ((a.latitude > p.latitude) != (b.latitude > p.latitude)) {
      final t = (p.latitude - a.latitude) / (b.latitude - a.latitude);
      if (p.longitude < a.longitude + t * (b.longitude - a.longitude)) {
        inside = !inside;
      }
    }
  }
  return inside;
}

// --- Codec ------------------------------------------------------------------

/// Encodes rings as `[[[lat,lng], …], …]`.
///
/// One blob per area rather than a point row each: a single state boundary is
/// 119 238 points, which as rows would mean that many UUIDs. Border areas are
/// derived, non-editable snapshots, so nothing ever needs to address one point.
String encodeRings(List<List<LatLng>> rings) => jsonEncode([
      for (final r in rings)
        [
          for (final p in r) [p.latitude, p.longitude],
        ],
    ]);

/// Decodes [encodeRings]. Returns what it could read (empty on any structural
/// surprise) rather than throwing — a corrupt row must not take the map down.
List<List<LatLng>> decodeRings(String json) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(json);
  } catch (_) {
    return const [];
  }
  if (decoded is! List) return const [];
  final out = <List<LatLng>>[];
  for (final r in decoded) {
    if (r is! List) continue;
    final ring = <LatLng>[];
    for (final pair in r) {
      if (pair is! List || pair.length < 2) continue;
      final la = pair[0], lo = pair[1];
      if (la is! num || lo is! num) continue;
      final lat = la.toDouble(), lng = lo.toDouble();
      if (!lat.isFinite || !lng.isFinite) continue;
      ring.add(LatLng(lat, lng));
    }
    if (ring.length >= 3) out.add(ring);
  }
  return out;
}

// --- The pipeline -----------------------------------------------------------

/// Isolate-transferable input for [buildBorderAreas].
class BorderBuildRequest {
  const BorderBuildRequest({required this.relations, required this.box});

  final List<BorderRelationData> relations;
  final LatLngBox box;
}

/// One finished area, ready to be written as a `border_areas` row.
class BuiltBorderArea {
  const BuiltBorderArea({
    required this.osmId,
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.labelLat,
    required this.labelLng,
    required this.pointCount,
    required this.rings,
    required this.wayIds,
  });

  final int osmId;
  final String? name;
  final double south, west, north, east;
  final double labelLat, labelLng;
  final int pointCount;

  /// [encodeRings] output.
  final String rings;
  final List<int> wayIds;
}

/// Assemble → clip → simplify, for every relation in one go. Runs in a
/// `compute()` isolate: a state-level import is 119 238 points through RDP,
/// which is not something to do on the UI thread.
///
/// Colouring is deliberately **not** here: it has to run over every area in the
/// layer (including ones already stored from an earlier import), which is a
/// database read — see [assignAreaColors] and the repository's recolour step.
List<BuiltBorderArea> buildBorderAreas(BorderBuildRequest req) {
  final out = <BuiltBorderArea>[];
  for (final rel in req.relations) {
    final assembled = assembleRings(rel.ways);
    final clipped = clipRingsToBox(assembled, req.box);
    final rings = <List<LatLng>>[];
    for (final r in clipped) {
      final s = simplifyRing(r, kImportSimplifyMeters, minPoints: 3);
      if (s.length >= 3) rings.add(s);
    }
    // An area whose every ring fell outside the box isn't in this import.
    if (rings.isEmpty) continue;

    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    var points = 0;
    for (final r in rings) {
      points += r.length;
      for (final p in r) {
        if (p.latitude < south) south = p.latitude;
        if (p.latitude > north) north = p.latitude;
        if (p.longitude < west) west = p.longitude;
        if (p.longitude > east) east = p.longitude;
      }
    }
    final anchor = labelAnchor(rings);
    out.add(BuiltBorderArea(
      osmId: rel.osmId,
      name: rel.name,
      south: south,
      west: west,
      north: north,
      east: east,
      labelLat: anchor.latitude,
      labelLng: anchor.longitude,
      pointCount: points,
      rings: encodeRings(rings),
      wayIds: rel.wayIds,
    ));
  }
  return out;
}

/// Total points across [areas] — the import's headline cost, denormalised onto
/// the set row.
int totalPointCount(Iterable<BuiltBorderArea> areas) =>
    areas.fold(0, (a, x) => a + x.pointCount);

/// Whether [p] lies on one of [box]'s four edges, to within [epsilon] degrees.
///
/// The painter skips outline segments whose **both** endpoints answer true:
/// those edges are where the import cut the boundary, not a real border, and
/// drawing them would put a confident straight line through the middle of a
/// municipality. Same trick as the height layer's bounding-circle arcs.
bool onBoxEdge(LatLng p, LatLngBox box, double epsilon) =>
    (p.latitude - box.south).abs() <= epsilon ||
    (p.latitude - box.north).abs() <= epsilon ||
    (p.longitude - box.west).abs() <= epsilon ||
    (p.longitude - box.east).abs() <= epsilon;
