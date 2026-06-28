import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/freeline.dart';

void main() {
  // Even-odd point-in-polygon on a lat/lng ring (lng=x, lat=y) — the same rule
  // the painter fills the cut rings with.
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

  // True when [q] is on the cut's filled (right) side: odd parity across the fill
  // rings, matching the painter's XOR of even-odd runs.
  bool filled(FreeLineRegion r, LatLng q) {
    if (r.missesDisk) return r.centreOnRight;
    var on = false;
    for (final ring in r.fillRings) {
      if (inside(ring, q)) on = !on;
    }
    return on;
  }

  const center = LatLng(0, 0);
  const radius = 2000.0; // m

  test('returns empty for fewer than two finite points', () {
    final r = freeLineDiskRegion(
      points: const <LatLng>[LatLng(0, 0)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
    );
    expect(r.fillRings, isEmpty);
    expect(r.boundaries, isEmpty);
  });

  test('a line missing the disk fills all or nothing by the centre side', () {
    // A line far north of the centre, running west→east: the centre is to its
    // right (south), so the whole disk is the filled side.
    final south = freeLineDiskRegion(
      points: const <LatLng>[LatLng(1.0, -0.05), LatLng(1.0, 0.05)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
    );
    expect(south.missesDisk, isTrue);
    expect(south.centreOnRight, isTrue);
    // Same line reversed (east→west): centre is now on the left → nothing.
    final north = freeLineDiskRegion(
      points: const <LatLng>[LatLng(1.0, 0.05), LatLng(1.0, -0.05)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
    );
    expect(north.missesDisk, isTrue);
    expect(north.centreOnRight, isFalse);
  });

  test('fills the right-hand side of a line cutting the disk', () {
    // West→east through the centre: right of eastward travel is south.
    final r = freeLineDiskRegion(
      points: const <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
    );
    expect(r.boundaries, isNotEmpty); // the dividing line is exposed
    expect(filled(r, const LatLng(-0.005, 0)), isTrue); // south → filled
    expect(filled(r, const LatLng(0.005, 0)), isFalse); // north → empty
  });

  test('a curvy/looping line still classifies points by the cut', () {
    // A meandering west→east line: deep south reads as the right side, deep
    // north as the other — no scatter, no chord.
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
    );
    expect(r.fillRings, isNotEmpty);
    expect(filled(r, const LatLng(-0.012, 0)), isTrue);
    expect(filled(r, const LatLng(0.012, 0)), isFalse);
  });

  test('ignores stitching jumps and stray fragments (imported feature)', () {
    // Mimics a stitched import: a finely-sampled south→north channel crossing
    // the disk (so the median segment stays small), then a giant connector jump,
    // a stray fragment inside the disk, and another jump. Only the real channel
    // should cut the disk — the connector and fragment must not carve slivers.
    final r = freeLineDiskRegion(
      points: <LatLng>[
        for (var i = -50; i <= 50; i++) LatLng(i * 0.001, 0.0), // dense channel
        const LatLng(0.30, 0.30), // 33 km connector jump
        const LatLng(0.002, 0.003), // stray fragment inside the disk
        const LatLng(0.001, 0.004),
        const LatLng(-0.30, -0.30), // another jump away
      ],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
    );
    // Exactly one cut run (the channel); no fragment/connector runs.
    expect(r.fillRings.length, 1);
    expect(r.boundaries.length, 1);
    // South→north travel ⇒ right side is east (positive lng).
    expect(filled(r, const LatLng(0, 0.005)), isTrue); // east → filled
    expect(filled(r, const LatLng(0, -0.005)), isFalse); // west → empty
  });

  test('bridges an ordinary gap inside the disk (sparse import still cuts)', () {
    // A dense south→north channel crossing the disk, but with a single moderate
    // gap (~2.3 km, both ends well inside the 2 km-radius disk) where the import
    // is sparse. That gap is larger than the 1.5 km jitter floor but smaller than
    // the disk's width, so it must be *bridged*, not treated as a connector. A
    // connector-break here would split the crossing into two dangling fragments,
    // both dropped, leaving the disk entirely on one side (the real-world bug:
    // an imported river that fills nothing).
    final r = freeLineDiskRegion(
      points: <LatLng>[
        for (var i = -50; i <= -16; i++) LatLng(i * 0.001, 0.0), // dense approach
        const LatLng(0.005, 0.0), // ~2.3 km gap from lat -0.016, still inside
        for (var i = 6; i <= 50; i++) LatLng(i * 0.001, 0.0), // dense continuation
      ],
      center: center,
      radiusMeters: radius,
      offsetMeters: 0,
    );
    expect(r.missesDisk, isFalse); // the crossing survives the gap
    expect(r.fillRings.length, 1);
    expect(filled(r, const LatLng(0, 0.005)), isTrue); // east → filled
    expect(filled(r, const LatLng(0, -0.005)), isFalse); // west → empty
  });

  test('offset pushes the filled side outward across the line', () {
    // West→east line; right side = south. A +1 km offset pushes the boundary
    // 1 km into the filled (south) side, so a point 500 m south flips to empty.
    final r = freeLineDiskRegion(
      points: const <LatLng>[LatLng(0, -0.05), LatLng(0, 0.05)],
      center: center,
      radiusMeters: radius,
      offsetMeters: 1000,
    );
    expect(filled(r, const LatLng(-0.0045, 0)), isFalse); // ~500 m south, now empty
    expect(filled(r, const LatLng(-0.02, 0)), isTrue); // deeper south, still filled
  });
}
