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

import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Spherical geometry on the unit sphere (ECEF unit vectors), used to build the
/// subspace regions geodesically: the set of points equidistant from two
/// points is a **great circle**, not a straight screen-space line. Working in
/// lat/lng here (then projecting to screen in the painter) mirrors how
/// [geodesicCircle] already builds circles.
///
/// Pure Dart, no flutter_map dependency, so it is directly unit-testable.

/// A 3-vector on (or scaled from) the unit sphere. ECEF-style: x toward
/// (lat 0, lng 0), y toward (lat 0, lng 90°E), z toward the north pole.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  double get length => sqrt(x * x + y * y + z * z);

  /// Unit vector; returns the zero vector when the length is ~0.
  Vec3 normalized() {
    final l = length;
    return l < 1e-12 ? const Vec3(0, 0, 0) : Vec3(x / l, y / l, z / l);
  }

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;
}

const double _deg2rad = pi / 180.0;
const double _rad2deg = 180.0 / pi;

/// Unit ECEF vector for [p].
Vec3 ecef(LatLng p) {
  final lat = p.latitude * _deg2rad;
  final lng = p.longitude * _deg2rad;
  final cosLat = cos(lat);
  return Vec3(cosLat * cos(lng), cosLat * sin(lng), sin(lat));
}

/// Lat/lng for the (not necessarily unit) vector [v].
LatLng toLatLng(Vec3 v) {
  final u = v.normalized();
  final lat = asin(u.z.clamp(-1.0, 1.0)) * _rad2deg;
  final lng = atan2(u.y, u.x) * _rad2deg;
  return LatLng(lat, lng);
}

/// Signed band threshold for a metric half-width [bandMeters]: a point that far
/// (along the surface) from the bisector great circle has `P·m == sin(band/R)`.
double bandThreshold(double bandMeters) {
  if (!bandMeters.isFinite || bandMeters <= 0) return 0;
  return sin(bandMeters / earthRadius);
}

/// The half-space `{ P : P·m ≥ threshold }` — with `threshold == 0` the side of
/// the great circle perpendicular to [m] that [m] points into; a positive /
/// negative threshold moves the boundary toward / away from [m] onto the
/// parallel small circle (the uncertainty band).
class _HalfSpace {
  const _HalfSpace(this.m, this.threshold);
  final Vec3 m;
  final double threshold;

  /// The latitudes of the meridian at [lngDeg] that lie in this half-space, as
  /// `[lo, hi]` intervals (usually one, at most two), empty for none.
  ///
  /// Along a meridian `P·m = A·cos(lat) + B·sin(lat)` with `A = m.x·cos λ +
  /// m.y·sin λ` and `B = m.z` — one sinusoid in `lat`, `R·cos(lat − φ)`. So
  /// `P·m ≥ t` is one arc of the full circle, `|lat − φ| ≤ acos(t/R)`, and its
  /// intersection with the meridian's `[−90, 90]` is one interval — or two,
  /// when the arc wraps in from both ends. That happens for a bisector that is
  /// nearly a meridian, seen from its far side, with the band grown *outward*:
  /// both polar ends of the meridian lie within the band of the divide (the
  /// poles are on a meridian bisector). Real, but within `band` metres of a
  /// pole, so past the Mercator limit for any band under ~500 km.
  List<_Interval> latIntervals(double lngDeg) {
    final lng = lngDeg * _deg2rad;
    final a = m.x * cos(lng) + m.y * sin(lng);
    final b = m.z;
    final r = sqrt(a * a + b * b);
    if (r < 1e-12) return const []; // m is the pole itself: no crossing
    final c = threshold / r;
    if (c > 1) return const []; // the band pushed the boundary off the sphere
    if (c < -1) return const [_Interval(-90, 90)]; // ...or over all of it
    final phi = atan2(b, a) * _rad2deg; // where P·m peaks on this meridian
    final w = acos(c) * _rad2deg; // half-width of the arc, 0…180
    final out = <_Interval>[];
    for (final shift in const [-360.0, 0.0, 360.0]) {
      final lo = max(phi + shift - w, -90.0);
      final hi = min(phi + shift + w, 90.0);
      if (lo <= hi) out.add(_Interval(lo, hi));
    }
    return out;
  }
}

/// A closed latitude interval.
class _Interval {
  const _Interval(this.lo, this.hi);
  final double lo, hi;
}

