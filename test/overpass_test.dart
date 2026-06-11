import 'package:flutter_test/flutter_test.dart';
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
  });
}
