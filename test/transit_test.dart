import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/transit.dart';

/// A relation element as `out geom` returns it.
Map<String, dynamic> relation({
  int id = 1,
  String route = 'tram',
  String? ref = '19',
  String? name = 'Tram 19',
  String? colour,
  List<Map<String, dynamic>> members = const [],
}) =>
    {
      'type': 'relation',
      'id': id,
      'tags': {
        'type': 'route',
        'route': route,
        'ref': ?ref,
        'name': ?name,
        'colour': ?colour,
      },
      'members': members,
    };

Map<String, dynamic> wayMember(List<dynamic> geometry, {String role = ''}) =>
    {'type': 'way', 'ref': 99, 'role': role, 'geometry': geometry};

Map<String, dynamic> nodeMember(int ref, {String role = 'stop'}) =>
    {'type': 'node', 'ref': ref, 'role': role};

Map<String, dynamic> pt(double lat, double lon) => {'lat': lat, 'lon': lon};

Map<String, dynamic> nodeElement(int id, double lat, double lon,
        {String? name}) =>
    {
      'type': 'node',
      'id': id,
      'lat': lat,
      'lon': lon,
      'tags': ?(name == null ? null : {'name': name}),
    };

String bodyOf(List<Map<String, dynamic>> elements) =>
    jsonEncode({'elements': elements});

// A small box around the fixture coordinates.
TransitFetchResult parse(String body) => parseTransitResponse(
      body,
      south: 48.0,
      west: 11.0,
      north: 49.0,
      east: 12.0,
    );

