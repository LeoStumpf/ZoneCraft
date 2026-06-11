import 'dart:ui';

/// Screen-space geometry for a "freehand line": a user-drawn polyline that
/// divides the viewport into two sides. The region returned fills the side on
/// the polyline's left (the `+90°` normal of its overall direction); the layer's
/// invert flips to the other side via the engine's `viewport − outer` complement.
///
/// Like [PlaneRegion]/[SubspaceRegion] this is a planar approximation in
/// projected screen space. A partial line is completed by **extending its first
/// and last segments straight** far past [bounds], so it still cleanly splits the
/// whole view.
///
/// To match the engine's `band = outer − core` model, the near edge (the drawn
/// polyline) is shifted toward the filled side by the signed `offsetPx`: [outer]
/// shifts `offsetPx − halfBandPx`, [core] shifts `offsetPx + halfBandPx`. A
/// positive offset pushes the boundary into the filled side (the coloured area
/// starts further from the line); a negative one extends it past the line.
class FreeLineRegion {
  const FreeLineRegion(this.outer, this.core);

  /// The filled side enlarged by half the band. Empty when fewer than two finite
  /// points are given or the geometry is degenerate.
  final List<Offset> outer;

  /// The filled side shrunk by half the band.
  final List<Offset> core;
}

/// Builds the filled-side polygons for the polyline [points] (projected to
/// screen), clipped implicitly by the painter to [bounds]. [halfBandPx] is half
/// the uncertainty band width in pixels (0 disables it); [offsetPx] is the signed
/// boundary offset in pixels.
FreeLineRegion freeLineRegion({
  required List<Offset> points,
  required double offsetPx,
  required double halfBandPx,
  required Rect bounds,
}) {
  final pts = <Offset>[
    for (final p in points)
      if (p.dx.isFinite && p.dy.isFinite) p,
  ];
  if (pts.length < 2) return const FreeLineRegion(<Offset>[], <Offset>[]);

  final ext = bounds.longestSide * 4 + 1000;
  final dirStart = _unit(pts[1] - pts.first);
  final dirEnd = _unit(pts[pts.length - 1] - pts[pts.length - 2]);
  if (dirStart == Offset.zero || dirEnd == Offset.zero) {
    return const FreeLineRegion(<Offset>[], <Offset>[]);
  }
  // Extend the first/last segments straight so the line spans the whole view.
  final e0 = pts.first - dirStart * ext;
  final eEnd = pts.last + dirEnd * ext;
  final ep = <Offset>[e0, ...pts, eEnd];

  final normals = _vertexNormals(ep); // per-vertex +90° unit normals
  final capN = _perp(_unit(eEnd - e0)); // overall filled-side direction
  if (capN == Offset.zero) {
    return const FreeLineRegion(<Offset>[], <Offset>[]);
  }

  final hb = halfBandPx.isFinite && halfBandPx > 0 ? halfBandPx : 0.0;
  final off = offsetPx.isFinite ? offsetPx : 0.0;
  // Far enough that the cap clears the viewport regardless of zoom.
  final huge = bounds.longestSide * 6 + 4000;

  List<Offset> build(double shift) {
    final near = <Offset>[
      for (var i = 0; i < ep.length; i++) ep[i] + normals[i] * shift,
    ];
    // Sweep out HUGE along the fixed filled-side normal, then back, to cover the
    // whole side. A single fixed direction avoids per-vertex fan-out crossings.
    return <Offset>[
      ...near,
      near.last + capN * huge,
      near.first + capN * huge,
    ];
  }

  final outer = build(off - hb);
  final core = build(off + hb);
  return FreeLineRegion(outer, core);
}

Offset _unit(Offset d) {
  final l = d.distance;
  return l == 0 ? Offset.zero : Offset(d.dx / l, d.dy / l);
}

/// The `+90°` rotation of [u] (screen coordinates, y down).
Offset _perp(Offset u) => Offset(-u.dy, u.dx);

/// Per-vertex unit normals: the (renormalised) bisector of the two adjacent
/// segment normals, so small offsets miter cleanly without producing spikes.
List<Offset> _vertexNormals(List<Offset> p) {
  final out = <Offset>[];
  for (var i = 0; i < p.length; i++) {
    var acc = Offset.zero;
    if (i > 0) acc += _perp(_unit(p[i] - p[i - 1]));
    if (i < p.length - 1) acc += _perp(_unit(p[i + 1] - p[i]));
    final u = _unit(acc);
    out.add(u == Offset.zero ? _perp(_unit(p.last - p.first)) : u);
  }
  return out;
}
