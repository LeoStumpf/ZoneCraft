import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Spherical geometry on the unit sphere (ECEF unit vectors), used to build the
/// plane/subspace regions geodesically: the set of points equidistant from two
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

/// Spherical-linear interpolation between unit vectors [a] and [b] at [t].
Vec3 slerp(Vec3 a, Vec3 b, double t) {
  final d = a.dot(b).clamp(-1.0, 1.0);
  final omega = acos(d);
  if (omega < 1e-9) return a; // coincident / antipodal-safe: just return a
  final s = sin(omega);
  final wa = sin((1 - t) * omega) / s;
  final wb = sin(t * omega) / s;
  return (a * wa + b * wb).normalized();
}

/// Densifies a closed ring of unit vectors into a LatLng ring, subdividing every
/// edge along its great-circle arc so the projected polygon tracks the curve.
/// [segments] sample points are emitted per edge (start inclusive, end
/// exclusive) so the ring stays closed without duplicated vertices.
List<LatLng> densifyRing(List<Vec3> ring, {int segments = 20}) {
  if (ring.length < 3) return const <LatLng>[];
  final out = <LatLng>[];
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    for (var s = 0; s < segments; s++) {
      out.add(toLatLng(slerp(a, b, s / segments)));
    }
  }
  return out;
}

/// Clips the convex spherical polygon [poly] (unit vectors, consistent winding)
/// to the half-space `{ P : P·m ≥ threshold }`. With `threshold == 0`, the
/// boundary is the great circle perpendicular to [m]; a positive/negative
/// threshold is the small circle offset toward/away from [m] (used for the
/// uncertainty band). Returns the clipped vertices, empty if nothing survives.
List<Vec3> clipByPlane(List<Vec3> poly, Vec3 m, double threshold) {
  if (poly.isEmpty) return poly;
  double side(Vec3 q) => q.dot(m) - threshold;

  final out = <Vec3>[];
  for (var i = 0; i < poly.length; i++) {
    final cur = poly[i];
    final nxt = poly[(i + 1) % poly.length];
    final dc = side(cur);
    final dn = side(nxt);
    if (dc >= 0) out.add(cur);
    if ((dc >= 0) != (dn >= 0)) {
      out.add(_planeCrossing(cur, nxt, m, threshold));
    }
  }
  return out;
}

/// The point on the great-circle arc from [a] to [b] where `P·m == threshold`,
/// found by bisection in the slerp parameter. The arc crosses the (near-great)
/// small circle once when the endpoints straddle it.
Vec3 _planeCrossing(Vec3 a, Vec3 b, Vec3 m, double threshold) {
  double f(double t) => slerp(a, b, t).dot(m) - threshold;
  var lo = 0.0, hi = 1.0;
  final flo = f(lo);
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    final fmid = f(mid);
    if ((fmid >= 0) == (flo >= 0)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return slerp(a, b, (lo + hi) / 2);
}

/// Signed band threshold for a metric half-width [bandMeters]: a point that far
/// (along the surface) from the bisector great circle has `P·m == sin(band/R)`.
double bandThreshold(double bandMeters) {
  if (!bandMeters.isFinite || bandMeters <= 0) return 0;
  return sin(bandMeters / earthRadius);
}

/// Builds the geodesic Voronoi cell of [main] against [others], clipped to the
/// spherical quad [viewportCorners], as densified lat/lng rings. This is the
/// shared core of both the plane (one "other") and subspace (N "others")
/// regions.
///
/// `outer` is the cell enlarged by the uncertainty half-band [bandMeters] (each
/// bisector pushed toward the other points), `core` the cell shrunk by it; the
/// engine paints the difference as the band. Returns empty rings when there are
/// no others, a point coincides with [main], or the geometry is non-finite.
({List<LatLng> outer, List<LatLng> core}) sphericalCell({
  required LatLng main,
  required List<LatLng> others,
  required double bandMeters,
  required List<LatLng> viewportCorners,
  int segments = 20,
}) {
  const empty = (outer: <LatLng>[], core: <LatLng>[]);
  if (others.isEmpty || viewportCorners.length < 3) return empty;
  final mainV = ecef(main);
  if (!mainV.isFinite) return empty;

  final quad = <Vec3>[];
  for (final c in viewportCorners) {
    final v = ecef(c);
    if (!v.isFinite) return empty; // a non-finite corner -> bail, don't draw
    quad.add(v);
  }

  // One bisector per other point: its pole [m] plus the signed band threshold
  // [s]. The band is clamped per bisector to **half the main–other distance**,
  // so widening the cell can never push its boundary past the neighbouring
  // site (which would wrongly engulf a point that is, by definition, closer to
  // itself). For well-separated points the clamp never binds.
  final planes = <({Vec3 m, double s})>[];
  for (final o in others) {
    final ov = ecef(o);
    if (!ov.isFinite) continue; // skip an invalid point
    final m = (mainV - ov).normalized();
    if (m.length < 1e-9) return empty; // coincident with main -> undefined cell
    final halfGap =
        acos(mainV.dot(ov).clamp(-1.0, 1.0)) * earthRadius / 2;
    final bandEff = bandMeters < halfGap ? bandMeters : halfGap;
    planes.add((m: m, s: bandThreshold(bandEff)));
  }
  if (planes.isEmpty) return empty;

  var outer = quad;
  var core = quad;
  for (final p in planes) {
    outer = clipByPlane(outer, p.m, -p.s);
    core = clipByPlane(core, p.m, p.s);
    if (outer.isEmpty && core.isEmpty) break;
  }
  return (
    outer: densifyRing(outer, segments: segments),
    core: densifyRing(core, segments: segments),
  );
}
