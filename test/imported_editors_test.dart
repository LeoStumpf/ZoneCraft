import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/border_area_editor.dart';
import 'package:zonecraft/ui/imported_point_editor.dart';
import 'package:zonecraft/ui/poi_set_editor.dart';
import 'package:zonecraft/ui/transit_set_editor.dart';

/// The four editors the import types gained. They exist because Edit mode and
/// long-press used to be dead over `poi`, `transit` and `borders`, and each is
/// deliberately **scoped to what an offline OSM snapshot can honestly offer** —
/// so what a sheet refuses to offer matters as much as what it does, and both
/// are easy to widen by accident.
///
/// These drive a **recording repository** rather than a live database: a widget
/// test runs inside `FakeAsync`, where a real drift round-trip never completes,
/// and what is being checked here is which call the sheet makes with which
/// arguments. That the calls then do the right thing to the rows is
/// `database_test.dart`'s job, against a real database and real async.
void main() {
  late AppDatabase db;
  late _RecordingRepository repo;
  late ProviderContainer container;

  setUp(() {
    // Never opened — Repository needs one, and every method that would touch it
    // is overridden below.
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingRepository(db);
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  Layer layerOf(String type, {String? borderLevel}) => Layer(
        id: 'L',
        name: 'Around home',
        colorArgb: 0xFF112233,
        isVisible: true,
        sortOrder: 0,
        type: type,
        isInverted: false,
        opacity: 1,
        borderLevel: borderLevel,
        borderFillAreas: false,
        borderShowNames: false,
        createdAt: DateTime(2026),
      );

  group('ImportedPointEditorSheet', () {
    Widget poiSheet({String? name}) => ImportedPointEditorSheet(
          id: 'p1',
          kind: ObjectKind.poiPoint,
          name: name,
          lat: 48.001,
          lng: 11.002,
          icon: Icons.place_outlined,
          title: 'Edit POI',
          subtitle: 'Cafés',
        );

    testWidgets('typing a name renames that POI', (tester) async {
      await pump(tester, poiSheet(name: 'Alte Post'));
      expect(find.text('Edit POI'), findsOneWidget);
      expect(find.text('Alte Post'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Neue Post');
      await tester.pump();
      expect(repo.calls, contains('updatePoiPoint p1 name=Neue Post'));
    });

    testWidgets('an emptied field clears the name rather than storing blank',
        (tester) async {
      // The renderer draws no plate for a nameless POI, and only null says
      // that — a stored '' would leave an empty white plate on the map.
      await pump(tester, poiSheet(name: 'Alte Post'));
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(repo.calls, contains('updatePoiPoint p1 name=null'));
    });

    testWidgets('delete removes the POI and clears the selection',
        (tester) async {
      container.read(selectedPoiPointProvider.notifier).select('p1');
      await pump(tester, poiSheet(name: 'Alte Post'));

      await tester.tap(find.byTooltip('Remove from this import'));
      await tester.pump();

      expect(repo.calls, contains('deletePoiPoint p1'));
      expect(repo.calls, isNot(contains('deletePoiSet')),
          reason: 'curating one POI away must not delete its import');
      expect(container.read(selectedPoiPointProvider), isNull);
    });

    testWidgets('the same sheet edits a station, through the other table',
        (tester) async {
      container.read(selectedTransitStopProvider.notifier).select('s1');
      await pump(
        tester,
        const ImportedPointEditorSheet(
          id: 's1',
          kind: ObjectKind.transitStop,
          name: 'Hauptbahnhof',
          lat: 48.14,
          lng: 11.56,
          icon: Icons.directions_transit,
          title: 'Edit station',
          subtitle: 'Train, Subway',
        ),
      );
      await tester.enterText(find.byType(TextField), 'Hbf');
      await tester.pump();
      expect(repo.calls, contains('updateTransitStop s1 name=Hbf'));

      await tester.tap(find.byTooltip('Remove from this import'));
      await tester.pump();
      expect(repo.calls, contains('deleteTransitStop s1'));
      expect(container.read(selectedTransitStopProvider), isNull);
    });

    testWidgets('the position is shown but never offered as a field',
        (tester) async {
      // The coordinate is the fetched fact the layer exists to record, and no
      // column would say one had been moved — so there is exactly one text
      // field here, and it is the name.
      await pump(tester, poiSheet(name: 'Alte Post'));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('48.0010'), findsOneWidget);
      expect(find.textContaining('Cafés'), findsOneWidget);
    });
  });

  group('PoiSetEditorSheet', () {
    PoiSet set({String? label}) => PoiSet(
          id: 'ps1',
          layerId: 'L',
          categoryKey: 'cafe',
          centerLat: 48.0,
          centerLng: 11.0,
          radiusMeters: 800,
          label: label,
          createdAt: DateTime(2026),
          colorShade: 0,
        );

    testWidgets('it names the category, the count and the circle that ran',
        (tester) async {
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(),
          pointCount: 2,
          layers: [layerOf('poi')],
        ),
      );
      expect(find.text('Edit POI import'), findsOneWidget);
      expect(find.textContaining('2 POIs stored'), findsOneWidget);
      expect(find.textContaining('within 800 m'), findsOneWidget);
    });

    testWidgets('one stored POI is not pluralised', (tester) async {
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(),
          pointCount: 1,
          layers: [layerOf('poi')],
        ),
      );
      expect(find.textContaining('1 POI stored'), findsOneWidget);
    });

    testWidgets('typing a label renames the import', (tester) async {
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(),
          pointCount: 2,
          layers: [layerOf('poi')],
        ),
      );
      await tester.enterText(find.byType(TextField), 'Cafés near home');
      await tester.pump();
      expect(repo.calls, contains('updatePoiSet ps1 label=Cafés near home'));
    });

    testWidgets('the category, centre and radius are text, not controls',
        (tester) async {
      // They describe a query that already ran: editing them would leave a row
      // claiming to hold something it never fetched.
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(),
          pointCount: 2,
          layers: [layerOf('poi')],
        ),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('deleting the import clears the selection', (tester) async {
      container.read(selectedPoiSetProvider.notifier).select('ps1');
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(),
          pointCount: 2,
          layers: [layerOf('poi')],
        ),
      );
      await tester.tap(find.byTooltip('Delete import'));
      await tester.pump();
      expect(repo.calls, contains('deletePoiSet ps1'));
      expect(container.read(selectedPoiSetProvider), isNull);
    });
  });

  group('TransitSetEditorSheet', () {
    TransitSet set({required int modeMask, required int visible}) => TransitSet(
          id: 'ts1',
          layerId: 'L',
          south: 48.0,
          west: 11.0,
          north: 48.2,
          east: 11.3,
          modeMask: modeMask,
          visibleModeMask: visible,
          stationCount: 3,
          nodeCount: 9,
          createdAt: DateTime(2026),
          colorShade: 0,
        );

    testWidgets('only the types the import actually fetched get a tick box',
        (tester) async {
      // What a narrower import left out was never stored, so a chip for it
      // could never draw anything — a control that does nothing.
      final rail = transitRailMask;
      await pump(
        tester,
        TransitSetEditorSheet(
          set: set(modeMask: rail, visible: rail),
          stopCount: 3,
          layers: [layerOf('transit')],
        ),
      );
      for (final m in transitModes) {
        expect(
          find.widgetWithText(FilterChip, m.label),
          rail & m.bit != 0 ? findsOneWidget : findsNothing,
          reason: m.label,
        );
      }
      expect(find.textContaining('3 stations stored'), findsOneWidget);
    });

    testWidgets('unticking a type writes the visible mask, not the imported one',
        (tester) async {
      final all = transitAllModesMask;
      final bus = transitModeByKey('bus')!;
      await pump(
        tester,
        TransitSetEditorSheet(
          set: set(modeMask: all, visible: all),
          stopCount: 9,
          layers: [layerOf('transit')],
        ),
      );
      await tester.tap(find.widgetWithText(FilterChip, bus.label));
      await tester.pump();

      expect(
        repo.calls,
        contains('setTransitVisibleModes [ts1] ${all & ~bus.bit}'),
      );
      expect(
        repo.calls.where((c) => c.startsWith('updateTransitSet')),
        isEmpty,
        reason: 'hiding a type must not rewrite what was fetched',
      );
    });

    testWidgets('ticking a hidden type back on restores its bit',
        (tester) async {
      final all = transitAllModesMask;
      final bus = transitModeByKey('bus')!;
      await pump(
        tester,
        TransitSetEditorSheet(
          set: set(modeMask: all, visible: all & ~bus.bit),
          stopCount: 9,
          layers: [layerOf('transit')],
        ),
      );
      await tester.tap(find.widgetWithText(FilterChip, bus.label));
      await tester.pump();
      expect(repo.calls, contains('setTransitVisibleModes [ts1] $all'));
    });

    testWidgets('an import that fetched nothing offers no Show section',
        (tester) async {
      await pump(
        tester,
        TransitSetEditorSheet(
          set: set(modeMask: 0, visible: 0),
          stopCount: 0,
          layers: [layerOf('transit')],
        ),
      );
      expect(find.text('Show'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.textContaining('0 stations stored'), findsOneWidget);
    });
  });

  group('BorderAreaEditorSheet', () {
    BorderArea area({DateTime? editedAt, int pointCount = 4}) => BorderArea(
          id: 'ba1',
          setId: 'bs1',
          osmId: 42,
          name: 'Maxvorstadt',
          south: 48.0,
          west: 11.0,
          north: 48.1,
          east: 11.1,
          labelLat: 48.05,
          labelLng: 11.05,
          pointCount: pointCount,
          rings: '[[[48.0,11.0],[48.0,11.1],[48.1,11.1],[48.1,11.0]]]',
          wayIds: '[7]',
          colorIndex: 0,
          createdAt: DateTime(2026),
          editedAt: editedAt,
        );

    testWidgets('an untouched area shows its OSM identity and no warning',
        (tester) async {
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      expect(find.text('Edit area'), findsOneWidget);
      expect(find.textContaining('OSM relation 42'), findsOneWidget);
      expect(find.textContaining('level 8'), findsOneWidget);
      expect(find.textContaining('4 points'), findsOneWidget);
      expect(find.textContaining('Reshaped by hand'), findsNothing);
      expect(find.textContaining('Convert to freehand area'), findsOneWidget);
    });

    testWidgets('it points at the name-plate handle, which is on the map',
        (tester) async {
      // The anchor is presentation, so it moves by dragging rather than through
      // a field here — but nothing would say so if the sheet didn't.
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      expect(find.textContaining('name plate'), findsOneWidget);
    });

    testWidgets('reshaping is off by default and is a mode, not handles',
        (tester) async {
      // Handles that are simply *there* on a read-only snapshot make a stray
      // drag — a silent fork from OSM — far too easy.
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      expect(container.read(borderReshapeProvider), isFalse);
      await tester.tap(find.text('Reshape outline'));
      await tester.pump();
      expect(container.read(borderReshapeProvider), isTrue);
    });

    testWidgets('a reshaped area says so, and an untouched one does not',
        (tester) async {
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(editedAt: DateTime(2026, 8, 19), pointCount: 3),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      expect(find.textContaining('Reshaped by hand'), findsOneWidget);
      expect(find.textContaining('3 points'), findsOneWidget);
    });

    testWidgets('closing disarms reshaping as well as deselecting',
        (tester) async {
      container.read(selectedBorderAreaProvider.notifier).select('ba1');
      container.read(borderReshapeProvider.notifier).arm(true);
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(container.read(selectedBorderAreaProvider), isNull);
      expect(container.read(borderReshapeProvider), isFalse,
          reason: 'armed handles must not survive onto the next selection');
    });

    testWidgets('there is no layer picker — an area belongs to its import',
        (tester) async {
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('Around home'), findsOneWidget,
          reason: 'named, but read-only');
    });

    testWidgets('renaming writes the area, not its import', (tester) async {
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Maxvorstadt-Nord');
      await tester.pump();
      expect(repo.calls, contains('updateBorderArea ba1 name=Maxvorstadt-Nord'));
    });

    testWidgets('deleting the area clears the selection', (tester) async {
      container.read(selectedBorderAreaProvider.notifier).select('ba1');
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      await tester.tap(find.byTooltip('Delete area'));
      await tester.pump();
      expect(repo.calls, contains('deleteBorderArea ba1'));
      expect(container.read(selectedBorderAreaProvider), isNull);
    });
  });
}

