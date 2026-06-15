import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/ui/area_geometry.dart';

void main() {
  // A ~2.2 km square around (48.0, 11.0). At this latitude 0.01° lng ≈ 743 m and
  // 0.01° lat ≈ 1113 m, so the square is roughly 1.5 km × 2.2 km.
  final square = <LatLng>[
    const LatLng(47.99, 10.99),
    const LatLng(47.99, 11.01),
    const LatLng(48.01, 11.01),
    const LatLng(48.01, 10.99),
  ];

  ({double minLat, double maxLat, double minLng, double maxLng}) bbox(
      List<List<LatLng>> contours) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final c in contours) {
      for (final p in c) {
        minLat = p.latitude < minLat ? p.latitude : minLat;
        maxLat = p.latitude > maxLat ? p.latitude : maxLat;
        minLng = p.longitude < minLng ? p.longitude : minLng;
        maxLng = p.longitude > maxLng ? p.longitude : maxLng;
      }
    }
    return (minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  }

  test('offset 0 returns the ring unchanged, no band when uncertainty 0', () {
    final r = resolveAreaGeometry(square,
        offsetMeters: 0, bandMeters: 0, inverted: false);
    expect(r.core.length, 1);
    expect(r.core.first.length, 4);
    expect(r.bandEdge, isEmpty);
  });

  test('positive offset erodes (shrinks) the core inward', () {
    final r = resolveAreaGeometry(square,
        offsetMeters: 300, bandMeters: 0, inverted: false);
    expect(r.core, isNotEmpty);
    final b = bbox(r.core);
    // Each side pulled in, so the eroded bbox sits strictly inside the original.
    expect(b.minLat, greaterThan(47.99));
    expect(b.maxLat, lessThan(48.01));
    expect(b.minLng, greaterThan(10.99));
    expect(b.maxLng, lessThan(11.01));
  });

  test('negative offset dilates (grows) the core outward', () {
    final r = resolveAreaGeometry(square,
        offsetMeters: -300, bandMeters: 0, inverted: false);
    final b = bbox(r.core);
    expect(b.minLat, lessThan(47.99));
    expect(b.maxLat, greaterThan(48.01));
    expect(b.minLng, lessThan(10.99));
    expect(b.maxLng, greaterThan(11.01));
  });

  test('normal layer: band edge grows beyond the boundary', () {
    final r = resolveAreaGeometry(square,
        offsetMeters: 0, bandMeters: 500, inverted: false);
    expect(r.bandEdge, isNotEmpty);
    final b = bbox(r.bandEdge);
    expect(b.maxLat, greaterThan(48.01)); // pushed out past the ring
    expect(b.minLng, lessThan(10.99));
  });

  test('inverted layer: band edge shrinks inside the boundary', () {
    final r = resolveAreaGeometry(square,
        offsetMeters: 0, bandMeters: 500, inverted: true);
    expect(r.bandEdge, isNotEmpty);
    final b = bbox(r.bandEdge);
    expect(b.maxLat, lessThan(48.01)); // pulled in inside the ring
    expect(b.minLng, greaterThan(10.99));
  });

  test('degenerate ring (<3 points) resolves to empty', () {
    final r = resolveAreaGeometry(
      [const LatLng(48, 11), const LatLng(48.01, 11.01)],
      offsetMeters: 0,
      bandMeters: 500,
      inverted: false,
    );
    expect(r.isEmpty, isTrue);
  });
}
