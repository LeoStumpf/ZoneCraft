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

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/poi_sets.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/border_area_editor.dart';
import 'package:zonecraft/ui/imported_point_editor.dart';
import 'package:zonecraft/ui/poi_set_editor.dart';

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
    PoiPoint row({String? name, DateTime? editedAt}) => PoiPoint(
      id: 'p1',
      poiSetId: 'ps1',
      lat: 48.001,
      lng: 11.002,
      name: name,
      sortOrder: 0,
      createdAt: DateTime(2026),
      osmType: 'node',
      osmId: 240109189,
      modeMask: 0,
      editedAt: editedAt,
    );

    /// The delete flow reads the point and its set from the providers, and a
    /// live drift stream never emits inside a widget test's FakeAsync.
    void seed({PoiPoint? point, bool manual = false}) {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          poiPointsProvider.overrideWith(
            (ref) => Stream.value([point ?? row(name: 'Alte Post')]),
          ),
          poiSetsProvider.overrideWith(
            (ref) => Stream.value([
              PoiSet(
                id: 'ps1',
                layerId: 'L',
                categoryKey: 'cafe',
                centerLat: 48,
                centerLng: 11,
                radiusMeters: 800,
                createdAt: DateTime(2026),
                colorShade: 0,
                zOrder: 0,
                source: manual ? kPoiSourceManual : kPoiSourceRadius,
                modeMask: 0,
                visibleModeMask: -1,
                fetchedAt: manual ? null : DateTime(2026),
              ),
            ]),
          ),
          osmReportsProvider.overrideWith(
            (ref) => Stream.value(const <OsmReport>[]),
          ),
        ],
      );
      // Subscribed now, so the one value each stream sends is there to read.
      container.listen(poiPointsProvider, (_, _) {});
      container.listen(poiSetsProvider, (_, _) {});
    }

    Widget poiSheet({
      String? name,
      DateTime? editedAt,
      double? origLat,
      double? origLng,
      String? origName,
      bool movable = false,
    }) => ImportedPointEditorSheet(
      id: 'p1',
      name: name,
      lat: 48.001,
      lng: 11.002,
      icon: Icons.place_outlined,
      title: 'Edit POI',
      subtitle: 'Cafés',
      osmType: movable ? null : 'node',
      osmId: movable ? null : 240109189,
      tagKey: 'amenity',
      tagValue: 'cafe',
      movable: movable,
      editedAt: editedAt,
      origLat: origLat,
      origLng: origLng,
      origName: origName,
    );

    /// The Edit button beside [fact] ("Name" / "Position").
    Finder editOf(String fact) => find.descendant(
      of: find.ancestor(of: find.text(fact), matching: find.byType(Wrap)).first,
      matching: find.widgetWithText(TextButton, 'Edit'),
    );

    Future<void> editAndSave(
      WidgetTester tester,
      String fact,
      String value,
    ) async {
      await tester.tap(editOf(fact));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        value,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('the name is text with an Edit button, saved once', (
      tester,
    ) async {
      await pump(tester, poiSheet(name: 'Alte Post'));
      expect(find.text('Edit POI'), findsOneWidget);
      expect(find.text('Alte Post'), findsOneWidget);
      // Not a live field any more: nothing is written until Save.
      expect(find.byType(TextField), findsNothing);

      await editAndSave(tester, 'Name', 'Neue Post');
      expect(repo.calls, ['updatePoiPoint p1 name=Neue Post']);
    });

    testWidgets('an emptied name clears it rather than storing blank', (
      tester,
    ) async {
      // The renderer draws no plate for a nameless POI, and only null says
      // that — a stored '' would leave an empty white plate on the map.
      await pump(tester, poiSheet(name: 'Alte Post'));
      await editAndSave(tester, 'Name', '   ');
      expect(repo.calls, contains('updatePoiPoint p1 name=null'));
    });

    testWidgets('a position is edited as text, and a bad one cannot be saved', (
      tester,
    ) async {
      await pump(tester, poiSheet(name: 'Alte Post'));
      expect(find.textContaining('48.0010'), findsOneWidget);
      await tester.tap(editOf('Position'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'somewhere');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.enterText(field, '48.5, 11.5');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('movePoiPoint p1 48.5,11.5'));
    });

    testWidgets('there is no copy button', (tester) async {
      await pump(tester, poiSheet(name: 'Alte Post'));
      expect(find.textContaining('Copy'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Move'), findsOneWidget);
    });

    testWidgets('delete asks first, and can tell OSM an import is gone', (
      tester,
    ) async {
      seed();
      container.read(selectedPoiPointProvider.notifier).select('p1');
      await pump(tester, poiSheet(name: 'Alte Post'));

      await tester.tap(find.byTooltip('Delete…'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Alte Post”?'), findsOneWidget);
      expect(find.text('Delete & tell OSM…'), findsOneWidget);
      expect(repo.calls, isEmpty, reason: 'nothing goes before the answer');

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('deletePoiPoint p1'));
      expect(
        repo.calls,
        isNot(contains('deletePoiSet')),
        reason: 'curating one POI away must not delete its import',
      );
      expect(container.read(selectedPoiPointProvider), isNull);
    });

    testWidgets('a hand-placed POI is only asked about — OSM never had it', (
      tester,
    ) async {
      seed(
        point: PoiPoint(
          id: 'p1',
          poiSetId: 'ps1',
          lat: 48.001,
          lng: 11.002,
          name: 'My bench',
          sortOrder: 0,
          createdAt: DateTime(2026),
          modeMask: 0,
        ),
        manual: true,
      );
      await pump(tester, poiSheet(name: 'My bench', movable: true));
      await tester.tap(find.byTooltip('Delete…'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “My bench”?'), findsOneWidget);
      expect(find.text('Delete & tell OSM…'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
    });

    testWidgets('an untouched import has nothing to publish', (tester) async {
      await pump(tester, poiSheet(name: 'Alte Post'));
      expect(find.text('Revert'), findsNothing);
      expect(find.textContaining('Publish'), findsNothing);
      expect(find.textContaining('Tell OpenStreetMap'), findsNothing);
    });

    testWidgets('a hand-placed POI offers to publish itself', (tester) async {
      await pump(tester, poiSheet(name: 'My bench', movable: true));
      expect(find.text('Publish to OpenStreetMap…'), findsOneWidget);
    });

    testWidgets('a corrected point says so, and offers to publish it', (
      tester,
    ) async {
      // The whole point of recording the fork: the row keeps its osmId, so
      // without this line nothing anywhere distinguishes your correction from
      // upstream's data.
      await pump(
        tester,
        poiSheet(
          name: 'Neue Post',
          editedAt: DateTime(2026, 3, 12),
          origLat: 48.001,
          origLng: 11.002,
          origName: 'Alte Post',
        ),
      );
      expect(find.textContaining('Corrected by you'), findsOneWidget);
      expect(find.textContaining('Alte Post'), findsOneWidget);
      expect(find.text('Publish this change…'), findsOneWidget);
    });

    testWidgets('Save & publish saves, then opens the publish sheet', (
      tester,
    ) async {
      await pump(tester, poiSheet(name: 'Alte Post'));
      await tester.tap(editOf('Name'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Neue Post',
      );
      await tester.pump();
      await tester.tap(find.text('Save & publish…'));
      await tester.pumpAndSettle();
      expect(repo.calls.first, 'updatePoiPoint p1 name=Neue Post');
      // The sheet describes the change just made, not the old row.
      expect(find.text('Publish to OpenStreetMap'), findsOneWidget);
      expect(find.textContaining('it is “Neue Post”'), findsOneWidget);
    });

    testWidgets('revert hands an imported point back', (tester) async {
      await pump(
        tester,
        poiSheet(
          name: 'Neue Post',
          editedAt: DateTime(2026, 3, 12),
          origLat: 48.5,
          origLng: 11.5,
          origName: 'Alte Post',
        ),
      );
      await tester.tap(find.text('Revert'));
      await tester.pump();
      expect(repo.calls, contains('revertPoiPoint p1'));
    });
  });

  group('PoiSetEditorSheet', () {
    PoiSet set({String? label, bool isManual = false, String? iconKey}) =>
        PoiSet(
          id: 'ps1',
          layerId: 'L',
          categoryKey: 'cafe',
          centerLat: 48.0,
          centerLng: 11.0,
          radiusMeters: 800,
          label: label,
          createdAt: DateTime(2026),
          colorShade: 0,
          source: isManual ? kPoiSourceManual : kPoiSourceRadius,
          fetchedAt: isManual ? null : DateTime(2026),
          iconKey: iconKey,
          zOrder: 0,
          modeMask: 0,
          visibleModeMask: -1,
        );

    testWidgets('it names the category, the count and the circle that ran', (
      tester,
    ) async {
      await pump(
        tester,
        PoiSetEditorSheet(set: set(), pointCount: 2, layers: [layerOf('poi')]),
      );
      expect(find.text('Edit POI import'), findsOneWidget);
      expect(find.textContaining('2 POIs stored'), findsOneWidget);
      expect(find.textContaining('within 800 m'), findsOneWidget);
    });

    testWidgets('one stored POI is not pluralised', (tester) async {
      await pump(
        tester,
        PoiSetEditorSheet(set: set(), pointCount: 1, layers: [layerOf('poi')]),
      );
      expect(find.textContaining('1 POI stored'), findsOneWidget);
    });

    testWidgets('typing a label renames the import', (tester) async {
      await pump(
        tester,
        PoiSetEditorSheet(set: set(), pointCount: 2, layers: [layerOf('poi')]),
      );
      await tester.enterText(find.byType(TextField), 'Cafés near home');
      await tester.pump();
      expect(repo.calls, contains('updatePoiSet ps1 label=Cafés near home'));
    });

    testWidgets('the category, centre and radius are text, not controls', (
      tester,
    ) async {
      // They describe a query that already ran: editing them would leave a row
      // claiming to hold something it never fetched.
      await pump(
        tester,
        PoiSetEditorSheet(set: set(), pointCount: 2, layers: [layerOf('poi')]),
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('deleting the import clears the selection', (tester) async {
      container.read(selectedPoiSetProvider.notifier).select('ps1');
      await pump(
        tester,
        PoiSetEditorSheet(set: set(), pointCount: 2, layers: [layerOf('poi')]),
      );
      await tester.tap(find.byTooltip('Delete import'));
      await tester.pump();
      expect(repo.calls, contains('deletePoiSet ps1'));
      expect(container.read(selectedPoiSetProvider), isNull);
    });
  });

  group('PoiSetEditorSheet on a station import', () {
    PoiSet set({required int modeMask, required int visible}) => PoiSet(
      id: 'ts1',
      layerId: 'L',
      categoryKey: kTransitStationCategoryKey,
      centerLat: 48.1,
      centerLng: 11.15,
      radiusMeters: 1,
      source: kPoiSourceBox,
      south: 48.0,
      west: 11.0,
      north: 48.2,
      east: 11.3,
      modeMask: modeMask,
      visibleModeMask: visible,
      fetchedAt: DateTime(2026),
      createdAt: DateTime(2026),
      colorShade: 0,
      zOrder: 0,
    );

    testWidgets('only the types the import actually fetched get a tick box', (
      tester,
    ) async {
      // What a narrower import left out was never stored, so a chip for it
      // could never draw anything — a control that does nothing.
      final rail = transitRailMask;
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(modeMask: rail, visible: rail),
          pointCount: 3,
          layers: [layerOf('poi')],
        ),
      );
      expect(find.text('Edit station import'), findsOneWidget);
      for (final m in transitModes) {
        expect(
          find.widgetWithText(FilterChip, m.label),
          rail & m.bit != 0 ? findsOneWidget : findsNothing,
          reason: m.label,
        );
      }
      expect(find.textContaining('3 stations stored'), findsOneWidget);
    });

    testWidgets(
      'unticking a type writes the visible mask, not the imported one',
      (tester) async {
        final all = transitAllModesMask;
        final bus = transitModeByKey('bus')!;
        await pump(
          tester,
          PoiSetEditorSheet(
            set: set(modeMask: all, visible: all),
            pointCount: 9,
            layers: [layerOf('poi')],
          ),
        );
        await tester.tap(find.widgetWithText(FilterChip, bus.label));
        await tester.pump();

        expect(
          repo.calls,
          contains('setPoiVisibleModes [ts1] ${all & ~bus.bit}'),
        );
        expect(
          repo.calls.where((c) => c.startsWith('updatePoiSet')),
          isEmpty,
          reason: 'hiding a type must not rewrite what was fetched',
        );
      },
    );

    testWidgets('ticking a hidden type back on restores its bit', (
      tester,
    ) async {
      final all = transitAllModesMask;
      final bus = transitModeByKey('bus')!;
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(modeMask: all, visible: all & ~bus.bit),
          pointCount: 9,
          layers: [layerOf('poi')],
        ),
      );
      await tester.tap(find.widgetWithText(FilterChip, bus.label));
      await tester.pump();
      expect(repo.calls, contains('setPoiVisibleModes [ts1] $all'));
    });

    testWidgets('an import that fetched nothing offers no Show section', (
      tester,
    ) async {
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(modeMask: 0, visible: 0),
          pointCount: 0,
          layers: [layerOf('poi')],
        ),
      );
      expect(find.text('Show'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.textContaining('0 stations stored'), findsOneWidget);
    });

    testWidgets('a pending import says so and offers a retry', (tester) async {
      await pump(
        tester,
        PoiSetEditorSheet(
          set: set(modeMask: transitAllModesMask, visible: -1).copyWith(
            fetchedAt: const Value(null),
            lastError: const Value('Overpass is busy'),
          ),
          pointCount: 0,
          layers: [layerOf('poi')],
        ),
      );
      expect(find.textContaining('Overpass is busy'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(container.read(pendingImportRetryProvider)?.setId, 'ts1');
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

    testWidgets('an untouched area shows its OSM identity and no warning', (
      tester,
    ) async {
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

    testWidgets('it points at the name-plate handle, which is on the map', (
      tester,
    ) async {
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

    testWidgets('reshaping is off by default and is a mode, not handles', (
      tester,
    ) async {
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

    testWidgets('a reshaped area says so, and an untouched one does not', (
      tester,
    ) async {
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

    testWidgets('closing disarms reshaping as well as deselecting', (
      tester,
    ) async {
      container.read(selectedBorderAreaProvider.notifier).select('ba1');
      container.read(borderReshapeProvider.notifier).arm(on: true);
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
      expect(
        container.read(borderReshapeProvider),
        isFalse,
        reason: 'armed handles must not survive onto the next selection',
      );
    });

    testWidgets('there is no layer picker — an area belongs to its import', (
      tester,
    ) async {
      await pump(
        tester,
        BorderAreaEditorSheet(
          area: area(),
          layer: layerOf('borders', borderLevel: '8'),
        ),
      );
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(
        find.text('Around home'),
        findsOneWidget,
        reason: 'named, but read-only',
      );
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
      expect(
        repo.calls,
        contains('updateBorderArea ba1 name=Maxvorstadt-Nord'),
      );
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

  static String _v(Value<String?> v) => v.present ? '${v.value}' : '<absent>';

  @override
  Future<void> updatePoiPoint(String id, {required Value<String?> name}) async {
    calls.add('updatePoiPoint $id name=${_v(name)}');
  }

  @override
  Future<void> deletePoiPoint(String id) async =>
      calls.add('deletePoiPoint $id');

  // The editor shows where a point's report stands, and the publish sheet
  // counts today's notes; neither may reach the never-opened database.
  @override
  Stream<List<OsmReport>> watchOsmReports() => Stream.value(const []);

  @override
  Future<int> osmReportsSentSince(Duration window) async => 0;

  @override
  Future<void> movePoiPoint({
    required String id,
    required double lat,
    required double lng,
  }) async {
    calls.add('movePoiPoint $id $lat,$lng');
  }

  @override
  Future<void> revertPoiPoint(String id) async =>
      calls.add('revertPoiPoint $id');

  @override
  Future<void> updatePoiSet(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
    String? categoryKey,
    Value<String?> iconKey = const Value.absent(),
  }) async {
    calls.add(
      'updatePoiSet $id label=${_v(label)}'
      '${layerId == null ? '' : ' layer=$layerId'}'
      '${categoryKey == null ? '' : ' category=$categoryKey'}'
      '${iconKey.present ? ' icon=${_v(iconKey)}' : ''}',
    );
  }

  @override
  Future<void> deletePoiSet(String id) async => calls.add('deletePoiSet $id');

  @override
  Future<void> setPoiVisibleModes(
    Iterable<String> setIds,
    int visibleModeMask,
  ) async {
    calls.add('setPoiVisibleModes ${setIds.toList()} $visibleModeMask');
  }

  @override
  Future<void> updateBorderArea(
    String id, {
    Value<String?> name = const Value.absent(),
    double? labelLat,
    double? labelLng,
  }) async {
    calls.add(
      'updateBorderArea $id name=${_v(name)}'
      '${labelLat == null ? '' : ' label=$labelLat,$labelLng'}',
    );
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
