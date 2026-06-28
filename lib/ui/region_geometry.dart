import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../geo/geodesic.dart';

/// Caches the camera-independent (or slowly-changing) lat/lng geometry of the
/// non-freehand-area region types, so a pan/zoom only re-projects rings instead
/// of rebuilding them every frame. (Freehand areas have their own cache in
/// `area_geometry.dart`.)
///
/// Two strategies:
/// - **Circles** are fully camera-independent — `geodesicCircle` depends only on
///   centre and radius — so their rings are memoised by `(centre, radius)` and
///   reused forever (until the inputs change).
/// - **Planes / subspaces / freelines** are unbounded regions clipped to the
///   view, so their rings *do* depend on the camera. Instead of the live
///   viewport they're built against a **generous bound** (the viewport grown by
///   [_boundInflate]); the result is reused for every frame whose viewport still
///   fits inside that bound — i.e. across panning and moderate zoom — and only
///   rebuilt when the viewport escapes it (or the inputs change). The painter
///   already clips the projected paths to the real viewport, so the extra slack
///   never shows.

/// How far to grow the viewport when building bound-dependent geometry, as a
/// fraction of its size on each side. 0.75 ⇒ the bound is 2.5× the viewport in
/// each dimension, giving generous pan/zoom headroom before a rebuild.
const double _boundInflate = 0.75;

/// A lat/lng bounding box, used both as the clip bound for unbounded regions and
/// to test whether a cached result still covers the current view.
class ViewBound {
  const ViewBound(this.minLat, this.minLng, this.maxLat, this.maxLng);

  final double minLat, minLng, maxLat, maxLng;

  factory ViewBound.ofCorners(List<LatLng> corners) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final c in corners) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }
    return ViewBound(minLat, minLng, maxLat, maxLng);
  }

  /// Whether this box fully contains [v].
  bool contains(ViewBound v) =>
      minLat <= v.minLat &&
      maxLat >= v.maxLat &&
      minLng <= v.minLng &&
      maxLng >= v.maxLng;

  ViewBound inflated(double f) {
    final dLat = (maxLat - minLat) * f;
    final dLng = (maxLng - minLng) * f;
    return ViewBound(
        minLat - dLat, minLng - dLng, maxLat + dLat, maxLng + dLng);
  }

  /// The four corners in NW, NE, SE, SW order (a convex ring) for clip quads.
  List<LatLng> get quad => [
        LatLng(maxLat, minLng),
        LatLng(maxLat, maxLng),
        LatLng(minLat, maxLng),
        LatLng(minLat, minLng),
      ];

  LatLng get center => LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

  bool containsPoint(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLng &&
      p.longitude <= maxLng;

  static const Distance _distance = Distance(calculator: Haversine());

  /// Diagonal length in metres — a characteristic size for freeline extension.
  double get diagonalMeters => _distance.as(
      LengthUnit.Meter, LatLng(minLat, minLng), LatLng(maxLat, maxLng));
}

/// The `outer`/`core` ring pair every band region resolves to.
typedef Rings = ({List<LatLng> outer, List<LatLng> core});

/// App-wide cache; a memo keyed by content signature, so it survives the
/// per-frame widget/painter rebuilds.
final regionGeometryCache = RegionGeometryCache();

class RegionGeometryCache {
  final Map<String, List<LatLng>> _circles = {};
  final Map<String, _BoundEntry> _bound = {};

  /// A geodesic circle ring, memoised by centre+radius (camera-independent).
  List<LatLng> circleRing(LatLng center, double radiusMeters, int points) {
    final key = '${center.latitude}|${center.longitude}|$radiusMeters|$points';
    final hit = _circles[key];
    if (hit != null) return hit;
    if (_circles.length > 4000) _circles.clear(); // bound memory
    return _circles[key] = geodesicCircle(center, radiusMeters, points: points);
  }

  /// Rings for an unbounded region [id], rebuilt only when [signature] changes
  /// or the cached bound no longer covers [viewport]. [build] receives the
  /// (generous) bound to clip/extend against.
  Rings boundRegion(
    String id,
    String signature,
    ViewBound viewport,
    Rings Function(ViewBound bound) build,
  ) {
    final e = _bound[id];
    if (e != null &&
        e.signature == signature &&
        e.bound.contains(viewport)) {
      return e.rings;
    }
    final bound = viewport.inflated(_boundInflate);
    final rings = build(bound);
    _bound[id] = _BoundEntry(signature, bound, rings);
    return rings;
  }
}

class _BoundEntry {
  const _BoundEntry(this.signature, this.bound, this.rings);
  final String signature;
  final ViewBound bound;
  final Rings rings;
}

/// The inclusion circle that bounds a freehand line to a clean half-disk. Uses
/// the stored [lat]/[lng]/[radiusMeters] when all are present and the radius is
/// positive; otherwise derives a sensible default from the line's own [points]
/// — centred on their bounding-box midpoint with a radius covering the line
/// (`diagonal * 0.75`, never below [_minDerivedRadius]). Legacy rows (no stored
/// circle) thus still render as a bounded half-disk.
({LatLng center, double radiusMeters}) effectiveInclusion({
  required double? lat,
  required double? lng,
  required double? radiusMeters,
  required List<LatLng> points,
}) {
  if (lat != null &&
      lng != null &&
      radiusMeters != null &&
      lat.isFinite &&
      lng.isFinite &&
      radiusMeters.isFinite &&
      radiusMeters > 0) {
    return (center: LatLng(lat, lng), radiusMeters: radiusMeters);
  }
  final bound = ViewBound.ofCorners(points);
  final r = math.max(bound.diagonalMeters * 0.75, _minDerivedRadius);
  return (center: bound.center, radiusMeters: r);
}

/// Floor for a derived inclusion radius, so a tiny drawn line still gets a
/// usable disk.
const double _minDerivedRadius = 300;

/// A cheap order-sensitive hash of [points], for cache signatures.
int hashPoints(Iterable<LatLng> points) {
  var h = 17;
  for (final p in points) {
    h = 0x1fffffff & (h * 31 + p.latitude.hashCode);
    h = 0x1fffffff & (h * 31 + p.longitude.hashCode);
  }
  return h;
}
