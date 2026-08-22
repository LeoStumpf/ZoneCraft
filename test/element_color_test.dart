import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/ui/element_color.dart';

void main() {
  const layerColours = [
    Color(0xFF43A047), // green, the case from the request
    Color(0xFF2196F3),
    Color(0xFF111111), // near-black: the lightness range has to be widened
    Color(0xFFF5F5F5), // near-white: same, the other way
    Color(0xFF808080), // grey: no hue to preserve
  ];

  test('shade 0 is the layer colour itself', () {
    // Every pre-existing element migrates in at shade 0, so an untouched map
    // must look exactly as it did.
    for (final c in layerColours) {
      expect(autoShade(c, 0), c);
      expect(autoShade(c, -1), c);
    }
  });

  test('shades are pairwise distinct', () {
    for (final c in layerColours) {
      final seen = <int>{};
      for (var i = 0; i < 12; i++) {
        expect(
          seen.add(autoShade(c, i).toARGB32()),
          isTrue,
          reason: 'shade $i of $c repeats an earlier one',
        );
      }
    }
  });

  test('a shade keeps the layer\'s hue — a green layer stays green', () {
    const green = Color(0xFF43A047);
    final baseHue = HSLColor.fromColor(green).hue;
    for (var i = 1; i < 12; i++) {
      final hsl = HSLColor.fromColor(autoShade(green, i));
      expect((hsl.hue - baseHue).abs(), lessThan(1.5), reason: 'shade $i');
      expect(hsl.lightness, inInclusiveRange(0.15, 0.85));
    }
  });

  test('consecutive shades land far apart, not adjacent', () {
    // Elements are numbered in creation order, so 1 and 2 are the pair a user
    // is most likely to compare.
    const green = Color(0xFF43A047);
    final l1 = HSLColor.fromColor(autoShade(green, 1)).lightness;
    final l2 = HSLColor.fromColor(autoShade(green, 2)).lightness;
    expect((l1 - l2).abs(), greaterThan(0.1));
  });

  test('an explicit colour wins over the shade', () {
    expect(
      elementColor(
        colorArgb: 0xFFFF0000,
        shadeIndex: 3,
        layerColor: const Color(0xFF43A047),
      ),
      const Color(0xFFFF0000),
    );
    expect(
      elementColor(
        colorArgb: null,
        shadeIndex: 0,
        layerColor: const Color(0xFF43A047),
      ),
      const Color(0xFF43A047),
    );
  });

  group('shadePalette', () {
    test('is exactly the ladder autoShade hands out, in order', () {
      // The strip must offer the colours the layer *actually* assigns, or
      // "the same green as my other circles" would be a near-miss by eye.
      for (final c in layerColours) {
        final palette = shadePalette(c, count: 6);
        expect(palette.length, 6);
        for (var i = 0; i < palette.length; i++) {
          expect(palette[i], autoShade(c, i));
        }
      }
    });

    test('starts at the layer colour and has no repeats', () {
      for (final c in layerColours) {
        final palette = shadePalette(c);
        expect(palette.first, c, reason: 'slot 0 is the layer colour exactly');
        expect(
          palette.map((s) => s.toARGB32()).toSet().length,
          palette.length,
          reason: 'two identical swatches would be an untappable choice',
        );
      }
    });

    test('defaults to eight swatches and accepts an empty request', () {
      expect(shadePalette(layerColours.first).length, 8);
      expect(shadePalette(layerColours.first, count: 0), isEmpty);
    });
  });
}
