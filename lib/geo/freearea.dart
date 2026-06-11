import 'dart:ui';

/// Screen-space geometry for a "freehand area": a user-drawn closed polygon
/// (ring). The region returned fills the inside; the layer's invert fills the
/// outside via the engine's `viewport − outer` complement.
///
/// Like the other region types this is a planar approximation in projected
/// screen space. To match the engine's `band = outer − core` model, the ring is
/// inset by the signed `offsetPx`: [outer] insets by `offsetPx − halfBandPx`,
/// [core] by `offsetPx + halfBandPx`. A positive offset shrinks the filled
/// interior inward (e.g. "inside the city and >5 km from the border"); a negative
/// one grows it outward past the drawn ring.
class FreeAreaRegion {
  const FreeAreaRegion(this.outer, this.core);

  /// The interior enlarged by half the band. Empty when fewer than three finite
  /// points are given or an inset collapses the ring.
  final List<Offset> outer;

  /// The interior shrunk by half the band.
  final List<Offset> core;
}

/// Builds the interior polygons for the closed ring [ring] (projected to
/// screen). [halfBandPx] is half the uncertainty band width in pixels (0
/// disables it); [offsetPx] is the signed inward offset in pixels. [bounds] is
/// unused for now (the painter clips), kept for signature symmetry.
FreeAreaRegion freeAreaRegion({
  required List<Offset> ring,
  required double offsetPx,
  required double halfBandPx,
  required Rect bounds,
}) {
  final pts = <Offset>[
    for (final p in ring)
      if (p.dx.isFinite && p.dy.isFinite) p,
  ];
  if (pts.length < 3) return const FreeAreaRegion(<Offset>[], <Offset>[]);
  final hb = halfBandPx.isFinite && halfBandPx > 0 ? halfBandPx : 0.0;
  final off = offsetPx.isFinite ? offsetPx : 0.0;
  final outer = _inset(pts, off - hb);
  final core = _inset(pts, off + hb);
  return FreeAreaRegion(outer, core);
}

/// Insets the simple polygon [p] inward by signed distance [d] (positive shrinks,
/// negative grows) via per-edge offset and miter intersection. Returns empty if
/// the polygon degenerates or the inset collapses/inverts it.
List<Offset> _inset(List<Offset> p, double d) {
  final n = p.length;
  if (d == 0) return List<Offset>.of(p);
  final orient0 = _signedArea(p);
  if (orient0 == 0) return <Offset>[];

  var cx = 0.0, cy = 0.0;
  for (final q in p) {
    cx += q.dx;
    cy += q.dy;
  }
  final centroid = Offset(cx / n, cy / n);

  // Each edge offset inward by d: a reference point [base] and its direction.
  final base = <Offset>[];
  final dir = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = p[i];
    final b = p[(i + 1) % n];
    final e = _unit(b - a);
    if (e == Offset.zero) return <Offset>[]; // degenerate edge
    var inward = Offset(-e.dy, e.dx);
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    if ((centroid.dx - mid.dx) * inward.dx +
            (centroid.dy - mid.dy) * inward.dy <
        0) {
      inward = -inward; // orient toward the interior
    }
    base.add(a + inward * d);
    dir.add(e);
  }

  // New vertex i is where the offset edges (i-1) and i meet.
  final out = <Offset>[];
  for (var i = 0; i < n; i++) {
    final prev = (i - 1 + n) % n;
    final x = _intersect(base[prev], dir[prev], base[i], dir[i]);
    out.add(x ?? base[i]);
  }

  // Reject a collapsed inset: a flipped orientation, or — for a shrink that
  // overshot the inradius — a polygon that mirrored through its centre (same
  // orientation but grown rather than shrunk).
  final orient1 = _signedArea(out);
  if (orient0 * orient1 <= 0) return <Offset>[];
  if (d > 0 && orient1.abs() >= orient0.abs()) return <Offset>[];
  return out;
}

double _signedArea(List<Offset> p) {
  var a = 0.0;
  for (var i = 0; i < p.length; i++) {
    final q = p[i];
    final r = p[(i + 1) % p.length];
    a += q.dx * r.dy - r.dx * q.dy;
  }
  return a / 2;
}

/// Intersection of lines `base1 + t·dir1` and `base2 + s·dir2`; null if parallel.
Offset? _intersect(Offset base1, Offset dir1, Offset base2, Offset dir2) {
  final denom = dir1.dx * dir2.dy - dir1.dy * dir2.dx;
  if (denom.abs() < 1e-9) return null;
  final t = ((base2.dx - base1.dx) * dir2.dy - (base2.dy - base1.dy) * dir2.dx) /
      denom;
  return base1 + dir1 * t;
}

Offset _unit(Offset d) {
  final l = d.distance;
  return l == 0 ? Offset.zero : Offset(d.dx / l, d.dy / l);
}
