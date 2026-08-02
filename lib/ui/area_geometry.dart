import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart' hide Path;

import '../data/database.dart';

/// Zoom/pan-independent render geometry for a freehand area, resolved **once**
/// per change and cached. The painter then only projects these lat/lng rings to
/// screen and fills them — the expensive offset/band buffering never runs on the
/// per-frame paint path.
///
/// [core] is the nominal (offset) boundary — the outline, which never moves;
/// [bandEdge] is the band's far edge, i.e. where the solid fill starts: the
/// boundary shrunk **inward** by the uncertainty for a normal layer, or grown
/// **outward** for an inverted one (whose coloured side is the outside). Each is
/// a list of contours so holes and islands from an offset survive; fill them
/// with the even-odd rule.
class ResolvedArea {
  const ResolvedArea({required this.core, required this.bandEdge});

  final List<List<LatLng>> core;
  final List<List<LatLng>> bandEdge;

  bool get isEmpty => core.isEmpty;
}

/// Resolves one ring's render geometry. [offsetMeters] is the signed inward
/// offset (positive shrinks/erodes, negative grows/dilates); [bandMeters] the
/// uncertainty half-band; [inverted] whether the layer's fill is the complement
/// (then the band sits outside the boundary instead of inside).
///
/// The offset and band are computed as Minkowski erosion/dilation
/// (`ring ∓ buffer(boundary)`) in a local equirectangular metre plane via
/// `Path` ops, then the result contours are sampled back to lat/lng. This is
/// robust on concave, wrinkly outlines (a per-vertex walk self-crosses into
/// spikes/islands there) and, crucially, is independent of the camera so it can
/// be cached.
ResolvedArea resolveAreaGeometry(
  List<LatLng> ring, {
  required double offsetMeters,
  required double bandMeters,
  required bool inverted,
}) {
  final clean = <LatLng>[
    for (final p in ring)
      if (p.latitude.isFinite && p.longitude.isFinite) p,
  ];
  if (clean.length < 3) return const ResolvedArea(core: [], bandEdge: []);

  // Local equirectangular frame at the ring centroid — metres on the ground,
  // accurate enough over a city-sized span and reversible.
  var sumLat = 0.0, sumLon = 0.0;
  for (final p in clean) {
    sumLat += p.latitude;
    sumLon += p.longitude;
  }
  final lat0 = sumLat / clean.length;
  final lon0 = sumLon / clean.length;
  const mPerDegLat = 111320.0;
  final mPerDegLon = 111320.0 * math.cos(lat0 * math.pi / 180);
  if (mPerDegLon == 0) return const ResolvedArea(core: [], bandEdge: []);

  Offset toPlane(LatLng p) => Offset(
        (p.longitude - lon0) * mPerDegLon,
        (p.latitude - lat0) * mPerDegLat,
      );
  LatLng fromPlane(Offset o) =>
      LatLng(lat0 + o.dy / mPerDegLat, lon0 + o.dx / mPerDegLon);
  final base = [for (final p in clean) toPlane(p)];

  // Band edge: it bounds the *coloured* side, so it is inset further inward
  // (larger signed inset) normally and grown outward when inverted.
  final bandEdgeOffset = offsetMeters + (inverted ? -bandMeters : bandMeters);

  final core = offsetMeters == 0
      ? [List<LatLng>.of(clean)]
      : _offsetContours(base, offsetMeters, fromPlane);
  final bandEdge = bandMeters <= 0
      ? const <List<LatLng>>[]
      : (bandEdgeOffset == 0
          ? [List<LatLng>.of(clean)]
          : _offsetContours(base, bandEdgeOffset, fromPlane));

  return ResolvedArea(core: core, bandEdge: bandEdge);
}

/// The metre-plane ring [base] offset by signed [offsetMeters], returned as
/// lat/lng contours via [fromPlane].
List<List<LatLng>> _offsetContours(
  List<Offset> base,
  double offsetMeters,
  LatLng Function(Offset) fromPlane,
) {
  final r = offsetMeters.abs();
  final buffer = _boundaryBuffer(base, r);
  final ring = _polyPath(base);
  final result = offsetMeters > 0
      ? Path.combine(PathOperation.difference, ring, buffer) // erode
      : Path.combine(PathOperation.union, ring, buffer); // dilate
  // Sample finer for tighter corners, but keep the point count modest.
  final step = (r / 16).clamp(8.0, 150.0);
  return _readContours(result, step, fromPlane);
}