/// Records what a sheet asked for and answers immediately, so no widget test
/// waits on a database round-trip that `FakeAsync` will never finish.
class _RecordingRepository extends Repository {
  _RecordingRepository(super.db);

  final List<String> calls = [];

  static String _v(Value<String?> v) =>
      v.present ? '${v.value}' : '<absent>';

  @override
  Future<void> updatePoiPoint(String id, {required Value<String?> name}) async {
    calls.add('updatePoiPoint $id name=${_v(name)}');
  }

  @override
  Future<void> deletePoiPoint(String id) async => calls.add('deletePoiPoint $id');

  @override
  Future<void> updateTransitStop(String id,
      {required Value<String?> name}) async {
    calls.add('updateTransitStop $id name=${_v(name)}');
  }

  @override
  Future<void> deleteTransitStop(String id) async =>
      calls.add('deleteTransitStop $id');

  @override
  Future<void> updatePoiSet(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) async {
    calls.add('updatePoiSet $id label=${_v(label)}'
        '${layerId == null ? '' : ' layer=$layerId'}');
  }

  @override
  Future<void> deletePoiSet(String id) async => calls.add('deletePoiSet $id');

  @override
  Future<void> updateTransitSet(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) async {
    calls.add('updateTransitSet $id label=${_v(label)}'
        '${layerId == null ? '' : ' layer=$layerId'}');
  }

  @override
  Future<void> setTransitVisibleModes(
      Iterable<String> setIds, int visibleModeMask) async {
    calls.add('setTransitVisibleModes ${setIds.toList()} $visibleModeMask');
  }

  @override
  Future<void> deleteTransitSet(String id) async =>
      calls.add('deleteTransitSet $id');

  @override
  Future<void> updateBorderArea(
    String id, {
    Value<String?> name = const Value.absent(),
    double? labelLat,
    double? labelLng,
  }) async {
    calls.add('updateBorderArea $id name=${_v(name)}'
        '${labelLat == null ? '' : ' label=$labelLat,$labelLng'}');
  }

  @override
  Future<void> deleteBorderArea(String id) async =>
      calls.add('deleteBorderArea $id');

  @override
  Future<List<List<LatLng>>> borderAreaRings(String id) async {
    calls.add('borderAreaRings $id');
    return const [];
  }
}
