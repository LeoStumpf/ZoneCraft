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

import 'package:latlong2/latlong.dart';

import '../geo/freeline.dart';
import '../geo/geodesic.dart';
import '../geo/measure.dart';
import '../geo/tiles.dart';

/// Caches the camera-independent (or slowly-changing) lat/lng geometry of the
/// non-freehand-area region types, so a pan/zoom only re-projects rings instead
/// of rebuilding them every frame. (Freehand areas have their own cache in
/// `area_geometry.dart`.)
///
/// Two strategies:
/// - **Circles** are fully camera-independent — `geodesicCircle` depends only on
///   centre and radius — so their rings are memoised by `(centre, radius)` and
///   reused forever (until the inputs change).
/// - **Subspaces** are unbounded regions clipped to the view, so their rings
///   *do* depend on the camera. Instead of the live viewport they're built
///   against a **generous bound** (the viewport grown by [_boundInflate], then
///   clamped to the drawable world — [ViewBound.clampedToWorld]); the result is
///   reused for every frame whose viewport still fits inside that bound — i.e.
///   across panning and moderate zoom — and only rebuilt when the viewport
///   escapes it (or the inputs change). The painter already clips the projected
///   paths to the real viewport, so the extra slack never shows. Zoomed out far
///   enough the bound *is* the world, and nothing rebuilds it again.

/// How far to grow the viewport when building bound-dependent geometry, as a
/// fraction of its size on each side. 0.75 ⇒ the bound is 2.5× the viewport in
/// each dimension, giving generous pan/zoom headroom before a rebuild.
const double _boundInflate = 0.75;

/// How much smaller than its bound a view may get before the cached rings are
/// rebuilt: a bound is 2.5× the view that built it, so this allows two zoom
/// levels in. The rings are sampled to look right at the zoom they were built
/// for (and the world-sized bound of a zoom-2 view *contains* every later
/// view), so without this a street-level view would be drawn from a divide
/// sampled every few hundred kilometres.
const double _maxBoundToViewRatio = 10;

/// How far short of a full 360° [ViewBound.clampedToWorld] stops. At exactly
/// 360° the box's west and east edges are the same meridian, and a vertex on
/// that seam has two longitudes 360° apart at equal distance from the centre —
/// the unwrap in `sphericalCell` could then pick the wrong world copy for the
/// whole ring. A hundredth of a degree (0.03 px at zoom 2) keeps them distinct.
const double _worldLngSpan = 360 - 0.01;

/// A lat/lng bounding box, used both as the clip bound for unbounded regions and
/// to test whether a cached result still covers the current view.
///
/// Longitudes are **continuous, not wrapped**: a box straddling the
/// antimeridian runs e.g. 170…190, never 170…−170 (see `viewportCorners`).
/// [contains] compares the other box in this box's frame, so a box built one
/// world copy over still covers it.
class ViewBound {
  const ViewBound(this.minLat, this.minLng, this.maxLat, this.maxLng);

  final double minLat, minLng, maxLat, maxLng;

