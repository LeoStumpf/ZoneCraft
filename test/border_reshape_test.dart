import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/ui/border_reshape.dart';

/// The screen-space half of reshaping an imported border outline. Both
/// functions take already-projected rings, so this needs no camera and no
/// widget tree — which is the point of them living outside `map_screen`.
void main() {
  // A 100 px square ring, plus a viewport it sits inside.
  const square = [
    Offset(0, 0),
    Offset(100, 0),
    Offset(100, 100),
    Offset(0, 100),
  ];
  const viewport = Rect.fromLTWH(-50, -50, 300, 300);

  group('reshapeHandles', () {
    test('every vertex gets a handle when they are far enough apart', () {
      final r = reshapeHandles(
        const [square],
        bounds: viewport,
        spacingPx: 30,
        max: 400,
      );
      expect(r.tooMany, isFalse);
      expect(r.handles, hasLength(4));
      expect(r.handles.map((h) => h.index), containsAll([0, 1, 2, 3]));
      expect(r.handles.every((h) => h.ring == 0), isTrue);
    });

    test('vertices closer than the spacing collapse to one real vertex', () {
      // An administrative boundary carries a vertex every few metres: without
      // thinning, the dots merge into a band with nothing to aim at.
      final dense = [
        for (var i = 0; i < 40; i++) Offset(i * 2.0, 0),
      ];
      final r = reshapeHandles(
        [dense],
        bounds: viewport,
        spacingPx: 30,
        max: 400,
      );
      expect(r.handles.length, lessThan(dense.length));
      // Whatever survives must be a *real* vertex, or a drag would move an
      // interpolation and the outline would not follow the finger.
      for (final h in r.handles) {
        expect(h.index, inInclusiveRange(0, dense.length - 1));
      }
      // And no two kept handles sit on top of each other.
      final kept = [for (final h in r.handles) dense[h.index]];
      for (var i = 0; i < kept.length; i++) {
        for (var j = i + 1; j < kept.length; j++) {
          expect((kept[i] - kept[j]).distance, greaterThanOrEqualTo(30));
        }
      }
    });

    test('off-screen vertices are dropped before thinning, not after', () {
      // If culling came second, an off-screen vertex could seed a cluster and
      // suppress the on-screen one you were trying to grab.
      const ring = [
        Offset(-500, -500), // off screen, and within the spacing of nothing
        Offset(-495, -500),
        Offset(10, 10), // on screen
        Offset(60, 60),
      ];
      final r = reshapeHandles(
        const [ring],
        bounds: viewport,
        spacingPx: 30,
        max: 400,
      );
      expect(r.handles.map((h) => h.index), unorderedEquals([2, 3]));
    });

    test('a non-finite vertex is skipped rather than poisoning the pass', () {
      const ring = [
        Offset(10, 10),
        Offset(double.nan, 50),
        Offset(90, 90),
      ];
      final r = reshapeHandles(
        const [ring],
        bounds: viewport,
        spacingPx: 30,
        max: 400,
      );
      expect(r.handles.map((h) => h.index), unorderedEquals([0, 2]));
    });

    test('holes are addressed by their own ring index', () {
      const hole = [Offset(40, 40), Offset(60, 40), Offset(60, 60)];
      final r = reshapeHandles(
        const [square, hole],
        bounds: viewport,
        spacingPx: 10,
        max: 400,
      );
      expect(r.handles.where((h) => h.ring == 1), hasLength(3));
      expect(r.handles.where((h) => h.ring == 0), hasLength(4));
    });

    test('nothing on screen means no handles, and no complaint', () {
      final r = reshapeHandles(
        const [square],
        bounds: const Rect.fromLTWH(1000, 1000, 100, 100),
        spacingPx: 30,
        max: 400,
      );
      expect(r.handles, isEmpty);
      expect(r.tooMany, isFalse, reason: 'empty is not the same as too dense');
    });

    test('past the cap it draws none and says so', () {
      // A whole state on screen: even thinned there is nothing to aim at, so
      // the honest answer is "zoom in" rather than a solid band of targets.
      final huge = [
        for (var i = 0; i < 500; i++) Offset(i * 40.0, (i % 7) * 40.0),
      ];
      final r = reshapeHandles(
        [huge],
        bounds: const Rect.fromLTWH(-1e5, -1e5, 2e5, 2e5),
        spacingPx: 30,
        max: 400,
      );
      expect(r.tooMany, isTrue);
      expect(r.handles, isEmpty);
    });
  });

  group('nearestInsertion', () {
    test('a tap by an edge splits that edge', () {
      // Just outside the top edge -> between vertex 0 and vertex 1.
      final at = nearestInsertion(const [square], const Offset(50, -5));
      expect(at, isNotNull);
      expect(at!.ring, 0);
      expect(at.index, 1);
    });

    test('a tap by the closing edge appends, which is the same place', () {
      // The last -> first segment wraps, so its insertion index is the length.
      final at = nearestInsertion(const [square], const Offset(-5, 50));
      expect(at!.index, square.length);
    });

    test('the insertion index really puts the point on that segment', () {
      final ring = [...square];
      final at = nearestInsertion([ring], const Offset(105, 50))!;
      ring.insert(at.index, const Offset(105, 50));
      expect(ring, [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(105, 50),
        const Offset(100, 100),
        const Offset(0, 100),
      ]);
    });

    test('the nearest ring wins, not the first one', () {
      const far = [Offset(900, 900), Offset(950, 900), Offset(950, 950)];
      final at = nearestInsertion(const [far, square], const Offset(50, -5));
      expect(at!.ring, 1);
    });

    test('rings too short to fill are not insertion targets', () {
      final at = nearestInsertion(const [
        [Offset(0, 0), Offset(10, 0)],
      ], const Offset(5, 5));
      expect(at, isNull);
    });

    test('no rings at all means nowhere to insert', () {
      expect(nearestInsertion(const [], const Offset(0, 0)), isNull);
    });
  });
}
