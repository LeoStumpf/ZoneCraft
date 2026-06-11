import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Lat/lng geometry for a "freehand line": a user-drawn polyline that divides
/// the viewport into two sides. The region returned fills the side on the
/// polyline's **right** (the `+90°` normal of its direction of travel); the
/// layer's invert flips to the other side via the engine's `viewport − outer`
/// complement.
///
/// The divide is the drawn polyline itself (already lat/lng); only the offset is
/// made geodesic here. A partial line is completed by **extending its first and
/// last segments straight** (along their end bearings) far past the viewport, so
/// it still cleanly splits the whole view. The boundary is offset on the ground
/// with [Distance], so a fixed `offsetMeters` keeps a constant real-world width
/// regardless of latitude — unlike the old single-reference pixel scale.
///
/// To match the engine's `band = outer − core` model, the boundary is shifted
/// toward the filled side by the signed `offsetMeters`: [outer] shifts
/// `offsetMeters − bandMeters`, [core] `offsetMeters + bandMeters`. A positive
/// offset pushes the boundary into the filled side; a negative one past the line.
class FreeLineRegion {
  const FreeLineRegion(this.outer, this.core);

  /// The filled side enlarged by half the band, as a lat/lng ring. Empty when
  /// fewer than two finite points are given or the geometry is degenerate.
  final List<LatLng> outer;

  /// The filled side shrunk by half the band.
  final List<LatLng> core;
}

const Distance _distance = Distance(calculator: Haversine());

/// Builds the filled-side rings for the polyline [points]. [offsetMeters] is the
/// signed boundary offset and [bandMeters] the uncertainty half-band, both on
/// the ground. [spanMeters] is a characteristic viewport size (e.g. its diagonal
/// in metres) used to extend the line and the fill cap well past the view.
FreeLineRegion freeLineRegion({
  required List<LatLng> points,
  required double offsetMeters,
  required double bandMeters,
  required double spanMeters,
}) {
  final pts = <LatLng>[
    for (final p in points)
      if (p.latitude.isFinite && p.longitude.isFinite) p,
  ];
  if (pts.length < 2) return const FreeLineRegion(<LatLng>[], <LatLng>[]);

  final ext = spanMeters * 4 + 1000;
  // Extend the first/last segments straight so the line spans the whole view.
  final e0 = _off(pts.first, ext, _distance.bearing(pts[1], pts.first));
  final eEnd =
      _off(pts.last, ext, _distance.bearing(pts[pts.length - 2], pts.last));
  final ep = <LatLng>[e0, ...pts, eEnd];

  // Per-segment filled-side normal bearings (travel bearing + 90°), then average
  // adjacent segments at each vertex so offsets miter cleanly.
  final segN = <double>[
    for (var i = 0; i < ep.length - 1; i++)
      _distance.bearing(ep[i], ep[i + 1]) + 90,
  ];
  final vNorm = <double>[
    for (var i = 0; i < ep.length; i++)
      _avgBearing(
        i > 0 ? segN[i - 1] : null,
        i < segN.length ? segN[i] : null,
      ),
  ];
  // Overall filled-side direction, for the cap that closes the fill far away.
  final capBearing = _distance.bearing(e0, eEnd) + 90;
  final huge = spanMeters * 6 + 4000;

  List<LatLng> build(double shift) {
    final mag = shift.abs();
    final near = <LatLng>[
      for (var i = 0; i < ep.length; i++)
        _off(ep[i], mag, shift >= 0 ? vNorm[i] : vNorm[i] + 180),
    ];
    // Sweep out HUGE along the fixed filled-side bearing, then back, covering the
    // whole side without per-vertex fan-out crossings.
    return <LatLng>[
      ...near,
      _off(near.last, huge, capBearing),
      _off(near.first, huge, capBearing),
    ];
  }

  return FreeLineRegion(
    build(offsetMeters - bandMeters),
    build(offsetMeters + bandMeters),
  );
}

/// [Distance.offset] with the bearing normalised to the required −180..180.
LatLng _off(LatLng from, double meters, double bearing) =>
    _distance.offset(from, meters, _norm180(bearing));

double _norm180(double deg) {
  var d = deg % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

/// Circular mean of up to two bearings (degrees); returns whichever is present
/// when one is null.
double _avgBearing(double? a, double? b) {
  if (a == null) return b!;
  if (b == null) return a;
  final ar = a * pi / 180, br = b * pi / 180;
  final x = cos(ar) + cos(br);
  final y = sin(ar) + sin(br);
  if (x == 0 && y == 0) return a; // opposite bearings: pick one
  return atan2(y, x) * 180 / pi;
}
