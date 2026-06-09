import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/geo/geodesic.dart';

void main() {
  // Measure with the same calculator geodesicCircle uses, so the radius check
  // stays tight (Haversine vs the default Vincenty would differ by ~0.3%).
  const distance = Distance(calculator: Haversine());

  group('geodesicCircle', () {
    test('returns the requested number of points', () {
      final ring = geodesicCircle(const LatLng(0, 0), 1000, points: 64);
      expect(ring.length, 64);
    });

    test('every point sits at ~radiusMeters from the center', () {
      const center = LatLng(48.137, 11.575); // Munich
      const radius = 5000.0;
      final ring = geodesicCircle(center, radius, points: 120);
      for (final p in ring) {
        final d = distance.as(LengthUnit.Meter, center, p);
        // latlong2 uses a spherical model; allow a small tolerance.
        expect((d - radius).abs(), lessThan(1.0), reason: 'point $p was ${d}m');
      }
    });

    test('works near the poles without throwing', () {
      const center = LatLng(89.5, 0);
      final ring = geodesicCircle(center, 20000, points: 90);
      expect(ring.length, 90);
      expect(ring.every((p) => p.latitude.abs() <= 90), isTrue);
    });

    test('ring is open (first point not repeated at the end)', () {
      final ring = geodesicCircle(const LatLng(10, 10), 1000, points: 36);
      expect(ring.first, isNot(equals(ring.last)));
    });

    test('returns empty for invalid input instead of NaN points', () {
      expect(geodesicCircle(const LatLng(0, 0), double.nan), isEmpty);
      expect(geodesicCircle(const LatLng(0, 0), double.infinity), isEmpty);
      expect(geodesicCircle(const LatLng(0, 0), 0), isEmpty);
      expect(geodesicCircle(const LatLng(0, 0), -100), isEmpty);
      expect(geodesicCircle(LatLng(double.nan, 0), 1000), isEmpty);
    });

    test('all points are finite for a large radius', () {
      final ring = geodesicCircle(const LatLng(0, 0), 2000000, points: 90);
      expect(ring, isNotEmpty);
      expect(
        ring.every((p) => p.latitude.isFinite && p.longitude.isFinite),
        isTrue,
      );
    });
  });
}
