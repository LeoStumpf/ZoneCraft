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
}
