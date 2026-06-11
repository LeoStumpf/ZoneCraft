import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/geo/tiles.dart';

void main() {
  group('slippy tile maths', () {
    test('known Berlin tile (z=10) matches the OSM wiki example', () {
      // lat 52.52, lon 13.40 at zoom 10 -> tile (550, 335).
      expect(tileXFor(13.40, 10), 550);
      expect(tileYFor(52.52, 10), 335);
    });

    test('zoom 1 quadrants', () {
      expect(tileXFor(-179, 1), 0);
      expect(tileXFor(1, 1), 1);
      expect(tileYFor(45, 1), 0); // northern hemisphere -> top row
      expect(tileYFor(-45, 1), 1); // southern hemisphere -> bottom row
    });

    test('zoom 0 is a single tile', () {
      expect(tileXFor(123.4, 0), 0);
      expect(tileYFor(-12.3, 0), 0);
    });

    test('coordinates clamp into [0, 2^z - 1]', () {
      expect(tileXFor(180, 5), 31); // east edge clamps, not 32
      expect(tileYFor(89, 5), inInclusiveRange(0, 31)); // beyond mercator limit
      expect(tileYFor(-89, 5), 31);
    });
  });

  group('tilesCovering', () {
    test('covers the exact tile of a box inside one tile', () {
      final one = tilesCovering(
          west: 13.40, east: 13.41, north: 52.52, south: 52.51, z: 10);
      expect(one, [const TileCoord(550, 335)]);
    });

    test('enumerates the full rectangle of tiles with no duplicates', () {
      final tiles = tilesCovering(
          west: 13.30, east: 13.80, north: 52.60, south: 52.30, z: 10);
      final xs = tiles.map((t) => t.x).toSet();
      final ys = tiles.map((t) => t.y).toSet();
      expect(tiles.length, xs.length * ys.length);
      expect(tiles.toSet().length, tiles.length); // unique
      // North maps to the smaller tile-Y.
      expect(ys.reduce((a, b) => a < b ? a : b),
          lessThan(ys.reduce((a, b) => a > b ? a : b)));
    });

    test('a ring widens the span on every side', () {
      final base = tilesCovering(
          west: 13.40, east: 13.41, north: 52.52, south: 52.51, z: 10);
      final ringed = tilesCovering(
          west: 13.40, east: 13.41, north: 52.52, south: 52.51, z: 10, ring: 1);
      expect(base.length, 1);
      expect(ringed.length, 9); // 3x3 around the single tile
    });

    test('drops rows off the top/bottom of the map but keeps columns', () {
      // At zoom 0 the whole world is one tile; a ring can't add rows (clamped).
      final tiles = tilesCovering(
          west: -10, east: 10, north: 10, south: -10, z: 0, ring: 1);
      expect(tiles.every((t) => t.y == 0), isTrue);
      expect(tiles.every((t) => t.x >= 0), isTrue);
    });
  });
}
