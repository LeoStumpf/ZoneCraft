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

import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/ui/paint_order.dart';

/// How the region engine splits a layer into paint passes.
///
/// The rule used to be "one pass per distinct colour, ordered by the newest
/// member", which is fine until an element is *moved*: a global grouping cannot
/// express green → blue → green, so a green circle sent behind a blue one would
/// drag every other green element behind it too. Runs can express it, and this
/// is the file that says so.
void main() {
  const green = Color(0xFF00FF00);
  const blue = Color(0xFF0000FF);

  List<({Color color, List<String> items})> runsOf(
    List<(String, Color)> input,
  ) => colorRuns([
    for (final (name, _) in input) name,
  ], (name) => input.firstWhere((e) => e.$1 == name).$2);

  test('adjacent same-colour elements share one pass', () {
    final runs = runsOf([('a', green), ('b', green), ('c', green)]);
    expect(runs, hasLength(1));
    expect(runs.single.items, ['a', 'b', 'c']);
    expect(runs.single.color, green);
  });

  // The case the old global grouping could not express, and the reason this
  // function exists at all.
  test(
    'a different colour between two same-coloured ones makes three passes',
    () {
      final runs = runsOf([('a', green), ('b', blue), ('c', green)]);
      expect(runs, hasLength(3));
      expect([for (final r in runs) r.items.single], ['a', 'b', 'c']);
      expect([for (final r in runs) r.color], [green, blue, green]);
    },
  );

  test('the input order is the pass order, front last', () {
    final runs = runsOf([('a', green), ('b', green), ('c', blue), ('d', blue)]);
    expect(runs, hasLength(2));
    expect(runs.first.items, ['a', 'b']);
    expect(runs.last.items, ['c', 'd']);
  });

  // Two Colors with the same ARGB are the same pass even if they are not
  // identical objects — the comparison has to be on the value.
  test('equal colours from different objects still merge', () {
    final runs = runsOf([('a', Color(0xFF00FF00)), ('b', Color(0xFF00FF00))]);
    expect(runs, hasLength(1));
  });

  test('one element is one pass, and none is none', () {
    expect(runsOf([('a', green)]), hasLength(1));
    expect(colorRuns<String>(const [], (_) => green), isEmpty);
  });

  test('every element survives into exactly one pass', () {
    final input = [
      ('a', green),
      ('b', blue),
      ('c', blue),
      ('d', green),
      ('e', green),
    ];
    final flat = [for (final r in runsOf(input)) ...r.items];
    expect(flat, ['a', 'b', 'c', 'd', 'e']);
  });

  group('bandPassLayers', () {
    Layer layer(String id, String type, {bool visible = true}) => Layer(
      id: id,
      name: id,
      type: type,
      colorArgb: 0xFF2196F3,
      opacity: 0.45,
      isVisible: visible,
      isInverted: false,
      sortOrder: 0,
      borderFillAreas: false,
      borderShowNames: false,
      createdAt: DateTime(2026, 9, 1),
    );

    test('keeps the layers in their own order, bottom to top', () {
      // The bands are stacked under the fills; among themselves they have to
      // hold the same relative order the fills hold, or sending an element
      // back would shuffle the bands the other way.
      final layers = [
        layer('a', kCircles),
        layer('b', kFreeArea),
        layer('c', kMixedType),
      ];
      expect(bandPassLayers(layers, 500).map((l) => l.id), ['a', 'b', 'c']);
    });

    test('no uncertainty, no band pass at all', () {
      // At 0 m there is no band to draw, and the extra widget per layer would
      // be pure cost — the map has to be exactly what it was before the split.
      final layers = [layer('a', kCircles)];
      expect(bandPassLayers(layers, 0), isEmpty);
      expect(bandPassLayers(layers, -1), isEmpty);
    });

    test('hidden layers are skipped, as they are for the fill pass', () {
      final layers = [
        layer('a', kCircles, visible: false),
        layer('b', kSubspace),
      ];
      expect(bandPassLayers(layers, 500).map((l) => l.id), ['b']);
    });

    test('borders and marker-only layers contribute no band', () {
      // `borders` has its own painter and no band at all; a POI layer paints
      // no region, so a band widget for it would draw nothing.
      final layers = [
        layer('borders', kBorders),
        layer('poi', kPoi),
        layer('height', kHeight),
      ];
      expect(bandPassLayers(layers, 500).map((l) => l.id), ['height']);
    });

    test('a mixed layer bands, because it can hold region types', () {
      expect(bandPassLayers([layer('m', kMixedType)], 500), hasLength(1));
    });
  });
}
