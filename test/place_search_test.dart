import 'package:flutter_test/flutter_test.dart';
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
    test('extracts a Polygon outer ring (closing vertex dropped)', () {
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
      expect(r.rings.length, 1);
      expect(r.rings.first.length, 4); // 5 coords minus the repeated closing one
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
      expect(results.first.rings.length, 2);
    });

    test('drops hits without polygon geometry', () {
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
}
