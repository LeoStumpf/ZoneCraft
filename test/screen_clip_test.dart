import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/ui/screen_clip.dart';

/// Shoelace area (absolute) of a closed polygon.
double _area(List<Offset> pts) {
  var s = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return (s / 2).abs();
}

void main() {
  const rect = Rect.fromLTRB(0, 0, 100, 100);

  test('ring fully inside is returned unchanged', () {
    final ring = [
      const Offset(10, 10),
      const Offset(90, 20),
      const Offset(50, 80),
    ];
    expect(identical(clipRingToRect(ring, rect), ring), isTrue);
  });

  test('ring fully outside clips to nothing', () {
    final ring = [
      const Offset(200, 10),
      const Offset(300, 20),
      const Offset(250, 80),
    ];
    expect(clipRingToRect(ring, rect), isEmpty);
  });

  test('huge ring surrounding the rect clips to the rect itself', () {
    final ring = [
      const Offset(-1e6, -1e6),
      const Offset(1e6, -1e6),
      const Offset(1e6, 1e6),
      const Offset(-1e6, 1e6),
    ];
    final out = clipRingToRect(ring, rect);
    expect(_area(out), closeTo(rect.width * rect.height, 1e-6));
    for (final p in out) {
      expect(rect.inflate(1e-6).contains(p), isTrue);
    }
  });

  test('partial overlap keeps the intersection', () {
    // Square straddling the left edge: x in [-50, 50], y in [25, 75].
    final ring = [
      const Offset(-50, 25),
      const Offset(50, 25),
      const Offset(50, 75),
      const Offset(-50, 75),
    ];
    final out = clipRingToRect(ring, rect);
    expect(_area(out), closeTo(50 * 50, 1e-6));
    for (final p in out) {
      expect(p.dx, greaterThanOrEqualTo(0));
      expect(p.dx, lessThanOrEqualTo(50));
      expect(p.dy, greaterThanOrEqualTo(25));
      expect(p.dy, lessThanOrEqualTo(75));
    }
  });

  test('concave ring crossing the rect keeps the correct area', () {
    // A "U" reaching into the rect from above: two 20-wide prongs down to
    // y == 40 joined by a bar over y in [40, 60]; the prong tops stay outside.
    final ring = [
      const Offset(10, -100),
      const Offset(30, -100),
      const Offset(30, 40),
      const Offset(70, 40),
      const Offset(70, -100),
      const Offset(90, -100),
      const Offset(90, 60),
      const Offset(10, 60),
    ];
    final out = clipRingToRect(ring, rect);
    expect(_area(out), closeTo(2 * 20 * 40 + 80 * 20, 1e-6));
  });

  group('clipSegmentToRect', () {
    test('a segment fully inside comes back unchanged', () {
      final s = clipSegmentToRect(
          const Offset(10, 10), const Offset(90, 90), rect);
      expect(s, isNotNull);
      expect(s!.$1, const Offset(10, 10));
      expect(s.$2, const Offset(90, 90));
    });

    test('a crossing segment is trimmed to the rect', () {
      // A border area at street zoom projects to ±10⁵ px; the whole point is
      // that Skia never sees those coordinates.
      final s = clipSegmentToRect(
          const Offset(-100000, 50), const Offset(100000, 50), rect);
      expect(s, isNotNull);
      expect(s!.$1.dx, closeTo(0, 1e-6));
      expect(s.$2.dx, closeTo(100, 1e-6));
      expect(s.$1.dy, closeTo(50, 1e-6));
    });

    test('one endpoint outside trims only that end', () {
      final s = clipSegmentToRect(
          const Offset(50, 50), const Offset(50, 500), rect);
      expect(s!.$1, const Offset(50, 50));
      expect(s.$2.dy, closeTo(100, 1e-6));
    });

    test('a segment that misses the rect is dropped', () {
      expect(
          clipSegmentToRect(
              const Offset(200, 200), const Offset(300, 300), rect),
          isNull);
      // Parallel to an edge, and outside it.
      expect(
          clipSegmentToRect(
              const Offset(-10, 0), const Offset(-10, 100), rect),
          isNull);
    });

    test('a degenerate segment inside survives, outside does not', () {
      expect(
          clipSegmentToRect(const Offset(50, 50), const Offset(50, 50), rect),
          isNotNull);
      expect(
          clipSegmentToRect(
              const Offset(500, 500), const Offset(500, 500), rect),
          isNull);
    });

    test('a non-finite endpoint is dropped rather than propagated', () {
      expect(
          clipSegmentToRect(
              const Offset(double.nan, 0), const Offset(50, 50), rect),
          isNull);
      expect(
          clipSegmentToRect(
              const Offset(0, 0), const Offset(double.infinity, 50), rect),
          isNull);
    });
  });
}