void main() {
  group('mode catalogue', () {
    test('bits are distinct single bits', () {
      final seen = <int>{};
      for (final m in transitModes) {
        expect(m.bit & (m.bit - 1), 0, reason: '${m.key} is not a single bit');
        expect(seen.add(m.bit), isTrue, reason: '${m.key} reuses a bit');
      }
    });

    test('no route= value belongs to two modes', () {
      final seen = <String>{};
      for (final m in transitModes) {
        for (final v in m.routeValues) {
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
      expect(transitMaskOf([bus, tram]), bus.bit | tram.bit);
      expect(transitModesFromMask(0), isEmpty);
    });
  });

  group('parseOsmColour', () {
    test('accepts the hex forms', () {
      expect(parseOsmColour('#FF0000'), 0xFFFF0000);
      expect(parseOsmColour('ff0000'), 0xFFFF0000);
      expect(parseOsmColour('#f00'), 0xFFFF0000);
      expect(parseOsmColour('  #DC281E '), 0xFFDC281E);
    });

    test('accepts the colour names OSM actually uses', () {
      expect(parseOsmColour('red'), 0xFFFF0000);
      expect(parseOsmColour('Blue'), 0xFF0000FF);
      expect(parseOsmColour('gray'), parseOsmColour('grey'));
    });

    test('rejects anything it cannot draw', () {
      expect(parseOsmColour(null), isNull);
      expect(parseOsmColour(''), isNull);
      expect(parseOsmColour('rgb(1,2,3)'), isNull);
      expect(parseOsmColour('blau'), isNull);
      expect(parseOsmColour('#ff00'), isNull);
      expect(parseOsmColour('#gggggg'), isNull);
    });

    test('darkens near-white so the line stays visible', () {
      final white = parseOsmColour('#FFFFFF')!;
      expect(white, isNot(0xFFFFFFFF));
      expect((white >> 16) & 0xFF, lessThan(0xFF));
      // A mid colour is untouched.
      expect(parseOsmColour('#DC281E'), 0xFFDC281E);
    });
  });

  group('encodeLatLngs / decodeLatLngs', () {
    test('round-trips', () {
      final pts = [const LatLng(48.1, 11.5), const LatLng(48.2, 11.6)];
      final back = decodeLatLngs(encodeLatLngs(pts));
      expect(back.length, 2);
      expect(back.first.latitude, closeTo(48.1, 1e-9));
      expect(back.last.longitude, closeTo(11.6, 1e-9));
    });

    test('never throws on garbage', () {
      expect(decodeLatLngs('not json'), isEmpty);
      expect(decodeLatLngs('{"a":1}'), isEmpty);
      expect(decodeLatLngs('[[1],["x","y"],[48.1,11.5]]'), hasLength(1));
    });
  });

  group('query builders', () {
    test('the pre-flight asks for tags only, with the bbox and a cap', () {
      final q = buildTransitCountQuery(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        modes: [transitModes[1], transitModes[2]], // tram, subway
      );
      expect(q, contains('["route"~"^(tram|subway)\$"]'));
      expect(q, contains('(48.1,11.5,48.2,11.6)'));
      expect(q, contains('out tags qt $transitPreflightCap;'));
      // Overpass verbosity levels are mutually exclusive.
      expect(q, isNot(contains('out ids tags')));
      expect(q, isNot(contains('geom')));
    });

    test('the geometry query clips ways but not the node recursion', () {
      final q = buildTransitGeomQuery(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        osmIds: [11, 22],
      );
      expect(q, contains('rel(id:11,22)->.r;'));
      expect(q, contains('.r out geom(48.1,11.5,48.2,11.6);'));
      // Bbox-filtering the recursed node set 504s on the public instance.
      expect(q, contains('node(r.r);'));
      expect(q, isNot(contains('node(r.r)(')));
      expect(q, contains('out body qt;'));
    });
  });

  group('parseTransitCounts', () {
    test('reads identity and tags, dropping unknown route values', () {
      final body = bodyOf([
        relation(id: 7, route: 'tram', ref: '19', colour: '#DC281E'),
        relation(id: 8, route: 'hiking', ref: 'E5'),
      ]);
      final heads = parseTransitCounts(body);
      expect(heads, hasLength(1));
      expect(heads.single.osmId, 7);
      expect(heads.single.modeKey, 'tram');
      expect(heads.single.ref, '19');
      expect(heads.single.colorArgb, 0xFFDC281E);
    });

    test('accepts the "color" misspelling', () {
      final body = jsonEncode({
        'elements': [
          {
            'type': 'relation',
            'id': 1,
            'tags': {'route': 'bus', 'color': '#00FF00'},
          }
        ]
      });
      expect(parseTransitCounts(body).single.colorArgb, 0xFF00FF00);
    });

    test('never throws', () {
      expect(parseTransitCounts('nonsense'), isEmpty);
      expect(parseTransitCounts('[]'), isEmpty);
      expect(parseTransitCounts('{"elements":"no"}'), isEmpty);
    });
  });

  group('wayRuns', () {
    test('a whole way is one run', () {
      final runs = wayRuns([pt(48.1, 11.5), pt(48.2, 11.5), pt(48.3, 11.5)]);
      expect(runs, hasLength(1));
      expect(runs.single, hasLength(3));
    });

    test('nulls from out geom(bbox) SPLIT the way, never join across', () {
      // [in, in, out, out, in, in] — two separate runs, not one straight jump.
      final runs = wayRuns([
        pt(48.1, 11.5),
        pt(48.2, 11.5),
        null,
        null,
        pt(48.8, 11.5),
        pt(48.9, 11.5),
      ]);
      expect(runs, hasLength(2));
      expect(runs[0].last.latitude, closeTo(48.2, 1e-9));
      expect(runs[1].first.latitude, closeTo(48.8, 1e-9));
    });

    test('single-point runs are dropped', () {
      expect(wayRuns([pt(48.1, 11.5), null, pt(48.9, 11.5)]), isEmpty);
    });

    test('the GeoJSON [lon,lat] shape is rejected, not silently swapped', () {
      // `convert ::geom=geom()` produces this; transit never uses convert, and
      // a swap would be invisible until the map is wrong.
      final runs = wayRuns({
        'coordinates': [
          [11.5, 48.1],
          [11.6, 48.2],
        ]
      });
      expect(runs, isEmpty);
    });

    test('never throws on junk', () {
      expect(wayRuns(null), isEmpty);
      expect(wayRuns('x'), isEmpty);
      expect(wayRuns([1, 2, 3]), isEmpty);
    });
  });

  group('parseTransitResponse', () {
    test('contiguous member ways stitch into one part', () {
      final body = bodyOf([
        relation(members: [
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
          wayMember([pt(48.11, 11.50), pt(48.12, 11.50)]),
        ]),
      ]);
      final r = parse(body).routes.single;
      expect(r.parts, hasLength(1));
      expect(r.head.modeKey, 'tram');
    });

    test('a reversed member still stitches into one part', () {
      final body = bodyOf([
        relation(members: [
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
          // Same shared node, drawn the other way round.
          wayMember([pt(48.12, 11.50), pt(48.11, 11.50)]),
        ]),
      ]);
      expect(parse(body).routes.single.parts, hasLength(1));
    });

    test('a disconnected member is KEPT as a second part', () {
      // stitchPolylines would have discarded this branch entirely.
      final body = bodyOf([
        relation(members: [
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
          wayMember([pt(48.80, 11.90), pt(48.81, 11.90)]),
        ]),
      ]);
      expect(parse(body).routes.single.parts, hasLength(2));
    });

    test('a member with no geometry is skipped', () {
      final body = bodyOf([
        relation(members: [
          {'type': 'way', 'ref': 1, 'role': ''}, // entirely outside the box
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
        ]),
      ]);
      expect(parse(body).routes.single.parts, hasLength(1));
    });

    test('platform ways are not part of the line', () {
      final body = bodyOf([
        relation(members: [
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
          wayMember([pt(48.50, 11.50), pt(48.51, 11.50)], role: 'platform'),
        ]),
      ]);
      expect(parse(body).routes.single.parts, hasLength(1));
    });

    test('stops come from the node pass, in member order', () {
      final body = bodyOf([
        relation(members: [
          nodeMember(101),
          nodeMember(102),
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
        ]),
        nodeElement(101, 48.10, 11.50, name: 'Alpha'),
        nodeElement(102, 48.11, 11.50, name: 'Beta'),
      ]);
      final res = parse(body);
      expect(res.routes.single.stopOsmIds, [101, 102]);
      expect(res.stops.map((s) => s.name), containsAll(['Alpha', 'Beta']));
    });

    test('falls back to platform roles for PTv1 data', () {
      final body = bodyOf([
        relation(members: [
          nodeMember(101, role: 'platform'),
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
        ]),
        nodeElement(101, 48.10, 11.50, name: 'Alpha'),
      ]);
      expect(parse(body).routes.single.stopOsmIds, [101]);
    });

    test('stops outside the box are clipped (the recursion is unfiltered)', () {
      final body = bodyOf([
        relation(members: [
          nodeMember(101),
          nodeMember(102),
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
        ]),
        nodeElement(101, 48.10, 11.50, name: 'Inside'),
        nodeElement(102, 51.00, 11.50, name: 'Far away'),
      ]);
      final res = parse(body);
      expect(res.routes.single.stopOsmIds, [101]);
      expect(res.stops.map((s) => s.name), ['Inside']);
    });

    test('stops are deduped across routes that share them', () {
      final body = bodyOf([
        relation(id: 1, members: [
          nodeMember(101),
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
        ]),
        relation(id: 2, ref: '20', members: [
          nodeMember(101),
          wayMember([pt(48.20, 11.50), pt(48.21, 11.50)]),
        ]),
        nodeElement(101, 48.10, 11.50, name: 'Shared'),
      ]);
      final res = parse(body);
      expect(res.routes, hasLength(2));
      expect(res.stops, hasLength(1));
    });

    test('a relation with an unknown route= is dropped', () {
      final body = bodyOf([
        relation(route: 'hiking', members: [
          wayMember([pt(48.10, 11.50), pt(48.11, 11.50)]),
        ]),
      ]);
      expect(parse(body).routes, isEmpty);
    });

    test('a route with nothing in the box is dropped', () {
      expect(parse(bodyOf([relation(members: const [])])).routes, isEmpty);
    });

    test('the point cap truncates and flags the route', () {
      final many = [
        for (var i = 0; i < transitPointCap + 500; i++)
          pt(48.0 + i * 0.001, 11.5),
      ];
      final body = bodyOf([
        relation(members: [wayMember(many)]),
      ]);
      final r = parse(body).routes.single;
      expect(r.pointCount, lessThanOrEqualTo(transitPointCap));
    });

    test('never throws', () {
      expect(parse('nonsense').routes, isEmpty);
      expect(parse('{"elements":{}}').routes, isEmpty);
    });
  });

  group('network contract', () {
    test('200 parses', () async {
      final client = MockClient((_) async => http.Response(
            bodyOf([relation(id: 3)]),
            200,
          ));
      final outcome = await countTransitRoutes(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        modes: transitModes,
        client: client,
      );
      expect(outcome.ok, isTrue);
      expect(outcome.value!.single.osmId, 3);
    });

    test('a busy server is reported as busy, and retried once', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('busy', 504);
      });
      final outcome = await countTransitRoutes(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        modes: transitModes,
        client: client,
      );
      expect(outcome.ok, isFalse);
      // A 504 answer to a valid query is routine on the public instance, so it
      // earns exactly one polite retry — and must not blame the connection.
      expect(calls, 2);
      expect(outcome.message, contains('busy'));
      expect(outcome.message, isNot(contains('connection')));
    });

    test('a retried request that then succeeds is a success', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('busy', 503)
            : http.Response(bodyOf([relation(id: 5)]), 200);
      });
      final outcome = await countTransitRoutes(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        modes: transitModes,
        client: client,
      );
      expect(outcome.ok, isTrue);
      expect(outcome.value!.single.osmId, 5);
    });

    test('a query error is NOT retried', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('bad query', 400);
      });
      final outcome = await countTransitRoutes(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        modes: transitModes,
        client: client,
      );
      expect(outcome.ok, isFalse);
      expect(calls, 1);
      expect(outcome.message, contains('400'));
    });

    test('a network failure is null, and never throws out', () async {
      final client = MockClient((_) async {
        throw const SocketException('offline');
      });
      final res = await fetchTransitRoutes(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        osmIds: const [1],
        client: client,
      );
      expect(res.ok, isFalse);
      expect(res.message, contains('connection'));
    });

    test('an oversized body is refused without decoding', () async {
      final huge = 'x' * (transitMaxResponseBytes + 1);
      final client = MockClient((_) async => http.Response(huge, 200));
      final res = await fetchTransitRoutes(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        osmIds: const [1],
        client: client,
      );
      expect(res.ok, isFalse);
      expect(res.message, contains('too much data'));
    });

    test('no ids means no request at all', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final res = await fetchTransitRoutes(
        south: 48.1,
        west: 11.5,
        north: 48.2,
        east: 11.6,
        osmIds: const [],
        client: client,
      );
      expect(called, isFalse);
      expect(res.value!.isEmpty, isTrue);
    });
  });
}
