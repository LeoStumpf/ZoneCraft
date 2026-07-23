import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/geo/simplify.dart';

void main() {
  const distance = Distance(calculator: Haversine());

  group('simplifyLine', () {
    test('collinear points on a meridian collapse to the two endpoints', () {
      // A meridian (constant lng) is a great circle, so every interior point has
      // zero cross-track distance and must be dropped at any positive tolerance.
      final line = [for (var i = 0; i <= 20; i++) LatLng(48.0 + i * 0.001, 11.0)];
      final s = simplifyLine(line, 5);
      expect(s, hasLength(2));
      expect(s.first, line.first);
      expect(s.last, line.last);
    });

    test('a bump is kept below its offset tolerance, dropped above it', () {
      final a = const LatLng(48.0, 11.00);
      final b = const LatLng(48.0, 11.02);
      final mid = const LatLng(48.0, 11.01);
      final bump = distance.offset(mid, 30, 0); // ~30 m north of the chord
      final line = [a, bump, b];

      expect(simplifyLine(line, 20), hasLength(3)); // 30 m > 20 m tol -> keep
      final coarse = simplifyLine(line, 40); // 30 m < 40 m tol -> drop
      expect(coarse, hasLength(2));
      expect(coarse.first, a);
      expect(coarse.last, b);
    });

    test('endpoints are always preserved', () {
      final line = [for (var i = 0; i <= 30; i++) LatLng(48.0 + i * 0.0005, 11.0 + i * 0.0005)];
      final s = simplifyLine(line, 25);
      expect(s.first, line.first);
      expect(s.last, line.last);
      expect(s.length, lessThan(line.length));
    });

    test('short lines and non-positive tolerance pass through unchanged', () {
      final two = [const LatLng(0, 0), const LatLng(1, 1)];
      expect(simplifyLine(two, 100), same(two));
      final many = [for (var i = 0; i < 10; i++) LatLng(i.toDouble(), 0)];
      expect(simplifyLine(many, 0), same(many));
      expect(simplifyLine(many, double.nan), same(many));
    });
  });

  group('simplifyRing', () {
    // A lat/lng square with extra collinear points along each edge.
    List<LatLng> squareRing({bool closed = false}) {
      const corners = [
        LatLng(48.00, 11.00),
        LatLng(48.00, 11.02),
        LatLng(48.02, 11.02),
        LatLng(48.02, 11.00),
      ];
      final ring = <LatLng>[];
      for (var e = 0; e < 4; e++) {
        final c0 = corners[e];
        final c1 = corners[(e + 1) % 4];
        for (var k = 0; k < 5; k++) {
          ring.add(LatLng(
            c0.latitude + (c1.latitude - c0.latitude) * k / 5,
            c0.longitude + (c1.longitude - c0.longitude) * k / 5,
          ));
        }
      }
      return closed ? [...ring, ring.first] : ring;
    }

    test('collapses a padded square to its four corners', () {
      final s = simplifyRing(squareRing(), 15, minPoints: 4);
      expect(s, hasLength(4));
      for (final c in const [
        LatLng(48.00, 11.00),
        LatLng(48.00, 11.02),
        LatLng(48.02, 11.02),
        LatLng(48.02, 11.00),
      ]) {
        expect(s.any((p) => p.latitude == c.latitude && p.longitude == c.longitude),
            isTrue, reason: 'corner $c missing');
      }
    });

    test('strips a duplicated closing vertex and stays implicit-closed', () {
      final s = simplifyRing(squareRing(closed: true), 15, minPoints: 4);
      expect(s, hasLength(4));
      expect(s.first == s.last, isFalse);
    });

    test('never collapses below minPoints', () {
      // A tiny triangle already at the minimum: nothing to remove.
      final tri = [
        const LatLng(48.0, 11.0),
        const LatLng(48.0, 11.001),
        const LatLng(48.001, 11.0),
      ];
      final s = simplifyRing(tri, 100, minPoints: 3);
      expect(s.length, greaterThanOrEqualTo(3));
    });
  });
}
