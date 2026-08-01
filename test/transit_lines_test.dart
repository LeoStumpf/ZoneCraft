import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/ui/transit_lines.dart';

class FakeRoute implements TransitRouteLike {
  FakeRoute(
    this.id,
    this.modeKey, {
    this.ref,
    this.name,
    this.operatorName,
    this.isVisible = true,
    this.colorArgb,
  });

  @override
  final String id;
  @override
  final String modeKey;
  @override
  final String? ref;
  @override
  final String? name;
  @override
  final String? operatorName;
  @override
  final bool isVisible;
  @override
  final int? colorArgb;
}

void main() {
  group('groupState', () {
    test('agrees, disagrees and handles empty', () {
      expect(groupState(const [true, true]), GroupState.all);
      expect(groupState(const [false, false]), GroupState.none);
      expect(groupState(const [true, false]), GroupState.some);
      expect(groupState(const []), GroupState.none);
    });

    test('maps to a tri-state checkbox value', () {
      expect(groupCheckboxValue(GroupState.all), isTrue);
      expect(groupCheckboxValue(GroupState.none), isFalse);
      expect(groupCheckboxValue(GroupState.some), isNull);
    });
  });

  group('compareRefs', () {
    List<String> sorted(List<String> refs) => [...refs]..sort(compareRefs);

    test('orders numbers numerically, not lexically', () {
      expect(sorted(['10', '2', '1']), ['1', '2', '10']);
    });

    test('orders lettered lines naturally', () {
      expect(sorted(['U6', 'U1', 'U10', 'U2']), ['U1', 'U2', 'U6', 'U10']);
      expect(sorted(['S20', 'S8', 'S1']), ['S1', 'S8', 'S20']);
    });

    test('keeps prefixes together', () {
      expect(sorted(['U1', 'S1', 'N1']), ['N1', 'S1', 'U1']);
    });

    test('is case-insensitive and tolerates empties', () {
      expect(compareRefs('u6', 'U6'), 0);
      expect(compareRefs('', ''), 0);
      expect(compareRefs('', 'U1'), lessThan(0));
    });
  });

  group('transitRouteLabel', () {
    test('prefers ref, then name, then the fallback', () {
      expect(transitRouteLabel(FakeRoute('a', 'bus', ref: '54', name: 'X')), '54');
      expect(transitRouteLabel(FakeRoute('a', 'bus', name: 'Nightliner')),
          'Nightliner');
      expect(
        transitRouteLabel(FakeRoute('a', 'bus'), fallback: 'Route 123'),
        'Route 123',
      );
      // Whitespace-only tags don't count as a label.
      expect(transitRouteLabel(FakeRoute('a', 'bus', ref: '  ', name: 'N')), 'N');
    });
  });

  group('groupTransitLines', () {
    final routes = [
      // U6 both directions — one line, two relations.
      FakeRoute('r1', 'subway', ref: 'U6', name: 'U6: North', colorArgb: 0xFF00FF00),
      FakeRoute('r2', 'subway', ref: 'U6', name: 'U6: South'),
      FakeRoute('r3', 'subway', ref: 'U1', name: 'U1: East'),
      FakeRoute('r4', 'bus', ref: '54', name: '54: Loop', operatorName: 'MVG'),
      FakeRoute('r5', 'tram', ref: '19', isVisible: false),
    ];

    test('folds a line\'s directions into one row', () {
      final groups = groupTransitLines(routes);
      final subway = groups.firstWhere((g) => g.mode.key == 'subway');
      expect(subway.lines.map((l) => l.label), ['U1', 'U6']); // natural order
      final u6 = subway.lines.last;
      expect(u6.routeIds, ['r1', 'r2']);
      expect(u6.colorArgb, 0xFF00FF00); // the first route that had one
      expect(u6.subtitle, 'U6: North');
    });

    test('groups come back in catalogue order and skip empty modes', () {
      final keys = groupTransitLines(routes).map((g) => g.mode.key).toList();
      expect(keys, ['bus', 'tram', 'subway']);
      expect(keys, isNot(contains('ferry')));
    });

    test('counts routes and visible routes per group', () {
      final groups = groupTransitLines(routes);
      final subway = groups.firstWhere((g) => g.mode.key == 'subway');
      expect(subway.routeCount, 3);
      expect(subway.visibleRouteCount, 3);
      expect(subway.state, GroupState.all);

      final tram = groups.firstWhere((g) => g.mode.key == 'tram');
      expect(tram.state, GroupState.none);
    });

    test('a partly hidden line reads as mixed', () {
      final groups = groupTransitLines([
        FakeRoute('a', 'subway', ref: 'U6'),
        FakeRoute('b', 'subway', ref: 'U6', isVisible: false),
      ]);
      final u6 = groups.single.lines.single;
      expect(u6.state, GroupState.some);
      expect(groups.single.state, GroupState.some);
    });

    test('search matches ref, name and operator', () {
      expect(
        groupTransitLines(routes, query: 'u6').single.lines.single.label,
        'U6',
      );
      expect(
        groupTransitLines(routes, query: 'loop').single.lines.single.label,
        '54',
      );
      expect(
        groupTransitLines(routes, query: 'mvg').single.mode.key,
        'bus',
      );
      expect(groupTransitLines(routes, query: 'zzz'), isEmpty);
      // A blank query is not a filter.
      expect(groupTransitLines(routes, query: '   ').length, 3);
    });

    test('routeIds spans every line in the group', () {
      final subway =
          groupTransitLines(routes).firstWhere((g) => g.mode.key == 'subway');
      expect(subway.routeIds, containsAll(['r1', 'r2', 'r3']));
    });

    test('an unknown mode key is dropped', () {
      expect(groupTransitLines([FakeRoute('x', 'hovercraft', ref: '1')]), isEmpty);
    });
  });
}
