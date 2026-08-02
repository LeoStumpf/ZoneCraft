import 'dart:ui';

/// Clips the closed polygon [ring] (screen-space points) to [rect] with
/// Sutherland–Hodgman, in double precision.
///
/// Skia — both its path-ops and its scan converter — misbehaves on polygons
/// whose vertices lie far outside the canvas (a city-sized outline at street
/// zoom projects to ±10⁵ px): `Path.combine` can throw or silently drop
/// contours, and fills rasterise with pieces missing. Clipping the point list
/// *before* a `Path` is ever built keeps every coordinate Skia sees within a
/// viewport-sized box, which is also far cheaper than a per-frame path-op
/// against a clip rect.
///
/// Returns the input list unchanged when it already fits inside [rect] and an
/// empty list when the ring cannot intersect it. For a concave ring whose
/// intersection with [rect] is several disjoint pieces, the pieces come back
/// joined by degenerate edges running along the rect boundary — harmless for
/// fills, and invisible for strokes as long as [rect] is inflated past the
/// canvas clip. Assumes a simple (non-self-crossing) ring.
List<Offset> clipRingToRect(List<Offset> ring, Rect rect) {
  if (ring.isEmpty) return const [];
  var minX = ring[0].dx, maxX = ring[0].dx;
  var minY = ring[0].dy, maxY = ring[0].dy;
  for (final p in ring) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  if (minX > rect.right ||
      maxX < rect.left ||
      minY > rect.bottom ||
      maxY < rect.top) {
    return const []; // bounding boxes disjoint -> empty intersection
  }
  if (minX >= rect.left &&
      maxX <= rect.right &&
      minY >= rect.top &&
      maxY <= rect.bottom) {
    return ring; // already inside -> nothing to do
  }
  var poly = _clipAxis(ring, rect.left, xAxis: true, keepBelow: false);
  poly = _clipAxis(poly, rect.right, xAxis: true, keepBelow: true);
  poly = _clipAxis(poly, rect.top, xAxis: false, keepBelow: false);
  poly = _clipAxis(poly, rect.bottom, xAxis: false, keepBelow: true);
  return poly;
}

/// Clips the segment a→b to [rect] (Liang–Barsky), or null when it misses.
///
/// The ring clipper's counterpart for geometry that is **stroked but not
/// filled** — the borders layer draws its outlines segment by segment, because
/// it has to skip the ones lying on the import box edge, and so cannot hand
/// Skia a closed ring. Same motivation as [clipRingToRect]: keep every
/// coordinate Skia sees inside a viewport-sized box.
(Offset, Offset)? clipSegmentToRect(Offset a, Offset b, Rect rect) {
  if (!a.dx.isFinite || !a.dy.isFinite || !b.dx.isFinite || !b.dy.isFinite) {
    return null;
  }
  var t0 = 0.0, t1 = 1.0;
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  // Each edge as `p * t <= q`; p == 0 means parallel, which only rejects when
  // the segment already lies outside that edge.
  for (final (p, q) in [
    (-dx, a.dx - rect.left),
    (dx, rect.right - a.dx),
    (-dy, a.dy - rect.top),
    (dy, rect.bottom - a.dy),
  ]) {
    if (p == 0) {
      if (q < 0) return null;
      continue;
    }
    final r = q / p;
    if (p < 0) {
      if (r > t1) return null;
      if (r > t0) t0 = r;
    } else {
      if (r < t0) return null;
      if (r < t1) t1 = r;
    }
  }
  return (
    Offset(a.dx + t0 * dx, a.dy + t0 * dy),
    Offset(a.dx + t1 * dx, a.dy + t1 * dy),
  );
}

/// One Sutherland–Hodgman pass: keeps the part of [poly] on the [keepBelow]
/// side of the axis-aligned line `x == bound` ([xAxis]) or `y == bound`.
List<Offset> _clipAxis(
  List<Offset> poly,
  double bound, {
  required bool xAxis,
  required bool keepBelow,
}) {
  if (poly.isEmpty) return poly;
  double coord(Offset p) => xAxis ? p.dx : p.dy;
  bool inside(Offset p) =>
      keepBelow ? coord(p) <= bound : coord(p) >= bound;
  Offset cross(Offset a, Offset b) {
    // Only called when a/b straddle the line, so the denominator is non-zero.
    final t = (bound - coord(a)) / (coord(b) - coord(a));
    return xAxis
        ? Offset(bound, a.dy + (b.dy - a.dy) * t)
        : Offset(a.dx + (b.dx - a.dx) * t, bound);
  }

  final out = <Offset>[];
  var prev = poly.last;
  var prevIn = inside(prev);
  for (final cur in poly) {
    final curIn = inside(cur);
    if (curIn) {
      if (!prevIn) out.add(cross(prev, cur));
      out.add(cur);
    } else if (prevIn) {
      out.add(cross(prev, cur));
    }
    prev = cur;
    prevIn = curIn;
  }
  return out;
}
