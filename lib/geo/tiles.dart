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

/// A `{z}/{x}/{y}` tile column/row pair (the zoom is carried by the caller).
class TileCoord {
  const TileCoord(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'TileCoord($x, $y)';
}

/// Enumerates the tiles covering the bounding box [west]..[east] (longitude) ×
/// [south]..[north] (latitude) at integer zoom [z], optionally widened by a
/// [ring] of extra tiles on every side. Longitude columns wrap around the
/// antimeridian; rows that fall off the top/bottom of the map are dropped.
///
/// Shared by the viewport prefetcher and the explicit "download this area"
/// action; pure and dependency-free for easy unit testing.
List<TileCoord> tilesCovering({
  required double west,
  required double east,
  required double north,
  required double south,
  required int z,
  int ring = 0,
}) {
  final n = 1 << z;
  final minX = tileXFor(west, z) - ring;
  final maxX = tileXFor(east, z) + ring;
  final minY = tileYFor(north, z) - ring; // north -> smaller tile-Y
  final maxY = tileYFor(south, z) + ring;
  final out = <TileCoord>[];
  for (var x = minX; x <= maxX; x++) {
    final cx = ((x % n) + n) % n; // wrap longitude
    for (var y = minY; y <= maxY; y++) {
      if (y < 0 || y >= n) continue; // off the top/bottom of the map
      out.add(TileCoord(cx, y));
    }
  }
  return out;
}
