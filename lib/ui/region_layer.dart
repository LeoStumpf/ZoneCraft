import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle, Path;

import '../data/database.dart';
import '../geo/geodesic.dart';
import '../geo/plane.dart';

/// Renders one layer's objects as a single composited region.
///
/// All of a layer's objects are unioned into one shape before painting, so
/// overlaps show a flat colour instead of compounding opacity. A lighter
/// "uncertainty" band is drawn between the core (object shrunk by
/// [uncertaintyMeters]) and the full outline. When [Layer.isInverted] is set,
/// the solid fill becomes the complement (everything outside the objects),
/// while the band still hugs the boundary.
///
/// Projection is done in screen space via [MapCamera.latLngToScreenOffset], and
/// the unions use `dart:ui` `Path.combine`.
class RegionLayer extends StatelessWidget {
  const RegionLayer({
    super.key,
    required this.layer,
    this.circles = const <Circle>[],
    this.planes = const <Plane>[],
    required this.uncertaintyMeters,
  });

  final Layer layer;
  final List<Circle> circles;
  final List<Plane> planes;
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
    required this.uncertaintyMeters,
  });

  final MapCamera camera;
  final Color color;
  final bool inverted;
  final List<Circle> circles;
  final List<Plane> planes;
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

    for (final c in circles) {
      final center = LatLng(c.centerLat, c.centerLng);
      final outerRing = geodesicCircle(center, c.radiusMeters, points: _ringPoints);
      if (outerRing.isEmpty) continue; // invalid geometry -> skip
      final outerPath = _ringToPath(outerRing);
      outerUnion = outerUnion == null
          ? outerPath
          : Path.combine(PathOperation.union, outerUnion, outerPath);

      final coreRadius = c.radiusMeters - uncertaintyMeters;
      if (coreRadius > 0) {
        final coreRing = geodesicCircle(center, coreRadius, points: _ringPoints);
        if (coreRing.isNotEmpty) {
          final corePath = _ringToPath(coreRing);
          coreUnion = coreUnion == null
              ? corePath
              : Path.combine(PathOperation.union, coreUnion, corePath);
        }
      }
    }

    if (planes.isNotEmpty) {
      // Inflate so the half-plane's viewport-edge runs just outside the canvas
      // (clipped away above), leaving only the dividing edge stroked.
      final bounds = (Offset.zero & size).inflate(8);
      for (final p in planes) {
        final a = camera.latLngToScreenOffset(LatLng(p.aLat, p.aLng));
        final b = camera.latLngToScreenOffset(LatLng(p.bLat, p.bLng));
        if (!a.dx.isFinite ||
            !a.dy.isFinite ||
            !b.dx.isFinite ||
            !b.dy.isFinite) {
          continue;
        }
        final region = planeRegion(
          a: a,
          b: b,
          nearA: p.nearA,
          halfBandPx: _halfBandPx(p),
          bounds: bounds,
        );
        if (region.outer.length >= 3) {
          final outerPath = _polyToPath(region.outer);
          outerUnion = outerUnion == null
              ? outerPath
              : Path.combine(PathOperation.union, outerUnion, outerPath);
        }
        if (region.core.length >= 3) {
          final corePath = _polyToPath(region.core);
          coreUnion = coreUnion == null
              ? corePath
              : Path.combine(PathOperation.union, coreUnion, corePath);
        }
      }
    }

    if (outerUnion == null) return; // nothing valid to draw
    final core = coreUnion ?? Path();

    // Band is always the ring between core and outline.
    final band = Path.combine(PathOperation.difference, outerUnion, core);

    // Solid fill: the core normally, or the complement when inverted.
    final Path solid;
    if (inverted) {
      final viewport = Path()..addRect(Offset.zero & size);
      solid = Path.combine(PathOperation.difference, viewport, outerUnion);
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
    canvas.drawPath(band, bandPaint);
    canvas.drawPath(outerUnion, strokePaint);
  }

  /// Half the uncertainty-band width, in pixels, measured at the plane's
  /// midpoint (where the dividing edge sits). 0 when uncertainty is off or the
  /// midpoint is non-finite.
  double _halfBandPx(Plane p) {
    if (uncertaintyMeters <= 0) return 0;
    final mid = LatLng((p.aLat + p.bLat) / 2, (p.aLng + p.bLng) / 2);
    if (!mid.latitude.isFinite || !mid.longitude.isFinite) return 0;
    final off = _distance.offset(mid, uncertaintyMeters, 0); // u metres north
    final px = (camera.latLngToScreenOffset(mid) -
            camera.latLngToScreenOffset(off))
        .distance;
    return px.isFinite ? px / 2 : 0;
  }

  Path _polyToPath(List<Offset> poly) {
    final path = Path()..moveTo(poly.first.dx, poly.first.dy);
    for (var i = 1; i < poly.length; i++) {
      path.lineTo(poly[i].dx, poly[i].dy);
    }
    path.close();
    return path;
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
        old.camera.center != camera.center ||
        old.camera.zoom != camera.zoom ||
        old.camera.rotation != camera.rotation;
  }
}
