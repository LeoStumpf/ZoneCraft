import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zonecraft/data/transit.dart';

Map<String, dynamic> node(
  int id,
  double lat,
  double lon, {
  String? name,
  Map<String, String> tags = const {},
}) =>
    {
      'type': 'node',
      'id': id,
      'lat': lat,
      'lon': lon,
      'tags': {...tags, 'name': ?name},
    };

String bodyOf(List<Map<String, dynamic>> elements) =>
    jsonEncode({'elements': elements});

int bit(String key) => transitModeByKey(key)!.bit;

void main() {
  group('mode catalogue', () {
    test('bits are distinct single bits', () {
      final seen = <int>{};
      for (final m in transitModes) {
        expect(m.bit & (m.bit - 1), 0, reason: '${m.key} is not a single bit');
        expect(seen.add(m.bit), isTrue, reason: '${m.key} reuses a bit');
      }
    });

    test('no tag key belongs to two modes', () {
      final seen = <String>{};
      for (final m in transitModes) {
        for (final v in m.tagKeys) {
          expect(seen.add(v), isTrue, reason: '$v is claimed twice');
        }
      }
    });

    test('mask round-trips', () {
      final bus = transitModes.first;
      final tram = transitModes[1];
      var mask = 0;
      mask = transitMaskWith(mask, bus, true);
      mask = transitMaskWith(mask, tram, true);
      expect(transitModesFromMask(mask), {bus, tram});
      mask = transitMaskWith(mask, bus, false);
      expect(transitModesFromMask(mask), {tram});
      expect(transitModesFromMask(0), isEmpty);
    });

    test('the rail mask covers the rail modes only', () {
      final rail = transitModesFromMask(transitRailMask).map((m) => m.key);
      expect(rail, containsAll(['tram', 'subway', 'light_rail', 'train']));
      expect(rail, isNot(contains('bus')));
      expect(rail, isNot(contains('ferry')));
    });
  });

  group('defaultVisibleModes', () {
    test('a neighbourhood shows everything, including bus', () {
      expect(defaultVisibleModes(2000), transitAllModesMask);
      expect(
          defaultVisibleModes(kTransitBusDefaultMaxMeters), transitAllModesMask);
    });

    test('a city-sized import starts with bus hidden', () {
      // 3 147 of Munich's 3 629 stations are bus-only — they'd swamp the view.
      final m = defaultVisibleModes(45000);
      expect(m & bit('bus'), 0);
      expect(m & bit('subway'), isNot(0));
      expect(m & bit('train'), isNot(0));
    });

    test('a non-finite diagonal falls back to showing everything', () {
      expect(defaultVisibleModes(double.nan), transitAllModesMask);
    });
  });

  group('recommendedImportModes', () {
    test('a city-sized box asks for everything', () {
      expect(recommendedImportModes(2000), transitAllModesMask);
      expect(recommendedImportModes(kTransitRegionalMaxMeters),
          transitAllModesMask);
    });

    test('a region drops the buses, which are the expensive half', () {
      final m = recommendedImportModes(100000);
      expect(m & bit('bus'), 0);
      expect(m & bit('train'), isNot(0));
      expect(m & bit('tram'), isNot(0));
    });

    test('a state-sized box asks for trains alone', () {
      // Bavaria is ~511 km across: 8 345 train nodes, 200 941 bus ones.
      expect(recommendedImportModes(511000), bit('train'));
    });

    test('an unusable box suggests everything rather than nothing', () {
      expect(recommendedImportModes(double.nan), transitAllModesMask);
    });
  });

  group('per-mode size limits', () {
    test('the limit of a selection is its strictest member', () {
      expect(transitMaxDiagonalFor(bit('train')),
          transitModeByKey('train')!.maxDiagonalMeters);
      expect(transitMaxDiagonalFor(bit('train') | bit('bus')),
          transitModeByKey('bus')!.maxDiagonalMeters);
      expect(transitWarnDiagonalFor(transitAllModesMask),
          transitModeByKey('bus')!.warnDiagonalMeters);
    });

    test('Bavaria is fine for trains and out of the question for buses', () {
      const bavaria = 511000.0;
      expect(transitModesOverLimit(bit('train'), bavaria), isEmpty);
      expect(transitModesOverLimit(bit('train') | bit('bus'), bavaria)
          .map((m) => m.key), ['bus']);
    });

    test('a mode only over its warning is warned about, not refused', () {
      final bus = transitModeByKey('bus')!;
      final d = bus.warnDiagonalMeters + 1;
      expect(transitModesOverLimit(bus.bit, d), isEmpty);
      expect(transitModesOverWarning(bus.bit, d).single.key, 'bus');
      // Past the hard limit it is a refusal instead — never both.
      final past = bus.maxDiagonalMeters + 1;
      expect(transitModesOverWarning(bus.bit, past), isEmpty);
      expect(transitModesOverLimit(bus.bit, past).single.key, 'bus');
    });

    test('an unusable diagonal warns about nothing', () {
      expect(transitModesOverLimit(transitAllModesMask, double.nan), isEmpty);
      expect(transitModesOverWarning(transitAllModesMask, double.nan), isEmpty);
    });
  });

  group('transitModeLabels', () {
    test('names a subset, and collapses the full set', () {
      expect(transitModeLabels(bit('train')), 'Train');
      expect(transitModeLabels(bit('train') | bit('bus')), 'Bus, Train');
      expect(transitModeLabels(transitAllModesMask), 'all types');
      expect(transitModeLabels(0), 'nothing');
    });
  });

  group('stopModeMask', () {
    test('reads the mode tags on the node', () {
      expect(stopModeMask({'bus': 'yes'}), bit('bus'));
      expect(stopModeMask({'bus': 'yes', 'train': 'yes'}),
          bit('bus') | bit('train'));
    });

    test('folds trolleybus and share_taxi into bus', () {
      expect(stopModeMask({'trolleybus': 'yes'}), bit('bus'));
      expect(stopModeMask({'share_taxi': 'yes'}), bit('bus'));
    });

    test('ignores a mode tag that is not "yes"', () {
      expect(stopModeMask({'bus': 'no'}), 0);
    });

    test('falls back to the stop kind when no mode is tagged', () {
      expect(stopModeMask({'railway': 'tram_stop'}), bit('tram'));
      expect(stopModeMask({'railway': 'station'}), bit('train'));
      expect(stopModeMask({'railway': 'halt'}), bit('train'));
      expect(stopModeMask({'highway': 'bus_stop'}), bit('bus'));
    });

    test('station=* beats the bare railway fallback', () {
      // Otherwise a metro station tagged the old way lands in a train-only
      // import as a train.
      expect(stopModeMask({'railway': 'station', 'station': 'subway'}),
          bit('subway'));
      expect(stopModeMask({'railway': 'station', 'station': 'light_rail'}),
          bit('light_rail'));
    });

    test('an explicit tag beats the stop-kind fallback', () {
      // A tram stop that also serves buses must keep both.
      expect(
        stopModeMask({'railway': 'tram_stop', 'tram': 'yes', 'bus': 'yes'}),
        bit('tram') | bit('bus'),
      );
    });

    test('an unspecified stop is 0, not dropped', () {
      expect(stopModeMask({'public_transport': 'platform'}), 0);
    });
  });

  group('mergeStations', () {
    TransitStopNode stop(int id, double lat, double lng,
            {String? name, int mask = 0, bool station = false}) =>
        TransitStopNode(
          osmId: id,
          lat: lat,
          lng: lng,
          name: name,
          modeMask: mask,
          isStation: station,
        );

    test('same name, close together, becomes one station with union of modes',
        () {
      // Real shape: Pasing Bahnhof is 11 nodes within ~110 m.
      final merged = mergeStations([
        stop(1, 48.14888, 11.46041, name: 'Pasing Bahnhof', mask: bit('bus')),
        stop(2, 48.14895, 11.45968, name: 'Pasing Bahnhof', mask: bit('bus')),
        stop(3, 48.14904, 11.45993, name: 'Pasing Bahnhof', mask: bit('train')),
        stop(4, 48.14919, 11.45964, name: 'Pasing Bahnhof', mask: bit('tram')),
      ]);
      expect(merged, hasLength(1));
      expect(merged.single.name, 'Pasing Bahnhof');
      expect(merged.single.modeMask, bit('bus') | bit('train') | bit('tram'));
      expect(merged.single.nodeCount, 4);
    });

    test('same name far apart stays two stations', () {
      final merged = mergeStations([
        stop(1, 48.10, 11.50, name: 'Rathaus', mask: bit('bus')),
        stop(2, 48.20, 11.60, name: 'Rathaus', mask: bit('bus')),
      ]);
      expect(merged, hasLength(2));
    });

    test('different names at the same spot stay separate', () {
      final merged = mergeStations([
        stop(1, 48.10, 11.50, name: 'A', mask: bit('bus')),
        stop(2, 48.10, 11.50, name: 'B', mask: bit('tram')),
      ]);
      expect(merged, hasLength(2));
    });

    test('unnamed nodes never merge', () {
      final merged = mergeStations([
        stop(1, 48.10, 11.50, mask: bit('bus')),
        stop(2, 48.10001, 11.50001, mask: bit('bus')),
      ]);
      expect(merged, hasLength(2));
    });

    test('a station node anchors the position', () {
      final merged = mergeStations([
        stop(1, 48.1000, 11.5000, name: 'Hbf', mask: bit('bus')),
        stop(2, 48.1005, 11.5005,
            name: 'Hbf', mask: bit('train'), station: true),
        stop(3, 48.1010, 11.5010, name: 'Hbf', mask: bit('subway')),
      ]);
      expect(merged, hasLength(1));
      expect(merged.single.lat, closeTo(48.1005, 1e-9));
      expect(merged.single.lng, closeTo(11.5005, 1e-9));
      expect(merged.single.osmId, 2);
    });

    test('without a station node the position is the mean', () {
      final merged = mergeStations([
        stop(1, 48.1000, 11.5000, name: 'X', mask: bit('bus')),
        stop(2, 48.1002, 11.5000, name: 'X', mask: bit('bus')),
      ]);
      expect(merged.single.lat, closeTo(48.1001, 1e-6));
    });

    test('merges across grid-cell boundaries', () {
      // A chain of nodes ~33 m apart spanning many cells; the 3x3 neighbourhood
      // scan is what stops a pair straddling a boundary from splitting.
      final merged = mergeStations([
        for (var i = 0; i < 40; i++)
          stop(i, 48.0 + i * 0.0003, 11.5, name: 'Chain', mask: bit('bus')),
      ]);
      expect(merged, hasLength(1));
      expect(merged.single.nodeCount, 40);
    });

    test('empty input yields no stations', () {
      expect(mergeStations(const []), isEmpty);
    });
  });

  group('buildTransitStopsQuery', () {
    test('asks for stop nodes only, with the bbox', () {
      final q = buildTransitStopsQuery(
          south: 48.1, west: 11.5, north: 48.2, east: 11.6);
      expect(q, contains('(48.1,11.5,48.2,11.6)'));
      expect(q, contains('node["public_transport"="stop_position"]'));
      expect(q, contains('node["highway"="bus_stop"]'));
      expect(q, contains('out body qt;'));
      // No relations and no geometry — that is the whole point.
      expect(q, isNot(contains('rel')));
      expect(q, isNot(contains('geom')));
    });

    test('a subset asks only for the chosen modes', () {
      final q = buildTransitStopsQuery(
        south: 47.27,
        west: 8.97,
        north: 50.57,
        east: 13.84,
        modeMask: transitModeByKey('train')!.bit,
      );
      expect(q, contains('node["railway"="station"]'));
      expect(q, contains('node["train"="yes"]'));
      // The 200 000 bus nodes are exactly what this shape exists to avoid.
      expect(q, isNot(contains('bus')));
      expect(q, isNot(contains('public_transport')));
    });

    test('a wide box gets a longer Overpass budget', () {
      String timeoutOf(double diagonal) => buildTransitStopsQuery(
            south: 48.1,
            west: 11.5,
            north: 48.2,
            east: 11.6,
            diagonalMeters: diagonal,
          ).split(';').first;
      expect(timeoutOf(20000), contains('timeout:90'));
      expect(timeoutOf(511000), contains('timeout:180'));
    });
  });

  group('parseTransitStations', () {
    test('parses nodes and merges them', () {
      final stations = parseTransitStations(bodyOf([
        node(1, 48.1000, 11.5000,
            name: 'Hbf', tags: {'bus': 'yes', 'public_transport': 'platform'}),
        node(2, 48.1002, 11.5001,
            name: 'Hbf', tags: {'train': 'yes', 'public_transport': 'station'}),
        node(3, 48.2000, 11.6000, name: 'Ostbahnhof', tags: {'subway': 'yes'}),
      ]))!;
      expect(stations, hasLength(2));
      final hbf = stations.firstWhere((s) => s.name == 'Hbf');
      expect(hbf.modeMask, bit('bus') | bit('train'));
      expect(hbf.nodeCount, 2);
      expect(hbf.osmId, 2); // the station node anchors it
    });

    test('keeps route_ref when present, without depending on it', () {
      final s = parseTransitStations(bodyOf([
        node(1, 48.1, 11.5,
            name: 'A', tags: {'bus': 'yes', 'route_ref': '52;X30'}),
      ]))!;
      expect(s.single.routeRef, '52;X30');
    });

    test('a node with no mode tags is kept with mask 0', () {
      final s = parseTransitStations(bodyOf([
        node(1, 48.1, 11.5,
            name: 'Mystery', tags: {'public_transport': 'platform'}),
      ]))!;
      expect(s, hasLength(1));
      expect(s.single.modeMask, 0);
    });

    test('keepModes drops stations the import never asked for', () {
      final stations = parseTransitStations(
        bodyOf([
          node(1, 48.1000, 11.5000, name: 'Hbf', tags: {'bus': 'yes'}),
          node(2, 48.1002, 11.5001, name: 'Hbf', tags: {'train': 'yes'}),
          node(3, 48.2000, 11.6000, name: 'Bus stop', tags: {'bus': 'yes'}),
          node(4, 48.3000, 11.7000,
              name: 'Mystery', tags: {'public_transport': 'platform'}),
        ]),
        keepModes: bit('train'),
      )!;
      // The merged Hbf survives on its train node and keeps its bus bit —
      // that is what the data says about it.
      expect(stations.map((s) => s.name), ['Hbf']);
      expect(stations.single.modeMask, bit('bus') | bit('train'));
    });

    test('an all-modes import keeps the ones that name no mode', () {
      final stations = parseTransitStations(
        bodyOf([
          node(1, 48.1, 11.5,
              name: 'Mystery', tags: {'public_transport': 'platform'}),
        ]),
        keepModes: transitAllModesMask,
      )!;
      expect(stations.single.modeMask, 0);
    });

    test('an empty area parses to an empty list, NOT to null', () {
      expect(parseTransitStations(bodyOf(const [])), isEmpty);
    });

    test('an unreadable body is null, so it can be reported honestly', () {
      // The old code returned "empty" here and told users nothing was found.
      expect(parseTransitStations('not json'), isNull);
      expect(parseTransitStations('[]'), isNull);
      expect(parseTransitStations('{"elements":"nope"}'), isNull);
    });

    test('never throws on hostile field types', () {
      final body = jsonEncode({
        'elements': [
          {'type': 'node', 'id': 'x', 'lat': 'y', 'lon': null, 'tags': 5},
          {'type': 'way', 'id': 1},
          node(2, 48.1, 11.5, name: 'Fine', tags: {'bus': 'yes'}),
        ]
      });
      final s = parseTransitStations(body)!;
      expect(s, hasLength(1));
      expect(s.single.name, 'Fine');
    });
  });

  group('network contract', () {
    Future<TransitOutcome<List<TransitStationData>>> fetch(http.Client c,
            {String? prefer}) =>
        fetchTransitStations(
          south: 48.1,
          west: 11.5,
          north: 48.2,
          east: 11.6,
          client: c,
          preferEndpoint: prefer,
        );

    test('200 parses and reports which endpoint served it', () async {
      final client = MockClient((_) async =>
          http.Response(bodyOf([node(1, 48.1, 11.5, name: 'A')]), 200));
      final out = await fetch(client);
      expect(out.ok, isTrue);
      expect(out.value!.single.name, 'A');
      expect(out.endpoint, transitEndpoints.first);
    });

    test('a busy instance fails OVER to the next one', () async {
      final tried = <String>[];
      final client = MockClient((req) async {
        tried.add(req.url.toString());
        if (tried.length == 1) return http.Response('busy', 504);
        return http.Response(bodyOf([node(1, 48.1, 11.5, name: 'A')]), 200);
      });
      final out = await fetch(client);
      expect(out.ok, isTrue);
      expect(tried, hasLength(2));
      expect(out.endpoint, transitEndpoints[1]);
    });

    test('a timeout or socket error also fails over', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) throw const SocketException('offline');
        return http.Response(bodyOf([node(1, 48.1, 11.5, name: 'A')]), 200);
      });
      final out = await fetch(client);
      expect(out.ok, isTrue, reason: 'a timeout says nothing about the query');
      expect(calls, 2);
    });

    test('all endpoints busy reports busy, never blames the connection',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('busy', 504);
      });
      final out = await fetch(client);
      expect(out.ok, isFalse);
      expect(calls, transitEndpoints.length);
      expect(out.message, contains('busy'));
      expect(out.message, isNot(contains('connection')));
    });

    test('a query error is reported as-is and does NOT fail over', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('bad query', 400);
      });
      final out = await fetch(client);
      expect(out.ok, isFalse);
      expect(calls, 1);
      expect(out.message, contains('400'));
    });

    test('the preferred endpoint is tried first', () async {
      final tried = <String>[];
      final client = MockClient((req) async {
        tried.add(req.url.toString());
        return http.Response(bodyOf(const []), 200);
      });
      final out = await fetch(client, prefer: transitEndpoints[2]);
      expect(tried.first, transitEndpoints[2]);
      expect(out.endpoint, transitEndpoints[2]);
    });

    test('an unknown preferred endpoint is ignored, not appended', () async {
      final tried = <String>[];
      final client = MockClient((req) async {
        tried.add(req.url.toString());
        return http.Response(bodyOf(const []), 200);
      });
      await fetch(client, prefer: 'https://evil.example/api');
      expect(tried.single, transitEndpoints.first);
    });

    test('an oversized body is refused without decoding', () async {
      final huge = 'x' * (transitMaxResponseBytes + 1);
      final client = MockClient((_) async => http.Response(huge, 200));
      final out = await fetch(client);
      expect(out.ok, isFalse);
      expect(out.message, contains('too much data'));
    });

    test('an unreadable 200 is reported distinctly from an empty area',
        () async {
      final client = MockClient((_) async => http.Response('garbage', 200));
      final out = await fetch(client);
      expect(out.ok, isFalse);
      expect(out.message, contains('could not read'));

      final empty =
          MockClient((_) async => http.Response(bodyOf(const []), 200));
      final ok = await fetch(empty);
      expect(ok.ok, isTrue);
      expect(ok.value, isEmpty);
    });
  });
}
