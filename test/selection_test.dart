import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/state/map_mode.dart';
import 'package:zonecraft/state/providers.dart';

/// Selection is eleven parallel providers with no shared type tag, kept
/// consistent only by [selectObject] / [clearSelection] / [hasAnySelection]
/// agreeing about all eleven. Every kind added since has had to be threaded
/// through three separate switch/or-chains by hand — the `borderArea`,
/// `poiSet` and `transitSet` cases spent a release `break`ing out of
/// [selectObject] because they had no editor yet, which is exactly the failure
/// this file exists to catch: a tap that reports a hit and then selects
/// nothing.
///
/// These need a `WidgetRef`, not a `Ref`, so each runs against a one-widget
/// tree that hands its ref out.
void main() {
  /// Every selectable kind paired with the provider that must end up holding
  /// its id. Deliberately written out rather than derived, so a new kind fails
  /// here until someone states where its selection lives.
  /// Each notifier has its own type, so the map holds a *reader* rather than
  /// the provider itself.
  final providerOf = <ObjectKind, String? Function(ProviderContainer c)>{
    ObjectKind.circle: (c) => c.read(selectedCircleProvider),
    ObjectKind.plane: (c) => c.read(selectedPlaneProvider),
    ObjectKind.subspace: (c) => c.read(selectedSubspaceProvider),
    ObjectKind.freeLine: (c) => c.read(selectedFreeLineProvider),
    ObjectKind.freeArea: (c) => c.read(selectedFreeAreaProvider),
    ObjectKind.heightRegion: (c) => c.read(selectedHeightRegionProvider),
    ObjectKind.poiSet: (c) => c.read(selectedPoiSetProvider),
    ObjectKind.poiPoint: (c) => c.read(selectedPoiPointProvider),
    ObjectKind.transitSet: (c) => c.read(selectedTransitSetProvider),
    ObjectKind.transitStop: (c) => c.read(selectedTransitStopProvider),
    ObjectKind.borderArea: (c) => c.read(selectedBorderAreaProvider),
  };

  /// Pumps a throwaway tree and hands [body] its `WidgetRef` and container.
  Future<void> withRef(
    WidgetTester tester,
    void Function(WidgetRef ref, ProviderContainer container) body,
  ) async {
    late WidgetRef captured;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    body(captured, container);
  }

  testWidgets('every kind has a provider that actually receives the id',
      (tester) async {
    await withRef(tester, (ref, container) {
      for (final entry in providerOf.entries) {
        selectObject(ref, entry.key, 'id-${entry.key.name}');
        expect(
          entry.value(container),
          'id-${entry.key.name}',
          reason: '${entry.key.name} selected nothing',
        );
      }
    });
  });

  testWidgets('the enum is fully covered — no kind is missing above',
      (tester) async {
    expect(providerOf.keys.toSet(), ObjectKind.values.toSet());
  });

  testWidgets('selecting one kind clears every other', (tester) async {
    await withRef(tester, (ref, container) {
      for (final kind in ObjectKind.values) {
        selectObject(ref, kind, 'x');
        for (final other in ObjectKind.values) {
          if (other == kind) continue;
          expect(
            providerOf[other]!(container),
            isNull,
            reason: 'selecting ${kind.name} left ${other.name} selected',
          );
        }
      }
    });
  });

  testWidgets('hasAnySelection sees every kind', (tester) async {
    await withRef(tester, (ref, container) {
      expect(hasAnySelection(ref), isFalse);
      for (final kind in ObjectKind.values) {
        selectObject(ref, kind, 'x');
        expect(hasAnySelection(ref), isTrue, reason: kind.name);
        clearSelection(ref);
        expect(hasAnySelection(ref), isFalse, reason: kind.name);
      }
    });
  });

  testWidgets('clearSelection also disarms the border reshape mode',
      (tester) async {
    // Reshaping is the one selection-scoped mode that writes to a read-only
    // OSM snapshot, so leaving it armed after the area is deselected would put
    // handles on whatever gets selected next.
    await withRef(tester, (ref, container) {
      selectObject(ref, ObjectKind.borderArea, 'a1');
      ref.read(borderReshapeProvider.notifier).arm(true);
      clearSelection(ref);
      expect(container.read(borderReshapeProvider), isFalse);
      expect(container.read(selectedBorderAreaProvider), isNull);
    });
  });

  testWidgets('selecting an object leaves edit mode alone but drops the others',
      (tester) async {
    await withRef(tester, (ref, container) {
      ref.read(mapModeProvider.notifier).set(MapMode.edit);
      selectObject(ref, ObjectKind.borderArea, 'a1');
      expect(container.read(mapModeProvider), MapMode.edit,
          reason: 'editing the object is now the job');

      ref.read(mapModeProvider.notifier).set(MapMode.add);
      selectObject(ref, ObjectKind.transitStop, 's1');
      expect(container.read(mapModeProvider), MapMode.view);
    });
  });

  group('ObjectKind', () {
    test('every kind names a layer type that exists', () {
      const types = {
        'circles',
        'planes',
        'subspace',
        'freeline',
        'freearea',
        'height',
        'poi',
        'transit',
        'borders',
      };
      for (final k in ObjectKind.values) {
        expect(types, contains(k.layerType), reason: k.name);
      }
    });

    test('a layer type maps back to the kind its Elements list shows', () {
      // The two point kinds are one level *below* an element, so no layer type
      // resolves to them — a POI layer's elements are its imports.
      for (final k in ObjectKind.values.where((k) => k.isElement)) {
        expect(ObjectKind.forLayerType(k.layerType), k, reason: k.name);
      }
      expect(ObjectKind.forLayerType('poi'), ObjectKind.poiSet);
      expect(ObjectKind.forLayerType('transit'), ObjectKind.transitSet);
      expect(ObjectKind.forLayerType('nope'), isNull);
    });

    test('exactly the two imported point kinds are not elements', () {
      expect(
        ObjectKind.values.where((k) => !k.isElement).toSet(),
        {ObjectKind.poiPoint, ObjectKind.transitStop},
      );
    });
  });
}