  factory ViewBound.ofCorners(List<LatLng> corners) {
    var minLat = double.infinity, maxLat = double.negativeInfinity;
    var minLng = double.infinity, maxLng = double.negativeInfinity;
    for (final c in corners) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }
    return ViewBound(minLat, minLng, maxLat, maxLng);
  }

  /// Whether this box fully contains [v], with [v] shifted by whole worlds in
  /// longitude to sit nearest this box's centre first.
  bool contains(ViewBound v) => shiftToContain(v) != null;

  /// The multiple of 360° to add to this box's longitudes so that it contains
  /// [v] — 0 while both sit in the same world copy — or null when it does not
  /// contain [v] in any copy. flutter_map jumps the camera centre from 180 to
  /// −180 (and back) as you pan across the antimeridian, so a view centred at
  /// 175 is still covered by a bound built one frame earlier around −175, only
  /// a world to the east.
  double? shiftToContain(ViewBound v) {
    final shift =
        ((v.center.longitude - center.longitude) / 360).round() * 360.0;
    final fits =
        minLat <= v.minLat &&
        maxLat >= v.maxLat &&
        minLng + shift <= v.minLng &&
        maxLng + shift >= v.maxLng;
    return fits ? shift : null;
  }

  /// This box moved [dLng] degrees east.
  ViewBound shiftedLng(double dLng) =>
      ViewBound(minLat, minLng + dLng, maxLat, maxLng + dLng);

  /// This box grown by [f] of its size on each side, then clamped to the
  /// drawable world ([clampedToWorld]).
  ViewBound inflated(double f) {
    final dLat = (maxLat - minLat) * f;
    final dLng = (maxLng - minLng) * f;
    return ViewBound(
      minLat - dLat,
      minLng - dLng,
      maxLat + dLat,
      maxLng + dLng,
    ).clampedToWorld();
  }

  /// This box cut down to what Web Mercator can show: latitudes within
  /// ±[mercatorMaxLat], and a longitude span of at most one world
  /// ([_worldLngSpan]) centred where the box was. Growing a zoom-2 viewport by
  /// 75 % gives lat −192…+207 and lng −176…+200; fed to `ecef` those fold over
  /// the pole into a small quad on the far side of the globe, and the cell
  /// clipped to it vanished or drew as a strip.
  ViewBound clampedToWorld() {
    var lo = minLng, hi = maxLng;
    if (hi - lo > _worldLngSpan) {
      final c = (lo + hi) / 2;
      lo = c - _worldLngSpan / 2;
      hi = c + _worldLngSpan / 2;
    }
    return ViewBound(
      minLat.clamp(-mercatorMaxLat, mercatorMaxLat),
      lo,
      maxLat.clamp(-mercatorMaxLat, mercatorMaxLat),
      hi,
    );
  }

  /// The four corners in NW, NE, SE, SW order (a convex ring) for clip quads.
  List<LatLng> get quad => [
    LatLng(maxLat, minLng),
    LatLng(maxLat, maxLng),
    LatLng(minLat, maxLng),
    LatLng(minLat, minLng),
  ];

  LatLng get center => LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

  double get latSpan => maxLat - minLat;
  double get lngSpan => maxLng - minLng;

  bool containsPoint(LatLng p) =>
      p.latitude >= minLat &&
      p.latitude <= maxLat &&
      p.longitude >= minLng &&
      p.longitude <= maxLng;

  static const Distance _distance = Distance(calculator: Haversine());

  /// Diagonal length in metres — a characteristic size for freeline extension.
  double get diagonalMeters => _distance.as(
    LengthUnit.Meter,
    LatLng(minLat, minLng),
    LatLng(maxLat, maxLng),
  );
}

/// The `outer`/`core` rings every band region resolves to — each a list of
/// rings, because a world-wide view cuts a cell at the antimeridian into two.
typedef Rings = ({List<List<LatLng>> outer, List<List<LatLng>> core});

/// App-wide cache; a memo keyed by content signature, so it survives the
/// per-frame widget/painter rebuilds.
final regionGeometryCache = RegionGeometryCache();

class RegionGeometryCache {
  final Map<String, List<LatLng>> _circles = {};
  final Map<String, _BoundEntry> _bound = {};
  final Map<String, _RingsEntry> _halfDisk = {};

  /// A geodesic circle ring, memoised by centre+radius (camera-independent).
  List<LatLng> circleRing(LatLng center, double radiusMeters, int points) {
    final key = '${center.latitude}|${center.longitude}|$radiusMeters|$points';
    final hit = _circles[key];
    if (hit != null) return hit;
    if (_circles.length > 4000) _circles.clear(); // bound memory
    return _circles[key] = geodesicCircle(center, radiusMeters, points: points);
  }

  /// Cut runs for a freehand line [id], memoised by [signature]. The split is
  /// camera-independent (it depends only on the line, circle, offset and band),
  /// so a heavy imported river is re-split only when its inputs change — a
  /// pan/zoom just re-projects the cached runs.
  FreeLineRegion halfDisk(
    String id,
    String signature,
    FreeLineRegion Function() build,
  ) {
    final e = _halfDisk[id];
    if (e != null && e.signature == signature) return e.region;
    final region = build();
    _halfDisk[id] = _RingsEntry(signature, region);
    return region;
  }

