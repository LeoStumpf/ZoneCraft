// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/ui/two_finger_gestures.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  const a = Offset(100, 300);
  const b = Offset(200, 300);

  test('two fingers down and up quickly is a tap at their midpoint', () {
    final d = TwoFingerTapDetector();
    d.down(1, a, _ms(0));
    d.down(2, b, _ms(20));
    expect(d.up(1, _ms(120)), isNull, reason: 'one finger still down');
    expect(d.up(2, _ms(140)), const Offset(150, 300));
  });

  test('order of lifting does not matter', () {
    final d = TwoFingerTapDetector();
    d.down(1, a, _ms(0));
    d.down(2, b, _ms(20));
    expect(d.up(2, _ms(100)), isNull);
    expect(d.up(1, _ms(120)), const Offset(150, 300));
  });

  test('one finger is not a two-finger tap', () {
    final d = TwoFingerTapDetector();
    d.down(1, a, _ms(0));
    expect(d.up(1, _ms(100)), isNull);
  });

  test('three fingers spoil it', () {
    final d = TwoFingerTapDetector();
    d.down(1, a, _ms(0));
    d.down(2, b, _ms(10));
    d.down(3, const Offset(150, 400), _ms(20));
    d.up(3, _ms(50));
    d.up(2, _ms(60));
    expect(d.up(1, _ms(70)), isNull);
  });

  test('a hold longer than maxDuration is not a tap', () {
    final d = TwoFingerTapDetector(maxDuration: _ms(300));
    d.down(1, a, _ms(0));
    d.down(2, b, _ms(10));
    d.up(1, _ms(200));
    expect(d.up(2, _ms(400)), isNull);
  });

  test('a finger that travels past the slop is a pinch, not a tap', () {
    final d = TwoFingerTapDetector(slopPx: 20);
    d.down(1, a, _ms(0));
    d.down(2, b, _ms(10));
    d.move(2, b + const Offset(30, 0));
    d.up(1, _ms(100));
    expect(d.up(2, _ms(120)), isNull);
  });

  test('a jitter within the slop still taps', () {
    final d = TwoFingerTapDetector(slopPx: 20);
    d.down(1, a, _ms(0));
    d.down(2, b, _ms(10));
    d.move(1, a + const Offset(5, -4));
    d.move(2, b + const Offset(-3, 6));
    d.up(1, _ms(100));
    expect(d.up(2, _ms(120)), const Offset(150, 300));
  });

  test('a cancelled pointer spoils the sequence', () {
    final d = TwoFingerTapDetector();
    d.down(1, a, _ms(0));
    d.down(2, b, _ms(10));
    d.cancel(1);
    expect(d.up(2, _ms(100)), isNull);
  });

  test('a spoiled sequence does not leak into the next one', () {
    final d = TwoFingerTapDetector();
    d.down(1, a, _ms(0));
    d.move(1, a + const Offset(100, 0));
    d.up(1, _ms(500));
    d.down(1, a, _ms(1000));
    d.down(2, b, _ms(1010));
    d.up(1, _ms(1100));
    expect(d.up(2, _ms(1120)), const Offset(150, 300));
  });

  test('two sequential single taps are not a two-finger tap', () {
    final d = TwoFingerTapDetector();
    d.down(1, a, _ms(0));
    expect(d.up(1, _ms(50)), isNull);
    d.down(2, b, _ms(80));
    expect(d.up(2, _ms(130)), isNull);
  });

  test('an unknown pointer lifting is ignored', () {
    final d = TwoFingerTapDetector();
    expect(d.up(9, _ms(0)), isNull);
  });

  group('TwistDetector', () {
    // The second finger at [deg] around the first, radius 100 px.
    Offset at(double deg) {
      final r = deg * math.pi / 180;
      return a + Offset(100 * math.cos(r), 100 * math.sin(r));
    }

    test('nothing turns below the threshold', () {
      final d = TwistDetector(thresholdDegrees: 20);
      d.down(1, a);
      d.down(2, at(0));
      expect(d.move(2, at(10)), isNull);
      expect(d.move(2, at(19)), isNull);
      expect(d.armed, isFalse);
    });

    test('crossing the threshold arms; later steps report their delta', () {
      final d = TwistDetector(thresholdDegrees: 20);
      d.down(1, a);
      d.down(2, at(0));
      expect(d.move(2, at(21)), isNull, reason: 'arming step itself is free');
      expect(d.armed, isTrue);
      final step = d.move(2, at(26))!;
      expect(step.degrees, closeTo(5, 1e-6));
      expect(step.midpoint, (a + at(26)) / 2);
      expect(d.move(2, at(20))!.degrees, closeTo(-6, 1e-6));
    });

    test('a horizontal pair with the first finger on the right is no turn', () {
      // The line sits at 180°: the wrap that fools flutter_map's race.
      final d = TwistDetector(thresholdDegrees: 20);
      d.down(1, a);
      d.down(2, at(180));
      expect(d.move(2, at(175)), isNull);
      expect(d.move(2, at(-175)), isNull, reason: 'crossed ±180, 10° total');
      expect(d.move(2, at(-158)), isNull, reason: 'arms at 22°');
      expect(d.move(2, at(-150))!.degrees, closeTo(8, 1e-6));
    });

    test('counter-clockwise arms too and reports negative steps', () {
      final d = TwistDetector(thresholdDegrees: 20);
      d.down(1, a);
      d.down(2, at(90));
      expect(d.move(2, at(65)), isNull);
      expect(d.move(2, at(60))!.degrees, closeTo(-5, 1e-6));
    });

    test('lifting a finger disarms; a new pair starts from rest', () {
      final d = TwistDetector(thresholdDegrees: 20);
      d.down(1, a);
      d.down(2, at(0));
      d.move(2, at(30));
      expect(d.armed, isTrue);
      d.up(2);
      expect(d.armed, isFalse);
      d.down(3, at(30));
      expect(d.move(3, at(40)), isNull, reason: 'only 10° since the new pair');
    });

    test('a third finger stops the twist', () {
      final d = TwistDetector(thresholdDegrees: 20);
      d.down(1, a);
      d.down(2, at(0));
      d.move(2, at(30));
      d.down(3, const Offset(400, 400));
      expect(d.move(2, at(40)), isNull);
    });

    test('a single finger never turns', () {
      final d = TwistDetector();
      d.down(1, a);
      expect(d.move(1, b), isNull);
    });
  });
}
