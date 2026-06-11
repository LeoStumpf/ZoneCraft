import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/geo/subspace.dart';

void main() {
  // A 100×100 viewport for all cases.
  final bounds = const Rect.fromLTWH(0, 0, 100, 100);

  double minX(List<Offset> p) => p.map((o) => o.dx).reduce(min);
  double maxX(List<Offset> p) => p.map((o) => o.dx).reduce(max);
  double minY(List<Offset> p) => p.map((o) => o.dy).reduce(min);
  double maxY(List<Offset> p) => p.map((o) => o.dy).reduce(max);

  test('main cell is the central strip between two flanking points', () {
    // Main in the centre, others due west and due east. The cell closer to the
    // centre than to both is the vertical strip x ∈ [25, 75].
    final r = subspaceRegion(
      main: const Offset(50, 50),
      others: const [Offset(0, 50), Offset(100, 50)],
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer.length, greaterThanOrEqualTo(4));
    expect(minX(r.outer), closeTo(25, 1e-6));
    expect(maxX(r.outer), closeTo(75, 1e-6));
    expect(minY(r.outer), closeTo(0, 1e-6));
    expect(maxY(r.outer), closeTo(100, 1e-6));
  });

  test('uncertainty widens outer and narrows core symmetrically', () {
    final r = subspaceRegion(
      main: const Offset(50, 50),
      others: const [Offset(0, 50), Offset(100, 50)],
      halfBandPx: 5,
      bounds: bounds,
    );
    // outer pushes each bisector toward the others (strip x ∈ [20, 80]).
    expect(minX(r.outer), closeTo(20, 1e-6));
    expect(maxX(r.outer), closeTo(80, 1e-6));
    // core pulls them toward main (strip x ∈ [30, 70]).
    expect(minX(r.core), closeTo(30, 1e-6));
    expect(maxX(r.core), closeTo(70, 1e-6));
  });

  test('three non-collinear points yield a convex, non-empty cell', () {
    final r = subspaceRegion(
      main: const Offset(50, 50),
      others: const [Offset(0, 0), Offset(100, 0)],
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer.length, greaterThanOrEqualTo(3));
    // The main point itself must lie inside its own cell.
    expect(_contains(r.outer, const Offset(50, 50)), isTrue);
    // A point hugging the far "others" corner must not.
    expect(_contains(r.outer, const Offset(0, 0)), isFalse);
  });

  test('empty when there are no other points', () {
    final r = subspaceRegion(
      main: const Offset(50, 50),
      others: const [],
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });

  test('empty when a point coincides with the main point', () {
    final r = subspaceRegion(
      main: const Offset(50, 50),
      others: const [Offset(50, 50), Offset(0, 0)],
      halfBandPx: 0,
      bounds: bounds,
    );
    expect(r.outer, isEmpty);
    expect(r.core, isEmpty);
  });
}

/// Is [q] inside the convex polygon [poly]? Orientation-agnostic: an interior
/// point sits on the same side of every edge. (Test-only.)
bool _contains(List<Offset> poly, Offset q) {
  int? sign;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    final cross = (b.dx - a.dx) * (q.dy - a.dy) - (b.dy - a.dy) * (q.dx - a.dx);
    if (cross.abs() < 1e-9) continue; // on an edge / collinear
    final s = cross > 0 ? 1 : -1;
    sign ??= s;
    if (s != sign) return false;
  }
  return true;
}
