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

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/ui/map_semantics.dart';

Layer _layer(String name, {bool visible = true}) => Layer(
      id: name,
      name: name,
      colorArgb: 0xFF000000,
      sortOrder: 0,
      isVisible: visible,
      isInverted: false,
      type: 'circles',
      opacity: 1,
      borderFillAreas: false,
      borderShowNames: false,
      createdAt: DateTime(2026),
    );

void main() {
  // The map is a CustomPaint over raster tiles, so it has no semantics of its
  // own and TalkBack reached it and said nothing at all — while every button
  // around it announced itself correctly.
  group('mapSemanticLabel', () {
    test('an empty map says what to do about it', () {
      final label = mapSemanticLabel(const []);
      expect(label, contains('No layers'));
      expect(label, contains('layers menu'));
    });

    test('names the layers that are actually shown', () {
      final label = mapSemanticLabel([_layer('Radar 1'), _layer('Thermometer')]);
      expect(label, contains('2 layers shown'));
      expect(label, contains('Radar 1'));
      expect(label, contains('Thermometer'));
    });

    test('hidden layers are counted, not named', () {
      final label = mapSemanticLabel([
        _layer('Shown'),
        _layer('Secret', visible: false),
      ]);
      expect(label, contains('1 layer shown'));
      expect(label, contains('Shown'));
      expect(label, contains('1 layer hidden'));
      expect(label, isNot(contains('Secret')),
          reason: 'a hidden layer is not on the map');
    });

    test('all-hidden is its own case, not "no layers"', () {
      final label = mapSemanticLabel([_layer('Off', visible: false)]);
      expect(label, contains('all hidden'));
      expect(label, isNot(contains('No layers')));
    });

    test('singular and plural are both right', () {
      expect(mapSemanticLabel([_layer('One')]), contains('1 layer shown'));
      expect(
        mapSemanticLabel([_layer('A'), _layer('B')]),
        contains('2 layers shown'),
      );
    });

    // The part that makes the label useful rather than merely present: a
    // canvas cannot be read out, and the app already has a view that can.
    test('points at the Elements list, which is the accessible view', () {
      final label = mapSemanticLabel([_layer('Radar 1')]);
      expect(label, contains('Elements'));
    });
  });
}
