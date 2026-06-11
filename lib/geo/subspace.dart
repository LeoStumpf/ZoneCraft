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
}) {
  final cell = sphericalCell(
    main: main,
    others: others,
    bandMeters: bandMeters,
    viewportCorners: viewportCorners,
  );
  return SubspaceRegion(cell.outer, cell.core);
}
