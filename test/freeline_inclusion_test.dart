import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/ui/region_geometry.dart';

void main() {
  const distance = Distance(calculator: Haversine());
  const line = <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)];

  test('uses the stored inclusion circle when fully set', () {
    final inc = effectiveInclusion(
      lat: 10,
      lng: 20,
      radiusMeters: 1234,
      points: line,
    );
    expect(inc.center.latitude, 10);
    expect(inc.center.longitude, 20);
    expect(inc.radiusMeters, 1234);
  });

  test('derives a circle covering the line when unset', () {
    final inc = effectiveInclusion(
      lat: null,
      lng: null,
      radiusMeters: null,
      points: line,
    );
    // Centred on the line's bbox midpoint (the equator at lng 0 here).
    expect(inc.center.latitude, closeTo(0, 1e-9));
    expect(inc.center.longitude, closeTo(0, 1e-9));
    // Radius ≈ 0.75 × the line's ~11.1 km span, and comfortably past each end.
    final spanMeters = distance(line.first, line.last);
    expect(inc.radiusMeters, closeTo(spanMeters * 0.75, 1));
    expect(inc.radiusMeters, greaterThan(distance(inc.center, line.first)));
  });

  test('derived radius never falls below the floor for a tiny line', () {
    final inc = effectiveInclusion(
      lat: null,
      lng: null,
      radiusMeters: null,
      points: const <LatLng>[LatLng(0, 0), LatLng(0, 0.0005)], // ~55 m
    );
    expect(inc.radiusMeters, 300);
  });

  test('a non-positive stored radius falls back to the derived circle', () {
    final inc = effectiveInclusion(
      lat: 10,
      lng: 20,
      radiusMeters: 0,
      points: line,
    );
    expect(inc.center.latitude, closeTo(0, 1e-9));
    expect(inc.radiusMeters, greaterThan(300));
  });
}
