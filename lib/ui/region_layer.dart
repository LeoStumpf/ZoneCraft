import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle, Path;

import '../data/database.dart';
import '../geo/geodesic.dart';

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
    required this.circles,
    required this.uncertaintyMeters,
  });

  final Layer layer;
  final List<Circle> circles;
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
    required this.uncertaintyMeters,
  });

  final MapCamera camera;
  final Color color;
  final bool inverted;
  final List<Circle> circles;
  final double uncertaintyMeters;

  static const int _ringPoints = 90;

  @override
  void paint(Canvas canvas, Size size) {
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
        old.camera.center != camera.center ||
        old.camera.zoom != camera.zoom ||
        old.camera.rotation != camera.rotation;
  }
}
