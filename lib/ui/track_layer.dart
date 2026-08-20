import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/database.dart';
import 'camera_viewport.dart';
import 'element_color.dart';
import 'screen_clip.dart';

/// Renders a `track` layer: the recorded lines, stroked in their own colour at
/// the layer's stroke width.
///
/// Its own painter rather than a [RegionLayer] type, for the same reason the
/// borders layer is: a track is a **path**, not a region. There is nothing to
/// union, nothing to fill, and nothing to invert — and no uncertainty band
/// either, since widening a recording sideways would suggest the phone might
/// have been somewhere it wasn't, which is the opposite of what the band means
/// everywhere else. No `Path.combine` is involved anywhere here.
///
/// A recording is also the largest point list the app produces without asking
/// anyone: an afternoon at 10 m spacing is thousands of vertices, and they are
/// re-projected on every camera tick. Two cheap passes keep that flat —
/// [thinScreenPoints] before any `Path` is built, and per-segment clipping
/// after.

/// Drops points that land within [minPx] of the last kept one.
///
/// Zoomed out, a whole walk collapses to a handful of pixels; drawing its ten
/// thousand vertices there costs the same as drawing them at street zoom and
/// looks identical to drawing twenty. Screen space rather than metres, because
/// what matters is what can be *seen*, and that changes with the camera while
/// the stored geometry does not.
///
/// The **last** point is always kept: a track's end is where you stopped, and
/// silently trimming it back would shorten the line as you record.
List<Offset> thinScreenPoints(List<Offset> pts, double minPx) {
  if (pts.length <= 2) return pts;
  final min2 = minPx * minPx;
  final out = <Offset>[pts.first];
  for (var i = 1; i < pts.length - 1; i++) {
    final d = pts[i] - out.last;
    if (d.dx * d.dx + d.dy * d.dy >= min2) out.add(pts[i]);
  }
  out.add(pts.last);
  return out;
}

/// Splits [points] wherever the segment index changes.
///
/// A change of segment is a gap the recording knows nothing about — a stop and
/// restart, a lost signal, time spent in the background — so the two sides must
/// not be joined by a stroke. Runs of one point yield nothing to draw.
List<List<TrackPoint>> splitSegments(List<TrackPoint> points) {
  if (points.isEmpty) return const [];
  final out = <List<TrackPoint>>[];
  var run = <TrackPoint>[points.first];
  for (var i = 1; i < points.length; i++) {
    if (points[i].segmentIndex != points[i - 1].segmentIndex) {
      out.add(run);
      run = <TrackPoint>[];
    }
    run.add(points[i]);
  }
  out.add(run);
  return [
    for (final r in out)
      if (r.length >= 2) r,
  ];
}

class TracksLayer extends StatelessWidget {
  const TracksLayer({
    super.key,
    required this.layer,
    required this.tracks,
    required this.pointsByTrack,
  });

  final Layer layer;
  final List<Track> tracks;

  /// Pre-grouped by track id — see the point-lookup providers. A `.where` scan
  /// here would run once per track per camera tick.
  final Map<String, List<TrackPoint>> pointsByTrack;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final visible = [
      for (final t in tracks)
        if (_overlapsViewport(t, camera.visibleBounds)) t,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        // The widget's own box, never `camera.size` — see [cameraViewport].
        size: camera.nonRotatedSize,
        painter: _TrackPainter(
          camera: camera,
          tracks: visible,
          pointsByTrack: pointsByTrack,
          layerColor: Color(layer.colorArgb),
          strokeWidth: layer.trackStrokeWidth,
          opacity: layer.opacity.clamp(0.0, 1.0),
        ),
      ),
    );
  }

  /// Culls on the track's stored bounds, before a single point is projected.
  /// Null bounds mean an empty track — one that exists because the layer was
  /// recorded into once and then cleared.
  static bool _overlapsViewport(Track t, LatLngBounds vp) {
    final south = t.south, west = t.west, north = t.north, east = t.east;
    if (south == null || west == null || north == null || east == null) {
      return false;
    }
    return south <= vp.north &&
        north >= vp.south &&
        west <= vp.east &&
        east >= vp.west;
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.camera,
    required this.tracks,
    required this.pointsByTrack,
    required this.layerColor,
    required this.strokeWidth,
    required this.opacity,
  });

  final MapCamera camera;
  final List<Track> tracks;
  final Map<String, List<TrackPoint>> pointsByTrack;
  final Color layerColor;
  final double strokeWidth;
  final double opacity;

  /// Points closer together than this on screen are dropped before drawing.
  static const double _thinPx = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final viewportRect = cameraViewport(camera);
    canvas.clipRect(viewportRect);
    // Every coordinate Skia sees stays inside a viewport-sized box: a track
    // spanning a country projects to ±10⁵ px at street zoom, which strokes
    // badly. The inflation keeps the clip's own cut ends off-canvas.
    final clip = viewportRect.inflate(strokeWidth + 4);

    for (final t in tracks) {
      final points = pointsByTrack[t.id] ?? const [];
      if (points.length < 2) continue;

      final path = Path();
      for (final run in splitSegments(points)) {
        final projected = thinScreenPoints(
          [for (final p in run) camera.latLngToScreenOffset(LatLng(p.lat, p.lng))],
          _thinPx,
        );
        for (var i = 0; i < projected.length - 1; i++) {
          final seg = clipSegmentToRect(projected[i], projected[i + 1], clip);
          if (seg == null) continue;
          path.moveTo(seg.$1.dx, seg.$1.dy);
          path.lineTo(seg.$2.dx, seg.$2.dy);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = elementColor(
            colorArgb: t.colorArgb,
            shadeIndex: t.colorShade,
            layerColor: layerColor,
          ).withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      old.camera != camera ||
      !identical(old.tracks, tracks) ||
      !identical(old.pointsByTrack, pointsByTrack) ||
      old.layerColor != layerColor ||
      old.strokeWidth != strokeWidth ||
      old.opacity != opacity;
}
