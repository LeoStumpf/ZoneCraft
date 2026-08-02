import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle, Path;

import '../data/database.dart';
import '../geo/freeline.dart';
import '../geo/plane.dart';
import '../geo/subspace.dart';
import 'area_geometry.dart';
import 'region_geometry.dart';
import 'screen_clip.dart';

/// Renders one layer's objects as a single composited region.
///
/// All of a layer's objects are unioned into one shape before painting, so
/// overlaps show a flat colour instead of compounding opacity. The outline
/// marks the nominal boundary and never moves; a lighter "uncertainty" band
/// occupies the first [uncertaintyMeters] of the *coloured* side, and the solid
/// fill starts only past it. When [Layer.isInverted] is set, the coloured side
/// is the complement (everything outside the objects), so the band sits just
/// outside the boundary instead — always on the same side as the fill.
///
/// Every object type builds its boundary in **lat/lng** (geodesically) and the
/// painter projects those rings to screen with [MapCamera.latLngToScreenOffset];
/// the unions use `dart:ui` `Path.combine`.
class RegionLayer extends StatelessWidget {
  const RegionLayer({
    super.key,
    required this.layer,
    this.circles = const <Circle>[],
    this.planes = const <Plane>[],
    this.subspaces = const <Subspace>[],
    this.subspacePoints = const <SubspacePoint>[],
    this.freeLines = const <FreeLine>[],
    this.freeLinePoints = const <FreeLinePoint>[],
    this.freeAreas = const <FreeArea>[],
    this.freeAreaPoints = const <FreeAreaPoint>[],
    this.heightRegions = const <HeightRegion>[],
    this.heightPolygons = const <HeightPolygon>[],
    this.heightPolygonPoints = const <HeightPolygonPoint>[],
    required this.uncertaintyMeters,
    this.opacity = 1.0,
  });

  final Layer layer;
  final List<Circle> circles;
  final List<Plane> planes;
  final List<Subspace> subspaces;

  /// Points belonging to [subspaces] (ordered); grouped per-subspace at paint.
  final List<SubspacePoint> subspacePoints;

  final List<FreeLine> freeLines;

  /// Points belonging to [freeLines] (ordered); grouped per-line at paint.
  final List<FreeLinePoint> freeLinePoints;

  final List<FreeArea> freeAreas;

  /// Points belonging to [freeAreas] (ordered); grouped per-area at paint.
  final List<FreeAreaPoint> freeAreaPoints;

  final List<HeightRegion> heightRegions;

  /// Generated fill polygons for [heightRegions] (ordered); grouped per-region.
  final List<HeightPolygon> heightPolygons;

  /// Ring points of [heightPolygons] (ordered); grouped per-polygon at paint.
  final List<HeightPolygonPoint> heightPolygonPoints;
  final double uncertaintyMeters;