/// A closed path through [pts].
Path _polyPath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx, pts[i].dy);
  }
  path.close();
  return path;
}

/// All points within [r] of the boundary through [pts]: the union of a rectangle
/// swept along each edge and a disk at each vertex (rounding the corners).
/// Rectangles share one winding, disks another, so each set unions under the
/// non-zero rule before they're merged with path-ops.
Path _boundaryBuffer(List<Offset> pts, double r) {
  final n = pts.length;
  final rects = Path();
  final disks = Path();
  for (var i = 0; i < n; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % n];
    final d = b - a;
    final len = d.distance;
    if (len > 0) {
      final nx = -d.dy / len * r;
      final ny = d.dx / len * r;
      rects.moveTo(a.dx + nx, a.dy + ny);
      rects.lineTo(b.dx + nx, b.dy + ny);
      rects.lineTo(b.dx - nx, b.dy - ny);
      rects.lineTo(a.dx - nx, a.dy - ny);
      rects.close();
    }
    disks.addOval(Rect.fromCircle(center: a, radius: r));
  }
  return Path.combine(PathOperation.union, rects, disks);
}

/// Samples each contour of [path] every [step] units and maps the points back
/// to lat/lng. Discretises any arcs the buffer introduced.
List<List<LatLng>> _readContours(
  Path path,
  double step,
  LatLng Function(Offset) fromPlane,
) {
  final out = <List<LatLng>>[];
  for (final metric in path.computeMetrics()) {
    final len = metric.length;
    if (len <= 0) continue;
    // Cap each contour to ~4k samples: on a city-sized outline (tens of km)
    // the metre-scale step would otherwise emit tens of thousands of vertices
    // that every frame then has to project. At that size the coarser step
    // deviates from the true offset curve by well under the band width.
    final s = math.max(step, len / 4096);
    final ring = <LatLng>[];
    for (var d = 0.0; d < len; d += s) {
      final t = metric.getTangentForOffset(d);
      if (t != null) ring.add(fromPlane(t.position));
    }
    if (ring.length >= 3) out.add(ring);
  }
  return out;
}

/// Memoises [resolveAreaGeometry] per freehand-area object, recomputing only
/// when the object's points, offset, the uncertainty, or the invert flag change
/// — never on a camera move. A single app-wide instance ([areaGeometryCache])
/// is consulted from the region painter's widget.
class AreaGeometryCache {
  final Map<String, _Cached> _entries = {};

  ResolvedArea resolve(
    FreeArea area,
    List<FreeAreaPoint> points, {
    required double bandMeters,
    required bool inverted,
  }) {
    final sig = _signature(area, points, bandMeters, inverted);
    final cached = _entries[area.id];
    if (cached != null && cached.signature == sig) return cached.geometry;
    final ring = [for (final p in points) LatLng(p.lat, p.lng)];
    final geometry = resolveAreaGeometry(
      ring,
      offsetMeters: area.offsetMeters,
      bandMeters: bandMeters,
      inverted: inverted,
    );
    _entries[area.id] = _Cached(sig, geometry);
    return geometry;
  }

  String _signature(
      FreeArea area, List<FreeAreaPoint> points, double band, bool inverted) {
    var h = points.length;
    for (final p in points) {
      h = 0x1fffffff & (h * 31 + p.lat.hashCode);
      h = 0x1fffffff & (h * 31 + p.lng.hashCode);
    }
    return '${area.offsetMeters}|$band|$inverted|$h';
  }
}

class _Cached {
  const _Cached(this.signature, this.geometry);
  final String signature;
  final ResolvedArea geometry;
}

/// App-wide cache instance (a memo keyed by content signature, so it survives
/// the per-frame widget/painter rebuilds).
final areaGeometryCache = AreaGeometryCache();
