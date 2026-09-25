// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Web-Mercator "slippy map" tile maths, used by the offline-prefetch logic to
/// enumerate which `{z}/{x}/{y}` tiles cover a viewport. Pure and dependency-free
/// so it's easy to unit-test. See <https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames>.

/// The Web-Mercator latitude limit: the projection maps ±[mercatorMaxLat] to
/// the top/bottom edge of the square world, and nothing beyond it is drawable.
/// Every latitude clamp in the app uses this one value.
const double mercatorMaxLat = 85.05112878;

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
  final clampedLat = lat.clamp(-mercatorMaxLat, mercatorMaxLat);
  final latRad = clampedLat * math.pi / 180.0;
  final y =
      ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
              2.0 *
              n)
          .floor();
  return y.clamp(0, n - 1);
}

/// A `{z}/{x}/{y}` tile column/row pair (the zoom is carried by the caller).
@immutable
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

/// One tile of a [tileWindow]: which tile, and where its top-left corner sits
/// in the window, in tile pixels (256 to a tile).
typedef WindowTile = ({int x, int y, double left, double top});

/// The tiles, and their offsets, that fill a square window [windowPx] tile
/// pixels wide centred on ([lat], [lng]) at zoom [z] — what an Elements row's
/// thumbnail draws, so the place sits in the middle whatever tile it falls in.
///
/// A window no wider than a tile touches at most four. Columns wrap at the
/// antimeridian; rows off the top or bottom of the world are left out (the
/// window shows blank there, as the map does).
List<WindowTile> tileWindow(double lat, double lng, int z, double windowPx) {
  final n = 1 << z;
  final world = 256.0 * n;
  final clampedLat = lat.clamp(-mercatorMaxLat, mercatorMaxLat);
  final latRad = clampedLat * math.pi / 180.0;
  final px = (lng + 180.0) / 360.0 * world;
  final py =
      (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
      2.0 *
      world;
  final ox = px - windowPx / 2, oy = py - windowPx / 2;
  final x0 = (ox / 256).floor(), x1 = ((ox + windowPx) / 256).ceil() - 1;
  final y0 = (oy / 256).floor(), y1 = ((oy + windowPx) / 256).ceil() - 1;
  return [
    for (var ty = y0; ty <= y1; ty++)
      if (ty >= 0 && ty < n)
        for (var tx = x0; tx <= x1; tx++)
          (
            x: ((tx % n) + n) % n,
            y: ty,
            left: tx * 256 - ox,
            top: ty * 256 - oy,
          ),
  ];
}