  /// The layer's fill opacity in [0, 1] (see [Layers.opacity]).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    // Resolve the (camera-independent) offset/band geometry once per change; the
    // cache returns the same instance on a plain camera move, so the per-frame
    // paint only projects and fills these rings.
    final resolvedAreas = <ResolvedArea>[
      for (final a in freeAreas)
        areaGeometryCache.resolve(
          a,
          [for (final p in freeAreaPoints) if (p.freeAreaId == a.id) p],
          bandMeters: uncertaintyMeters,
          inverted: layer.isInverted,
        ),
    ];
    return IgnorePointer(
      child: CustomPaint(
        size: camera.size,
        painter: _RegionPainter(
          camera: camera,
          color: Color(layer.colorArgb),
          inverted: layer.isInverted,
          circles: circles,
          planes: planes,
          subspaces: subspaces,
          subspacePoints: subspacePoints,
          freeLines: freeLines,
          freeLinePoints: freeLinePoints,
          freeAreas: freeAreas,
          freeAreaPoints: freeAreaPoints,
          resolvedAreas: resolvedAreas,
          heightRegions: heightRegions,
          heightPolygons: heightPolygons,
          heightPolygonPoints: heightPolygonPoints,
          uncertaintyMeters: uncertaintyMeters,
          opacity: layer.opacity,
        ),
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  _RegionPainter({
    required this.camera,
    required this.color,
    required this.inverted,
    required this.circles,
    required this.planes,
    required this.subspaces,
    required this.subspacePoints,
    required this.freeLines,
    required this.freeLinePoints,
    required this.freeAreas,
    required this.freeAreaPoints,
    required this.resolvedAreas,
    required this.heightRegions,
    required this.heightPolygons,
    required this.heightPolygonPoints,
    required this.uncertaintyMeters,
    required this.opacity,
  });

  final MapCamera camera;
  final Color color;
  final bool inverted;
  final List<Circle> circles;
  final List<Plane> planes;
  final List<Subspace> subspaces;
  final List<SubspacePoint> subspacePoints;
  final List<FreeLine> freeLines;
  final List<FreeLinePoint> freeLinePoints;
  final List<FreeArea> freeAreas;
  final List<FreeAreaPoint> freeAreaPoints;

  /// Pre-resolved, camera-independent geometry for [freeAreas], one per object.
  final List<ResolvedArea> resolvedAreas;

  final List<HeightRegion> heightRegions;
  final List<HeightPolygon> heightPolygons;
  final List<HeightPolygonPoint> heightPolygonPoints;
  final double uncertaintyMeters;

  /// The layer's fill opacity in [0, 1]. It scales all three paint elements by
  /// the same factor `k = opacity / kDefaultRegionLayerOpacity` (so at the
  /// default it reproduces the original look exactly: solid 0.45, band 0.20,
  /// crisp outline), clamped to [0, 1]. At opacity 1.0 the solid fill is fully
  /// opaque (the map is hidden); at 0 the layer disappears.
  final double opacity;

  double get _solidAlpha => (0.45 * _k).clamp(0.0, 1.0);
  double get _bandAlpha => (0.20 * _k).clamp(0.0, 1.0);
  double get _strokeAlpha => (1.0 * _k).clamp(0.0, 1.0);
  double get _k => opacity / kDefaultRegionLayerOpacity;

  static const int _ringPoints = 90;
  static const Distance _distance = Distance(calculator: Haversine());

  /// The viewport inflated a few px, set at the start of [paint]. Every
  /// projected ring is pre-clipped to this box (see [clipRingToRect]) so Skia
  /// never sees far-off-screen coordinates — path-ops on such geometry fail or
  /// mis-rasterise, and are slow. The inflation puts the clip's cut edges
  /// outside the canvas clip, so strokes never trace the viewport border.
  Rect _clip = Rect.zero;

  @override
  void paint(Canvas canvas, Size size) {
    // Clip so region fills/strokes (which extend a few px past the viewport to
    // hide their clip-cut edges) don't paint outside this layer's bounds.
    canvas.clipRect(Offset.zero & size);
    _clip = (Offset.zero & size).inflate(4);

    // Height layers render their stored fill polygons with their own bounded
    // band (along the elevation contour only), so handle them separately.
    if (heightRegions.isNotEmpty) {
      _paintHeight(canvas, size);
      return;
    }

    // Freehand areas derive their band by buffering the (often wrinkly, concave)
    // boundary rather than offsetting its vertices — a vertex offset self-crosses
    // at reflex corners and gaps at convex ones, which on a city-sized outline
    // turns the band into spikes. Handle them separately so the buffer is robust.
    if (freeAreas.isNotEmpty) {
      _paintFreeAreas(canvas, size);
      return;
    }

    // Freehand lines are bounded to an inclusion circle (each fills a clean
    // half-disk), so the invert complement is the disk — not the viewport.
    // Handle them separately rather than on the shared unbounded path.
    if (freeLines.isNotEmpty) {
      _paintFreeLines(canvas, size);
      return;
    }

    Path? outerUnion;
    Path? coreUnion;

    void addOuter(List<LatLng> ring) {
      if (ring.length < 3) return;
      final path = _ringToPath(ring);
      outerUnion = outerUnion == null
          ? path
          : Path.combine(PathOperation.union, outerUnion!, path);
    }

    void addCore(List<LatLng> ring) {
      if (ring.length < 3) return;
      final path = _ringToPath(ring);
      coreUnion = coreUnion == null
          ? path
          : Path.combine(PathOperation.union, coreUnion!, path);
    }

    // Every type keeps its nominal boundary (the outline) fixed and puts the
    // uncertainty band on the **coloured** side, just inside it, so the solid
    // fill only starts a band-width past the line: normal layers shrink the
    // solid inward, inverted layers (whose fill is `viewport − outer`) push it
    // outward.
    final band = uncertaintyMeters > 0 ? uncertaintyMeters : 0.0;

    for (final c in circles) {
      final center = LatLng(c.centerLat, c.centerLng);
      // Outline stays at the drawn radius; the band sits just inside it (normal)
      // or just outside it (inverted). Rings are memoised by centre+radius, so a
      // pan/zoom just re-projects them instead of recomputing the geodesic ring.
      final outerRadius = inverted ? c.radiusMeters + band : c.radiusMeters;
      final coreRadius = inverted ? c.radiusMeters : c.radiusMeters - band;
      if (outerRadius <= 0) continue; // invalid geometry -> skip
      addOuter(regionGeometryCache.circleRing(center, outerRadius, _ringPoints));
      if (coreRadius > 0) {
        addCore(regionGeometryCache.circleRing(center, coreRadius, _ringPoints));
      }
    }
    // Plane/subspace clip to the viewport as a spherical quad; unproject its
    // (slightly inflated) corners once. Null at extreme zoom / near-pole.
    final corners = _viewportCorners(size);
    // Unbounded regions (plane/subspace/freeline) are cached against a generous
    // bound and reused while the live view still fits inside it, so a pan/zoom
    // re-projects cached rings instead of re-clipping every frame.
    final viewport = corners == null ? null : ViewBound.ofCorners(corners);

    if (planes.isNotEmpty && viewport != null) {
      for (final p in planes) {
        final sig = '${p.aLat}|${p.aLng}|${p.bLat}|${p.bLng}|'
            '${p.nearA}|$band|$inverted';
        final region = regionGeometryCache.boundRegion(p.id, sig, viewport,
            (bound) {
          final r = planeRegion(
            a: LatLng(p.aLat, p.aLng),
            b: LatLng(p.bLat, p.bLng),
            nearA: p.nearA,
            bandMeters: band,
            viewportCorners: bound.quad,
            bandInward: !inverted,
          );
          return (outer: r.outer, core: r.core);
        });
        addOuter(region.outer);
        addCore(region.core);
      }
    }

    if (subspaces.isNotEmpty && viewport != null) {
      for (final s in subspaces) {
        final pts = subspacePoints.where((p) => p.subspaceId == s.id).toList();
        final mainPt = pts.where((p) => p.isMain).firstOrNull;
        if (mainPt == null) continue; // no main point -> nothing to fill
        final main = LatLng(mainPt.lat, mainPt.lng);
        final others = <LatLng>[
          for (final p in pts)
            if (p.id != mainPt.id) LatLng(p.lat, p.lng),
        ];
        final sig = '${hashPoints([main, ...others])}|$band|$inverted';
        final region = regionGeometryCache.boundRegion(s.id, sig, viewport,
            (bound) {
          final r = subspaceRegion(
            main: main,
            others: others,
            bandMeters: band,
            viewportCorners: bound.quad,
            bandInward: !inverted,
          );
          return (outer: r.outer, core: r.core);
        });
        addOuter(region.outer);
        addCore(region.core);
      }
    }

    final outer = outerUnion;
    if (outer == null) return; // nothing valid to draw
    final core = coreUnion ?? Path();

    // Band is always the ring between core and outline. Its two operands are
    // near-parallel outlines — Skia path-ops' worst case — so degrade to "no
    // band this frame" rather than let a throw abort the whole paint.
    final bandPath = _tryCombine(PathOperation.difference, outer, core);

    // Solid fill: the core normally, or the complement when inverted.
    final Path solid;
    if (inverted) {
      final viewport = Path()..addRect(_clip);
      solid = Path.combine(PathOperation.difference, viewport, outer);
    } else {
      solid = core;
    }

    final solidPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: _solidAlpha);
    final bandPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: _bandAlpha);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: _strokeAlpha);

