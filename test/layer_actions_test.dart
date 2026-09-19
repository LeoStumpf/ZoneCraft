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

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';
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

  group('layerActionUnavailable', () {
    LayerActionContext ctx(
      String type, {
      bool holdsAnything = true,
      bool holdsInvertible = true,
      bool holdsRegionFill = true,
      bool holdsBorderAreas = true,
      bool fillAreas = false,
      bool showNames = false,
    }) => LayerActionContext(
      type: type,
      holdsAnything: holdsAnything,
      holdsInvertible: holdsInvertible,
      holdsRegionFill: holdsRegionFill,
      holdsBorderAreas: holdsBorderAreas,
      fillAreas: fillAreas,
      showNames: showNames,
    );

    test('an empty layer cannot be filled outside of', () {
      // The painter returns before the viewport complement is ever taken, so
      // this toggle wrote the database and changed nothing on screen.
      final reason = layerActionUnavailable(
        LayerActionId.invert,
        ctx(kCircles, holdsAnything: false, holdsInvertible: false),
      );
      expect(reason, contains('empty'));
      expect(reason, contains('circle'),
          reason: 'the remedy names the layer\'s own noun');
    });

    test('a layer that is not empty can still have nothing to invert', () {
      // The bug: a combined layer holding only POI markers is far from empty,
      // so the toggle lit up — and markers have no outside.
      final reason = layerActionUnavailable(
        LayerActionId.invert,
        ctx(kMixedType, holdsInvertible: false, holdsRegionFill: false),
      );
      expect(reason, isNotNull);
      expect(reason, isNot(contains('empty')),
          reason: 'it is not empty — that would be the wrong complaint');
      expect(reason, contains('merge'));
    });

    test('a toggle that is already on can always be turned off', () {
      // Otherwise a layer left inverted with nothing to invert would fill the
      // whole viewport the moment a shape was merged in, with the one control
      // that could undo it greyed out.
      expect(
        layerActionUnavailable(
          LayerActionId.invert,
          LayerActionContext(
            type: kMixedType,
            isInverted: true,
            holdsInvertible: false,
          ),
        ),
        isNull,
      );
      expect(
        layerActionUnavailable(
          LayerActionId.fillAreas,
          LayerActionContext(
            type: kBorders,
            fillAreas: true,
            holdsBorderAreas: false,
          ),
        ),
        isNull,
      );
      expect(
        layerActionUnavailable(
          LayerActionId.showNames,
          LayerActionContext(
            type: kBorders,
            showNames: true,
            holdsBorderAreas: false,
          ),
        ),
        isNull,
      );
    });

    test('an import that came back empty has no areas to colour or name', () {
      for (final id in [LayerActionId.fillAreas, LayerActionId.showNames]) {
        expect(
          layerActionUnavailable(id, ctx(kBorders, holdsBorderAreas: false)),
          contains('borders'),
          reason: id.name,
        );
        expect(
          layerActionUnavailable(id, ctx(kBorders)),
          isNull,
          reason: id.name,
        );
      }
    });

    test('everything else acts whenever it is offered', () {
      final full = ctx(kMixedType);
      for (final id in LayerActionId.values) {
        if (id == LayerActionId.invert ||
            id == LayerActionId.fillAreas ||
            id == LayerActionId.showNames) {
          continue;
        }
        expect(layerActionUnavailable(id, full), isNull, reason: id.name);
        // ...including on a layer holding nothing at all: a rename, an
        // import or a delete does not need contents.
        expect(
          layerActionUnavailable(id, ctx(kMixedType, holdsAnything: false)),
          isNull,
          reason: id.name,
        );
      }
    });

    test('a reason is a sentence naming a remedy, not a fault', () {
      final states = [
        ctx(kCircles, holdsAnything: false, holdsInvertible: false),
        ctx(kMixedType, holdsInvertible: false),
        ctx(kBorders, holdsBorderAreas: false),
      ];
      for (final c in states) {
        for (final id in LayerActionId.values) {
          final reason = layerActionUnavailable(id, c);
          if (reason == null) continue;
          expect(reason, endsWith('.'), reason: id.name);
          expect(reason.length, greaterThan(20), reason: '${id.name} terse');
          expect(reason, contains('first'),
              reason: '${id.name} does not say what to do about it');
        }
      }
    });

    test('the remedy is named in the layer\'s own noun', () {
      expect(fillLayerWith(kFreeLine), contains('line'));
      expect(fillLayerWith(kFreeArea), contains('area'));
      expect(fillLayerWith(kPoi), contains('POI'));
      expect(fillLayerWith(kBorders), contains('borders'));
      expect(fillLayerWith(kHeight), contains('height'));
      expect(fillLayerWith(kSubspace), contains('subspace'));
      // A combined layer makes nothing of its own, so the one remedy is the
      // one thing that fills it.
      expect(fillLayerWith(kMixedType), contains('merge'));
      expect(fillLayerWith('something-new'), isNotEmpty);
    });
  });

  group('layerOpacityNote', () {
    LayerActionContext ctx(
      String type, {
      bool holdsAnything = true,
      bool holdsRegionFill = true,
      bool fillAreas = true,
    }) => LayerActionContext(
      type: type,
      holdsAnything: holdsAnything,
      holdsRegionFill: holdsRegionFill,
      fillAreas: fillAreas,
    );

    test('says so when there is nothing for transparency to fade', () {
      // Markers on a combined layer are drawn at full strength on purpose, so
      // the slider moves and nothing changes.
      expect(
        layerOpacityNote(ctx(kMixedType, holdsRegionFill: false)),
        contains('markers'),
      );
      // A borders layer drawn as outlines has no fill to fade either.
      expect(
        layerOpacityNote(ctx(kBorders, fillAreas: false)),
        contains('Colour areas'),
      );
    });

    test('stays quiet when transparency works, or when it is obvious', () {
      expect(layerOpacityNote(ctx(kCircles)), isNull);
      expect(layerOpacityNote(ctx(kPoi)), isNull,
          reason: 'a POI layer fades its markers through an Opacity wrapper');
      expect(layerOpacityNote(ctx(kMixedType)), isNull);
      expect(layerOpacityNote(ctx(kBorders)), isNull);
      expect(
        layerOpacityNote(
          ctx(kMixedType, holdsAnything: false, holdsRegionFill: false),
        ),
        isNull,
        reason: 'an empty layer fading nothing needs no explaining',
      );
    });
  });

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

    test('POI imports go wherever POIs can live, except a combined layer', () {
      expect(
        actions(kPoi),
        containsAll([LayerActionId.importPois, LayerActionId.importStations]),
      );
      for (final t in [
        kCircles,
        kSubspace,
        kFreeLine,
        kFreeArea,
        kHeight,
        kBorders,
        kMixedType,
      ]) {
        expect(
          actions(t),
          isNot(contains(LayerActionId.importPois)),
          reason: t,
        );
        expect(
          actions(t),
          isNot(contains(LayerActionId.importStations)),
          reason: t,
        );
      }
    });

    test(
      'map-feature and track imports go wherever freehand geometry can live',
      () {
        for (final t in [kFreeLine, kFreeArea]) {
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

    test('a combined layer makes nothing of its own', () {
      // It is a merge destination: every import that asks a server for a kind
      // of thing belongs to the layer that holds that kind. "Import track…"
      // stays — it reads a file, and needs no type chosen for it.
      final a = actions(kMixedType, hasStations: true, canCombine: true);
      for (final id in [
        LayerActionId.importPois,
        LayerActionId.importStations,
        LayerActionId.importFeature,
        LayerActionId.importBordersVisible,
      ]) {
        expect(a, isNot(contains(id)), reason: id.name);
      }
      expect(a, contains(LayerActionId.importTrack));
      // What acts on what it already holds is untouched.
      expect(a, containsAll([LayerActionId.invert, LayerActionId.stations]));
      // And its empty Elements list has no button to offer, since the action
      // that fills it lives on the other layer.
      expect(emptyStateActions(kMixedType), isEmpty);
      expect(emptyStateActions(kPoi), isNotEmpty);
    });

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

  // Every action's words, checked where they are written rather than where
  // they are shown. The map renders one of these as a bare icon whose only
  // explanation is this text, so an empty or lazy description is a button
  // nobody can read.
  testWidgets('every action explains itself, not just names itself',
      (tester) async {
    final layers = [
      _layer('a', kCircles),
      _layer('b', kBorders),
      _layer('c', kPoi),
      _layer('d', kFreeArea),
      _layer('e', kMixedType),
    ];

    late List<LayerAction> seen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              // Watched, not just read: `layerActionsFor` reads this to decide
              // whether the station filter is offered, and on the first frame
              // the stream has not emitted yet. Without the watch nothing
              // rebuilds when it does, and the filter is never seen.
              ref.watch(poiSetsProvider);
              seen = [
                for (final l in layers)
                  ...layerActionsFor(context, ref, l, layers),
              ];
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump(); // let the overridden POI-set stream arrive

    // Between them the five layer types reach every action there is.
    expect(
      seen.map((a) => a.id).toSet(),
      LayerActionId.values.toSet(),
      reason: 'a type that reaches no surface would go unchecked',
    );

    for (final a in seen) {
      expect(a.label, isNotEmpty, reason: a.id.name);
      expect(a.description, isNotEmpty, reason: a.id.name);
      expect(
        a.description.toLowerCase(),
        isNot(a.label.toLowerCase()),
        reason: '${a.id.name} repeats its label instead of explaining it',
      );
      // It is shown as a subtitle and spoken in a one-line tip; a paragraph
      // would be neither.
      expect(a.description.length, lessThan(90), reason: a.id.name);
      expect(a.description, endsWith('.'), reason: a.id.name);
    }
  });

  testWidgets('the region toggle is named by its result, not its operation',
      (tester) async {
    // "Invert" made the user ask invert *what*, into what. Both states have to
    // read as a statement about what the map will show.
    for (final inverted in [false, true]) {
      late LayerAction invert;
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final l = _layer('a', kCircles, isInverted: inverted);
                invert = layerActionsFor(context, ref, l, [l])
                    .firstWhere((a) => a.id == LayerActionId.invert);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(invert.label, isNot(contains('nvert')));
      expect(invert.checked, inverted);
      expect(invert.description, contains('olour'));
    }
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

/// Enough of the app for `layerActionsFor` to run, and no more.
///
/// Every element stream is overridden rather than served from a real database:
/// they are read to decide which options a layer offers and whether each can
/// do anything, and a live Drift stream leaves a timer pending that never lets
/// the test finish.
final _overrides = [
  circlesProvider.overrideWith((ref) => Stream.value(const <Circle>[])),
  subspacesProvider.overrideWith((ref) => Stream.value(const <Subspace>[])),
  freeLinesProvider.overrideWith((ref) => Stream.value(const <FreeLine>[])),
  freeAreasProvider.overrideWith((ref) => Stream.value(const <FreeArea>[])),
  heightRegionsProvider.overrideWith(
    (ref) => Stream.value(const <HeightRegion>[]),
  ),
  borderSetsProvider.overrideWith((ref) => Stream.value(const <BorderSet>[])),
  borderAreasProvider.overrideWith((ref) => Stream.value(const <BorderArea>[])),
  repositoryProvider.overrideWith(
    (ref) => Repository(AppDatabase.forTesting(NativeDatabase.memory())),
  ),
  // One station import on layer 'c', so the station filter — which only
  // exists where a layer actually holds one — is among the actions checked.
  poiSetsProvider.overrideWith(
    (ref) => Stream.value([
      PoiSet(
        id: 's1',
        layerId: 'c',
        categoryKey: 'transit',
        centerLat: 48.1,
        centerLng: 11.5,
        radiusMeters: 1000,
        createdAt: DateTime(2026),
        colorShade: 0,
        zOrder: 0,
        source: kPoiSourceBox,
        modeMask: 1,
        visibleModeMask: 1,
      ),
    ]),
  ),
];

Layer _layer(String id, String type, {bool isInverted = false}) => Layer(
      id: id,
      name: 'L$id',
      colorArgb: 0xFF000000,
      type: type,
      isVisible: true,
      sortOrder: 0,
      isInverted: isInverted,
      opacity: 1,
      createdAt: DateTime(2026),
      borderFillAreas: false,
      borderShowNames: false,
    );
