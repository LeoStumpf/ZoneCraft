import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle, Path;

import '../data/database.dart';
import '../geo/freearea.dart';
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
  final double uncertaintyMeters;

  static const int _ringPoints = 90;
  static const Distance _distance = Distance(calculator: Haversine());

  @override
  void paint(Canvas canvas, Size size) {
    // Clip so plane polygons (which extend a few px past the viewport to hide
    // their viewport-edge stroke) don't paint outside this layer's bounds.
    canvas.clipRect(Offset.zero & size);

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

    for (final c in circles) {
      final center = LatLng(c.centerLat, c.centerLng);
      final outerRing =
          geodesicCircle(center, c.radiusMeters, points: _ringPoints);
      if (outerRing.isEmpty) continue; // invalid geometry -> skip
      addOuter(outerRing);
      final coreRadius = c.radiusMeters - uncertaintyMeters;
      if (coreRadius > 0) {
        addCore(geodesicCircle(center, coreRadius, points: _ringPoints));
      }
    }

    // The band straddles each divide; its half-width on the ground is half the
    // global uncertainty (matching the circle's full-width core inset).
    final band = uncertaintyMeters > 0 ? uncertaintyMeters / 2 : 0.0;
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
        );
        addOuter(region.outer);
        addCore(region.core);
      }
    }

    if (freeAreas.isNotEmpty) {
      for (final a in freeAreas) {
        final pts = freeAreaPoints.where((p) => p.freeAreaId == a.id).toList();
        if (pts.length < 3) continue;
        final region = freeAreaRegion(
          ring: <LatLng>[for (final p in pts) LatLng(p.lat, p.lng)],
          offsetMeters: a.offsetMeters,
          bandMeters: band,
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

    // Regions are disjoint, so paint order is irrelevant.
    canvas.drawPath(solid, solidPaint);
    canvas.drawPath(bandPath, bandPaint);
    canvas.drawPath(outer, strokePaint);
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
        old.camera.center != camera.center ||
        old.camera.zoom != camera.zoom ||
        old.camera.rotation != camera.rotation;
  }
}
