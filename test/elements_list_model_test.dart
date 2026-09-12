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

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/elements_list_model.dart';
import 'package:zonecraft/ui/object_summary.dart';
import 'package:zonecraft/ui/poi_groups.dart';

Layer layer(String type) => Layer(
      id: 'L',
      name: 'Layer',
      colorArgb: 0xFF0000FF,
      isVisible: true,
      sortOrder: 0,
      type: type,
      isInverted: false,
      opacity: 1,
      borderFillAreas: false,
      borderShowNames: false,
      createdAt: DateTime.utc(2026),
    );

ObjectSummary sum(
  ObjectKind kind,
  String id, {
  String? name,
  String subtitle = '',
  double? size,
  bool pending = false,
}) =>
    ObjectSummary(
      ref: ObjectRef(kind: kind, id: id, layerId: 'L'),
      title: name ?? '${kind.name} $id',
      subtitle: subtitle,
      center: const LatLng(48, 11),
      fitPoints: const [LatLng(48, 11)],
      sortName: name ?? '',
      sizeMeasure: size,
      isPending: pending,
    );

PoiTypeGroup poiGroup(
  String key,
  List<ObjectSummary> points, {
  PoiGroupKind kind = PoiGroupKind.category,
  TransitMode? mode,
  Set<String> setIds = const {'S'},
}) =>
    PoiTypeGroup(
      key: key,
      kind: kind,
      label: key,
      icon: Icons.place,
      mode: mode,
      setIds: setIds,
      points: points,
    );

ElementRows build({
  Layer? on,
  List<ObjectSummary> summaries = const [],
  List<PoiTypeGroup> groups = const [],
  ElementSort sort = ElementSort.stack,
  String query = '',
  Set<String> expanded = const {},
  bool importsExpanded = false,
}) =>
    buildElementRows(
      layer: on ?? layer('circles'),
      summaries: summaries,
      poiGroups: groups,
      sort: sort,
      query: query,
      expandedGroups: expanded,
      importsExpanded: importsExpanded,
    );

List<String> ids(ElementRows r) => [
      for (final row in r.rows)
        if (row is ElementRow) row.summary.ref.id,
    ];

