import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/data/serialization.dart';

void main() {
  ExportData sample() => ExportData([
        ExportLayer(
          name: 'Circles',
          colorArgb: 0xFF2196F3,
          type: 'circles',
          isInverted: false,
          objects: const [
            ExportObject(
              kind: 'circle',
              coords: [LatLng(52.5, 13.4)],
              radiusMeters: 1500,
              label: 'home',
            ),
          ],
        ),
        ExportLayer(
          name: 'Planes',
          colorArgb: 0xFFEF5350,
          type: 'planes',
          isInverted: true,
          objects: const [
            ExportObject(
              kind: 'plane',
              coords: [LatLng(52.4, 13.3), LatLng(52.6, 13.5)],
              nearA: false,
            ),
          ],
        ),
        ExportLayer(
          name: 'Subspaces',
          colorArgb: 0xFF66BB6A,
          type: 'subspace',
          isInverted: false,
          objects: const [
            ExportObject(
              kind: 'subspace',
              coords: [LatLng(0, 0), LatLng(0, 1), LatLng(1, 0)],
              mainIndex: 2,
            ),
          ],
        ),
        ExportLayer(
          name: 'Lines',
          colorArgb: 0xFFAB47BC,
          type: 'freeline',
          isInverted: false,
          objects: const [
            ExportObject(
              kind: 'freeline',
              coords: [LatLng(10, 10), LatLng(11, 11), LatLng(12, 10)],
              offsetMeters: -250,
            ),
          ],
        ),
        ExportLayer(
          name: 'Areas',
          colorArgb: 0xFFFFA726,
          type: 'freearea',
          isInverted: false,
          objects: const [
            ExportObject(
              kind: 'freearea',
              coords: [LatLng(0, 0), LatLng(0, 2), LatLng(2, 2), LatLng(2, 0)],
              offsetMeters: 300,
            ),
          ],
        ),
        ExportLayer(
          name: 'POIs',
          colorArgb: 0xFF00ACC1,
          type: 'poi',
          isInverted: false,
          objects: const [
            ExportObject(
              kind: 'poi',
              // coords[0] = search centre, then the POIs themselves.
              coords: [LatLng(48.1, 11.5), LatLng(48.11, 11.51), LatLng(48.09, 11.49)],
              radiusMeters: 2000,
              categoryKey: 'cafe',
              pointLabels: ['Café A', null],
              label: 'Cafés',
            ),
          ],
        ),
      ]);

  void expectSameObject(ExportObject a, ExportObject b) {
    expect(b.kind, a.kind);
    expect(b.label, a.label);
    expect(b.radiusMeters, a.radiusMeters);
    expect(b.nearA, a.nearA);
    expect(b.offsetMeters, a.offsetMeters);
    expect(b.mainIndex, a.mainIndex);
    expect(b.categoryKey, a.categoryKey);
    expect(b.pointLabels, a.pointLabels);
    expect(b.coords.length, a.coords.length);
    for (var i = 0; i < a.coords.length; i++) {
      expect(b.coords[i].latitude, closeTo(a.coords[i].latitude, 1e-9));
      expect(b.coords[i].longitude, closeTo(a.coords[i].longitude, 1e-9));
    }
  }

  group('GeoJSON round-trip', () {
    test('preserves every layer and object attribute', () {
      final original = sample();
      final restored = importFromGeoJson(exportToGeoJson(original));
      expect(restored, isNotNull);
      expect(restored!.layers.length, original.layers.length);
      for (var li = 0; li < original.layers.length; li++) {
        final a = original.layers[li];
        final b = restored.layers[li];
        expect(b.name, a.name);
        expect(b.colorArgb, a.colorArgb);
        expect(b.type, a.type);
        expect(b.isInverted, a.isInverted);
        expect(b.objects.length, a.objects.length);
        for (var oi = 0; oi < a.objects.length; oi++) {
          expectSameObject(a.objects[oi], b.objects[oi]);
        }
      }
    });

    test('the document is a valid GeoJSON FeatureCollection', () {
      final text = exportToGeoJson(sample());
      expect(text, contains('"type": "FeatureCollection"'));
      expect(text, contains('"type": "Feature"'));
      expect(text, contains('"zonecraftLayer"'));
    });
  });

  group('importFromGeoJson rejection', () {
    test('returns null for non-JSON', () {
      expect(importFromGeoJson('not json at all'), isNull);
    });

    test('returns null for foreign GeoJSON without the zonecraft extension', () {
      const foreign =
          '{"type":"FeatureCollection","features":[{"type":"Feature",'
          '"geometry":{"type":"Point","coordinates":[1,2]},"properties":{}}]}';
      expect(importFromGeoJson(foreign), isNull);
    });
  });

  group('KML export', () {
    test('wraps each layer in a folder and emits geometry', () {
      final kml = exportToKml(sample());
      expect(kml, startsWith('<?xml'));
      expect(kml, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
      expect('<Folder>'.allMatches(kml).length, 6); // one per layer
      expect(kml, contains('<Polygon>')); // circle ring + freearea
      expect(kml, contains('<LineString>')); // plane + freeline
      expect(kml, contains('<MultiGeometry>')); // subspace seed points
      // POIs: one named Placemark per stored point (centre is skipped).
      expect(kml, contains('<name>Café A</name>'));
      expect(kml, isNot(contains('11.5,48.1,0'))); // the search centre
    });

    test('escapes XML-special characters in names', () {
      final data = ExportData([
        const ExportLayer(
          name: 'A & B <test>',
          colorArgb: 0xFF000000,
          type: 'circles',
          isInverted: false,
          objects: [
            ExportObject(
                kind: 'circle', coords: [LatLng(0, 0)], radiusMeters: 100),
          ],
        ),
      ]);
      final kml = exportToKml(data);
      expect(kml, contains('A &amp; B &lt;test&gt;'));
    });
  });
}
