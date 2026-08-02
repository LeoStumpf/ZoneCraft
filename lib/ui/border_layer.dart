import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/database.dart';
import '../geo/border_areas.dart';
import '../state/providers.dart';
import 'screen_clip.dart';
import 'screen_cluster.dart';

/// Renders a `borders` layer: its imported administrative areas, outlined in
/// the layer colour, optionally filled from a palette that no two neighbours
/// share, optionally named.
///
/// Two things make this its own painter rather than a `RegionLayer` type. The
/// areas are **not** unioned — the whole point is the individual borders — so
/// there is no `Path.combine` anywhere here (the freearea precedent, and the
/// path-ops fragility this repo has already been bitten by). And the fill has
/// no uncertainty band: an administrative border is a legal line, not a
/// measurement, so widening it would be inventing doubt that isn't there.

/// The area fill palette, indexed by [BorderArea.colorIndex]. Six entries; four
/// suffice for a planar map, and the spares absorb exclaves and areas meeting
/// at a point without ever needing a search.
const List<Color> borderPalette = [
  Color(0xFF4E79A7),
  Color(0xFFF28E2B),
  Color(0xFF59A14F),
  Color(0xFFE15759),
  Color(0xFFB07AA1),
  Color(0xFF76B7B2),
];

/// A vertex within this many degrees (~1 cm) of the import box edge is a cut,
/// not a border. Clipping produces exact edge coordinates and simplification
/// only ever *drops* vertices, so nothing drifts off the edge in between.
const double _edgeEpsilonDegrees = 1e-7;

/// One area with its geometry decoded, plus the box it was clipped to.
///
/// Decoding happens once per stream emission (see [borderShapesProvider]), not
/// per frame: a state-level area is over 100 000 points, and re-parsing that
/// JSON at 60 Hz is not a thing that can be done.
class BorderShape {
  const BorderShape({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.labelPoint,
    required this.rings,
    required this.box,
  });

  final String id;
  final String? name;
  final int colorIndex;

  /// The area's own bounds, for viewport culling.
  final double south, west, north, east;
  final LatLng labelPoint;

  /// Outer ring(s) and holes together, filled with even-odd parity — a ring
  /// inside another *is* a hole, so no role flag is needed.
  final List<List<LatLng>> rings;

  /// The set's imported box, so the painter can tell a real border from the
  /// straight edge where the import cut one.
  final LatLngBox box;
}

/// The decoded areas of one borders layer, rebuilt only when the rows change.
final borderShapesProvider =
    Provider.family<List<BorderShape>, String>((ref, layerId) {
  final sets = ref.watch(borderSetsProvider).asData?.value ?? const [];
  final areas = ref.watch(borderAreasProvider).asData?.value ?? const [];
  final boxes = <String, LatLngBox>{
    for (final s in sets)
      if (s.layerId == layerId)
        s.id: LatLngBox(
            south: s.south, west: s.west, north: s.north, east: s.east),
  };
  if (boxes.isEmpty) return const [];
  return [
    for (final a in areas)
      if (boxes[a.setId] case final box?)
        BorderShape(
          id: a.id,
          name: a.name,
          colorIndex: a.colorIndex,
          south: a.south,
          west: a.west,
          north: a.north,
          east: a.east,
          labelPoint: LatLng(a.labelLat, a.labelLng),
          rings: decodeRings(a.rings),
          box: box,
        ),
  ];
});

/// The areas of one borders layer.
class BorderAreasLayer extends StatelessWidget {
  const BorderAreasLayer({
    super.key,
    required this.layer,
    required this.shapes,
  });

  final Layer layer;
  final List<BorderShape> shapes;

