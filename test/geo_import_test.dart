import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/data/geo_import.dart';

void main() {
  group('GeoJSON', () {
    test('parses a LineString as a line feature', () {
      const text = '''
      {"type":"Feature","properties":{"name":"route"},
       "geometry":{"type":"LineString",
         "coordinates":[[13.4,52.5],[13.5,52.6]]}}''';
      final feats = parseGeoJsonGeometry(text);
      expect(feats, hasLength(1));
      expect(feats.first.kind, GeometryKind.line);
      expect(feats.first.label, 'route');
      expect(feats.first.coords, hasLength(2));
      // [lng,lat] -> LatLng(lat,lng)
      expect(feats.first.coords.first.latitude, 52.5);
      expect(feats.first.coords.first.longitude, 13.4);
    });

    test('parses a Polygon outer ring, dropping the closing vertex', () {
      const text = '''
      {"type":"FeatureCollection","features":[
        {"type":"Feature","properties":{},
         "geometry":{"type":"Polygon","coordinates":[
           [[13.0,52.0],[13.1,52.0],[13.1,52.1],[13.0,52.1],[13.0,52.0]]]}}]}''';
      final feats = parseGeoJsonGeometry(text);
      expect(feats, hasLength(1));
      expect(feats.first.kind, GeometryKind.area);
      expect(feats.first.coords, hasLength(4)); // closing vertex dropped
    });

    test('returns empty on invalid JSON', () {
      expect(parseGeoJsonGeometry('not json'), isEmpty);
    });
  });

  group('KML', () {
    test('parses a Placemark Polygon', () {
      const text = '''
      <kml><Document><Placemark><name>Munich</name>
        <Polygon><outerBoundaryIs><LinearRing><coordinates>
          11.5,48.1,0 11.6,48.1,0 11.6,48.2,0 11.5,48.2,0 11.5,48.1,0
        </coordinates></LinearRing></outerBoundaryIs></Polygon>
      </Placemark></Document></kml>''';
      final feats = parseKml(text);
      expect(feats, hasLength(1));
      expect(feats.first.kind, GeometryKind.area);
      expect(feats.first.label, 'Munich');
      expect(feats.first.coords, hasLength(4));
      expect(feats.first.coords.first.latitude, 48.1);
      expect(feats.first.coords.first.longitude, 11.5);
    });

    test('parses a LineString', () {
      const text = '''
      <kml><Placemark><LineString><coordinates>
        11.5,48.1 11.6,48.2</coordinates></LineString></Placemark></kml>''';
      final feats = parseKml(text);
      expect(feats, hasLength(1));
      expect(feats.first.kind, GeometryKind.line);
    });
  });

  group('KMZ', () {
    test('unzips and parses the contained KML', () {
      const kml = '''
      <kml><Placemark><name>z</name><LineString><coordinates>
        1,2 3,4</coordinates></LineString></Placemark></kml>''';
      final archive = Archive()
        ..addFile(ArchiveFile.string('doc.kml', kml));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final feats = parseKmz(bytes);
      expect(feats, hasLength(1));
      expect(feats.first.label, 'z');
    });
  });

  group('GPX', () {
    test('parses a track segment as a line', () {
      const text = '''
      <gpx><trk><name>hike</name><trkseg>
        <trkpt lat="48.1" lon="11.5"/>
        <trkpt lat="48.2" lon="11.6"/>
      </trkseg></trk></gpx>''';
      final feats = parseGpx(text);
      expect(feats, hasLength(1));
      expect(feats.first.kind, GeometryKind.line);
      expect(feats.first.label, 'hike');
      expect(feats.first.coords.first.latitude, 48.1);
    });
  });

  group('dispatch by filename', () {
    test('routes .geojson to the GeoJSON parser', () {
      final bytes = Uint8List.fromList(utf8.encode(
          '{"type":"Feature","geometry":{"type":"LineString",'
          '"coordinates":[[1,2],[3,4]]}}'));
      final feats = parseExternalGeometry('x.geojson', bytes);
      expect(feats, hasLength(1));
    });
  });

  group('stitchPolylines', () {
    test('chains contiguous parts into one ordered polyline', () {
      final parts = [
        [const LatLng(0, 0), const LatLng(0, 1)],
        [const LatLng(0, 1), const LatLng(0, 2)],
        [const LatLng(0, 2), const LatLng(0, 3)],
      ];
      final line = stitchPolylines(parts);
      expect(line.first, const LatLng(0, 0));
      expect(line.last, const LatLng(0, 3));
      // monotonically increasing longitude across the join
      for (var i = 1; i < line.length; i++) {
        expect(line[i].longitude, greaterThanOrEqualTo(line[i - 1].longitude));
      }
    });

    test('reverses a part whose orientation is flipped', () {
      final parts = [
        [const LatLng(0, 0), const LatLng(0, 1)],
        [const LatLng(0, 2), const LatLng(0, 1)], // reversed orientation
      ];
      final line = stitchPolylines(parts);
      expect(line.last, const LatLng(0, 2));
    });

    test('handles a single part and empty input', () {
      expect(
        stitchPolylines([
          [const LatLng(1, 1), const LatLng(2, 2)]
        ]),
        hasLength(2),
      );
      expect(stitchPolylines(const []), isEmpty);
      expect(
        stitchPolylines([
          [const LatLng(1, 1)] // too short, dropped
        ]),
        isEmpty,
      );
    });

    const distance = Distance(calculator: Haversine());
    double maxGap(List<LatLng> line) {
      var m = 0.0;
      for (var i = 1; i < line.length; i++) {
        final d = distance.as(LengthUnit.Meter, line[i - 1], line[i]);
        if (d > m) m = d;
      }
      return m;
    }

    test('does not fabricate a connector between far-apart channels', () {
      // A main channel (meridian, ~111 m steps) and a separate channel far east.
      final main = [for (var i = 0; i <= 10; i++) LatLng(48.0 + i * 0.001, 11.0)];
      final side = [const LatLng(48.0, 11.05), const LatLng(48.003, 11.05)];
      final line = stitchPolylines([main, side]);
      // The longer (main) channel is returned; the side channel is dropped and
      // NOT joined by a multi-km straight jump.
      expect(line, hasLength(main.length));
      expect(maxGap(line), lessThan(200)); // within-channel steps only
    });

    test('still joins parts across a small (shared-node) gap', () {
      final a = [const LatLng(48.0, 11.0), const LatLng(48.005, 11.0)];
      final gapStart = distance.offset(a.last, 20, 0); // 20 m north (< 50 m)
      final b = [gapStart, distance.offset(gapStart, 500, 0)];
      final line = stitchPolylines([a, b]);
      expect(line, hasLength(a.length + b.length)); // bridged into one run
    });

    test('a near-but-separate channel (gap > threshold) is not merged', () {
      final main = [for (var i = 0; i <= 8; i++) LatLng(48.0 + i * 0.001, 11.0)];
      // ~149 m east of the main channel — a distinct parallel channel.
      final side = [const LatLng(48.0, 11.002), const LatLng(48.002, 11.002)];
      final line = stitchPolylines([main, side]);
      expect(line, hasLength(main.length));
      // None of the side channel's vertices leaked into the result.
      expect(line.every((p) => p.longitude == 11.0), isTrue);
    });
  });
}
