import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zonecraft/data/geo_import.dart';
import 'package:zonecraft/data/place_search.dart';

void main() {
  group('buildPlaceSearchUri', () {
    test('targets Nominatim with polygon geometry requested', () {
      final uri = buildPlaceSearchUri('Munich, Bavaria');
      expect(uri.host, 'nominatim.openstreetmap.org');
      expect(uri.path, '/search');
      expect(uri.queryParameters['q'], 'Munich, Bavaria');
      expect(uri.queryParameters['polygon_geojson'], '1');
      expect(uri.queryParameters['format'], 'jsonv2');
    });
  });

  group('parsePlaceSearchResponse', () {
    test('extracts a Polygon outer ring (closing vertex dropped) as an area', () {
      const body = '''
      [
        {
          "display_name": "Munich, Bavaria, Germany",
          "category": "boundary",
          "type": "administrative",
          "geojson": {
            "type": "Polygon",
            "coordinates": [[[11.0,48.0],[11.2,48.0],[11.2,48.2],[11.0,48.2],[11.0,48.0]]]
          }
        }
      ]''';
      final results = parsePlaceSearchResponse(body);
      expect(results.length, 1);
      final r = results.first;
      expect(r.shortName, 'Munich');
      expect(r.category, 'boundary');
      expect(r.type, 'administrative');
      expect(r.dominantKind, GeometryKind.area);
      expect(r.areas.length, 1);
      expect(r.areas.first.length, 4); // 5 coords minus the repeated closing one
      expect(r.lines, isEmpty);
      expect(r.pointCount, 4);
    });

    test('splits a MultiPolygon into one ring per part', () {
      const body = '''
      [
        {
          "display_name": "Two Parts",
          "geojson": {
            "type": "MultiPolygon",
            "coordinates": [
              [[[0,0],[1,0],[1,1],[0,0]]],
              [[[5,5],[6,5],[6,6],[5,5]]]
            ]
          }
        }
      ]''';
      final results = parsePlaceSearchResponse(body);
      expect(results.length, 1);
      expect(results.first.areas.length, 2);
    });

    test('keeps a LineString as a line feature (e.g. a river)', () {
      const body = '''
      [
        {
          "display_name": "Isar",
          "category": "waterway",
          "type": "river",
          "geojson": {
            "type": "LineString",
            "coordinates": [[11.5,48.0],[11.6,48.1],[11.7,48.2]]
          }
        }
      ]''';
      final results = parsePlaceSearchResponse(body);
      expect(results.length, 1);
      final r = results.first;
      expect(r.shortName, 'Isar');
      expect(r.type, 'river');
      expect(r.dominantKind, GeometryKind.line);
      expect(r.lines.length, 1);
      expect(r.lines.first.length, 3);
      expect(r.areas, isEmpty);
      expect(r.pointCount, 3);
    });

    test('splits a MultiLineString into one line per part', () {
      const body = '''
      [
        {
          "display_name": "Branchy River",
          "geojson": {
            "type": "MultiLineString",
            "coordinates": [
              [[0,0],[1,1]],
              [[2,2],[3,3],[4,4]]
            ]
          }
        }
      ]''';
      final results = parsePlaceSearchResponse(body);
      expect(results.length, 1);
      expect(results.first.lines.length, 2);
      expect(results.first.dominantKind, GeometryKind.line);
    });

    test('a hit with both line and area is dominated by the area', () {
      const body = '''
      [
        {
          "display_name": "Mixed",
          "geojson": {
            "type": "GeometryCollection",
            "geometries": [
              {"type": "LineString", "coordinates": [[0,0],[1,1]]},
              {"type": "Polygon", "coordinates": [[[5,5],[6,5],[6,6],[5,5]]]}
            ]
          }
        }
      ]''';
      final results = parsePlaceSearchResponse(body);
      expect(results.length, 1);
      expect(results.first.areas, isNotEmpty);
      expect(results.first.lines, isNotEmpty);
      expect(results.first.dominantKind, GeometryKind.area);
    });

    test('drops hits without line or area geometry', () {
      const body = '''
      [
        {"display_name": "A point", "geojson": {"type": "Point", "coordinates": [1,2]}},
        {"display_name": "No geojson"}
      ]''';
      expect(parsePlaceSearchResponse(body), isEmpty);
    });

    test('returns empty on malformed JSON rather than throwing', () {
      expect(parsePlaceSearchResponse('not json'), isEmpty);
      expect(parsePlaceSearchResponse('{"oops":true}'), isEmpty);
    });
  });

  group('searchPlaces caching', () {
    // Nominatim's policy: "Results must be cached on your side", and "clients
    // sending repeatedly the same query may be classified as faulty and
    // blocked". Repeating a search is ordinary behaviour, so this is the
    // difference between normal use and the pattern that gets clients blocked.
    const body = '''
      [{"display_name": "Isar, Bayern",
        "category": "waterway", "type": "river",
        "geojson": {"type": "LineString", "coordinates": [[11.5,48.1],[11.6,48.2]]}}]''';

    setUp(placeSearchCache.clear);

    test('a repeated query is answered without a second request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(body, 200);
      });

      final first = await searchPlaces('Isar', client: client);
      final second = await searchPlaces('Isar', client: client);

      expect(calls, 1, reason: 'the second search must not reach the network');
      expect(first, isNotNull);
      expect(second, same(first));
    });

    test('normalised variants share the cached entry', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(body, 200);
      });

      await searchPlaces('Isar', client: client);
      await searchPlaces('  isar  ', client: client);

      expect(calls, 1);
    });

    test('a failure is not cached as though it were an answer', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('nope', 500)
            : http.Response(body, 200);
      });

      expect(await searchPlaces('Isar', client: client), isNull);
      // A 500 says nothing about the query, so the retry must go out again.
      final retry = await searchPlaces('Isar', client: client);
      expect(calls, 2);
      expect(retry, isNotNull);
      expect(retry, hasLength(1));
    });

    test('an empty result still counts as an answer worth caching', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      });

      expect(await searchPlaces('Nowhere', client: client), isEmpty);
      expect(await searchPlaces('Nowhere', client: client), isEmpty);
      // "Found nothing" is a real answer — asking again would be exactly the
      // repeated-identical-query pattern the policy warns about.
      expect(calls, 1);
    });
  });
}