  /// Name plates closer than this (screen px) collapse to whichever was placed
  /// first, so a zoomed-out import doesn't become a wall of overlapping text.
  static const double _plateSpacingPx = 64;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final visible = [
      for (final s in shapes)
        if (_overlapsViewport(s, camera.visibleBounds)) s,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        IgnorePointer(
          child: CustomPaint(
            size: camera.size,
            painter: _BorderPainter(
              camera: camera,
              shapes: visible,
              outline: Color(layer.colorArgb),
              fillAreas: layer.borderFillAreas,
              opacity: layer.opacity.clamp(0.0, 1.0),
            ),
          ),
        ),
        if (layer.borderShowNames) _plates(camera, visible),
      ],
    );
  }

  static bool _overlapsViewport(BorderShape s, LatLngBounds vp) =>
      s.south <= vp.north &&
      s.north >= vp.south &&
      s.west <= vp.east &&
      s.east >= vp.west;

  /// Name plates at each area's precomputed anchor, greedily thinned so no two
  /// overlap — the same seed-clustering pass the marker layers use, keeping one
  /// label per cluster instead of drawing a badge for it.
  Widget _plates(MapCamera camera, List<BorderShape> visible) {
    final named = [
      for (final s in visible)
        if (s.name != null && s.name!.isNotEmpty) s,
    ];
    if (named.isEmpty) return const SizedBox.shrink();
    final offsets = <Offset>[];
    final kept = <BorderShape>[];
    final bounds = (Offset.zero & camera.size).inflate(_plateSpacingPx);
    for (final s in named) {
      if (!s.labelPoint.latitude.isFinite ||
          !s.labelPoint.longitude.isFinite) {
        continue;
      }
      final o = camera.latLngToScreenOffset(s.labelPoint);
      if (!bounds.contains(o)) continue;
      offsets.add(o);
      kept.add(s);
    }
    if (offsets.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: [
        for (final c in clusterOffsets(offsets, _plateSpacingPx))
          _plate(kept[c.indices.first]),
      ],
    );
  }

  Marker _plate(BorderShape s) => Marker(
        point: s.labelPoint,
        width: 140,
        height: 18,
        alignment: Alignment.center,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              s.name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ),
      );
}

class _BorderPainter extends CustomPainter {
  _BorderPainter({
    required this.camera,
    required this.shapes,
    required this.outline,
    required this.fillAreas,
    required this.opacity,
  });

  final MapCamera camera;
  final List<BorderShape> shapes;

  /// The layer colour. It drives the **outline only** — the fills come from
  /// [borderPalette], because their whole job is to differ from each other.
  final Color outline;
  final bool fillAreas;

  /// The layer's opacity, which drives the **fill only**: an outline you can
  /// half see is just a worse outline.
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    // Every projected coordinate is confined to this box before Skia sees it:
    // a city-sized outline at street zoom projects to ±10⁵ px, where fills
    // rasterise with pieces missing. The inflation puts the clip's own cut
    // edges outside the canvas clip, so they are never visible as strokes.
    final clip = (Offset.zero & size).inflate(4);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = outline;

    for (final s in shapes) {
      if (fillAreas) {
        final path = Path()..fillType = PathFillType.evenOdd;
        var any = false;
        for (final ring in s.rings) {
          if (ring.length < 3) continue;
          final pts = clipRingToRect(
              [for (final p in ring) camera.latLngToScreenOffset(p)], clip);
          if (pts.length < 3) continue;
          path.moveTo(pts[0].dx, pts[0].dy);
          for (var i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
          path.close();
          any = true;
        }
        if (any) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.fill
              ..color = borderPalette[s.colorIndex % borderPalette.length]
                  .withValues(alpha: opacity),
          );
        }
      }

      // The outline is drawn segment by segment rather than as a ring, because
      // the segments lying on the import box edge have to be left out: those
      // are where the import cut the boundary, and drawing them would put a
      // confident straight line through the middle of a real area.
      final border = Path();
      for (final ring in s.rings) {
        if (ring.length < 2) continue;
        for (var i = 0; i < ring.length; i++) {
          final a = ring[i];
          final b = ring[(i + 1) % ring.length];
          if (onBoxEdge(a, s.box, _edgeEpsilonDegrees) &&
              onBoxEdge(b, s.box, _edgeEpsilonDegrees)) {
            continue;
          }
          final seg = clipSegmentToRect(camera.latLngToScreenOffset(a),
              camera.latLngToScreenOffset(b), clip);
          if (seg == null) continue;
          border.moveTo(seg.$1.dx, seg.$1.dy);
          border.lineTo(seg.$2.dx, seg.$2.dy);
        }
      }
      canvas.drawPath(border, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BorderPainter old) =>
      old.camera != camera ||
      old.shapes != shapes ||
      old.outline != outline ||
      old.fillAreas != fillAreas ||
      old.opacity != opacity;
}
