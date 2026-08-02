import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zonecraft/data/borders.dart';
import 'package:zonecraft/data/overpass_client.dart';

void main() {
  BorderLevel lvl(String key) => borderLevels.firstWhere((l) => l.key == key);

  group('level catalogue', () {
    test('keys, labels and admin levels are unique', () {
      for (final f in [
        borderLevels.map((l) => l.key),
        borderLevels.map((l) => l.label),
        borderLevels.map((l) => l.adminLevel),
      ]) {
        expect(f.toSet().length, borderLevels.length);
      }
    });

    test('lookup by admin level and by key round-trips', () {
      for (final l in borderLevels) {
        expect(borderLevelByAdminLevel(l.adminLevel)?.key, l.key);
        expect(borderLevelByKey(l.key)?.adminLevel, l.adminLevel);
      }
      expect(borderLevelByAdminLevel(null), isNull);
      expect(borderLevelByAdminLevel('7'), isNull);
      expect(borderLevelByKey('nope'), isNull);
    });

    test('every level carries a usable cap, warning at half of it', () {
      for (final l in borderLevels) {
        expect(l.maxDiagonalMeters, greaterThan(0));
        expect(l.warnDiagonalMeters, l.maxDiagonalMeters / 2);
        expect(l.blurb, isNotEmpty);
      }
    });

    test('the caps reflect what was measured, not the level ordering', () {
      // Countries are the *most* expensive despite being the coarsest: any box
      // touching a national border downloads whole countries (17.3 MB).
      expect(lvl('country').maxDiagonalMeters,
          lessThan(lvl('state').maxDiagonalMeters));
      // Suburbs were unobtainable in Munich, so they are capped tightly too.
      expect(lvl('suburb').maxDiagonalMeters,
          lessThan(lvl('city').maxDiagonalMeters));
    });
  });

  group('buildBorderAreasQuery', () {
    test('asks for whole relations at one level, with geometry', () {
      final q = buildBorderAreasQuery(
        south: 1,
        west: 2,
        north: 3,
        east: 4,
        adminLevel: '8',
      );
      expect(q, contains('[out:json]'));
      expect(q, contains('rel["boundary"="administrative"]'));
      expect(q, contains('["admin_level"="8"](1.0,2.0,3.0,4.0);'));
      expect(q, contains('out geom;'));
      // The old shape is what could only ever draw lines — never come back.
      expect(q, isNot(contains('way(r)')));
      expect(q, isNot(contains('convert')));
    });

    test('one level per query — a layer holds exactly one', () {
      final q = buildBorderAreasQuery(
          south: 1, west: 2, north: 3, east: 4, adminLevel: '4');
      expect('"admin_level"'.allMatches(q).length, 1);
    });
  });

  group('parseBorderRelations', () {
    String body(String members) => '''
      {"elements":[
        {"type":"relation","id":42,"tags":{"name":"München"},
         "members":[$members]}
      ]}''';

    const wayA = '{"type":"way","ref":100,"role":"outer","geometry":'
        '[{"lat":48.0,"lon":11.0},{"lat":48.0,"lon":11.1}]}';

    test('reads the relation, its name and its member ways', () {
      final res = parseBorderRelations(body(wayA));
      expect(res, hasLength(1));
      final rel = res!.single;
      expect(rel.osmId, 42);
      expect(rel.name, 'München');
      expect(rel.ways, hasLength(1));
      expect(rel.ways.single.id, 100);
      expect(rel.ways.single.role, 'outer');
      expect(rel.ways.single.points.first.latitude, 48.0);
      expect(rel.wayIds, [100]);
    });

    test('also accepts the GeoJSON LineString shape', () {
      const way = '{"type":"way","ref":7,"role":"inner","geometry":'
          '{"type":"LineString","coordinates":[[11.0,48.0],[11.2,48.2]]}}';
      final rel = parseBorderRelations(body(way))!.single;
      expect(rel.ways.single.role, 'inner');
      // GeoJSON is [lon, lat] — the swap is the classic way to get this wrong.
      expect(rel.ways.single.points.first.latitude, 48.0);
      expect(rel.ways.single.points.first.longitude, 11.0);
    });

    test('skips non-way members and degenerate geometry', () {
      const junk = '{"type":"node","ref":5,"role":"admin_centre"},'
          '{"type":"way","ref":6,"role":"outer","geometry":'
          '[{"lat":48.0,"lon":11.0}]}';
      // Only junk left, so the whole relation goes: nothing to draw or name.
      expect(parseBorderRelations(body(junk)), isEmpty);
      // With one good way alongside, the relation survives with just that way.
      final rel = parseBorderRelations(body('$junk,$wayA'))!.single;
      expect(rel.ways, hasLength(1));
      expect(rel.ways.single.id, 100);
    });

    test('an empty area parses to an empty list, NOT to null', () {
      expect(parseBorderRelations('{"elements":[]}'), isEmpty);
    });

    test('an unreadable body is null, so it can be reported honestly', () {
      expect(parseBorderRelations('nope'), isNull);
      expect(parseBorderRelations('[]'), isNull);
      expect(parseBorderRelations('{"elements":{}}'), isNull);
    });

    test('never throws on hostile field types', () {
      const hostile = '''
      {"elements":[
        {"type":"relation","id":"not a number","members":[]},
        {"type":"relation","id":1,"tags":"not a map","members":"not a list"},
        {"type":"relation","id":2,"tags":{"name":42},"members":[
          {"type":"way","ref":null,"geometry":[]},
          {"type":"way","ref":3,"geometry":[{"lat":"x","lon":"y"},
                                            {"lat":1,"lon":2},
                                            {"lat":3,"lon":4}]}
        ]}
      ]}''';
      final res = parseBorderRelations(hostile);
      expect(res, hasLength(1));
      expect(res!.single.osmId, 2);
      expect(res.single.name, isNull, reason: 'a non-string name is no name');
      // The unparseable point is dropped; the two good ones survive.
      expect(res.single.ways.single.points, hasLength(2));
      expect(res.single.ways.single.role, '', reason: 'missing role is empty');
    });
  });

  group('network contract', () {
    const ok = '{"elements":[{"type":"relation","id":1,"members":['
        '{"type":"way","ref":1,"role":"outer","geometry":'
        '[{"lat":0,"lon":0},{"lat":1,"lon":1}]}]}]}';

    Future<OverpassOutcome<List<BorderRelationData>>> fetch(http.Client c) =>
        fetchBorderAreas(
          south: 0,
          west: 0,
          north: 1,
          east: 1,
          adminLevel: '8',
          client: c,
        );

    test('200 parses and reports which endpoint served it', () async {
      final out = await fetch(MockClient((_) async => http.Response(ok, 200)));
      expect(out.ok, isTrue);
      expect(out.value!.single.osmId, 1);
      expect(out.endpoint, overpassEndpoints.first);
    });

    test('a busy instance is asked again before we fail over', () async {
      // The level-9 failure that prompted this: overpass-api.de rejects roughly
      // one ask in three in ~8 s, then answers. Failing straight over sent the
      // import to a 160 s instance and then a dead one.
      var calls = 0;
      final out = await fetch(MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('busy', 504)
            : http.Response(ok, 200);
      }));
      expect(out.ok, isTrue);
      expect(out.endpoint, overpassEndpoints.first);
    });

    test('a query error is reported as-is and does NOT fail over', () async {
      var calls = 0;
      final out = await fetch(MockClient((_) async {
        calls++;
        return http.Response('bad query', 400);
      }));
      expect(out.ok, isFalse);
      expect(out.message, contains('400'));
      expect(calls, 1);
    });

    test('an oversized body is refused with advice, not decoded', () async {
      final huge = 'x' * (borderMaxResponseBytes + 1);
      final out = await fetch(MockClient((_) async => http.Response(huge, 200)));
      expect(out.ok, isFalse);
      expect(out.message, contains('smaller box'));
    });

    test('an unreadable 200 is distinguished from an empty area', () async {
      final out =
          await fetch(MockClient((_) async => http.Response('nope', 200)));
      expect(out.ok, isFalse);
      expect(out.message, contains('could not read'));
    });
  });
}
