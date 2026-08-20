import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/circle_editor.dart';
import 'package:zonecraft/ui/layers_panel.dart';

/// Every numeric control must be typeable, not only draggable: a slider cannot
/// hit "exactly 500 m" on a 10 m–1000 km log scale, and 33 % is between two of
/// the opacity slider's 5 % steps. The two controls that were slider-only keep
/// the slider *and* a field, and the pair must never disagree about the value —
/// the field kept showing the old number while the slider moved, because the
/// keyboard stays up (and the field keeps focus) during a drag.
///
/// Driven by a recording repository, like `imported_editors_test.dart`: what is
/// checked is which call the sheet makes with which argument.
void main() {
  late AppDatabase db;
  late _RecordingRepository repo;
  late ProviderContainer container;

  setUp(() {
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

  final layer = Layer(
    id: 'L',
    name: 'Around home',
    colorArgb: 0xFF112233,
    isVisible: true,
    sortOrder: 0,
    type: 'circles',
    isInverted: false,
    opacity: 1,
    borderLevel: null,
    borderFillAreas: false,
    borderShowNames: false,
        trackStrokeWidth: 4,
        trackMinDistanceMeters: 10,
    createdAt: DateTime(2026),
  );

  Widget circleSheet({double radius = 191913.8}) => CircleEditorSheet(
        circle: Circle(
          id: 'c1',
          layerId: 'L',
          centerLat: 48.137154,
          centerLng: 11.575382,
          radiusMeters: radius,
          createdAt: DateTime(2026),
          colorShade: 0,
        ),
        layers: [layer],
      );

  Finder radiusField() => find.ancestor(
        of: find.text('Radius (m)'),
        matching: find.byType(TextField),
      );

  String textOf(WidgetTester tester, Finder f) =>
      tester.widget<TextField>(f).controller!.text;

  group('circle radius', () {
    testWidgets('opens showing the stored radius as a number', (tester) async {
      await pump(tester, circleSheet());
      expect(textOf(tester, radiusField()), '191913.8');
      // The km reading is the helper, so the field itself stays metres — the
      // unit the value is typed and stored in.
      expect(find.text('192 km'), findsOneWidget);
    });

    testWidgets('an exactly typed radius is stored as typed', (tester) async {
      await pump(tester, circleSheet());
      await tester.enterText(radiusField(), '500');
      await tester.pump();
      expect(repo.calls, contains('updateCircle c1 radius=500.0'));
    });

    testWidgets('a comma decimal is parsed, not dropped', (tester) async {
      // parseDecimal, not double.tryParse: on a comma-decimal locale the field
      // would otherwise silently no-op.
      await pump(tester, circleSheet());
      await tester.enterText(radiusField(), '500,5');
      await tester.pump();
      expect(repo.calls, contains('updateCircle c1 radius=500.5'));
    });

    testWidgets('nonsense and zero leave the radius alone', (tester) async {
      await pump(tester, circleSheet());
      await tester.enterText(radiusField(), '');
      await tester.enterText(radiusField(), '0');
      await tester.enterText(radiusField(), 'abc');
      await tester.pump();
      expect(repo.calls, isEmpty);
    });

    testWidgets('dragging the slider writes the field, even while it has focus',
        (tester) async {
      await pump(tester, circleSheet(radius: 1000));
      await tester.tap(radiusField());
      await tester.pump();
      expect(tester.widget<TextField>(radiusField()).focusNode!.hasFocus, isTrue);

      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pump();

      final shown = double.parse(textOf(tester, radiusField()));
      expect(shown, greaterThan(1000));
      // What the field shows is what was stored: the slider rounds to whole
      // metres precisely so the two can agree.
      expect(repo.calls.last, 'updateCircle c1 radius=$shown');
      expect(shown, shown.roundToDouble());
    });
  });

  group('opacity dialog', () {
    Future<double?> openAndEdit(
      WidgetTester tester,
      Future<void> Function(WidgetTester) edit,
    ) async {
      double? applied;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showOpacityDialog(
              context,
              title: 'Layer transparency',
              value: 1,
              onChanged: (v) => applied = v,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await edit(tester);
      return applied;
    }

    testWidgets('a typed per cent applies exactly', (tester) async {
      final applied = await openAndEdit(tester, (t) async {
        await t.enterText(find.byType(TextField), '33');
        await t.pump();
      });
      expect(applied, closeTo(0.33, 1e-9));
    });

    testWidgets('out-of-range typing is clamped, not stored raw',
        (tester) async {
      final applied = await openAndEdit(tester, (t) async {
        await t.enterText(find.byType(TextField), '400');
        await t.pump();
      });
      expect(applied, 1.0);
    });

    testWidgets('the slider writes the field back', (tester) async {
      await openAndEdit(tester, (t) async {
        await t.tap(find.byType(TextField));
        await t.pump();
        await t.drag(find.byType(Slider), const Offset(-80, 0));
        await t.pump();
      });
      final shown = tester.widget<TextField>(find.byType(TextField));
      expect(int.parse(shown.controller!.text), lessThan(100));
    });
  });
}

class _RecordingRepository extends Repository {
  _RecordingRepository(super.db);

  final List<String> calls = [];

  @override
  Future<void> updateCircle(
    String id, {
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) async {
    if (radiusMeters != null) calls.add('updateCircle $id radius=$radiusMeters');
    if (centerLat != null) calls.add('updateCircle $id centre=$centerLat,$centerLng');
    if (layerId != null) calls.add('updateCircle $id layer=$layerId');
    if (label.present) calls.add('updateCircle $id label=${label.value}');
  }
}
