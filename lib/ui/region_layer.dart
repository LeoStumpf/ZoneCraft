import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle, Path;

import '../data/database.dart';
import '../geo/freeline.dart';
import '../geo/geodesic.dart';
import '../geo/plane.dart';
import '../geo/subspace.dart';

/// Renders one layer's objects as a single composited region.
///
/// All of a layer's objects are unioned into one shape before painting, so
/// overlaps show a flat colour instead of compounding opacity. A lighter
/// "uncertainty" band is drawn between the core (object shrunk by
/// [uncertaintyMeters]) and the full outline. When [Layer.isInverted] is set,
/// the solid fill becomes the complement (everything outside the objects),
/// while the band still hugs the boundary.
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

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
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
          heightRegions: heightRegions,
          heightPolygons: heightPolygons,
          heightPolygonPoints: heightPolygonPoints,
          uncertaintyMeters: uncertaintyMeters,
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
    required this.heightRegions,
    required this.heightPolygons,
    required this.heightPolygonPoints,
    required this.uncertaintyMeters,
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
  final List<HeightRegion> heightRegions;
  final List<HeightPolygon> heightPolygons;
  final List<HeightPolygonPoint> heightPolygonPoints;
  final double uncertaintyMeters;

  static const int _ringPoints = 90;
  static const Distance _distance = Distance(calculator: Haversine());

  @override
  void paint(Canvas canvas, Size size) {
    // Clip so plane polygons (which extend a few px past the viewport to hide
    // their viewport-edge stroke) don't paint outside this layer's bounds.
    canvas.clipRect(Offset.zero & size);

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
    // uncertainty band on the **uncoloured** side: normal layers grow the region
    // outward, inverted layers shrink it inward (the fill is `viewport − outer`).
    final band = uncertaintyMeters > 0 ? uncertaintyMeters : 0.0;

    for (final c in circles) {
      final center = LatLng(c.centerLat, c.centerLng);
      // Outline stays at the drawn radius; the band sits just outside it (normal)
      // or just inside it (inverted).
      final outerRadius = inverted ? c.radiusMeters : c.radiusMeters + band;
      final coreRadius = inverted ? c.radiusMeters - band : c.radiusMeters;
      final outerRing = geodesicCircle(center, outerRadius, points: _ringPoints);
      if (outerRing.isEmpty) continue; // invalid geometry -> skip
      addOuter(outerRing);
      if (coreRadius > 0) {
        addCore(geodesicCircle(center, coreRadius, points: _ringPoints));
      }
    }
    // Plane/subspace clip to the viewport as a spherical quad; unproject its
    // (slightly inflated) corners once. Null at extreme zoom / near-pole.
    final corners = _viewportCorners(size);

    if (planes.isNotEmpty && corners != null) {
      for (final p in planes) {
        final region = planeRegion(
          a: LatLng(p.aLat, p.aLng),
          b: LatLng(p.bLat, p.bLng),
          nearA: p.nearA,
          bandMeters: band,
          viewportCorners: corners,
          bandInward: inverted,
        );
        addOuter(region.outer);
        addCore(region.core);
      }
    }

    if (subspaces.isNotEmpty && corners != null) {
      for (final s in subspaces) {
        final pts = subspacePoints.where((p) => p.subspaceId == s.id).toList();
        final mainPt = pts.where((p) => p.isMain).firstOrNull;
        if (mainPt == null) continue; // no main point -> nothing to fill
        final others = <LatLng>[
          for (final p in pts)
            if (p.id != mainPt.id) LatLng(p.lat, p.lng),
        ];
        final region = subspaceRegion(
          main: LatLng(mainPt.lat, mainPt.lng),
          others: others,
          bandMeters: band,
          viewportCorners: corners,
          bandInward: inverted,
        );
        addOuter(region.outer);
        addCore(region.core);
      }
    }

    if (freeLines.isNotEmpty) {
      final span = _spanMeters(corners);
      for (final l in freeLines) {
        final pts = freeLinePoints.where((p) => p.freeLineId == l.id).toList();
        if (pts.length < 2) continue;
        final region = freeLineRegion(
          points: <LatLng>[for (final p in pts) LatLng(p.lat, p.lng)],
          offsetMeters: l.offsetMeters,
          bandMeters: band,
          spanMeters: span,
          bandInward: inverted,
        );
        addOuter(region.outer);
        addCore(region.core);
      }
    }

    final outer = outerUnion;
    if (outer == null) return; // nothing valid to draw
    final core = coreUnion ?? Path();

    // Band is always the ring between core and outline.
    final bandPath = Path.combine(PathOperation.difference, outer, core);

    // Solid fill: the core normally, or the complement when inverted.
    final Path solid;
    if (inverted) {
      final viewport = Path()..addRect(Offset.zero & size);
      solid = Path.combine(PathOperation.difference, viewport, outer);
    } else {
      solid = core;
    }

    final solidPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.45);
    final bandPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.20);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;

    // The outline traces the *nominal* boundary, which every type keeps fixed
    // regardless of invert: normally that's `core` (the band grows outward from
    // it); when inverted the band shrinks inward so the nominal edge is `outer`.
    final outline = inverted ? outer : core;

    // Clip every path to the viewport via path-ops (double precision) before
    // rasterising. A large object (e.g. an imported city border) projects its
    // far vertices to screen coordinates well outside the view; Skia's scan
    // converter mis-rasterises such paths and drops part of the fill — a clean
    // straight cut across the shape. `canvas.clipRect` only masks the bad
    // output, so it can't fix this; intersecting the geometry bounds the
    // coordinates the rasteriser sees. Inflate past the canvas clip so any clip
    // edges this introduces fall outside the visible area (they're masked by the
    // `clipRect` above), keeping the stroked outline from tracing the viewport.
    final clip = Path()..addRect((Offset.zero & size).inflate(4));
    Path bounded(Path p) => Path.combine(PathOperation.intersect, p, clip);

    // Regions are disjoint, so paint order is irrelevant.
    canvas.drawPath(bounded(solid), solidPaint);
    canvas.drawPath(bounded(bandPath), bandPaint);
    canvas.drawPath(bounded(outline), strokePaint);
  }

  /// Paints a freehand-area layer. The nominal boundary (the outline) is the
  /// union of the drawn rings with each object's signed offset applied; the
  /// solid fills the interior (or, when inverted, the complement). The
  /// uncertainty band is a uniform strip of [uncertaintyMeters] hugging the
  /// boundary on the **uncoloured** side. Both the offset and the band are built
  /// by *buffering* the boundary rather than walking its vertices, so they keep
  /// a constant width around concave/convex corners alike — a vertex walk
  /// self-crosses at reflex corners into spikes and islands on a city outline.
  void _paintFreeAreas(Canvas canvas, Size size) {
    Path? coreUnion;
    for (final a in freeAreas) {
      final pts = freeAreaPoints.where((p) => p.freeAreaId == a.id).toList();
      if (pts.length < 3) continue;
      final offs = <Offset>[
        for (final p in pts) camera.latLngToScreenOffset(LatLng(p.lat, p.lng)),
      ];
      final path = _offsetCorePath(offs, a.offsetMeters);
      coreUnion = coreUnion == null
          ? path
          : Path.combine(PathOperation.union, coreUnion, path);
    }
    final core = coreUnion;
    if (core == null) return;

    final solidPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.45);
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.20);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;

    // Clip fills to the viewport via path-ops so the rasteriser never sees the
    // huge off-screen coordinates a city-sized ring projects to (see the note in
    // [paint]). Inflate past the canvas clip so introduced edges stay hidden.
    final viewport = Path()..addRect((Offset.zero & size).inflate(4));
    Path bounded(Path p) => Path.combine(PathOperation.intersect, p, viewport);

    // Solid: interior normally, the viewport complement when inverted.
    final solid = inverted
        ? Path.combine(PathOperation.difference, viewport, core)
        : core;
    canvas.drawPath(bounded(solid), solidPaint);

    final bandPx =
        uncertaintyMeters > 0 ? _metersToPixels(camera.center, uncertaintyMeters) : 0.0;
    if (bandPx > 0) {
      // Stroke the boundary at twice the band width (centred on the line, so the
      // kept half is exactly `band` wide) and clip to the uncoloured side. Clip
      // the boundary itself to a little past the band's reach first, so the
      // stroke only processes near-viewport geometry (bounding Skia's coords);
      // any rect edges that introduces sit beyond the band reach, outside the
      // visible clip.
      final reach = Path()..addRect((Offset.zero & size).inflate(bandPx + 24));
      final nearBoundary = Path.combine(PathOperation.intersect, core, reach);
      final uncoloured = inverted
          ? core
          : Path.combine(PathOperation.difference, viewport, core);
      canvas.save();
      canvas.clipPath(uncoloured);
      canvas.drawPath(nearBoundary, bandPaint..strokeWidth = 2 * bandPx);
      canvas.restore();
    }

    // Outline traces the nominal boundary.
    canvas.drawPath(bounded(core), strokePaint);
  }

  /// The nominal interior of one freehand ring [offs] (screen space) with its
  /// signed [offsetMeters] applied: positive shrinks (erodes), negative grows
  /// (dilates). Robust on concave outlines — instead of walking vertices it
  /// buffers the boundary and subtracts it from / adds it to the ring, a
  /// Minkowski erosion/dilation via path-ops.
  Path _offsetCorePath(List<Offset> offs, double offsetMeters) {
    final base = _offsetsToPath(offs);
    if (offsetMeters == 0 || offs.length < 3) return base;
    final rPx = _metersToPixels(camera.center, offsetMeters.abs());
    if (rPx <= 0) return base;
    final buffer = _boundaryBuffer(offs, rPx);
    return offsetMeters > 0
        ? Path.combine(PathOperation.difference, base, buffer)
        : Path.combine(PathOperation.union, base, buffer);
  }

  /// A closed screen-space path through [offs].
  Path _offsetsToPath(List<Offset> offs) {
    final path = Path();
    if (offs.isEmpty) return path;
    path.moveTo(offs.first.dx, offs.first.dy);
    for (var i = 1; i < offs.length; i++) {
      path.lineTo(offs[i].dx, offs[i].dy);
    }
    path.close();
    return path;
  }

  /// All points within [rPx] of the boundary through [offs]: the union of a
  /// rectangle swept along each edge and a disk at each vertex (to round the
  /// corners). Rectangles share one winding and disks another, so each set
  /// unions under the non-zero rule before they're merged with path-ops.
  Path _boundaryBuffer(List<Offset> offs, double rPx) {
    final n = offs.length;
    final rects = Path();
    final disks = Path();
    for (var i = 0; i < n; i++) {
      final a = offs[i];
      final b = offs[(i + 1) % n];
      final d = b - a;
      final len = d.distance;
      if (len > 0) {
        final nx = -d.dy / len * rPx;
        final ny = d.dx / len * rPx;
        rects.moveTo(a.dx + nx, a.dy + ny);
        rects.lineTo(b.dx + nx, b.dy + ny);
        rects.lineTo(b.dx - nx, b.dy - ny);
        rects.lineTo(a.dx - nx, a.dy - ny);
        rects.close();
      }
      disks.addOval(Rect.fromCircle(center: a, radius: rPx));
    }
    return Path.combine(PathOperation.union, rects, disks);
  }

  /// Paints a height layer: each region's stored polygons fill with an even-odd
  /// path (so enclosed sub-threshold pockets read as holes), plus an uncertainty
  /// **band** along the *elevation* border only (the circle clip arc is excluded)
  /// and clipped to the region's circle. The filled area stays fully solid; the
  /// band is drawn only *outside* the fill (the outer halo, and the halo inside
  /// holes), so the confident core never darkens and only the genuinely uncertain
  /// strip beyond the border is lightened. The fill already encodes above/below
  /// and is bounded, so there is no viewport invert here.
  void _paintHeight(Canvas canvas, Size size) {
    final solidPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.45);
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.20);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;

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

      // Solid fill stays fully solid.
      canvas.drawPath(fill, solidPaint);

      final bandPx =
          uncertaintyMeters > 0 ? _metersToPixels(center, uncertaintyMeters) : 0.0;
      if (bandPx > 0) {
        // Band only where it isn't already filled: clip to (circle − fill), so
        // the inner half of the corridor (over the solid core) is dropped and
        // the core never lightens. The outer half — and the halo inside any
        // sub-threshold holes — shows the uncertain strip.
        final ring = geodesicCircle(center, rMeters, points: _ringPoints);
        final bound = ring.isNotEmpty
            ? _ringToPath(ring)
            : (Path()..addRect(Offset.zero & size));
        final outside = Path.combine(PathOperation.difference, bound, fill);
        canvas.save();
        canvas.clipPath(outside);
        canvas.drawPath(contour, bandPaint..strokeWidth = bandPx);
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

  /// A characteristic viewport size in metres (its diagonal), used to extend
  /// freehand lines and their fill cap well past the view. Falls back to a
  /// globe-scale value when the corners are unavailable.
  double _spanMeters(List<LatLng>? corners) {
    if (corners == null) return 40000000;
    return _distance.distance(corners[0], corners[2]);
  }

  Path _ringToPath(List<LatLng> ring) {
    final path = Path();
    for (var i = 0; i < ring.length; i++) {
      final o = camera.latLngToScreenOffset(ring[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
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
