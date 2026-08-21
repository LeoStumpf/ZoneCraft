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
              pointLabels: ['west', null, 'mine'],
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
              // The circle that bounds the line to a half-disk: stored per
              // line, and silently absent from this file for a long time.
              inclusionLat: 11,
              inclusionLng: 10.5,
              inclusionRadiusMeters: 12000,
              colorArgb: 0xFF00FF00,
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
              pointOsmIds: [240109189, 0],
              pointOsmTypes: ['node', null],
              label: 'Cafés',
            ),
          ],
        ),
        ExportLayer(
          name: 'Height',
          colorArgb: 0xFF8D6E63,
          type: 'height',
          isInverted: false,
          // Hidden — the one layer attribute that used to be left behind.
          isVisible: false,
          objects: const [
            ExportObject(
              kind: 'height',
              coords: [LatLng(47.42, 10.98)],
              radiusMeters: 12000,
              thresholdMeters: 1850.5,
              aboveThreshold: false,
              sampleZoom: 14,
              // The generated fill: what the layer actually draws, and what an
              // export used to leave behind so the layer came back blank.
              generated: true,
              heightRings: [
                [LatLng(47.4, 10.9), LatLng(47.45, 10.9), LatLng(47.45, 11.0)],
              ],
            ),
          ],
        ),
        ExportLayer(
          name: 'Track',
          colorArgb: 0xFF26A69A,
          type: 'track',
          isInverted: false,
          trackStrokeWidth: 7.5,
          trackMinDistanceMeters: 25,
          objects: const [
            ExportObject(
              kind: 'track',
              coords: [
                LatLng(48.1, 11.5),
                LatLng(48.11, 11.51),
                LatLng(48.3, 11.7),
                LatLng(48.31, 11.71),
              ],
              // Two segments: the recording paused between them, and a single
              // LineString would draw a straight jump across the gap.
              segments: [
                [LatLng(48.1, 11.5), LatLng(48.11, 11.51)],
                [LatLng(48.3, 11.7), LatLng(48.31, 11.71)],
              ],
              label: 'morning run',
            ),
          ],
        ),
        ExportLayer(
          name: 'Transit',
          colorArgb: 0xFF7E57C2,
          type: 'transit',
          isInverted: false,
          objects: const [
            ExportObject(
              kind: 'transitstop',
              coords: [LatLng(48.14, 11.46)],
              pointLabels: ['Pasing Bahnhof'],
              pointOsmIds: [1],
              pointModeMasks: [3],
              pointNodeCounts: [31],
              pointRouteRefs: ['S3;S4'],
              bbox: [48.0, 11.3, 48.3, 11.8],
              modeMask: 7,
              visibleModeMask: 3,
              label: 'München',
            ),
            // An import that never succeeded: no stations, but still a retry
            // row on the layer, so it has to survive the trip.
            ExportObject(
              kind: 'transitstop',
              coords: [],
              bbox: [49.0, 12.0, 49.5, 12.5],
              modeMask: 1,
              visibleModeMask: -1,
              pending: true,
              errorMessage: 'Overpass was busy',
              label: 'Regensburg',
            ),
          ],
        ),
      ]);

  void expectSamePoints(List<LatLng>? a, List<LatLng>? b, String what) {
    if (a == null || b == null) {
      expect(b, a, reason: what);
      return;
    }
    expect(b.length, a.length, reason: what);
    for (var i = 0; i < a.length; i++) {
      expect(b[i].latitude, closeTo(a[i].latitude, 1e-9), reason: what);
      expect(b[i].longitude, closeTo(a[i].longitude, 1e-9), reason: what);
    }
  }

  void expectSameRings(
      List<List<LatLng>>? a, List<List<LatLng>>? b, String what) {
    if (a == null || b == null) {
      expect(b, a, reason: what);
      return;
    }
    expect(b.length, a.length, reason: what);
    for (var i = 0; i < a.length; i++) {
      expectSamePoints(a[i], b[i], '$what[$i]');
    }
  }

  /// **Every** field, not a chosen few — a field this misses is a field the
  /// format can silently drop, which is how the inclusion circle and the
  /// height fills went missing for as long as they did.
  void expectSameObject(ExportObject a, ExportObject b) {
    expect(b.kind, a.kind);
    expect(b.label, a.label);
    expect(b.colorArgb, a.colorArgb);
    expect(b.radiusMeters, a.radiusMeters);
    expect(b.nearA, a.nearA);
    expect(b.offsetMeters, a.offsetMeters);
    expect(b.mainIndex, a.mainIndex);
    expect(b.thresholdMeters, a.thresholdMeters);
    expect(b.aboveThreshold, a.aboveThreshold);
    expect(b.sampleZoom, a.sampleZoom);
    expect(b.generated, a.generated);
    expect(b.inclusionLat, a.inclusionLat);
    expect(b.inclusionLng, a.inclusionLng);
    expect(b.inclusionRadiusMeters, a.inclusionRadiusMeters);
    expect(b.categoryKey, a.categoryKey);
    expect(b.pointLabels, a.pointLabels);
    expect(b.pointOsmIds, a.pointOsmIds);
    expect(b.pointOsmTypes, a.pointOsmTypes);
    expect(b.pointModeMasks, a.pointModeMasks);
    expect(b.pointNodeCounts, a.pointNodeCounts);
    expect(b.pointRouteRefs, a.pointRouteRefs);
    expect(b.bbox, a.bbox);
    expect(b.osmId, a.osmId);
    expect(b.adminLevel, a.adminLevel);
    expect(b.setLabel, a.setLabel);
    expect(b.colorIndex, a.colorIndex);
    expect(b.labelLat, a.labelLat);
    expect(b.labelLng, a.labelLng);
    expect(b.wayIds, a.wayIds);
    expect(b.edited, a.edited);
    expect(b.modeMask, a.modeMask);
    expect(b.visibleModeMask, a.visibleModeMask);
    expect(b.pending, a.pending);
    expect(b.errorMessage, a.errorMessage);
    expectSamePoints(a.coords, b.coords, '${a.kind} coords');
    expectSameRings(a.rings, b.rings, '${a.kind} rings');
    expectSameRings(a.heightRings, b.heightRings, '${a.kind} heightRings');
    expectSameRings(a.segments, b.segments, '${a.kind} segments');
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
        expect(b.isVisible, a.isVisible);
        expect(b.opacity, a.opacity);
        expect(b.borderLevel, a.borderLevel);
        expect(b.borderFillAreas, a.borderFillAreas);
        expect(b.borderShowNames, a.borderShowNames);
        expect(b.trackStrokeWidth, a.trackStrokeWidth);
        expect(b.trackMinDistanceMeters, a.trackMinDistanceMeters);
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
      expect('<Folder>'.allMatches(kml).length, 9); // one per layer
      expect(kml, contains('<Polygon>')); // circle ring + freearea
      expect(kml, contains('<LineString>')); // plane + freeline
      expect(kml, contains('<MultiGeometry>')); // subspace seed points
      // A generated height region draws its actual fill, not its bound.
      expect(kml, contains('47.4,0 10.9,47.45,0'));
      // A recording's pauses are separate LineStrings, so nothing draws a
      // straight jump across them.
      expect(kml, contains('11.51,48.11,0</coordinates></LineString>'));
      // POIs: one named Placemark per stored point (centre is skipped).
      expect(kml, contains('<name>Café A</name>'));
      // The search centre is not a POI, so it gets no Placemark of its own.
      // Matched as a Point, because the track layer's line passes through
      // the same coordinate.
      expect(kml, isNot(contains('<Point><coordinates>11.5,48.1,0')));
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
