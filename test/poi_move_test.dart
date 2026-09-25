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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/osm_report.dart';
import 'package:zonecraft/data/poi_sets.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/poi_move.dart';

/// Moving a POI is a mode that writes nothing until Save — these hold that,
/// and what the banner says while it is on.
void main() {
  const from = LatLng(48.13718, 11.575);
  const to = LatLng(48.1374, 11.575);

  group('the move mode', () {
    test('holds a pin, not a write, and Cancel forgets it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final moves = c.read(poiMoveProvider.notifier);
      moves.start('p1', from);
      expect(c.read(poiMoveProvider)!.moved, isFalse);
      moves.moveTo(to);
      final m = c.read(poiMoveProvider)!;
      expect((m.pointId, m.from, m.to), ('p1', from, to));
      expect(m.moved, isTrue);
      moves.cancel();
      expect(c.read(poiMoveProvider), isNull);
    });

    test('a non-finite drop is ignored', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(poiMoveProvider.notifier)
        ..start('p1', from)
        ..moveTo(const LatLng(double.nan, 11));
      expect(c.read(poiMoveProvider)!.to, from);
    });

    test('clearing the transient modes puts the pin away', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(poiMoveProvider.notifier).start('p1', from);
      clearTransientModesIn(c);
      expect(c.read(poiMoveProvider), isNull);
    });
  });

  group('the banner', () {
    test('asks for a drag until the pin moves, then measures it', () {
      expect(
        poiMoveBannerText(const PoiMove(pointId: 'p', from: from, to: from)),
        'Drag the pin, or tap where it really is',
      );
      expect(
        poiMoveBannerText(const PoiMove(pointId: 'p', from: from, to: to)),
        'Moved 24 m north',
      );
    });

    testWidgets('Save is off until the pin has moved', (tester) async {
      Future<void> show(PoiMove m) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PoiMoveBanner(
              move: m,
              onCancel: () {},
              onSave: () {},
              onSaveAndPublish: () {},
            ),
          ),
        ),
      );
      FilledButton save() =>
          tester.widget(find.widgetWithText(FilledButton, 'Save'));

      await show(const PoiMove(pointId: 'p', from: from, to: from));
      expect(save().onPressed, isNull);
      await show(const PoiMove(pointId: 'p', from: from, to: to));
      expect(save().onPressed, isNotNull);
      expect(find.text('Save & publish…'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  test('a move about to be saved composes as a correction', () {
    // "Save & publish" writes, then describes the change from the row it
    // read *before* the write — so the untouched import's position becomes
    // the original, exactly as the repository records it.
    final point = PoiPoint(
      id: 'p1',
      poiSetId: 's1',
      lat: from.latitude,
      lng: from.longitude,
      name: 'Gate bench',
      sortOrder: 0,
      createdAt: DateTime(2026),
      osmType: 'node',
      osmId: 7,
      modeMask: 0,
    );
    final set = PoiSet(
      id: 's1',
      layerId: 'L',
      categoryKey: 'bench',
      centerLat: 48,
      centerLng: 11,
      radiusMeters: 800,
      createdAt: DateTime(2026),
      colorShade: 0,
      zOrder: 0,
      source: kPoiSourceRadius,
      modeMask: 0,
      visibleModeMask: -1,
      fetchedAt: DateTime(2026),
    );
    expect(osmSubjectFor(point, [set]).canPublish, isFalse);
    final moved = osmSubjectFor(
      point,
      [set],
      lat: to.latitude,
      lng: to.longitude,
    );
    expect(moved.availableKinds, [OsmReportKind.movedHere]);
    expect(moved.origLat, from.latitude);
    expect(
      composeOsmReportText(OsmReportKind.movedHere, moved),
      contains('about 24 m north of there'),
    );
  });
}
