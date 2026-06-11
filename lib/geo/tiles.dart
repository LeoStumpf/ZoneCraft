import 'dart:math' as math;

/// Web-Mercator "slippy map" tile maths, used by the offline-prefetch logic to
/// enumerate which `{z}/{x}/{y}` tiles cover a viewport. Pure and dependency-free
/// so it's easy to unit-test. See <https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames>.

/// The tile column index for [lng] at integer zoom [z], clamped to `[0, 2^z-1]`.
int tileXFor(double lng, int z) {
  final n = 1 << z;
  final x = ((lng + 180.0) / 360.0 * n).floor();
  return x.clamp(0, n - 1);
}

/// The tile row index for [lat] at integer zoom [z], clamped to `[0, 2^z-1]`.
/// Latitudes are clamped to the Web-Mercator limit (~±85.05°) first.
int tileYFor(double lat, int z) {
  final n = 1 << z;
  final clampedLat = lat.clamp(-85.05112878, 85.05112878);
  final latRad = clampedLat * math.pi / 180.0;
  final y = ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
          2.0 *
          n)
      .floor();
  return y.clamp(0, n - 1);
}
