import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Lat/lng geometry for a "freehand area": a user-drawn closed polygon (ring).
/// The region returned fills the inside; the layer's invert fills the outside
/// via the engine's `viewport − outer` complement.
///
/// The ring is drawn in lat/lng (correct); only the offset/inset is made
/// geodesic here, by moving each vertex on the ground with [Distance] along its
/// inward normal bearing — so a fixed `offsetMeters` holds a constant real-world
/// width regardless of latitude. To match the engine's `band = outer − core`
/// model one ring is the nominal interior (inset by `offsetMeters`) and the
/// other offsets it by `bandMeters` to put the band on the **uncoloured** side:
/// normally (`bandInward` false) [outer] grows past the ring (`offsetMeters −
/// bandMeters`) and [core] is the nominal interior; when the layer is inverted
/// (`bandInward` true) [outer] is the nominal interior and [core] is shrunk
/// inward (`offsetMeters + bandMeters`).
class FreeAreaRegion {
  const FreeAreaRegion(this.outer, this.core);

  /// The interior on the band's outer edge, as a lat/lng ring. Empty when fewer
  /// than three finite points are given or an inset collapses the ring.
  final List<LatLng> outer;

  /// The interior on the band's inner edge.
  final List<LatLng> core;
}

const Distance _distance = Distance(calculator: Haversine());

/// Builds the interior rings for the closed ring [ring]. [offsetMeters] is the
/// signed inward offset and [bandMeters] the uncertainty half-band, both on the
/// ground.
FreeAreaRegion freeAreaRegion({
  required List<LatLng> ring,
  required double offsetMeters,
  required double bandMeters,
  bool bandInward = false,
}) {
  final pts = <LatLng>[
    for (final p in ring)
      if (p.latitude.isFinite && p.longitude.isFinite) p,
  ];
  if (pts.length < 3) return const FreeAreaRegion(<LatLng>[], <LatLng>[]);
  // Keep the nominal ring (inset by offset) on the coloured side; offset the
  // other ring by the band onto the uncoloured side (outward by default, inward
  // when inverted), so the band hugs the divide on its uncoloured side.
  final outerInset = bandInward ? offsetMeters : offsetMeters - bandMeters;
  final coreInset = bandInward ? offsetMeters + bandMeters : offsetMeters;
  return FreeAreaRegion(_inset(pts, outerInset), _inset(pts, coreInset));
}

/// Insets the simple ring [p] inward by signed metres [d] (positive shrinks,
/// negative grows) by moving each vertex along its inward normal bearing.
/// Returns empty if the inset collapses or inverts the ring.
List<LatLng> _inset(List<LatLng> p, double d) {
  if (d == 0) return List<LatLng>.of(p);
  final n = p.length;
  final orient0 = _signedArea(p);
  if (orient0 == 0) return <LatLng>[];

  final centroid = LatLng(
    p.map((q) => q.latitude).reduce((a, b) => a + b) / n,
    p.map((q) => q.longitude).reduce((a, b) => a + b) / n,
  );

  // Inward normal bearing of each edge (perpendicular pointing toward centroid).
  final edgeIn = <double>[
    for (var i = 0; i < n; i++) _inwardBearing(p[i], p[(i + 1) % n], centroid),
  ];

  final out = <LatLng>[
    for (var i = 0; i < n; i++)
      () {
        // Vertex i sits between edge (i-1) and edge i; average their inward normals.
        final b = _avgBearing(edgeIn[(i - 1 + n) % n], edgeIn[i]);
        return _off(p[i], d.abs(), d > 0 ? b : b + 180);
      }(),
  ];

  // Reject a collapsed inset: flipped orientation, or a shrink that overshot the
  // inradius (same orientation but grew rather than shrank).
  final orient1 = _signedArea(out);
  if (orient0 * orient1 <= 0) return <LatLng>[];
  if (d > 0 && orient1.abs() >= orient0.abs()) return <LatLng>[];
  return out;
}

/// The perpendicular of edge `a→b` that points toward [centroid] (degrees).
double _inwardBearing(LatLng a, LatLng b, LatLng centroid) {
  final edge = _distance.bearing(a, b);
  final mid = LatLng((a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2);
  final left = edge - 90;
  final pLeft = _off(mid, 1, left);
  final pRight = _off(mid, 1, edge + 90);
  return _distance.distance(pLeft, centroid) <=
          _distance.distance(pRight, centroid)
      ? left
      : edge + 90;
}

/// Planar signed area in lat/lng degrees — adequate for orientation sign and the
/// relative-size collapse check at the scales these polygons live at.
double _signedArea(List<LatLng> p) {
  var a = 0.0;
  for (var i = 0; i < p.length; i++) {
    final q = p[i];
    final r = p[(i + 1) % p.length];
    a += q.longitude * r.latitude - r.longitude * q.latitude;
  }
  return a / 2;
}

LatLng _off(LatLng from, double meters, double bearing) =>
    _distance.offset(from, meters, _norm180(bearing));

double _norm180(double deg) {
  var d = deg % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

double _avgBearing(double a, double b) {
  final ar = a * pi / 180, br = b * pi / 180;
  final x = cos(ar) + cos(br);
  final y = sin(ar) + sin(br);
  if (x == 0 && y == 0) return a;
  return atan2(y, x) * 180 / pi;
}
