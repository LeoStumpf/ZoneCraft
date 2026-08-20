import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/serialization.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/object_summary.dart';
import 'package:zonecraft/ui/track_layer.dart';

/// The two pure halves of drawing a recorded line, plus what the rest of the
/// app says about a track.
void main() {
  TrackPoint point(double lat, double lng, {int segment = 0, int order = 0}) =>
      TrackPoint(
        id: 'p$order',
        trackId: 't1',
        lat: lat,
        lng: lng,
        sortOrder: order,
        segmentIndex: segment,
        recordedAt: DateTime(2026, 8, 20),
      );

  group('thinScreenPoints', () {
    test('drops points closer than the threshold to the last kept one', () {
      // GPS jitter at city zoom: ten fixes inside one pixel.
      final pts = [
        for (var i = 0; i < 10; i++) Offset(i * 0.1, 0),
        const Offset(50, 0),
      ];
      final out = thinScreenPoints(pts, 2);
      expect(out.first, const Offset(0, 0));
      expect(out.last, const Offset(50, 0));
      expect(out.length, lessThan(pts.length));
    });

    test('keeps the last point, always', () {
      // A track's end is where you stopped; trimming it would shorten the line
      // as it is being recorded.
      final pts = [const Offset(0, 0), const Offset(100, 0), const Offset(100.5, 0)];
      expect(thinScreenPoints(pts, 2).last, const Offset(100.5, 0));
    });

    test('keeps everything already further apart than the threshold', () {
      final pts = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(20, 10),
      ];
      expect(thinScreenPoints(pts, 2), pts);
    });

    test('a two-point line is returned untouched', () {
      final pts = [const Offset(0, 0), const Offset(0.1, 0)];
      expect(thinScreenPoints(pts, 2), pts);
    });
  });

  group('splitSegments', () {
    test('one run of one segment stays whole', () {
      final pts = [
        point(48.1, 11.5, order: 0),
        point(48.2, 11.6, order: 1),
        point(48.3, 11.7, order: 2),
      ];
      expect(splitSegments(pts), hasLength(1));
      expect(splitSegments(pts).single, hasLength(3));
    });

    test('a segment change splits the line rather than joining the walks', () {
      final pts = [
        point(48.1, 11.5, order: 0),
        point(48.2, 11.6, order: 1),
        point(52.5, 13.4, segment: 1, order: 2),
        point(52.6, 13.5, segment: 1, order: 3),
      ];
      final runs = splitSegments(pts);
      expect(runs, hasLength(2));
      expect(runs[0].last.lat, 48.2);
      expect(runs[1].first.lat, 52.5);
    });

    test('a lone point in a segment is not a line and is dropped', () {
      final pts = [
        point(48.1, 11.5, order: 0),
        point(48.2, 11.6, order: 1),
        point(52.5, 13.4, segment: 1, order: 2),
      ];
      final runs = splitSegments(pts);
      expect(runs, hasLength(1));
      expect(runs.single, hasLength(2));
    });

    test('no points, nothing to draw', () {
      expect(splitSegments(const []), isEmpty);
    });
  });

  group('the track type across the app', () {
    test('has an icon but deliberately no editor', () {
      expect(typeIcon('track'), isNotNull);
      expect(layerHasEditor('track'), isFalse,
          reason: 'a recording has nothing to edit in place');
      // Every other type still has one — this is an exception, not a hole.
      for (final t in const [
        'circles',
        'planes',
        'subspace',
        'freeline',
        'freearea',
        'height',
        'poi',
        'transit',
        'borders',
      ]) {
        expect(layerHasEditor(t), isTrue, reason: t);
      }
    });

    test('a track layer is opaque by default — a stroke has no fill', () {
      expect(defaultLayerOpacity('track'), 1.0);
    });

    test('the Elements row counts the fixes and measures the walk', () {
      final layer = Layer(
        id: 'L',
        name: 'Walks',
        colorArgb: 0xFF2196F3,
        isVisible: true,
        sortOrder: 0,
        type: 'track',
        isInverted: false,
        opacity: 1,
        borderLevel: null,
        borderFillAreas: false,
        borderShowNames: false,
        trackStrokeWidth: 4,
        trackMinDistanceMeters: 10,
        createdAt: DateTime(2026),
      );
      final rows = summariseLayer(
        layer,
        tracks: [
          Track(
            id: 't1',
            layerId: 'L',
            createdAt: DateTime(2026),
            colorShade: 0,
          ),
        ],
        // ~1.1 km apart in latitude, twice.
        trackPoints: [
          point(48.10, 11.5, order: 0),
          point(48.11, 11.5, order: 1),
          point(48.12, 11.5, order: 2),
        ],
      );
      expect(rows, hasLength(1));
      expect(rows.single.ref.kind, ObjectKind.track);
      expect(rows.single.title, 'Track 1');
      expect(rows.single.subtitle, startsWith('3 points · '));
      expect(rows.single.subtitle, contains('km'));
    });

    test('the length skips the gap between two segments', () {
      // A break is time the track knows nothing about. The straight line across
      // it is not drawn, so it must not be counted either — otherwise a walk in
      // Munich and a walk in Berlin read as a 500 km hike.
      final layer = Layer(
        id: 'L',
        name: 'Walks',
        colorArgb: 0xFF2196F3,
        isVisible: true,
        sortOrder: 0,
        type: 'track',
        isInverted: false,
        opacity: 1,
        borderLevel: null,
        borderFillAreas: false,
        borderShowNames: false,
        trackStrokeWidth: 4,
        trackMinDistanceMeters: 10,
        createdAt: DateTime(2026),
      );
      final track = Track(
        id: 't1',
        layerId: 'L',
        createdAt: DateTime(2026),
        colorShade: 0,
      );
      String lengthOf(List<TrackPoint> pts) => summariseLayer(
            layer,
            tracks: [track],
            trackPoints: pts,
          ).single.subtitle;

      // Munich, then Berlin — as one segment, and as two.
      final joined = [
        point(48.10, 11.50, order: 0),
        point(48.11, 11.50, order: 1),
        point(52.50, 13.40, order: 2),
        point(52.51, 13.40, order: 3),
      ];
      final split = [
        point(48.10, 11.50, order: 0),
        point(48.11, 11.50, order: 1),
        point(52.50, 13.40, segment: 1, order: 2),
        point(52.51, 13.40, segment: 1, order: 3),
      ];
      // Joined, the Munich→Berlin jump dominates: hundreds of km.
      expect(lengthOf(joined), '4 points · 509 km');
      // Split, only the two ~1.1 km legs count.
      expect(lengthOf(split), '4 points · 2.23 km');
    });
  });

  group('export', () {
    late AppDatabase db;
    late Repository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = Repository(db);
    });
    tearDown(() => db.close());

    test('a track round-trips through GeoJSON as a line', () async {
      final layerId = await repo.createLayer(
          name: 'Walks', colorArgb: 0xFF2196F3, type: 'track');
      await repo.updateTrackLayerOptions(layerId,
          strokeWidth: 6, minDistanceMeters: 25);
      final trackId = await repo.ensureTrackForLayer(layerId);
      await repo.updateTrack(trackId, label: const Value('Sunday walk'));
      await repo.addTrackPoints(trackId, const [
        LatLng(48.10, 11.50),
        LatLng(48.15, 11.55),
        LatLng(48.20, 11.60),
      ]);

      final text = exportToGeoJson(await repo.exportData());
      expect(text, contains('"kind": "track"'));
      expect(text, contains('LineString'));

      final back = importFromGeoJson(text);
      expect(back, isNotNull);
      final layer = back!.layers.single;
      expect(layer.type, 'track');
      // The per-layer settings travel with it: a shared track should look the
      // way it was drawn.
      expect(layer.trackStrokeWidth, 6);
      expect(layer.trackMinDistanceMeters, 25);
      expect(layer.objects.single.kind, 'track');
      expect(layer.objects.single.label, 'Sunday walk');
      expect(layer.objects.single.coords, hasLength(3));

      // And importing it builds a real track layer again.
      expect(await repo.importData(back), 1);
      final layers = await repo.watchLayers().first;
      expect(layers.where((l) => l.type == 'track'), hasLength(2));
      final imported = layers.lastWhere((l) => l.type == 'track');
      expect(imported.trackStrokeWidth, 6);
      final tracks = await repo.watchAllTracks().first;
      expect(tracks.where((t) => t.layerId == imported.id), hasLength(1));
    });
  });
}
