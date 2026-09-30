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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/ui/editor_sheet.dart';

import 'support/map_harness.dart';

/// `scaledPx` turns a size chosen against text into one that grows with it.
///
/// It used to ask the scaler how big a *font* of that many pixels would be.
/// On Android 14, whose font scaling is a curve, that is the wrong question:
/// a 132 dp field came back 140 dp at "largest" while the 14 sp label inside
/// it doubled — the field stayed the size it was at 1.0 and its label read
/// "Radius (…".
void main() {
  Future<double> measure(
    WidgetTester tester,
    TextScaler scaler,
    double px,
  ) async {
    late double out;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: Builder(
          builder: (context) {
            out = scaledPx(context, px);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return out;
  }

  testWidgets('a width grows as much as body text does, on a curve too', (
    tester,
  ) async {
    const curve = AndroidNonLinearTextScaler();
    // Body text doubles at "largest" on Android 14…
    expect(curve.scale(14), 28);
    // …so a width chosen against it does too, however large the width is.
    expect(await measure(tester, curve, 132), closeTo(264, 0.01));
    expect(await measure(tester, curve, 560), closeTo(1120, 0.01));
  });

  testWidgets('linear scaling and the default are unchanged', (tester) async {
    expect(
      await measure(tester, const TextScaler.linear(1.3), 132),
      closeTo(171.6, 0.01),
    );
    expect(await measure(tester, TextScaler.noScaling, 132), 132);
  });
}
