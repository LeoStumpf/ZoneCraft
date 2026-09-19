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

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/ui/map_screen.dart';

/// The FAB row has no give: it is pinned bottom-right on a screen about 390
/// logical pixels wide, and every button in it is there because some layer type
/// needs it. The only thing that can yield is the Add button's label.
///
/// This exists because the original guard read `smallFabs < 4 || textScale <=
/// 1.15` — true whenever the font is *normal*, so the label never collapsed at
/// the default size however many buttons preceded it. That is precisely the
/// case that overflows: five small FABs plus an extended "Add subspace" ran 11
/// pixels past the edge of a Pixel 4a at the default font size, which in a
/// debug build is the yellow-and-black hazard stripe.
void main() {
  group('the Add label survives', () {
    test('an ordinary layer at an ordinary font size', () {
      // Tools toggle + Edit + one import button: room to spare.
      expect(addFabIsExtended(smallFabs: 3, textScale: 1), isTrue);
    });

    test('the emptiest row there is', () {
      expect(addFabIsExtended(smallFabs: 2, textScale: 1), isTrue);
    });
  });

  group('the Add label collapses', () {
    test('when every button in the row is present', () {
      // The measured overflow case: toggle, Edit, quick toggle, feature import
      // and OSM import all showing at once.
      expect(addFabIsExtended(smallFabs: 5, textScale: 1), isFalse);
    });

    test('at four buttons too — the label is longer than the margin', () {
      expect(addFabIsExtended(smallFabs: 4, textScale: 1), isFalse);
    });

    test('when the system font is enlarged, even on a short row', () {
      expect(addFabIsExtended(smallFabs: 2, textScale: 1.3), isFalse);
      expect(addFabIsExtended(smallFabs: 3, textScale: 1.5), isFalse);
    });

    test('for every combination of a full row and a large font', () {
      for (var n = 4; n <= 5; n++) {
        for (final scale in [1.0, 1.15, 1.3, 2.0]) {
          expect(
            addFabIsExtended(smallFabs: n, textScale: scale),
            isFalse,
            reason: '$n small FABs at text scale $scale',
          );
        }
      }
    });
  });

  test('both conditions are required, not either', () {
    // The regression in one line: a lenient font size must not licence a full
    // row, and a short row must not licence a huge font.
    expect(addFabIsExtended(smallFabs: 5, textScale: 1), isFalse);
    expect(addFabIsExtended(smallFabs: 2, textScale: 2), isFalse);
  });
}
