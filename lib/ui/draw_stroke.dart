import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../geo/simplify.dart';
import 'camera_viewport.dart';

/// Turning a finger stroke into freehand geometry.
///
/// The stroke is collected in **screen** coordinates (the map's non-rotated
/// widget box — see [cameraViewport]) and only converted at the end, which is
/// safe because a stroke is abandoned the moment a second finger arrives: the
/// camera cannot move underneath it.

/// A finger stroke's screen points thinned into a lat/lng polyline, or null when
/// the gesture was not a drawing at all.
///
/// Rejects anything whose bounding box is smaller than [minSpanPx] — a tap, or
/// the twitch of a finger that meant to pan — because a two-point object at one
/// spot is worse than nothing: it draws as an invisible degenerate region the
/// user then has to find and delete.
///
/// Thinning is **zoom-relative**, not a fixed ground distance. A finger emits a
/// point per frame, so the raw stroke is hundreds of vertices no matter how far
/// out the map is; [tolerancePx] px of screen error is what the user can
/// actually see, and at street zoom that is centimetres while over a country it
/// is hundreds of metres. A fixed metre tolerance would either keep every jitter
/// when zoomed out or flatten real detail when zoomed in.
List<LatLng>? strokeToPoints(
  List<Offset> stroke,
  MapCamera camera, {
  required bool closed,
  double tolerancePx = 2,
  double minSpanPx = 16,
  double minAreaPx = 200,
}) {
  if (stroke.length < 2) return null;

  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in stroke) {
    if (!p.dx.isFinite || !p.dy.isFinite) return null;
    minX = min(minX, p.dx);
    minY = min(minY, p.dy);
    maxX = max(maxX, p.dx);
    maxY = max(maxY, p.dy);
  }
  final span = Offset(maxX - minX, maxY - minY).distance;
  if (span < minSpanPx) return null;

  // An area also has to *enclose* something. A straight drag (or a scribble
  // back along itself) closes into a zero-area sliver, and `simplifyRing`
  // refuses to thin a ring it would collapse — so accepting it would leave a
  // hundred-handle polygon that draws as a line. Screen-space shoelace: cheap,
  // and "did that look like a shape" is a screen question.
  if (closed && _screenArea(stroke) < minAreaPx) return null;

  // Drop points the finger didn't really move — a held finger emits the same
  // position every frame, and duplicates only cost work downstream.
  final pts = <LatLng>[];
  Offset? last;
  for (final p in stroke) {
    if (last != null && (p - last).distance < 1) continue;
    last = p;
    final ll = camera.screenOffsetToLatLng(p);
    if (!ll.latitude.isFinite || !ll.longitude.isFinite) return null;
    pts.add(ll);
  }
  if (pts.length < 2) return null;

  final tolM = max(
    _metersPerPixel(camera, Offset(minX, minY)) * tolerancePx,
    0.5,
  );
  final out = closed ? simplifyRing(pts, tolM) : simplifyLine(pts, tolM);
  if (out.length < (closed ? 3 : 2)) return null;
  return out;
}

/// Area (px²) the closed stroke encloses, by the shoelace formula.
double _screenArea(List<Offset> pts) {
  var s = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return (s / 2).abs();
}

/// Ground metres one screen pixel covers near [at] (screen coordinates).
/// Rotation is a screen-space isometry, so the axis used doesn't matter.
double _metersPerPixel(MapCamera camera, Offset at) {
  const distance = Distance(calculator: Haversine());
  final a = camera.screenOffsetToLatLng(at);
  final b = camera.screenOffsetToLatLng(at + const Offset(1, 0));
  final m = distance.as(LengthUnit.Meter, a, b);
  return m.isFinite && m > 0 ? m : 1;
}

/// Paints the stroke being drawn, in screen space, so the user sees the line
/// under their finger before it becomes an object.
///
/// Takes the live list plus a [repaint] listenable rather than a copy: the
/// points arrive at pointer-event rate, and rebuilding the map screen for each
/// one would drop frames on exactly the gesture that has to feel immediate.
class StrokePainter extends CustomPainter {
  StrokePainter({
    required this.points,
    required this.color,
    required this.closed,
    required super.repaint,
  });

  final List<Offset> points;
  final Color color;

  /// Whether the shape closes on release (a freehand **area**), in which case
  /// the closing edge is previewed too — the user is drawing a region, and the
  /// part they never trace is the part they most need to see.
  final bool closed;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (closed) {
      canvas.drawPath(
        path..close(),
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.2),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant StrokePainter old) =>
      old.color != color || old.closed != closed;
}
