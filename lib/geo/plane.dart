import 'package:latlong2/latlong.dart';

import 'spherical.dart';

/// Lat/lng geometry for a "plane" object: the region of the viewport that is
/// closer to the near point than the far point — i.e. the side of the
/// perpendicular bisector of A,B that contains the near point.
///
/// The bisector is the **great circle** equidistant from A and B (a curve in
/// Web Mercator), computed geodesically via [sphericalCell] and returned as
/// densified lat/lng rings that the painter projects — mirroring how
/// [geodesicCircle] builds circles. A plane is exactly a subspace with a single
/// "other" (far) point.
///
/// To match the rendering engine's `band = outer − core` model, the bisector is
/// offset by the uncertainty half-band: [outer] is the near side enlarged onto
/// the far side, [core] retracted onto the near side.
class PlaneRegion {
  const PlaneRegion(this.outer, this.core);

  /// Near side enlarged by half the band, as a lat/lng ring. Empty when the
  /// geometry is degenerate (A and B coincide) or non-finite.
  final List<LatLng> outer;

  /// Near side retracted by half the band. Empty when the band swallows the
  /// whole near side within the viewport.
  final List<LatLng> core;
}

/// Builds the near-side rings for a plane defined by [a] and [b]. [nearA]
/// selects which point's side is filled. [bandMeters] is the uncertainty
/// half-band on the ground (0 disables it). [viewportCorners] is the (usually
/// slightly inflated) viewport, as the four corner lat/lngs in ring order.
PlaneRegion planeRegion({
  required LatLng a,
  required LatLng b,
  required bool nearA,
  required double bandMeters,
  required List<LatLng> viewportCorners,
}) {
  final near = nearA ? a : b;
  final far = nearA ? b : a;
  final cell = sphericalCell(
    main: near,
    others: <LatLng>[far],
    bandMeters: bandMeters,
    viewportCorners: viewportCorners,
  );
  return PlaneRegion(cell.outer, cell.core);
}
