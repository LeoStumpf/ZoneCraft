import 'dart:math';
import 'dart:ui';

/// Screen-space geometry for a "closest subspace" object: the region of the
/// viewport closer to the [main] point than to any of the [others] — i.e. the
/// main point's Voronoi cell, the intersection of the half-planes "closer to
/// main than to Pⱼ" for every other point Pⱼ.
///
/// Like [PlaneRegion] this is a planar approximation in projected screen space
/// (project the points, bisect, clip). It is accurate at city scale; a geodesic
/// refinement is a possible follow-up.
///
/// To match the engine's `band = outer − core` model, each bisector is offset:
/// [outer] pushes every bisector `halfBandPx` toward the other points (enlarging
/// the cell), and [core] pulls each `halfBandPx` toward the main point (shrinking
/// it). The difference is a band of width `2·halfBandPx` hugging the internal
/// divides.
class SubspaceRegion {
  const SubspaceRegion(this.outer, this.core);

  /// The cell enlarged by half the band. Empty when there are no other points
  /// or the geometry is degenerate (a point coincident with the main point).
  final List<Offset> outer;

  /// The cell shrunk by half the band. May be empty when the band swallows the
  /// whole cell within [bounds].
  final List<Offset> core;
}

/// Builds the main point's cell, clipped to [bounds] (usually the slightly
/// inflated viewport). [others] are the projected non-main points. [halfBandPx]
/// is half the uncertainty band width in pixels (0 disables it). Returns empty
/// polygons when [others] is empty or a point coincides with [main].
SubspaceRegion subspaceRegion({
  required Offset main,
  required List<Offset> others,
  required double halfBandPx,
  required Rect bounds,
}) {
  if (others.isEmpty || !main.dx.isFinite || !main.dy.isFinite) {
    return const SubspaceRegion(<Offset>[], <Offset>[]);
  }
  final hb = halfBandPx.isFinite && halfBandPx > 0 ? halfBandPx : 0.0;

  var outer = _rectPoly(bounds);
  var core = _rectPoly(bounds);

  for (final p in others) {
    if (!p.dx.isFinite || !p.dy.isFinite) continue; // skip an invalid point
    final dx = main.dx - p.dx;
    final dy = main.dy - p.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (!len.isFinite || len == 0) {
      // Coincident with the main point: the cell is undefined -> empty.
      return const SubspaceRegion(<Offset>[], <Offset>[]);
    }
    // Unit normal of the bisector, pointing from the divide toward main.
    final n = Offset(dx / len, dy / len);
    final mid = Offset((main.dx + p.dx) / 2, (main.dy + p.dy) / 2);
    outer = _clipPolyByHalfPlane(outer, n, mid - n * hb);
    core = _clipPolyByHalfPlane(core, n, mid + n * hb);
    if (outer.isEmpty && core.isEmpty) break;
  }
  return SubspaceRegion(outer, core);
}

List<Offset> _rectPoly(Rect rect) => <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];

/// Clips the convex polygon [poly] to the half-plane `{ q : (q − p0)·n ≥ 0 }`
/// with a single-edge Sutherland–Hodgman pass. Returns the (still convex)
/// clipped vertices, empty if nothing survives.
List<Offset> _clipPolyByHalfPlane(List<Offset> poly, Offset n, Offset p0) {
  if (poly.isEmpty) return poly;
  double side(Offset q) => (q.dx - p0.dx) * n.dx + (q.dy - p0.dy) * n.dy;

  final out = <Offset>[];
  for (var i = 0; i < poly.length; i++) {
    final cur = poly[i];
    final nxt = poly[(i + 1) % poly.length];
    final dc = side(cur);
    final dn = side(nxt);
    if (dc >= 0) out.add(cur);
    if ((dc >= 0) != (dn >= 0)) {
      final t = dc / (dc - dn);
      out.add(Offset(
        cur.dx + (nxt.dx - cur.dx) * t,
        cur.dy + (nxt.dy - cur.dy) * t,
      ));
    }
  }
  return out;
}