  /// Rings for an unbounded region [id], rebuilt only when [signature] changes,
  /// the cached bound no longer covers [viewport], or [viewport] has zoomed in
  /// far past the bound's sampling ([_maxBoundToViewRatio]). [build] receives
  /// the (generous, world-clamped) bound to clip/extend against.
  ///
  /// The viewport is clamped to the drawable world first: a zoom-2 view reaches
  /// past the Mercator limit (its corners unproject to lat ±90), and a bound —
  /// itself clamped — could never contain that, so every frame would rebuild.
  Rings boundRegion(
    String id,
    String signature,
    ViewBound viewport,
    Rings Function(ViewBound bound) build,
  ) {
    viewport = viewport.clampedToWorld();
    final e = _bound[id];
    if (e != null &&
        e.signature == signature &&
        e.bound.lngSpan <= viewport.lngSpan * _maxBoundToViewRatio &&
        e.bound.latSpan <= viewport.latSpan * _maxBoundToViewRatio) {
      final shift = e.bound.shiftToContain(viewport);
      if (shift == 0) return e.rings;
      if (shift != null) {
        // Same geometry, one world copy over: the camera centre wrapped across
        // the antimeridian. Re-frame the entry instead of rebuilding it.
        final moved = _BoundEntry(signature, e.bound.shiftedLng(shift), (
          outer: [for (final r in e.rings.outer) _shiftRing(r, shift)],
          core: [for (final r in e.rings.core) _shiftRing(r, shift)],
        ));
        _bound[id] = moved;
        return moved.rings;
      }
    }
    final bound = viewport.inflated(_boundInflate);
    final rings = build(bound);
    _bound[id] = _BoundEntry(signature, bound, rings);
    return rings;
  }

  static List<LatLng> _shiftRing(List<LatLng> ring, double dLng) => [
    for (final p in ring) LatLng(p.latitude, p.longitude + dLng),
  ];
}

class _BoundEntry {
  const _BoundEntry(this.signature, this.bound, this.rings);
  final String signature;
  final ViewBound bound;
  final Rings rings;
}

class _RingsEntry {
  const _RingsEntry(this.signature, this.region);
  final String signature;
  final FreeLineRegion region;
}

/// The inclusion circle that bounds a freehand line to a clean half-disk. Uses
/// the stored [lat]/[lng]/[radiusMeters] when all are present and the radius is
/// positive; otherwise derives a **local, visible** default from the line's own
/// [points] — centred on the line's arc-length midpoint (always a point *on* the
/// line) with a radius of `diagonal * 0.75` clamped to
/// `[_minDerivedRadius, _maxDerivedRadius]`. The clamp matters for imports: a
/// whole-river line (hundreds of km) would otherwise derive a continent-sized
/// circle far off the river, so the visible area falls entirely on one side.
/// Centring on the line and capping the radius keeps the split visible; the user
/// then moves/resizes the circle to their area of interest.
({LatLng center, double radiusMeters}) effectiveInclusion({
  required double? lat,
  required double? lng,
  required double? radiusMeters,
  required List<LatLng> points,
}) {
  // Use whichever parts are stored and derive only the missing ones, so editing
  // just the centre (move-centre leaves the radius null) or just the radius
  // takes effect instead of silently falling back to the fully-derived circle.
  final hasCenter = lat != null && lng != null && lat.isFinite && lng.isFinite;
  final hasRadius =
      radiusMeters != null && radiusMeters.isFinite && radiusMeters > 0;
  final center = hasCenter ? LatLng(lat, lng) : _arcMidpoint(points);
  final r = hasRadius
      ? radiusMeters
      : (ViewBound.ofCorners(points).diagonalMeters * 0.75)
            .clamp(_minDerivedRadius, _maxDerivedRadius)
            .toDouble();
  return (center: center, radiusMeters: r);
}

/// The point halfway along [pts] by ground distance — always *on* the line, so a
/// derived inclusion circle sits over the line rather than over its (possibly
/// far-off) bounding-box centre.
LatLng _arcMidpoint(List<LatLng> pts) {
  if (pts.length < 2) return pts.first;
  const d = Distance(calculator: Haversine());
  final half = polylineLengthMeters(pts) / 2;
  var acc = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final seg = d(pts[i], pts[i + 1]);
    if (acc + seg >= half) {
      final t = seg > 0 ? (half - acc) / seg : 0.0;
      return LatLng(
        pts[i].latitude + (pts[i + 1].latitude - pts[i].latitude) * t,
        pts[i].longitude + (pts[i + 1].longitude - pts[i].longitude) * t,
      );
    }
    acc += seg;
  }
  return pts.last;
}

/// Floor for a derived inclusion radius, so a tiny drawn line still gets a
/// usable disk.
const double _minDerivedRadius = 300;

/// Cap for a derived inclusion radius, so a whole-river import stays a local,
/// visible circle rather than a continent-sized one.
const double _maxDerivedRadius = 5000;

/// A cheap order-sensitive hash of [points], for cache signatures.
int hashPoints(Iterable<LatLng> points) {
  var h = 17;
  for (final p in points) {
    h = 0x1fffffff & (h * 31 + p.latitude.hashCode);
    h = 0x1fffffff & (h * 31 + p.longitude.hashCode);
  }
  return h;
}
