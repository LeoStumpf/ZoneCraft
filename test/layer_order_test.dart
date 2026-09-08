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
import 'package:zonecraft/ui/layers_panel.dart';

/// The layers drawer's explicit "move up / down / to top / to bottom".
///
/// Every list here is **bottom-to-top**, the order `watchLayers` emits and
/// `reorderLayers` expects. The drawer shows it reversed, which is exactly why
/// the arithmetic is pure and tested away from the widget.
void main() {
  const stack = ['a', 'b', 'c', 'd']; // 'a' at the bottom, 'd' on top

  group('movedLayerOrder', () {
    test('up swaps with the layer above', () {
      expect(movedLayerOrder(stack, 'b', LayerMove.up), ['a', 'c', 'b', 'd']);
    });

    test('down swaps with the layer below', () {
      expect(movedLayerOrder(stack, 'c', LayerMove.down), ['a', 'c', 'b', 'd']);
    });

    test('toTop puts the layer last, so it draws over everything', () {
      expect(movedLayerOrder(stack, 'a', LayerMove.toTop),
          ['b', 'c', 'd', 'a']);
    });

    test('toBottom puts the layer first, under everything', () {
      expect(movedLayerOrder(stack, 'd', LayerMove.toBottom),
          ['d', 'a', 'b', 'c']);
    });

    test('the other layers keep their relative order', () {
      // The whole point of a move: one layer changes place, the rest do not
      // shuffle around it.
      final moved = movedLayerOrder(stack, 'b', LayerMove.toTop);
      expect(moved.where((id) => id != 'b').toList(), ['a', 'c', 'd']);
    });

    // A move that changes nothing returns the *same* list, which is what the
    // caller uses to skip the write — a menu tap at the end of the stack must
    // not spend a batch rewriting every layer's sortOrder to what it already is.
    test('a no-op move returns the list identically', () {
      expect(identical(movedLayerOrder(stack, 'd', LayerMove.up), stack), isTrue);
      expect(identical(movedLayerOrder(stack, 'd', LayerMove.toTop), stack),
          isTrue);
      expect(identical(movedLayerOrder(stack, 'a', LayerMove.down), stack),
          isTrue);
      expect(identical(movedLayerOrder(stack, 'a', LayerMove.toBottom), stack),
          isTrue);
    });

    test('an unknown id is left alone rather than inserted', () {
      expect(identical(movedLayerOrder(stack, 'zz', LayerMove.toTop), stack),
          isTrue);
    });

    test('a single layer is already at both ends', () {
      const one = ['only'];
      for (final move in LayerMove.values) {
        expect(identical(movedLayerOrder(one, 'only', move), one), isTrue,
            reason: '$move on a one-layer stack should not write');
      }
    });

    test('an empty stack has nothing to move', () {
      expect(movedLayerOrder(const [], 'a', LayerMove.toTop), isEmpty);
    });
  });
}
