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

    test('a borders layer keeps its level and toggles through GeoJSON', () {
      final data = ExportData([
        const ExportLayer(
          name: 'Districts',
          colorArgb: 0xFF00FF00,
          type: 'borders',
          isInverted: false,
          opacity: 0.7,
          borderLevel: '9',
          borderFillAreas: true,
          borderShowNames: false,
          objects: [
            ExportObject(
              kind: 'borderarea',
              coords: [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
              rings: [
                [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
              ],
              label: 'Maxvorstadt',
              osmId: 42,
              adminLevel: '9',
              bbox: [0, 0, 1, 1],
              colorIndex: 3,
              labelLat: 0.4,
              labelLng: 0.4,
              wayIds: [7, 8],
            ),
          ],
        ),
      ]);
      final back = importFromGeoJson(exportToGeoJson(data))!;
      final l = back.layers.single;
      expect(l.type, 'borders');
      expect(l.opacity, 0.7);
      expect(l.borderLevel, '9');
      expect(l.borderFillAreas, isTrue);
      expect(l.borderShowNames, isFalse);
      final o = l.objects.single;
      expect(o.kind, 'borderarea');
      expect(o.osmId, 42);
      expect(o.adminLevel, '9');
      expect(o.bbox, [0.0, 0.0, 1.0, 1.0]);
      expect(o.colorIndex, 3);
      expect(o.labelLat, 0.4);
      expect(o.wayIds, [7, 8]);
      expect(o.rings, hasLength(1));
      expect(o.rings!.single, hasLength(3), reason: 'the closing vertex is dropped');
    });

    test('a reshaped outline travels as edited, an untouched one silently', () {
      // A shared file must not launder a hand-edited boundary into "what OSM
      // says" on the receiving device — where re-import dedup then keeps this
      // version, which is exactly where it would matter.
      ExportData dataWith(bool? edited) => ExportData([
            ExportLayer(
              name: 'Districts',
              colorArgb: 0xFF00FF00,
              type: 'borders',
              isInverted: false,
              borderLevel: '9',
              objects: [
                ExportObject(
                  kind: 'borderarea',
                  coords: const [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
                  rings: const [
                    [LatLng(0, 0), LatLng(0, 1), LatLng(1, 1)],
                  ],
                  osmId: 42,
                  edited: edited,
                ),
              ],
            ),
          ]);

      final json = exportToGeoJson(dataWith(true));
      expect(json, contains('"edited"'));
      expect(
        importFromGeoJson(json)!.layers.single.objects.single.edited,
        isTrue,
      );

      // Untouched geometry says nothing at all, rather than "edited: false" —
      // absence is what every pre-v23 file carries, so the two must agree.
      final plain = exportToGeoJson(dataWith(null));
      expect(plain, isNot(contains('"edited"')));
      expect(
        importFromGeoJson(plain)!.layers.single.objects.single.edited,
        isNull,
      );
    });

    test('a hole and an exclave survive as separate rings', () {
      const outer = [LatLng(0, 0), LatLng(0, 10), LatLng(10, 10), LatLng(10, 0)];
      const hole = [LatLng(2, 2), LatLng(2, 4), LatLng(4, 4), LatLng(4, 2)];
      const exclave =
          [LatLng(20, 20), LatLng(20, 21), LatLng(21, 21), LatLng(21, 20)];
      final data = ExportData([
        const ExportLayer(
          name: 'B',
          colorArgb: 0xFF000000,
          type: 'borders',
          isInverted: false,
          borderLevel: '8',
          objects: [
            ExportObject(
              kind: 'borderarea',
              coords: outer,
              rings: [outer, hole, exclave],
              osmId: 1,
            ),
          ],
        ),
      ]);
      final json = exportToGeoJson(data);
      // GeoJSON has to say which ring is a hole; the stored form does not.
      expect(json, contains('MultiPolygon'));
      final rings = importFromGeoJson(json)!.layers.single.objects.single.rings!;
      expect(rings, hasLength(3));
      expect(rings[0], outer);
      expect(rings[1], hole);
      expect(rings[2], exclave);
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
