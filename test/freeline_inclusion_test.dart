import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/ui/region_geometry.dart';

void main() {
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

  test('derives a local circle on the line when unset', () {
    final inc = effectiveInclusion(
      lat: null,
      lng: null,
      radiusMeters: null,
      points: line,
    );
    // Centred on the line's arc-length midpoint (the equator at lng 0 here).
    expect(inc.center.latitude, closeTo(0, 1e-9));
    expect(inc.center.longitude, closeTo(0, 1e-9));
    // 0.75 × the ~11.1 km span exceeds the 5 km cap, so it clamps to 5 km.
    expect(inc.radiusMeters, 5000);
  });

  test('caps the derived radius for a very long (whole-river) line', () {
    // ~220 km west→east: the uncapped 0.75×diagonal would be a continent-sized
    // circle; the cap keeps it a local, visible 5 km disk centred on the line.
    final inc = effectiveInclusion(
      lat: null,
      lng: null,
      radiusMeters: null,
      points: const <LatLng>[LatLng(0, -1.0), LatLng(0, 1.0)],
    );
    expect(inc.radiusMeters, 5000);
    expect(inc.center.longitude, closeTo(0, 1e-6)); // midpoint, on the line
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
