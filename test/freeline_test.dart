import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/geo/freeline.dart';

void main() {
  final bounds = const Rect.fromLTWH(0, 0, 100, 100);

  double minY(List<Offset> p) => p.map((o) => o.dy).reduce(min);

  // A horizontal line left→right fills the +90° side, which (screen y-down) is
  // below the line.
  const horizontal = [Offset(20, 50), Offset(80, 50)];

  test('fills the side below a horizontal line', () {
    final r = freeLineRegion(
      points: horizontal,
      offsetPx: 0,
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer.length, greaterThanOrEqualTo(3));
    expect(_contains(r.outer, const Offset(50, 90)), isTrue); // below
    expect(_contains(r.outer, const Offset(50, 10)), isFalse); // above
    // With no band the two are identical.
    expect(minY(r.core), closeTo(50, 1e-6));
    expect(minY(r.outer), closeTo(50, 1e-6));
  });

  test('uncertainty band straddles the line', () {
    final r = freeLineRegion(
      points: horizontal,
      offsetPx: 0,
      halfBandPx: 10,
      bounds: bounds,
    );
    // outer reaches 10px above the line, core only down to 10px below.
    expect(minY(r.outer), closeTo(40, 1e-6));
    expect(minY(r.core), closeTo(60, 1e-6));
  });

  test('positive offset pushes the boundary into the filled side', () {
    final r = freeLineRegion(
      points: horizontal,
      offsetPx: 20,
      halfBandPx: 0,
      bounds: bounds,
    );
    // Boundary moves down (into the filled side); the fill starts further away.
    expect(minY(r.outer), closeTo(70, 1e-6));
    expect(_contains(r.outer, const Offset(50, 60)), isFalse);
    expect(_contains(r.outer, const Offset(50, 80)), isTrue);
  });

  test('negative offset extends the fill past the line', () {
    final r = freeLineRegion(
      points: horizontal,
      offsetPx: -20,
      halfBandPx: 0,
      bounds: bounds,
    );
    // Boundary moves up past the line; points just above the line are filled.
    expect(minY(r.outer), closeTo(30, 1e-6));
    expect(_contains(r.outer, const Offset(50, 40)), isTrue);
  });

  test('empty with fewer than two points', () {
    final r = freeLineRegion(
      points: const [Offset(20, 50)],
      offsetPx: 0,
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });
}

/// Is [q] inside the convex polygon [poly]? (Test-only; the straight-line region
/// is convex.)
bool _contains(List<Offset> poly, Offset q) {
  int? sign;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    final cross = (b.dx - a.dx) * (q.dy - a.dy) - (b.dy - a.dy) * (q.dx - a.dx);
    if (cross.abs() < 1e-9) continue;
    final s = cross > 0 ? 1 : -1;
    sign ??= s;
    if (s != sign) return false;
  }
  return true;
}