void main() {
  final circles = [
    sum(ObjectKind.circle, 'a', name: 'Zoo', size: 500),
    sum(ObjectKind.circle, 'b', size: 2000),
    sum(ObjectKind.circle, 'c', name: 'alps', size: 1000),
  ];

  group('sorting', () {
    test('stack order is the input order', () {
      expect(ids(build(summaries: circles)), ['a', 'b', 'c']);
    });

    test('by name: case-insensitive, unnamed after the named', () {
      expect(
        ids(build(summaries: circles, sort: ElementSort.name)),
        ['c', 'a', 'b'],
      );
    });

    test('by size: largest first', () {
      expect(
        ids(build(summaries: circles, sort: ElementSort.size)),
        ['b', 'c', 'a'],
      );
    });

    test('kinds without a size fall back to name', () {
      final sets = [
        sum(ObjectKind.poiSet, 'x', name: 'Cafés'),
        sum(ObjectKind.poiSet, 'y', name: 'Benches'),
      ];
      final r = build(
        on: layer('poi'),
        summaries: sets,
        sort: ElementSort.size,
        importsExpanded: true,
      );
      expect(ids(r), ['y', 'x']);
    });

    test('a combined layer keeps draw order between kinds', () {
      final r = build(
        on: layer(kMixedType),
        summaries: [
          sum(ObjectKind.circle, 'c1', name: 'Zed', size: 1),
          sum(ObjectKind.freeArea, 'a1', name: 'Alpha', size: 1),
        ],
        sort: ElementSort.name,
      );
      expect(ids(r), ['c1', 'a1']);
    });

    test('z-order flags come from stack order whatever the sort', () {
      Map<String, (bool, bool)> flags(ElementSort sort) => {
            for (final row in build(summaries: circles, sort: sort).rows)
              if (row is ElementRow)
                row.summary.ref.id: (row.canMoveBack, row.canMoveForward),
          };
      final stack = flags(ElementSort.stack);
      expect(stack['a'], (false, true), reason: 'bottom of the stack');
      expect(stack['b'], (true, true));
      expect(stack['c'], (true, false), reason: 'front of the map');
      expect(flags(ElementSort.name), stack);
      expect(flags(ElementSort.size), stack);
    });

    test('a lone element, and a border area, cannot be restacked', () {
      final lone = build(summaries: [circles.first]).rows.single as ElementRow;
      expect(lone.canMoveBack || lone.canMoveForward, isFalse);
      final areas = build(
        on: layer('borders'),
        summaries: [
          sum(ObjectKind.borderArea, 'p', name: 'Pasing'),
          sum(ObjectKind.borderArea, 'q', name: 'Laim'),
        ],
      );
      for (final row in areas.rows.cast<ElementRow>()) {
        expect(row.canMoveBack || row.canMoveForward, isFalse);
      }
    });

    test('the sort menu offers only what applies', () {
      expect(canSortByStack(circles), isTrue);
      expect(canSortBySize(circles), isTrue);
      final areas = [sum(ObjectKind.borderArea, 'p', size: 3)];
      expect(canSortByStack(areas), isFalse);
      expect(canSortBySize(areas), isTrue);
      expect(canSortBySize([sum(ObjectKind.poiSet, 's')]), isFalse);
    });
  });

  group('search', () {
    test('matches title or subtitle, case-insensitively', () {
      final rows = [
        sum(ObjectKind.circle, 'a', name: 'Home', subtitle: '500 m radius'),
        sum(ObjectKind.circle, 'b', name: 'Work', subtitle: '2.00 km radius'),
      ];
      expect(ids(build(summaries: rows, query: 'home')), ['a']);
      expect(ids(build(summaries: rows, query: ' KM ')), ['b']);
      expect(ids(build(summaries: rows, query: 'radius')), ['a', 'b']);
    });

    test('nothing matching is a NoMatchesRow, not an empty list', () {
      final r = build(summaries: circles, query: 'xyz');
      expect(r.rows.single, isA<NoMatchesRow>());
      expect((r.rows.single as NoMatchesRow).query, 'xyz');
      expect(build(summaries: const []).rows, isEmpty);
    });
  });

  group('POI groups', () {
    final bus = transitModeByKey('bus')!;
    final stations = poiGroup(
      'station:bus',
      [
        sum(ObjectKind.poiPoint, 's1', name: 'Pasing', subtitle: 'Bus'),
        sum(ObjectKind.poiPoint, 's2', name: 'Laim', subtitle: 'Bus'),
      ],
      kind: PoiGroupKind.station,
      mode: bus,
    );
    final cafes = poiGroup('category:cafe', [
      sum(ObjectKind.poiPoint, 'c1', name: 'Aroma', subtitle: 'Cafés'),
    ]);
    final handmade = poiGroup(
      'manual:M',
      [sum(ObjectKind.poiPoint, 'm1', name: 'Bench', subtitle: 'Mine')],
      kind: PoiGroupKind.manual,
      setIds: {'M'},
    );
    final sets = [
      sum(ObjectKind.poiSet, 'S', name: 'Import'),
      sum(ObjectKind.poiSet, 'M', name: 'Mine'),
    ];

    test('collapsed groups show only their heading', () {
      final r = build(
        on: layer('poi'),
        summaries: sets,
        groups: [stations, cafes, handmade],
      );
      expect(r.poiCount, 4);
      expect(r.rows.map((x) => x.runtimeType), [
        StationToolsRow,
        GroupHeaderRow,
        GroupHeaderRow,
        GroupHeaderRow,
        SectionRow,
      ]);
      final header = r.rows[1] as GroupHeaderRow;
      expect(header.expanded, isFalse);
      expect(header.shown, 2);
      expect((r.rows.last as SectionRow).expanded, isFalse);
    });

    test('an expanded group lists its points, indented', () {
      final r = build(
        on: layer('poi'),
        summaries: sets,
        groups: [stations, cafes],
        expanded: {'category:cafe'},
      );
      final rows = r.rows.whereType<ElementRow>().toList();
      expect(rows.single.summary.ref.id, 'c1');
      expect(rows.single.inGroup, isTrue);
    });

    test('the Imports section holds the imports but not a hand-made set', () {
      final r = build(
        on: layer('poi'),
        summaries: sets,
        groups: [stations, handmade],
        importsExpanded: true,
      );
      final section = r.rows.whereType<SectionRow>().single;
      expect(section.trailing, '1');
      final imports = r.rows.whereType<ElementRow>().toList();
      expect(imports.map((x) => x.summary.ref.id), ['S']);
      expect(imports.single.inGroup, isFalse);
    });

    test('station tools appear once, before the first station group', () {
      final r = build(on: layer('poi'), groups: [cafes, stations]);
      expect(r.rows.whereType<StationToolsRow>(), hasLength(1));
      expect(r.rows.first, isA<GroupHeaderRow>());
      expect(r.rows[1], isA<StationToolsRow>());
      expect(build(on: layer('poi'), groups: [cafes]).rows.first,
          isA<GroupHeaderRow>());
    });

    test('searching expands matching groups and drops the rest', () {
      final r = build(
        on: layer('poi'),
        summaries: sets,
        groups: [stations, cafes],
        query: 'pas',
      );
      expect(r.rows.map((x) => x.runtimeType), [GroupHeaderRow, ElementRow]);
      final header = r.rows.first as GroupHeaderRow;
      expect(header.group.key, 'station:bus');
      expect(header.expanded, isTrue);
      expect(header.shown, 1);
      expect((r.rows.last as ElementRow).summary.ref.id, 's1');
    });

    test('a search that matches only an import still shows it', () {
      final r = build(
        on: layer('poi'),
        summaries: sets,
        groups: [stations],
        query: 'import',
      );
      expect(r.rows.map((x) => x.runtimeType), [SectionRow, ElementRow]);
      expect((r.rows.first as SectionRow).expanded, isTrue);
    });

    test('a failed import floats to the top, above everything', () {
      final r = build(
        on: layer('poi'),
        summaries: [
          ...sets,
          sum(ObjectKind.poiSet, 'P', name: 'Import didn\'t finish', pending: true),
        ],
        groups: [stations],
      );
      expect((r.rows.first as ElementRow).summary.ref.id, 'P');
      // …and is not listed a second time under Imports.
      expect(
        r.rows.whereType<ElementRow>().where((x) => x.summary.ref.id == 'P'),
        hasLength(1),
      );
    });

    test('a combined layer heads each kind, POIs by their point count', () {
      final r = build(
        on: layer(kMixedType),
        summaries: [
          sum(ObjectKind.circle, 'c1'),
          sum(ObjectKind.circle, 'c2'),
          sum(ObjectKind.poiSet, 'S'),
        ],
        groups: [cafes],
      );
      final headers = r.rows.whereType<KindHeaderRow>().toList();
      expect(headers.map((h) => h.kind), [ObjectKind.circle, ObjectKind.poiSet]);
      expect(headers.map((h) => h.count), [2, 1]);
    });

    test('a single-kind layer has no kind headers', () {
      expect(build(summaries: circles).rows.whereType<KindHeaderRow>(), isEmpty);
      final oneKind = build(
        on: layer(kMixedType),
        summaries: [sum(ObjectKind.circle, 'c1'), sum(ObjectKind.circle, 'c2')],
      );
      expect(oneKind.rows.whereType<KindHeaderRow>(), isEmpty);
    });
  });
}
