import 'dart:math';
import 'dart:ui';

/// Screen-space geometry for a "plane" object: the region of the viewport that
/// is closer to the near point than the far point — i.e. the side of the
/// perpendicular bisector of A,B that contains the near point.
///
/// v1 is a planar approximation done in projected screen space (project A and B,
/// bisect, fill the near side). It is accurate at city scale; a geodesic
/// refinement is a possible follow-up.
///
/// To match the rendering engine's `band = outer − core` model (shared with
/// circles), the uncertainty band straddles the bisector: [outer] is the near
/// half-plane pushed `halfBandPx` onto the far side, and [core] is it pulled
/// `halfBandPx` back onto the near side. The difference is a strip of width
/// `2·halfBandPx` centred on the divide.
class PlaneRegion {
  const PlaneRegion(this.outer, this.core);

  /// Near half-plane extended by half the band onto the far side. Empty when
  /// the geometry is degenerate (A and B project to the same point).
  final List<Offset> outer;

  /// Near half-plane retracted by half the band. Empty when the band swallows
  /// the whole near side within [bounds].
  final List<Offset> core;
}

/// Builds the clipped near-side polygons for a plane defined by projected
/// points [a] and [b]. [nearA] selects which point's side is filled.
/// [halfBandPx] is half the uncertainty band width in pixels (0 disables it).
/// [bounds] is the (usually slightly inflated) viewport rectangle to clip to.
PlaneRegion planeRegion({
  required Offset a,
  required Offset b,
  required bool nearA,
  required double halfBandPx,
  required Rect bounds,
}) {
  final near = nearA ? a : b;
  final far = nearA ? b : a;
  final dx = near.dx - far.dx;
  final dy = near.dy - far.dy;
  final len = sqrt(dx * dx + dy * dy);
  if (!len.isFinite || len == 0) {
    return const PlaneRegion(<Offset>[], <Offset>[]);
  }
  // Unit normal pointing from the divide toward the near point.
  final n = Offset(dx / len, dy / len);
  final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  final hb = halfBandPx.isFinite && halfBandPx > 0 ? halfBandPx : 0.0;

  final outer = _clipRectByHalfPlane(bounds, n, mid - n * hb);
  final core = _clipRectByHalfPlane(bounds, n, mid + n * hb);
  return PlaneRegion(outer, core);
}

/// Clips the rectangle [rect] to the half-plane `{ q : (q − p0)·n ≥ 0 }` using
/// a single-edge Sutherland–Hodgman pass. Returns the convex polygon vertices
/// (empty if the rectangle lies entirely outside the half-plane).
List<Offset> _clipRectByHalfPlane(Rect rect, Offset n, Offset p0) {
  final poly = <Offset>[
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
  ];
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
