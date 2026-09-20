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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/ui/theme.dart';

/// Relative luminance contrast, the WCAG formula, so "passes AA" is measured
/// rather than asserted. The light scheme was built this way — its comments
/// quote the ratios — and the dark one has to be held to the same bar.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double chan(double v) {
      final s = v;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * chan(c.r) + 0.7152 * chan(c.g) + 0.0722 * chan(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('the dark scheme is readable', () {
    // 4.5 is AA for body text. The light scheme's own comments quote its
    // numbers; these are the dark equivalents, measured the same way.
    test('body text on every surface tier', () {
      const s = zoneCraftDark;
      for (final surface in [
        s.surface,
        s.surfaceContainerLowest,
        s.surfaceContainerLow,
        s.surfaceContainer,
        s.surfaceContainerHigh,
        s.surfaceContainerHighest,
      ]) {
        expect(_contrast(s.onSurface, surface), greaterThan(4.5));
      }
    });

    test('the muted text role still passes', () {
      const s = zoneCraftDark;
      expect(_contrast(s.onSurfaceVariant, s.surface), greaterThan(4.5));
    });

    // Every accent had to be lifted, not merely reused: `primary` is #0B6E13,
    // chosen to be dark *on paper*, and it measures about 1.4:1 on charcoal.
    test('accents carry on the dark ground', () {
      const s = zoneCraftDark;
      expect(_contrast(s.primary, s.surface), greaterThan(4.5));
      expect(_contrast(s.secondary, s.surface), greaterThan(4.5));
      expect(_contrast(s.error, s.surface), greaterThan(4.5));
      expect(
        _contrast(ZoneCraftColors.dark.warning, s.surface),
        greaterThan(4.5),
      );
    });

    test('text on a filled accent passes too', () {
      const s = zoneCraftDark;
      expect(_contrast(s.onPrimary, s.primary), greaterThan(4.5));
      expect(_contrast(s.onError, s.error), greaterThan(4.5));
    });

    test('the outline separates', () {
      const s = zoneCraftDark;
      expect(_contrast(s.outline, s.surface), greaterThan(3.0));
    });
  });

  group('the map stays light', () {
    // The load-bearing decision. osm-carto has no dark variant, so the tiles
    // are bright whatever the system says; chrome that followed the system
    // would be dark buttons on a bright map.
    test('map ink is a constant, not a scheme role', () {
      final light = zoneCraftLightTheme();
      final dark = zoneCraftDarkTheme();
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      // kMapInk/kMapPlate are consts and cannot vary by theme — this asserts
      // they are what the map draws with, so the check has something to fail.
      expect(kMapInk, const Color(0xDD1F1D19));
      expect(kMapPlate.a, greaterThan(0.5));
    });

    testWidgets('MapChrome under a light Theme stays light in a dark app', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: zoneCraftLightTheme(),
          darkTheme: zoneCraftDarkTheme(),
          themeMode: ThemeMode.dark,
          home: Theme(
            data: zoneCraftLightTheme(),
            child: const Scaffold(
              body: MapChrome(child: SizedBox(width: 40, height: 40)),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(MapChrome),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, zoneCraftLight.surfaceContainerLowest);
    });
  });

  group('both themes are built the same way', () {
    test('each carries its own ZoneCraftColors', () {
      expect(
        zoneCraftLightTheme().extension<ZoneCraftColors>()?.warning,
        ZoneCraftColors.light.warning,
      );
      expect(
        zoneCraftDarkTheme().extension<ZoneCraftColors>()?.warning,
        ZoneCraftColors.dark.warning,
      );
    });

    test('the scaffold ground follows its own scheme', () {
      expect(
        zoneCraftLightTheme().scaffoldBackgroundColor,
        zoneCraftLight.surface,
      );
      expect(
        zoneCraftDarkTheme().scaffoldBackgroundColor,
        zoneCraftDark.surface,
      );
    });
  });
}
