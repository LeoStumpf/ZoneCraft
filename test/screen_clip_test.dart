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
}
