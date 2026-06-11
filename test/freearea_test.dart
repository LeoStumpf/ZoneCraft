import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/geo/freearea.dart';

void main() {
  final bounds = const Rect.fromLTWH(0, 0, 100, 100);

  double minX(List<Offset> p) => p.map((o) => o.dx).reduce(min);
  double maxX(List<Offset> p) => p.map((o) => o.dx).reduce(max);
  double minY(List<Offset> p) => p.map((o) => o.dy).reduce(min);
  double maxY(List<Offset> p) => p.map((o) => o.dy).reduce(max);

  // A 60×60 square centred in the viewport.
  const square = [
    Offset(20, 20),
    Offset(80, 20),
    Offset(80, 80),
    Offset(20, 80),
  ];

  test('no offset / no band leaves the ring unchanged', () {
    final r = freeAreaRegion(
      ring: square,
      offsetPx: 0,
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(minX(r.outer), closeTo(20, 1e-6));
    expect(maxX(r.outer), closeTo(80, 1e-6));
    expect(minY(r.core), closeTo(20, 1e-6));
    expect(maxY(r.core), closeTo(80, 1e-6));
  });

  test('positive offset insets the filled interior', () {
    final r = freeAreaRegion(
      ring: square,
      offsetPx: 10,
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(minX(r.core), closeTo(30, 1e-6));
    expect(maxX(r.core), closeTo(70, 1e-6));
    expect(minY(r.core), closeTo(30, 1e-6));
    expect(maxY(r.core), closeTo(70, 1e-6));
  });

  test('uncertainty band straddles the ring edge', () {
    final r = freeAreaRegion(
      ring: square,
      offsetPx: 0,
      halfBandPx: 5,
      bounds: bounds,
    );
    // outer grows 5px outward, core shrinks 5px inward.
    expect(minX(r.outer), closeTo(15, 1e-6));
    expect(maxX(r.outer), closeTo(85, 1e-6));
    expect(minX(r.core), closeTo(25, 1e-6));
    expect(maxX(r.core), closeTo(75, 1e-6));
  });

  test('an inset larger than the shape collapses to empty', () {
    final r = freeAreaRegion(
      ring: square,
      offsetPx: 100, // far past the 30px half-width
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });

  test('empty with fewer than three points', () {
    final r = freeAreaRegion(
      ring: const [Offset(20, 20), Offset(80, 20)],
      offsetPx: 0,
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });
}
