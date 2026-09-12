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
import 'dart:ui';

/// Recognises a **two-finger tap** — Google Maps' zoom-out gesture, the
/// complement of double-tap zoom-in — from raw pointer events.
///
/// flutter_map has no such gesture, and it must not be built as a
/// `GestureRecognizer`: entering the gesture arena would contest the map's
/// own pinch and drag. So the map is wrapped in a `Listener` that only
/// *watches*, feeds every pointer here, and acts when [up] says the sequence
/// that just ended was a tap: two fingers down together, both lifted within
/// [maxDuration] of the first touch, neither having moved more than [slopPx].
/// Anything else — a third finger, a hold, a pinch that crossed the slop —
/// spoils the sequence, and the next first touch starts a fresh one.
///
/// Pure and synchronous: no timers, so it is testable with hand-written event
/// sequences, and it cannot fire late on its own.
class TwoFingerTapDetector {
  TwoFingerTapDetector({
    this.maxDuration = const Duration(milliseconds: 300),
    this.slopPx = 20,
  });

  /// Longest a tap may take from the first finger down to the last up.
  final Duration maxDuration;

  /// Farthest either finger may travel and still count as a tap.
  final double slopPx;

  /// Fingers currently down, with where each landed.
  final Map<int, Offset> _down = {};

  /// Where the fingers of this sequence landed, in order, kept after they
  /// lift — the tap's midpoint is read from here once the last one is up.
  final List<Offset> _landed = [];

  Duration? _firstDown;
  bool _spoiled = false;

  /// A pointer touched down. The first touch of a sequence starts it.
  void down(int pointer, Offset position, Duration timestamp) {
    if (_down.isEmpty) {
      _landed.clear();
      _firstDown = timestamp;
      _spoiled = false;
    }
    _down[pointer] = position;
    _landed.add(position);
    if (_landed.length > 2) _spoiled = true;
  }

  /// A pointer moved. Past [slopPx] from where it landed the sequence is a
  /// drag or a pinch, not a tap.
  void move(int pointer, Offset position) {
    final start = _down[pointer];
    if (start == null) return;
    if ((position - start).distance > slopPx) _spoiled = true;
  }

  /// A pointer lifted. Returns the midpoint of the two touches when this was
  /// the last finger of a clean two-finger tap, null otherwise.
  Offset? up(int pointer, Duration timestamp) {
    if (_down.remove(pointer) == null) return null;
    final first = _firstDown;
    if (first != null && timestamp - first > maxDuration) _spoiled = true;
    if (_down.isNotEmpty) return null;
    final tap = !_spoiled && _landed.length == 2 && first != null;
    final midpoint = tap ? (_landed[0] + _landed[1]) / 2 : null;
    reset();
    return midpoint;
  }

  /// A pointer was cancelled (the system took it): the sequence is gone.
  void cancel(int pointer) {
    _spoiled = true;
    _down.remove(pointer);
    if (_down.isEmpty) reset();
  }

  /// Forgets everything; the next touch starts a fresh sequence.
  void reset() {
    _down.clear();
    _landed.clear();
    _firstDown = null;
    _spoiled = false;
  }
}

/// Recognises a **deliberate twist** — the Google Maps rotation gesture — from
/// the same raw pointer stream, and hands back the degrees to rotate by.
///
/// flutter_map's own twist handling is switched off (`InteractiveFlag.rotate`
/// is never set) because it cannot be gated: its multi-finger *race* compares
/// Flutter's raw `ScaleUpdateDetails.rotation` against the threshold, and that
/// value is `angle2 − angle1` un-normalised — a horizontal pinch whose line sits
/// near ±180° reads as a 359° twist and "wins" rotation at once. Without the
/// race every wobble of a pinch rotated the map. So rotation is decided here:
/// nothing turns until the line between the two fingers has swung
/// [thresholdDegrees] from where the pair formed; from then on the map follows
/// the fingers, step by step, around their midpoint. Pinch zoom and two-finger
/// pan stay flutter_map's and keep working throughout — a rotate-while-zooming
/// still works once it is meant.
class TwistDetector {
  TwistDetector({this.thresholdDegrees = 20});

  /// Degrees the finger line must swing before the map starts to turn.
  final double thresholdDegrees;

  final Map<int, Offset> _pos = {};
  double? _startAngle;
  double? _lastAngle;
  bool _armed = false;

  /// Whether the threshold has been crossed and the map is following.
  bool get armed => _armed;

  void down(int pointer, Offset position) {
    _pos[pointer] = position;
    _reseat();
  }

  /// A pointer moved. While two fingers are down and the twist is past the
  /// threshold, returns the degrees to add to the map rotation (clockwise
  /// positive, the convention `MapCamera.rotation` uses) and the fingers'
  /// midpoint to turn about; null otherwise.
  ({double degrees, Offset midpoint})? move(int pointer, Offset position) {
    if (!_pos.containsKey(pointer)) return null;
    _pos[pointer] = position;
    if (_pos.length != 2) return null;
    final angle = _angle();
    if (!_armed) {
      if (_wrap(angle - _startAngle!).abs() < thresholdDegrees) return null;
      _armed = true;
      _lastAngle = angle;
      return null;
    }
    final d = _wrap(angle - _lastAngle!);
    _lastAngle = angle;
    return (degrees: d, midpoint: _midpoint());
  }

  void up(int pointer) {
    _pos.remove(pointer);
    _reseat();
  }

  void cancel(int pointer) => up(pointer);

  void reset() {
    _pos.clear();
    _reseat();
  }

  /// A finger came or went: whatever pair is down now starts from rest.
  void _reseat() {
    _armed = false;
    _lastAngle = null;
    _startAngle = _pos.length == 2 ? _angle() : null;
  }

  Offset _midpoint() {
    final it = _pos.values.iterator..moveNext();
    final a = it.current;
    it.moveNext();
    return (a + it.current) / 2;
  }

  /// Screen angle of the line from the first-down finger to the second, in
  /// degrees; y grows downwards, so a clockwise turn increases it — the same
  /// sense as `MapCamera.rotation`.
  double _angle() {
    final it = _pos.values.iterator..moveNext();
    final a = it.current;
    it.moveNext();
    final v = it.current - a;
    return math.atan2(v.dy, v.dx) * 180 / math.pi;
  }

  /// Folds a difference of angles into (-180, 180], so a line crossing ±180°
  /// is a small step and never a full turn.
  static double _wrap(double d) {
    d %= 360;
    return d > 180 ? d - 360 : d;
  }
}
