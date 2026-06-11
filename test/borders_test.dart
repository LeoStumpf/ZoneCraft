import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zonecraft/data/borders.dart';

void main() {
  BorderLevel lvl(String key) =>
      borderLevels.firstWhere((l) => l.key == key);

  group('level bitmask', () {
    test('round-trips through borderMaskWith / borderLevelsFromMask', () {
      var mask = 0;
      mask = borderMaskWith(mask, lvl('country'), true);
      mask = borderMaskWith(mask, lvl('city'), true);
      expect(borderLevelsFromMask(mask).map((l) => l.key).toSet(),
          {'country', 'city'});

      mask = borderMaskWith(mask, lvl('country'), false);
      expect(borderLevelsFromMask(mask).map((l) => l.key), {'city'});
    });

    test('every level has a distinct single bit and unique admin_level', () {
      final bits = borderLevels.map((l) => l.bit).toList();
      expect(bits.toSet().length, bits.length);
      for (final b in bits) {
        expect(b & (b - 1), 0);
      }
      final levels = borderLevels.map((l) => l.adminLevel).toList();
      expect(levels.toSet().length, levels.length);
    });
  });

  group('buildBordersQuery', () {
    test('emits a relation→member-way→convert block per level', () {
      final q = buildBordersQuery(
        south: 1,
        west: 2,
        north: 3,
        east: 4,
        levels: [lvl('country'), lvl('district')],
      );
      expect(q, contains('[out:json]'));
      // Country (admin_level 2) block.
      expect(q, contains('["admin_level"="2"](1.0,2.0,3.0,4.0);'));
      // District (admin_level 9) block.
      expect(q, contains('["admin_level"="9"](1.0,2.0,3.0,4.0);'));
      expect(q, contains('way(r)(1.0,2.0,3.0,4.0);'));
      expect(q, contains('convert way ::id=id(),::geom=geom(),lvl="2";'));
      expect(q, contains('convert way ::id=id(),::geom=geom(),lvl="9";'));
    });
  });

  group('parseBordersResponse', () {
    test('parses GeoJSON LineString from convert, coloured by lvl tag', () {
      // convert ::geom=geom() emits GeoJSON: coordinates are [lon, lat].
      const body = '''
      {"elements":[
        {"type":"way","tags":{"lvl":"2"},
         "geometry":{"type":"LineString","coordinates":[[11.0,48.0],[11.1,48.1]]}},
        {"type":"way","tags":{"lvl":"9"},
         "geometry":{"type":"LineString","coordinates":[[11.2,48.2],[11.3,48.3],[11.4,48.4]]}}
      ]}''';
      final res =
          parseBordersResponse(body, [lvl('country'), lvl('district')]);
      expect(res, hasLength(2));
      expect(res[0].colorArgb, lvl('country').colorArgb);
      expect(res[0].points, hasLength(2));
      expect(res[0].points.first.latitude, 48.0);
      expect(res[0].points.first.longitude, 11.0);
      expect(res[1].colorArgb, lvl('district').colorArgb);
      expect(res[1].points, hasLength(3));
    });

    test('also accepts the plain out-geom array shape', () {
      const body = '''
      {"elements":[
        {"type":"way","tags":{"lvl":"2"},"geometry":[
          {"lat":48.0,"lon":11.0},{"lat":48.1,"lon":11.1}]}
      ]}''';
      final res = parseBordersResponse(body, [lvl('country')]);
      expect(res.single.points, hasLength(2));
      expect(res.single.points.first.latitude, 48.0);
    });

    test('skips single-point geometries and unknown levels', () {
      const body = '''
      {"elements":[
        {"type":"way","tags":{"lvl":"2"},
         "geometry":{"type":"LineString","coordinates":[[2.0,1.0]]}},
        {"type":"way","tags":{"lvl":"6"},
         "geometry":{"type":"LineString","coordinates":[[2.0,1.0],[4.0,3.0]]}}
      ]}''';
      // Only the country level is enabled, so the lvl="6" way is dropped, and
      // the lvl="2" way has too few points.
      expect(parseBordersResponse(body, [lvl('country')]), isEmpty);
    });

    test('returns empty on malformed JSON instead of throwing', () {
      expect(parseBordersResponse('nope', borderLevels), isEmpty);
    });
  });

  group('fetchBorders', () {
    test('returns parsed lines on HTTP 200', () async {
      final client = MockClient((_) async => http.Response(
            '{"elements":[{"type":"way","tags":{"lvl":"2"},"geometry":{"type":"LineString","coordinates":[[2,1],[4,3]]}}]}',
            200,
          ));
      final r = await fetchBorders(
        south: 0,
        west: 0,
        north: 1,
        east: 1,
        levels: [lvl('country')],
        client: client,
      );
      expect(r, isNotNull);
      expect(r!.single.colorArgb, lvl('country').colorArgb);
    });

    test('returns null on a non-200 so borders are kept', () async {
      final client = MockClient((_) async => http.Response('busy', 504));
      final r = await fetchBorders(
        south: 0,
        west: 0,
        north: 1,
        east: 1,
        levels: [lvl('country')],
        client: client,
      );
      expect(r, isNull);
    });
  });
}
