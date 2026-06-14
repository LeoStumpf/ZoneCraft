import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'spherical.dart';

/// Lat/lng geometry for a "closest subspace" object: the region of the viewport
/// closer to the [main] point than to any of the other points — the main
/// point's Voronoi cell, the intersection of the geodesic half-spaces "closer to
/// main than to Pⱼ" for every other point Pⱼ.
///
/// Each bisector is the **great circle** equidistant from main and Pⱼ (a curve
/// in Web Mercator), so the cell is built geodesically via [sphericalCell] and
/// returned as densified lat/lng rings the painter projects — like
/// [geodesicCircle].
///
/// To match the engine's `band = outer − core` model, each bisector is offset by
/// the uncertainty half-band: [outer] pushes every bisector toward the other
/// points (enlarging the cell), [core] pulls each toward main (shrinking it).
class SubspaceRegion {
  const SubspaceRegion(this.outer, this.core);

  /// The cell enlarged by half the band, as a lat/lng ring. Empty when there are
  /// no other points or the geometry is degenerate.
  final List<LatLng> outer;

  /// The cell shrunk by half the band. May be empty when the band swallows the
  /// whole cell within the viewport.
  final List<LatLng> core;
}

/// Builds the main point's cell, clipped to [viewportCorners] (the four corner
/// lat/lngs of the usually slightly inflated viewport, in ring order). [others]
/// are the non-main points. [bandMeters] is the uncertainty half-band on the
/// ground (0 disables it). Returns empty rings when [others] is empty or a point
/// coincides with [main].
SubspaceRegion subspaceRegion({
  required LatLng main,
  required List<LatLng> others,
  required double bandMeters,
  required List<LatLng> viewportCorners,
  int maxOthers = 32,
}) {
  // The main point's cell is bounded only by its *Voronoi neighbours* — points
  // close to it. Every far point's bisector lies entirely outside the cell
  // (masked by nearer points), so it can't change the result. With dense inputs
  // (e.g. POIs metres apart) that's dozens of useless half-plane clips per
  // frame, so keep just the nearest [maxOthers] before building the cell. The
  // neighbour count of a Voronoi cell is tiny, so this is exact in practice.
  final culled = others.length > maxOthers
      ? _nearest(main, others, maxOthers)
      : others;
  final cell = sphericalCell(
    main: main,
    others: culled,
    bandMeters: bandMeters,
    viewportCorners: viewportCorners,
  );
  return SubspaceRegion(cell.outer, cell.core);
}

/// The [n] points of [pts] nearest [origin], ranked by a cheap equirectangular
/// metric (exact ordering isn't needed — only "is this among the nearest few").
List<LatLng> _nearest(LatLng origin, List<LatLng> pts, int n) {
  final cosLat = cos(origin.latitude * pi / 180);
  double d2(LatLng p) {
    final dx = (p.longitude - origin.longitude) * cosLat;
    final dy = p.latitude - origin.latitude;
    return dx * dx + dy * dy;
  }

  final sorted = pts.toList()..sort((a, b) => d2(a).compareTo(d2(b)));
  return sorted.sublist(0, n);
}