/// A sampled meridian of the cell: the latitudes `[lo, hi]` of the box's
/// column at [lng] that lie in every half-space, or `lo > hi` when none do.
class _Column {
  const _Column(this.lng, this.lo, this.hi);
  final double lng, lo, hi;
  bool get filled => lo <= hi;
}

/// Builds the geodesic Voronoi cell of [main] against [others] inside the
/// lat/lng box spanned by [viewportCorners] — the four corners of the painter's
/// (generous, world-clamped) view bound, with **continuous** longitudes — as
/// lat/lng rings in that same longitude frame. This is the shared core of both
/// the plane (one "other") and subspace (N "others") regions.
///
/// Each of `outer` and `core` is a **list of rings**: a cell is one piece in
/// any view narrower than the world, but a world-wide box cuts the hemisphere
/// closer to [main] at the antimeridian seam, and the two ends of the box then
/// hold the two halves of one region — both are drawn.
///
/// One of `outer`/`core` is always the **strict cell** (the true "closer to
/// [main]" region, whose boundary is the equidistant divide the engine outlines)
/// and the other offsets it by [bandMeters] to make the uncertainty band as
/// `outer − core`. With `bandInward` false, `core` is the strict cell and
/// `outer` grows **outward**, so the band lies on the divide's outside; with
/// `bandInward: true`, `outer` is the strict cell and `core` is it shrunk
/// **inward**, putting the band on the divide's inside. Either way the divide
/// itself — the ring the engine outlines — does not move.
///
/// The painter picks the direction so the band always falls on the *coloured*
/// side (inward for a normal layer, outward for an inverted one, whose fill is
/// the complement). Returns empty rings when there are no others, a point
/// coincides with [main], or the geometry is non-finite.
///
/// **How it is built.** A great circle (or a small circle parallel to it)
/// crosses every meridian in one contiguous arc, so on each meridian the
/// half-space "closer to [main] than to Pⱼ" is one latitude interval; the cell's
/// slice of that meridian is the intersection of those intervals with the box
/// (`max` of the lower ends, `min` of the upper). The box is sampled at
/// longitudes [minColumns] wide, refined wherever the slice's ends jump between
/// neighbours — a divide that is nearly a meridian is steep in this
/// parametrisation — and wherever a slice appears or vanishes (the cell pinches
/// off), and every maximal run of filled columns becomes one ring: along the
/// upper ends eastward, back along the lower ends. The rings' box edges lie
/// outside the viewport by construction (the bound is grown 75 % past it), so
/// only the divide is ever seen.
///
/// This replaces Sutherland–Hodgman on the sphere. That was right while the
/// clip box fitted in a hemisphere, but a box wider than that has no "inside":
/// its edges crossed the divide only at the seam, and the two crossings were
/// joined by the *short* arc — a strip across the world instead of the cell.
/// Working in a longitude-continuous lat/lng frame has no such limit, and a
/// cell across the antimeridian comes out as one simple polygon.
({List<List<LatLng>> outer, List<List<LatLng>> core}) sphericalCell({
  required LatLng main,
  required List<LatLng> others,
  required double bandMeters,
  required List<LatLng> viewportCorners,
  bool bandInward = false,
  int minColumns = 128,
}) {
  const empty = (outer: <List<LatLng>>[], core: <List<LatLng>>[]);
  if (others.isEmpty || viewportCorners.length < 3) return empty;
  final mainV = ecef(main);
  if (!mainV.isFinite) return empty;

  var minLat = double.infinity, maxLat = double.negativeInfinity;
  var minLng = double.infinity, maxLng = double.negativeInfinity;
  for (final c in viewportCorners) {
    if (!c.latitude.isFinite || !c.longitude.isFinite) return empty;
    minLat = min(minLat, c.latitude);
    maxLat = max(maxLat, c.latitude);
    minLng = min(minLng, c.longitude);
    maxLng = max(maxLng, c.longitude);
  }
  if (maxLat <= minLat || maxLng <= minLng) return empty;

  // Bisector pole directions, one per other point.
  final mList = <Vec3>[];
  for (final o in others) {
    final ov = ecef(o);
    if (!ov.isFinite) continue; // skip an invalid point
    final m = (mainV - ov).normalized();
    if (m.length < 1e-9) return empty; // coincident with main -> undefined cell
    mList.add(m);
  }
  if (mList.isEmpty) return empty;

  // The band is a **fixed** offset of the divide — every bisector is pushed by
  // the same [bandMeters], so the halo is uniformly that wide on all sides
  // regardless of how near each neighbour is. One ring is the strict cell
  // (threshold 0); the other is offset by ±s. Outward (default) grows the cell,
  // inward shrinks it — the divide stays put either way.
  final s = bandThreshold(bandMeters);
  final outerThresh = bandInward ? 0.0 : -s;
  final coreThresh = bandInward ? s : 0.0;
  final box = (minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  return (
    outer: _envelopeRings(
      [for (final m in mList) _HalfSpace(m, outerThresh)],
      box,
      minColumns,
    ),
    core: _envelopeRings(
      [for (final m in mList) _HalfSpace(m, coreThresh)],
      box,
      minColumns,
    ),
  );
}

typedef _Box = ({double minLat, double maxLat, double minLng, double maxLng});

/// The rings of `box ∩ ⋂ halfSpaces` (see [sphericalCell]).
List<List<LatLng>> _envelopeRings(
  List<_HalfSpace> halfSpaces,
  _Box box,
  int minColumns,
) {
  _Column column(double lng) {
    // Intersect interval *sets*: a half-space can hand back two polar pieces
    // (see [_HalfSpace.latIntervals]), and taking their hull would fill the
    // whole column for a meridian divide seen from its far side, where both
    // pieces are just the poles. The box clamp then drops what is past the
    // Mercator limit; should two pieces survive that (a band over ~500 km),
    // the longer one is the column.
    var current = <_Interval>[_Interval(box.minLat, box.maxLat)];
    for (final h in halfSpaces) {
      final pieces = h.latIntervals(lng);
      current = [
        for (final a in current)
          for (final b in pieces)
            if (max(a.lo, b.lo) <= min(a.hi, b.hi))
              _Interval(max(a.lo, b.lo), min(a.hi, b.hi)),
      ];
      if (current.isEmpty) return _Column(lng, 1, 0);
    }
    var best = current.first;
    for (final iv in current.skip(1)) {
      if (iv.hi - iv.lo > best.hi - best.lo) best = iv;
    }
    return _Column(lng, best.lo, best.hi);
  }

  final lngSpan = box.maxLng - box.minLng;
  // Stop refining below this: a divide that is exactly a meridian is a step
  // in this parametrisation, and the step is placed to within this much.
  final minStep = lngSpan / 4096;
  // Neighbouring columns whose ends differ by more than this get a column
  // between them, so a steep divide is traced, not cut across.
  final tol = (box.maxLat - box.minLat) / 256;

  final columns = <_Column>[];
  void refine(_Column a, _Column b) {
    if (b.lng - a.lng <= minStep) return;
    final needed =
        a.filled != b.filled ||
        (a.filled && ((a.lo - b.lo).abs() > tol || (a.hi - b.hi).abs() > tol));
    if (!needed) return;
    final mid = column((a.lng + b.lng) / 2);
    refine(a, mid);
    columns.add(mid);
    refine(mid, b);
  }

  var prev = column(box.minLng);
  columns.add(prev);
  for (var i = 1; i <= minColumns; i++) {
    final next = column(box.minLng + lngSpan * i / minColumns);
    refine(prev, next);
    columns.add(next);
    prev = next;
  }

  // Every maximal run of filled columns is one ring: eastward along the upper
  // ends, back westward along the lower ends. Between a filled column and an
  // empty neighbour the cell pinches to a point (the refinement above put
  // those two within `minStep` of each other), so the run closes there.
  final rings = <List<LatLng>>[];
  var start = -1;
  for (var i = 0; i <= columns.length; i++) {
    final filled = i < columns.length && columns[i].filled;
    if (filled && start < 0) start = i;
    if (!filled && start >= 0) {
      final ring = _ring(columns.sublist(start, i));
      if (ring.isNotEmpty) rings.add(ring);
      start = -1;
    }
  }
  return rings;
}

/// One ring from a run of filled columns, dropping the interior vertices of
/// straight horizontal stretches (long runs along the box's top or bottom).
List<LatLng> _ring(List<_Column> run) {
  final out = <LatLng>[];
  void add(double lat, double lng) {
    if (out.length >= 2) {
      final a = out[out.length - 2], b = out.last;
      if (a.latitude == b.latitude && b.latitude == lat) {
        out[out.length - 1] = LatLng(lat, lng);
        return;
      }
    }
    out.add(LatLng(lat, lng));
  }

  for (final c in run) {
    add(c.hi, c.lng);
  }
  for (final c in run.reversed) {
    add(c.lo, c.lng);
  }
  return out.length < 3 ? const <LatLng>[] : out;
}
