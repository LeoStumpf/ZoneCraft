import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/freeline.dart';

void main() {
  // Even-odd point-in-polygon on a lat/lng ring (lng=x, lat=y).
  bool inside(List<LatLng> poly, LatLng q) {
    var hit = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      final intersect = (yi > q.latitude) != (yj > q.latitude) &&
          q.longitude < (xj - xi) * (q.latitude - yi) / (yj - yi) + xi;
      if (intersect) hit = !hit;
    }
    return hit;
  }

  const center = LatLng(0, 0);
  const radius = 2000.0; // m

  test('returns empty for fewer than two finite points', () {
    final r = freeLineDiskRegion(
      points: const <LatLng>[LatLng(0, 0)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
      bandMeters: 0,
    );
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });

  test('returns empty for a non-positive radius', () {
    final r = freeLineDiskRegion(
      points: const <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)],
      center: center,
      radiusMeters: 0,
      offsetMeters: 0,
      bandMeters: 0,
    );
    expect(r.outer, isEmpty);
  });

  test('fills the right-hand half of the disk, bounded to the circle', () {
    // West→east through the centre: right of eastward travel is south, so the
    // filled half is the southern half-disk.
    final r = freeLineDiskRegion(
      points: const <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
      bandMeters: 0,
    );
    // ~556 m south & north of the line, both well inside the disk.
    expect(inside(r.outer, const LatLng(-0.005, 0)), isTrue); // south → filled
    expect(inside(r.outer, const LatLng(0.005, 0)), isFalse); // north → empty
    // A point far outside the inclusion circle is never filled (bounded).
    expect(inside(r.outer, const LatLng(-0.5, 0)), isFalse);
  });

  test('a curvy line still splits the disk into two non-overlapping halves', () {
    // A meandering (zig-zag) west→east line: every in-disk point is in exactly
    // one of the two halves (right via default, left via the disk complement is
    // tested in the painter; here we just assert the right half is well-formed
    // and excludes a clearly-left point).
    final r = freeLineDiskRegion(
      points: const <LatLng>[
        LatLng(0.004, -0.05),
        LatLng(-0.004, -0.01),
        LatLng(0.004, 0.0),
        LatLng(-0.004, 0.01),
        LatLng(0.004, 0.05),
      ],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
      bandMeters: 0,
    );
    expect(r.outer.length, greaterThan(3));
    // Deep south is on the right of an overall-eastward line; deep north is not.
    expect(inside(r.outer, const LatLng(-0.012, 0)), isTrue);
    expect(inside(r.outer, const LatLng(0.012, 0)), isFalse);
  });

  test('band makes outer enclose a strictly wider half than core', () {
    final r = freeLineDiskRegion(
      points: const <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
      bandMeters: 1000, // half-band 1 km, pushed onto the uncoloured (north) side
    );
    // ~500 m north of the line: inside the enlarged outer, outside the core.
    const justNorth = LatLng(0.0045, 0);
    expect(inside(r.outer, justNorth), isTrue);
    expect(inside(r.core, justNorth), isFalse);
  });
}
