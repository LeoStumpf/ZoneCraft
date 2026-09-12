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
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/ui/layer_actions.dart';

void main() {
  List<LayerActionId> actions(
    String type, {
    bool hasStations = false,
    bool canCombine = false,
    bool isTop = false,
    bool isBottom = false,
  }) => visibleLayerActions(
    LayerActionContext(
      type: type,
      hasStations: hasStations,
      canCombine: canCombine,
      isTop: isTop,
      isBottom: isBottom,
    ),
  );

  group('visibleLayerActions', () {
    test('every type gets the common core, and delete is last', () {
      for (final t in kAllLayerTypes) {
        final a = actions(t);
        expect(
          a,
          containsAll([
            LayerActionId.rename,
            LayerActionId.color,
            LayerActionId.opacity,
            LayerActionId.export,
            LayerActionId.delete,
          ]),
          reason: t,
        );
        expect(a.last, LayerActionId.delete, reason: t);
        // No duplicates: a combined layer holds both freehand types, and the
        // same item listed twice is a menu bug.
        expect(a.toSet().length, a.length, reason: t);
      }
    });

    test('invert is offered for region layers and combined, never for '
        'height / poi / borders', () {
      for (final t in [kCircles, kSubspace, kFreeLine, kFreeArea, kMixedType]) {
        expect(actions(t), contains(LayerActionId.invert), reason: t);
      }
      for (final t in [kHeight, kPoi, kBorders]) {
        expect(actions(t), isNot(contains(LayerActionId.invert)), reason: t);
      }
    });

    test('Colour areas / Show names / Import borders are borders-only', () {
      const bordersOnly = [
        LayerActionId.fillAreas,
        LayerActionId.showNames,
        LayerActionId.importBordersVisible,
      ];
      expect(actions(kBorders), containsAll(bordersOnly));
      for (final t in kAllLayerTypes.where((t) => t != kBorders)) {
        for (final id in bordersOnly) {
          expect(actions(t), isNot(contains(id)), reason: '$t $id');
        }
      }
    });

    test('Stations… only once a station import exists', () {
      expect(actions(kPoi), isNot(contains(LayerActionId.stations)));
      expect(
        actions(kPoi, hasStations: true),
        contains(LayerActionId.stations),
      );
      expect(
        actions(kMixedType, hasStations: true),
        contains(LayerActionId.stations),
      );
    });

    test('POI imports go wherever POIs can live', () {
      for (final t in [kPoi, kMixedType]) {
        expect(
          actions(t),
          containsAll([LayerActionId.importPois, LayerActionId.importStations]),
          reason: t,
        );
      }
      for (final t in [
        kCircles,
        kSubspace,
        kFreeLine,
        kFreeArea,
        kHeight,
        kBorders,
      ]) {
        expect(
          actions(t),
          isNot(contains(LayerActionId.importPois)),
          reason: t,
        );
      }
    });

    test(
      'map-feature and track imports go wherever freehand geometry can live',
      () {
        for (final t in [kFreeLine, kFreeArea, kMixedType]) {
          expect(
            actions(t),
            containsAll([
              LayerActionId.importFeature,
              LayerActionId.importTrack,
            ]),
            reason: t,
          );
        }
        for (final t in [kCircles, kSubspace, kHeight, kPoi, kBorders]) {
          expect(
            actions(t),
            isNot(contains(LayerActionId.importFeature)),
            reason: t,
          );
          expect(
            actions(t),
            isNot(contains(LayerActionId.importTrack)),
            reason: t,
          );
        }
      },
    );

    test('Make combined layer follows canBecomeMixed', () {
      for (final t in kAllLayerTypes) {
        expect(
          actions(t).contains(LayerActionId.makeMixed),
          canBecomeMixed(t),
          reason: t,
        );
      }
    });

    test('Combine… only with a target', () {
      expect(actions(kCircles), isNot(contains(LayerActionId.combine)));
      expect(
        actions(kCircles, canCombine: true),
        contains(LayerActionId.combine),
      );
    });

    test('stacking items follow the layer\'s position', () {
      final middle = actions(kCircles);
      expect(middle.take(4), [
        LayerActionId.toTop,
        LayerActionId.up,
        LayerActionId.down,
        LayerActionId.toBottom,
      ]);
      final top = actions(kCircles, isTop: true);
      expect(top, isNot(contains(LayerActionId.toTop)));
      expect(top, isNot(contains(LayerActionId.up)));
      expect(top.take(2), [LayerActionId.down, LayerActionId.toBottom]);
      final only = actions(kCircles, isTop: true, isBottom: true);
      expect(only.first, LayerActionId.rename);
    });

    test('groups are contiguous, so dividers land between them', () {
      for (final t in kAllLayerTypes) {
        final groups = actions(
          t,
          hasStations: true,
          canCombine: true,
        ).map(layerActionGroup).toList();
        for (var i = 1; i < groups.length; i++) {
          expect(groups[i], greaterThanOrEqualTo(groups[i - 1]), reason: t);
        }
      }
    });
  });

  test('layerChipLabel names the layer, or says there is none', () {
    expect(layerChipLabel(null), 'No layer');
    final layer = Layer(
      id: 'a',
      name: 'Radar 1',
      colorArgb: 0xFF000000,
      type: kCircles,
      isVisible: true,
      sortOrder: 0,
      isInverted: false,
      opacity: 1,
      createdAt: DateTime(2026),
      borderFillAreas: false,
      borderShowNames: false,
    );
    expect(layerChipLabel(layer), 'Radar 1');
  });
}