    // The outline traces the *nominal* boundary, which every type keeps fixed
    // regardless of invert: normally that's `outer` (the band eats inward from
    // it into the fill); when inverted the band grows outward so the nominal
    // edge is `core`.
    final outline = inverted ? core : outer;

    // All geometry was pre-clipped to `_clip` at projection time (see
    // [_ringToPath]), so it can be drawn directly — no per-frame path-op
    // against a clip rect, and no far-off-screen coordinates for Skia.
    // Regions are disjoint, so paint order is irrelevant.
    canvas.drawPath(solid, solidPaint);
    if (bandPath != null) canvas.drawPath(bandPath, bandPaint);
    canvas.drawPath(outline, strokePaint);
  }

  /// [Path.combine] that returns null instead of throwing — Skia path-ops can
  /// still fail on pathological (near-coincident) inputs, and one bad frame
  /// must not take the rest of the layer's paint down with it.
  static Path? _tryCombine(PathOperation op, Path a, Path b) {
    try {
      return Path.combine(op, a, b);
    } catch (_) {
      return null;
    }
  }

  /// Paints a freehand-area layer from its **pre-resolved** geometry
  /// ([resolvedAreas]). The expensive offset/band buffering happened once
  /// off-frame (see [resolveAreaGeometry]); here we only project the cached
  /// lat/lng rings to screen and fill. The outline traces the nominal boundary
  /// (`core`); the band is the annulus between it and its band edge (which sits
  /// on the *coloured* side) — a fill, not a wide stroke — and the solid starts
  /// at that band edge: the shrunk interior, or the viewport complement of the
  /// grown one when inverted.
  ///
  /// The composite is built by **overpainting inside a layer**, not with
  /// `Path.combine`: these buffered city-sized outlines are thousands of
  /// near-collinear vertices, exactly the input Skia's path-ops fail on — and a
  /// failed `viewport − objects` would paint the complement over *everything*.
  /// Painting the wider region first and replacing it with the narrower one
  /// ([BlendMode.src], [BlendMode.clear]) needs no path-ops at all and keeps
  /// overlapping objects flat, which is the whole point of the union anyway.
  void _paintFreeAreas(Canvas canvas, Size size) {
    // Per-object screen geometry: the nominal boundary, and the band's far edge
    // (where the solid starts). With no uncertainty the two coincide; an empty
    // band edge under a positive uncertainty means the band swallowed the whole
    // object, so it contributes no solid at all.
    final cores = <Path>[];
    final edges = <Path>[];
    for (final r in resolvedAreas) {
      if (r.isEmpty) continue;
      final cp = _contoursToPath(r.core);
      cores.add(cp);
      edges.add(uncertaintyMeters <= 0
          ? cp
          : (r.bandEdge.isEmpty ? Path() : _contoursToPath(r.bandEdge)));
    }
    if (cores.isEmpty) return;

    final solidPaint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.src
      ..color = color.withValues(alpha: _solidAlpha);
    final bandPaint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.src
      ..color = color.withValues(alpha: _bandAlpha);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: _strokeAlpha);

    // Layer the fill widest-first, each pass replacing the last. Normally that
    // is: whole interior at band alpha, then the band edge (the interior shrunk
    // by the uncertainty) solid. Inverted, the coloured side is the outside, so
    // it is: whole viewport solid, then the grown band edge at band alpha, then
    // the interior cleared away.
    canvas.saveLayer(_clip, Paint());
    if (inverted) {
      canvas.drawRect(_clip, solidPaint);
      for (final e in edges) {
        canvas.drawPath(e, bandPaint);
      }
      for (final c in cores) {
        canvas.drawPath(c, clearPaint);
      }
    } else {
      for (final c in cores) {
        canvas.drawPath(c, bandPaint);
      }
      for (final e in edges) {
        canvas.drawPath(e, solidPaint);
      }
    }
    canvas.restore();

    // Outline traces the nominal boundary.
    for (final c in cores) {
      canvas.drawPath(c, strokePaint);
    }
  }

  /// Paints a freehand-line layer. Each line **cuts** its inclusion circle: the
  /// filled side is the even-odd XOR of the cut runs ∩ the disk, and the layer's
  /// invert fills the other side (`disk − filled`). The uncertainty band is the
  /// strip of the *coloured* side closest to the dividing line — obtained by
  /// stroking the boundary line (only the line, never the circle arc) by twice
  /// the uncertainty radius and clipping it to the coloured side — so the fill
  /// turns solid only a band-width past the divider and nothing ever spills onto
  /// the far side. The outline traces the dividing line.
  void _paintFreeLines(Canvas canvas, Size size) {
    final bandMeters = uncertaintyMeters > 0 ? uncertaintyMeters : 0.0;

    Path? coreUnion; // the right-hand filled side, ∩ disk
    Path? diskUnion;
    final boundary = Path(); // the (offset-free) dividing line(s), for outline+band
    LatLng? bandRef; // a point to scale band metres → pixels

    for (final l in freeLines) {
      final pts = freeLinePoints.where((p) => p.freeLineId == l.id).toList();
      if (pts.length < 2) continue;
      final line = <LatLng>[for (final p in pts) LatLng(p.lat, p.lng)];

      final inc = effectiveInclusion(
        lat: l.inclusionLat,
        lng: l.inclusionLng,
        radiusMeters: l.inclusionRadiusMeters,
        points: line,
      );
      final ring =
          regionGeometryCache.circleRing(inc.center, inc.radiusMeters, _ringPoints);
      if (ring.length < 3) continue;
      final diskPath = _ringToPath(ring);
      bandRef ??= inc.center;

      // Treat the line as a cut: each continuous run is an even-odd ring (filled
      // = its right side), XOR'd inside the disk so a loop/re-crossing just flips
      // the side. Memoised (camera-independent) so a heavy import is re-split
      // only when its inputs change.
      // Offset-free cut geometry (the offset is a render-time buffer below), so
      // it is memoised independent of the offset.
      final sig = '${hashPoints(line)}|${inc.center.latitude}|'
          '${inc.center.longitude}|${inc.radiusMeters}';
      final r = regionGeometryCache.halfDisk(
          l.id,
          sig,
          () => freeLineDiskRegion(
                points: line,
                center: inc.center,
                radiusMeters: inc.radiusMeters,
              ));

      Path? corePath;
      if (r.missesDisk) {
        corePath = r.centreOnRight ? diskPath : null;
      } else {
        for (final fr in r.fillRings) {
          if (fr.length < 3) continue;
          final rp = Path.combine(
              PathOperation.intersect, _ringToPathEvenOdd(fr), diskPath);
          corePath =
              corePath == null ? rp : Path.combine(PathOperation.xor, corePath, rp);
        }
      }

      // Apply the signed offset by buffering the divider and growing/shrinking
      // the filled side by |offset|. A buffer (overlapping segment quads + round
      // joins) never self-intersects into an island, so a tight river bend no
      // longer sprouts the spurious fold a vertex offset did.
      if (corePath != null && l.offsetMeters != 0 && r.boundaries.isNotEmpty) {
        final dPx = _metersToPixels(inc.center, l.offsetMeters.abs());
        if (dPx > 0.5) {
          final ribbon = Path.combine(
              PathOperation.intersect, _ribbon(r.boundaries, dPx), diskPath);
          corePath = l.offsetMeters > 0
              ? Path.combine(PathOperation.difference, corePath, ribbon)
              : Path.combine(
                  PathOperation.intersect,
                  Path.combine(PathOperation.union, corePath, ribbon),
                  diskPath);
        }
      }

      // Outline + band trace the offset-free divider — always a simple line, so
      // they never inherit the self-cross a shifted divider would have. (With an
      // offset the filled region is the buffered one above; the divider line
      // still marks the river it was cut along.)
      for (final b in r.boundaries) {
        _addPolyline(boundary, b);
      }

      diskUnion = diskUnion == null
          ? diskPath
          : Path.combine(PathOperation.union, diskUnion, diskPath);
      if (corePath != null) {
        coreUnion = coreUnion == null
            ? corePath
            : Path.combine(PathOperation.union, coreUnion, corePath);
      }
    }

    final disk = diskUnion;
    if (disk == null) return;
    final core = coreUnion ?? Path();

    // The coloured side within the disk (the other side stays empty).
    final coloured =
        inverted ? Path.combine(PathOperation.difference, disk, core) : core;

    final solidPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: _solidAlpha);
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: _bandAlpha);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: _strokeAlpha);

    final clip = Path()..addRect(_clip);
    Path bounded(Path p) => Path.combine(PathOperation.intersect, p, clip);

    // Band: the uncertainty-wide strip of the **coloured** side hugging the
    // line — the fill only becomes solid a band-width past the divider. Stroke
    // the dividing line at 2× the radius and clip it to the coloured side, so
    // only the near strip (never the arc, never the far side) lights up.
    //
    // The strip lies *on* the solid, so painting it normally would compound the
    // two alphas into something darker than either. Draw both into an offscreen
    // layer and give the band `BlendMode.src`: it replaces the solid's pixels
    // there instead of stacking on them, and the layer then composites once.
    final bandPx = bandMeters > 0 && bandRef != null
        ? _metersToPixels(bandRef, bandMeters)
        : 0.0;
    final coloredArea = bounded(coloured);
    if (bandPx > 0) canvas.saveLayer(_clip, Paint());
    canvas.drawPath(coloredArea, solidPaint);
    if (bandPx > 0) {
      canvas.save();
      canvas.clipPath(coloredArea);
      canvas.drawPath(
          boundary,
          bandPaint
            ..strokeWidth = 2 * bandPx
            ..blendMode = BlendMode.src);
      canvas.restore();
      canvas.restore();
    }

    // Outline: the dividing line, clipped to the disk.
    canvas.save();
    canvas.clipPath(bounded(disk));
    canvas.drawPath(boundary, strokePaint);
    canvas.restore();
  }

  /// A filled screen-space buffer of [runs] — every point within [radiusPx] of
  /// the polylines. Built as the union (non-zero winding) of one quad per segment
  /// plus a disc at each vertex (round joins), so it is robust: overlapping or
  /// self-crossing pieces just merge instead of carving even-odd holes. Used to
  /// grow/shrink the freeline's filled side by a metric offset without the
  /// island artefacts a vertex offset produces at tight bends.
  Path _ribbon(List<List<LatLng>> runs, double radiusPx) {
    final path = Path();
    for (final run in runs) {
      if (run.length < 2) continue;
      final pts = [for (final p in run) camera.latLngToScreenOffset(p)];
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i], b = pts[i + 1];
        final d = b - a;
        final len = d.distance;
        if (len == 0) continue;
        final n = Offset(-d.dy / len, d.dx / len) * radiusPx; // left normal
        path.moveTo(a.dx + n.dx, a.dy + n.dy);
        path.lineTo(b.dx + n.dx, b.dy + n.dy);
        path.lineTo(b.dx - n.dx, b.dy - n.dy);
        path.lineTo(a.dx - n.dx, a.dy - n.dy);
        path.close();
      }
      for (final p in pts) {
        path.addOval(Rect.fromCircle(center: p, radius: radiusPx));
      }
    }
    return path;
  }

  /// Appends [ring] as an **open** subpath (no close) to [path] — used to build
  /// the freehand-line boundary for stroking.
  void _addPolyline(Path path, List<LatLng> ring) {
    if (ring.length < 2) return;
    final o0 = camera.latLngToScreenOffset(ring[0]);
    path.moveTo(o0.dx, o0.dy);
    for (var i = 1; i < ring.length; i++) {
      final o = camera.latLngToScreenOffset(ring[i]);
      path.lineTo(o.dx, o.dy);
    }
  }

  /// A screen-space even-odd path through [contours] (so holes/islands read
  /// correctly), projecting each lat/lng vertex with the current camera. Each
  /// contour is pre-clipped to [_clip]; clipping rings independently preserves
  /// even-odd parity inside the clip box, since a point keeps its in/out state
  /// per ring under intersection with the same convex region.
  Path _contoursToPath(List<List<LatLng>> contours) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final ring in contours) {
      if (ring.length < 3) continue;
      final pts = clipRingToRect(
          [for (final p in ring) camera.latLngToScreenOffset(p)], _clip);
      if (pts.length < 3) continue;
      path.moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
    }
    return path;
  }

  /// Paints a height layer: each region's stored polygons fill with an even-odd
  /// path (so enclosed sub-threshold pockets read as holes), plus an uncertainty
  /// **band** along the *elevation* border only (the circle clip arc is
  /// excluded). Like every other type, the band is the uncertain strip on the
  /// **coloured** side: it is clipped to the fill, so the border line stays put
  /// and the fill only reads as fully solid a band-width inside it (holes get
  /// the same treatment from their side). The fill already encodes above/below
  /// and is bounded, so there is no viewport invert here.
  void _paintHeight(Canvas canvas, Size size) {
    final solidPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: _solidAlpha);
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: _bandAlpha);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: _strokeAlpha);

    for (final r in heightRegions) {
      final polys =
          heightPolygons.where((p) => p.heightRegionId == r.id).toList();
      if (polys.isEmpty) continue;
      final center = LatLng(r.centerLat, r.centerLng);
      final rMeters = r.radiusMeters;

      final fill = Path()..fillType = PathFillType.evenOdd;
      final contour = Path(); // the real elevation border, for band + outline
      var hasFill = false;
      for (final poly in polys) {
        final pts =
            heightPolygonPoints.where((p) => p.polygonId == poly.id).toList();
        if (pts.length < 3) continue;
        final offs = <Offset>[
          for (final p in pts)
            camera.latLngToScreenOffset(LatLng(p.lat, p.lng)),
        ];
        fill.moveTo(offs[0].dx, offs[0].dy);
        for (var i = 1; i < offs.length; i++) {
          fill.lineTo(offs[i].dx, offs[i].dy);
        }
        fill.close();
        hasFill = true;
        // Stroke only edges that aren't the circle clip arc (both endpoints on
        // the boundary ring) — those aren't a real height border.
        for (var i = 0; i < pts.length; i++) {
          final a = pts[i];
          final b = pts[(i + 1) % pts.length];
          final dA = _distance.as(LengthUnit.Meter, center, LatLng(a.lat, a.lng));
          final dB = _distance.as(LengthUnit.Meter, center, LatLng(b.lat, b.lng));
          if (dA > rMeters * 0.97 && dB > rMeters * 0.97) continue;
          final bo = offs[(i + 1) % offs.length];
          contour.moveTo(offs[i].dx, offs[i].dy);
          contour.lineTo(bo.dx, bo.dy);
        }
      }
      if (!hasFill) continue;

      final bandPx =
          uncertaintyMeters > 0 ? _metersToPixels(center, uncertaintyMeters) : 0.0;
      if (bandPx <= 0) {
        canvas.drawPath(fill, solidPaint);
      } else {
        // Band only *inside* the fill: stroke the contour at twice the radius
        // and clip it to the fill, so the outer half of the corridor is dropped
        // and the band is exactly the uncertain strip just inside the border
        // (and just inside any sub-threshold hole's border). The solid starts
        // where it ends.
        //
        // The strip overlays the solid, so drawing it plainly would compound the
        // alphas; render both into an offscreen layer and let the band
        // `BlendMode.src`-replace the solid's pixels there instead.
        canvas.saveLayer(_clip, Paint());
        canvas.drawPath(fill, solidPaint);
        canvas.save();
        canvas.clipPath(fill);
        canvas.drawPath(
            contour,
            bandPaint
              ..strokeWidth = 2 * bandPx
              ..blendMode = BlendMode.src);
        canvas.restore();
        canvas.restore();
      }
      canvas.drawPath(contour, strokePaint);
    }
  }

  /// Screen-space length (px) of [meters] on the ground near [at].
  double _metersToPixels(LatLng at, double meters) {
    final east = _distance.offset(at, meters, 90);
    return (camera.latLngToScreenOffset(at) - camera.latLngToScreenOffset(east))
        .distance;
  }

  /// The four corners of the (slightly inflated) viewport as lat/lng, in ring
  /// order, for use as the spherical clip quad. Null when a corner unprojects to
  /// a non-finite coordinate (extreme zoom-out / near-pole).
  List<LatLng>? _viewportCorners(Size size) {
    final r = (Offset.zero & size).inflate(8);
    final offs = <Offset>[r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    final out = <LatLng>[];
    for (final o in offs) {
      final ll = camera.screenOffsetToLatLng(o);
      if (!ll.latitude.isFinite || !ll.longitude.isFinite) return null;
      out.add(ll);
    }
    return out;
  }

  /// Projects [ring] and pre-clips it to [_clip] (see [clipRingToRect]) before
  /// building the closed path, so Skia never sees far-off-screen vertices.
  /// Returns an empty path when nothing of the ring is in view.
  Path _ringToPath(List<LatLng> ring) {
    final pts = clipRingToRect(
        [for (final p in ring) camera.latLngToScreenOffset(p)], _clip);
    final path = Path();
    if (pts.length < 3) return path;
    path.moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    return path;
  }

  /// A projected ring with the **even-odd** fill rule, so a self-crossing cut
  /// ring (a looping freehand line) resolves to the correct alternating "this
  /// side / the other side" regions instead of a winding-filled blob. NOT
  /// pre-clipped: Sutherland–Hodgman assumes a simple polygon, and these rings
  /// may self-cross.
  Path _ringToPathEvenOdd(List<LatLng> ring) {
    final path = Path()..fillType = PathFillType.evenOdd;
    if (ring.length < 3) return path;
    final o0 = camera.latLngToScreenOffset(ring[0]);
    path.moveTo(o0.dx, o0.dy);
    for (var i = 1; i < ring.length; i++) {
      final o = camera.latLngToScreenOffset(ring[i]);
      path.lineTo(o.dx, o.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _RegionPainter old) {
    // The widget is rebuilt with a fresh camera on every map move, so a simple
    // identity/value comparison is enough to avoid redundant repaints.
    return old.color != color ||
        old.inverted != inverted ||
        old.opacity != opacity ||
        old.uncertaintyMeters != uncertaintyMeters ||
        !identical(old.circles, circles) ||
        !identical(old.planes, planes) ||
        !identical(old.subspaces, subspaces) ||
        !identical(old.subspacePoints, subspacePoints) ||
        !identical(old.freeLines, freeLines) ||
        !identical(old.freeLinePoints, freeLinePoints) ||
        !identical(old.freeAreas, freeAreas) ||
        !identical(old.freeAreaPoints, freeAreaPoints) ||
        !identical(old.heightRegions, heightRegions) ||
        !identical(old.heightPolygons, heightPolygons) ||
        !identical(old.heightPolygonPoints, heightPolygonPoints) ||
        old.camera.center != camera.center ||
        old.camera.zoom != camera.zoom ||
        old.camera.rotation != camera.rotation;
  }
}
