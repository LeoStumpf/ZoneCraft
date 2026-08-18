import 'package:flutter/material.dart';

/// Per-element colours inside one layer.
///
/// A layer still has one colour, and that colour is still what the layer means.
/// Elements sit *within* it: by default each new element takes a distinct
/// **shade** of the layer colour (same hue, different lightness), so a layer of
/// five circles reads as five telling-apart-able greens rather than one green
/// blob — and if the layer colour changes to blue, they all become blues,
/// because the shade is derived and not stored. An element that wants a colour
/// of its own stores an explicit ARGB, which then wins over everything.
///
/// **Shade 0 is the layer colour exactly.** Every element that predates this
/// feature migrated in with shade 0, so an existing map looks identical until
/// something new is added to it.

/// Lightness room the shades are spread over, and the absolute band they must
/// stay inside: a shade that reaches white or black is no longer recognisably
/// the layer's colour, and two of them would be indistinguishable from each
/// other for exactly that reason.
const double _spread = 0.28;
const double _minL = 0.18;
const double _maxL = 0.82;

/// The auto shade of [layerColor] at [index] (0 = the layer colour itself).
///
/// Distinct indices give distinct shades: the lightness slots are visited in
/// van der Corput order (½, ¾, ¼, ⅝, ⅛ …), shifted so no slot ever lands back
/// on the base lightness. That ordering matters because elements are numbered
/// in creation order — consecutive ones must land far apart, not adjacent.
Color autoShade(Color layerColor, int index) {
  if (index <= 0) return layerColor;
  final base = HSLColor.fromColor(layerColor);
  var lo = (base.lightness - _spread).clamp(_minL, _maxL);
  var hi = (base.lightness + _spread).clamp(_minL, _maxL);
  if (hi - lo < 0.3) {
    // A near-black or near-white layer colour clamps to a sliver; widen it
    // within the absolute band so the shades stay apart from each other.
    lo = (hi - 0.3).clamp(_minL, _maxL);
    hi = (lo + 0.3).clamp(_minL, _maxL);
  }
  final t = (_vanDerCorput(index) + 0.5) % 1.0;
  return base.withLightness(lo + t * (hi - lo)).toColor();
}

/// Radical-inverse base 2: 1 → ½, 2 → ¼, 3 → ¾, 4 → ⅛ … Successive values are
/// as far from each other as the sequence so far allows.
double _vanDerCorput(int i) {
  var n = i, denom = 1, result = 0.0;
  while (n > 0) {
    denom *= 2;
    result += (n % 2) / denom;
    n ~/= 2;
  }
  return result;
}

/// What an element actually paints in: its own [colorArgb] when it has one,
/// otherwise its auto shade of [layerColor].
Color elementColor({
  required int? colorArgb,
  required int shadeIndex,
  required Color layerColor,
}) => colorArgb != null ? Color(colorArgb) : autoShade(layerColor, shadeIndex);
