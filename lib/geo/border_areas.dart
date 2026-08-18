import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../data/borders.dart';
import 'simplify.dart';

/// Geometry for the `borders` layer: stitch an OSM relation's member ways into
/// closed rings, thin them, and colour the areas so no two neighbours match.
///
/// **Nothing is cut to the imported box.** The box bounds what is *asked for*,
/// not what is kept: if a boundary came down, you get all of it, even where that
/// means an area extending well past the box you drew. Clipping used to happen
/// here, and it was wrong twice over — it threw away data already paid for, and
/// it left straight fake edges the painter then had to recognise and hide.
///
/// Pure Dart — no Flutter, no drift — so [buildBorderAreas] runs inside a
/// `compute()` isolate (the precedent being `data/height_generator.dart`), and
/// every step here is directly unit-testable.

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

/// Assemble → simplify, for every relation in one go. Runs in a `compute()`
/// isolate: a state-level import is 119 238 points through RDP, which is not
/// something to do on the UI thread.
///
/// Nothing is clipped — see this file's header. Colouring is deliberately not
/// here either: it has to run over every area in the layer (including ones
/// already stored from an earlier import), which is a database read — see
/// [assignAreaColors] and the repository's recolour step.
List<BuiltBorderArea> buildBorderAreas(List<BorderRelationData> relations) {
  final out = <BuiltBorderArea>[];
  for (final rel in relations) {
    final rings = <List<LatLng>>[];
    for (final r in assembleRings(rel.ways)) {
      final s = simplifyRing(r, kImportSimplifyMeters, minPoints: 3);
      if (s.length >= 3) rings.add(s);
    }
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

/// Groups a flat ring list into GeoJSON-shaped polygons: each entry is one
/// outer ring followed by the rings that fall inside it.
///
/// Stored rings carry **no** outer/hole flag, and don't need one — the painter
/// fills even-odd (see `BorderAreas.rings`). GeoJSON does need one: a
/// `Polygon`'s first ring is its outside and the rest are its holes, so an area
/// with two exclaves has to become a `MultiPolygon` or the second island reads
/// as a hole punched in the first.
///
/// A hole nested two deep (an island inside a lake inside an island) is
/// attached to the outer ring that encloses it, which even-odd draws correctly
/// either way. Flattening the result back gives exactly the input ring list, so
/// an export/import round-trip is lossless regardless.
List<List<List<LatLng>>> groupRings(List<List<LatLng>> rings) {
  final usable = [
    for (final r in rings)
      if (r.length >= 3) r,
  ];
  if (usable.length < 2) return [for (final r in usable) [r]];
  final polys = <List<List<LatLng>>>[];
  final outerAt = <int, int>{}; // ring index -> polygon index
  for (var i = 0; i < usable.length; i++) {
    if (_isEnclosed(usable[i], usable, i)) continue;
    outerAt[i] = polys.length;
    polys.add([usable[i]]);
  }
  // Every ring was enclosed by another (rings crossing, or a corrupt row):
  // fall back to one polygon per ring rather than losing geometry.
  if (polys.isEmpty) return [for (final r in usable) [r]];
  for (var i = 0; i < usable.length; i++) {
    if (outerAt.containsKey(i)) continue;
    var target = 0;
    for (final e in outerAt.entries) {
      if (_containsPoint(usable[e.key], usable[i].first)) {
        target = e.value;
        break;
      }
    }
    polys[target].add(usable[i]);
  }
  return polys;
}

/// The rings of an area that are **not** holes: those not enclosed by another
/// ring of the same area.
///
/// The stored geometry carries no role flag, because the painter fills with
/// even-odd parity and doesn't need one. Converting to a freehand area does
/// need one, though — a freehand area is a single ring with no notion of a
/// hole, so a hole exported as its own area would render as solid fill exactly
/// where the real area has a gap. Containment recovers what the role flag would
/// have said, and an exclave (a second outer ring) survives as its own area.
List<List<LatLng>> outerRings(List<List<LatLng>> rings) {
  if (rings.length < 2) return rings;
  return [
    for (var i = 0; i < rings.length; i++)
      if (!_isEnclosed(rings[i], rings, i)) rings[i],
  ];
}

bool _isEnclosed(List<LatLng> ring, List<List<LatLng>> all, int self) {
  // One vertex decides it: rings of one area never cross, so a ring is either
  // wholly inside another or wholly outside it.
  final probe = ring.first;
  for (var j = 0; j < all.length; j++) {
    if (j == self || all[j].length < 3) continue;
    if (_containsPoint(all[j], probe)) return true;
  }
  return false;
}

/// Total points across [areas] — the import's headline cost, denormalised onto
/// the set row.
int totalPointCount(Iterable<BuiltBorderArea> areas) =>
    areas.fold(0, (a, x) => a + x.pointCount);
