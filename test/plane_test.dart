import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/geo/plane.dart';

void main() {
  // A 100x100 viewport. A=(40,50) left of centre, B=(60,50) right of centre;
  // their bisector is the vertical line x=50.
  const bounds = Rect.fromLTWH(0, 0, 100, 100);
  const a = Offset(40, 50);
  const b = Offset(60, 50);

  bool inside(List<Offset> poly, Offset q) {
    // Winding/parity test for a convex polygon via signed-area sign agreement.
    var sign = 0;
    for (var i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      final cross =
          (p2.dx - p1.dx) * (q.dy - p1.dy) - (p2.dy - p1.dy) * (q.dx - p1.dx);
      if (cross != 0) {
        final s = cross > 0 ? 1 : -1;
        if (sign == 0) {
          sign = s;
        } else if (s != sign) {
          return false;
        }
      }
    }
    return true;
  }

  group('planeRegion', () {
    test('fills the half nearer point A (no band)', () {
      final r = planeRegion(
          a: a, b: b, nearA: true, halfBandPx: 0, bounds: bounds);
      // Left of the divide is inside; right is not.
      expect(inside(r.outer, const Offset(10, 50)), isTrue);
      expect(inside(r.outer, const Offset(90, 50)), isFalse);
      // With no band, core == outer.
      expect(inside(r.core, const Offset(10, 50)), isTrue);
    });

    test('near-side toggle flips which half is filled', () {
      final r = planeRegion(
          a: a, b: b, nearA: false, halfBandPx: 0, bounds: bounds);
      expect(inside(r.outer, const Offset(90, 50)), isTrue);
      expect(inside(r.outer, const Offset(10, 50)), isFalse);
    });

    test('band straddles the divide: outer extends past it, core stops short',
        () {
      final r = planeRegion(
          a: a, b: b, nearA: true, halfBandPx: 10, bounds: bounds);
      // A point 5px onto the far side is within outer (band) but not core.
      const inBand = Offset(55, 50);
      expect(inside(r.outer, inBand), isTrue);
      expect(inside(r.core, inBand), isFalse);
      // Well onto the near side is in both.
      expect(inside(r.outer, const Offset(20, 50)), isTrue);
      expect(inside(r.core, const Offset(20, 50)), isTrue);
    });

    test('degenerate (A == B) yields empty polygons', () {
      final r = planeRegion(
          a: a, b: a, nearA: true, halfBandPx: 0, bounds: bounds);
      expect(r.outer, isEmpty);
      expect(r.core, isEmpty);
    });
  });
}
