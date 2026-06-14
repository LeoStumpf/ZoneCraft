import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zonecraft/data/overpass.dart';

void main() {
  PoiCategory cat(String key) =>
      poiCategories.firstWhere((c) => c.key == key);

  group('category bitmask', () {
    test('mask round-trips through poiMaskWith / poiCategoriesFromMask', () {
      var mask = 0;
      mask = poiMaskWith(mask, cat('bench'), true);
      mask = poiMaskWith(mask, cat('cafe'), true);
      final enabled = poiCategoriesFromMask(mask).map((c) => c.key).toSet();
      expect(enabled, {'bench', 'cafe'});

      mask = poiMaskWith(mask, cat('bench'), false);
      expect(poiCategoriesFromMask(mask).map((c) => c.key), {'cafe'});
    });

    test('every category occupies a distinct single bit', () {
      final bits = poiCategories.map((c) => c.bit).toList();
      expect(bits.toSet().length, bits.length); // unique
      for (final b in bits) {
        expect(b & (b - 1), 0); // exactly one bit set
      }
    });
  });

  group('buildOverpassQuery', () {
    test('includes the bbox and a clause per category', () {
      final q = buildOverpassQuery(
        south: 1,
        west: 2,
        north: 3,
        east: 4,
        categories: [cat('bench'), cat('post_box')],
      );
      expect(q, contains('[out:json]'));
      expect(q, contains('nwr["amenity"="bench"](1.0,2.0,3.0,4.0);'));
      expect(q, contains('nwr["amenity"="post_box"](1.0,2.0,3.0,4.0);'));
      expect(q, contains('out center $overpassResultCap;'));
    });
  });

  group('parseOverpassResponse', () {
    test('parses node lat/lon and way center, tagging by category', () {
      const body = '''
      {"elements":[
        {"type":"node","lat":48.1,"lon":11.5,"tags":{"amenity":"bench"}},
        {"type":"way","center":{"lat":48.2,"lon":11.6},"tags":{"amenity":"cafe"}}
      ]}''';
      final res = parseOverpassResponse(body, [cat('bench'), cat('cafe')]);
      expect(res, hasLength(2));
      expect(res[0].categoryKey, 'bench');
      expect(res[0].lat, 48.1);
      expect(res[1].categoryKey, 'cafe');
      expect(res[1].lat, 48.2);
      expect(res[1].lng, 11.6);
    });

    test('skips elements without a position or a known category', () {
      const body = '''
      {"elements":[
        {"type":"node","tags":{"amenity":"bench"}},
        {"type":"node","lat":48.1,"lon":11.5,"tags":{"amenity":"fountain"}}
      ]}''';
      expect(parseOverpassResponse(body, [cat('bench')]), isEmpty);
    });

    test('returns empty on malformed JSON instead of throwing', () {
      expect(parseOverpassResponse('not json', poiCategories), isEmpty);
      expect(parseOverpassResponse('{"elements":"oops"}', poiCategories),
          isEmpty);
    });

    test('captures the OSM name tag (trimmed), null when absent/blank', () {
      const body = '''
      {"elements":[
        {"type":"node","lat":1,"lon":2,"tags":{"amenity":"cafe","name":"  Tati  "}},
        {"type":"node","lat":3,"lon":4,"tags":{"amenity":"cafe"}},
        {"type":"node","lat":5,"lon":6,"tags":{"amenity":"cafe","name":"   "}}
      ]}''';
      final res = parseOverpassResponse(body, [cat('cafe')]);
      expect(res, hasLength(3));
      expect(res[0].name, 'Tati');
      expect(res[1].name, isNull);
      expect(res[2].name, isNull);
    });
  });

  group('poisWithinRadius', () {
    // ~111 m per 0.001° of latitude near the equator.
    const here = (lat: 0.0, lng: 0.0);
    PoiResult at(double lat, double lng, {String? name}) =>
        PoiResult(lat: lat, lng: lng, categoryKey: 'cafe', name: name);

    test('keeps only within radius, sorted nearest-first', () {
      final pois = [
        at(0.010, 0), // ~1110 m
        at(0.001, 0), // ~111 m
        at(0.005, 0), // ~555 m
      ];
      final res =
          poisWithinRadius(here.lat, here.lng, 600, pois);
      expect(res.map((p) => p.lat), [0.001, 0.005]); // 1110 m dropped
    });

    test('caps the result count', () {
      final pois = [for (var i = 1; i <= 100; i++) at(0.00001 * i, 0)];
      final res = poisWithinRadius(here.lat, here.lng, 1e9, pois, cap: 10);
      expect(res, hasLength(10));
      expect(res.first.lat, closeTo(0.00001, 1e-12)); // nearest kept
    });
  });

  group('fetchPois', () {
    test('returns the parsed list on HTTP 200', () async {
      final client = MockClient((_) async => http.Response(
            '{"elements":[{"type":"node","lat":1,"lon":2,"tags":{"amenity":"bench"}}]}',
            200,
          ));
      final r = await fetchPois(
        south: 0,
        west: 0,
        north: 1,
        east: 1,
        categories: [cat('bench')],
        client: client,
      );
      expect(r, isNotNull);
      expect(r!.single.categoryKey, 'bench');
    });

    test('returns null (not empty) on a non-200, so markers are kept', () async {
      final client = MockClient((_) async => http.Response('slow down', 429));
      final r = await fetchPois(
        south: 0,
        west: 0,
        north: 1,
        east: 1,
        categories: [cat('bench')],
        client: client,
      );
      expect(r, isNull);
    });

    test('short-circuits to empty when no categories are enabled', () async {
      expect(
        await fetchPois(
            south: 0, west: 0, north: 1, east: 1, categories: const []),
        isEmpty,
      );
    });
  });

  group('persistent cache JSON', () {
    test('encode/decode round-trips POI results', () {
      const pois = [
        PoiResult(lat: 48.137, lng: 11.575, categoryKey: 'cafe', name: 'Tati'),
        PoiResult(lat: -33.86, lng: 151.21, categoryKey: 'bench'),
      ];
      final back = decodePoiResults(encodePoiResults(pois));
      expect(back.length, 2);
      expect(back[0].lat, closeTo(48.137, 1e-9));
      expect(back[0].lng, closeTo(11.575, 1e-9));
      expect(back[0].categoryKey, 'cafe');
      expect(back[0].name, 'Tati');
      expect(back[1].categoryKey, 'bench');
      expect(back[1].name, isNull);
    });

    test('decode returns empty on garbage rather than throwing', () {
      expect(decodePoiResults('not json'), isEmpty);
      expect(decodePoiResults('{"oops": true}'), isEmpty);
    });
  });
}
