import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/state/track_recorder.dart';

/// The recorder is the one place in the app that writes rows from something
/// other than a tap, and the only holder of a stream subscription — so what
/// needs proving is that fixes land where they should, that the segment rule
/// draws the line the user expects, and that stopping actually stops.
///
/// It runs against a **real** in-memory database (the writes are the point)
/// with a **fake** position stream, injected through [positionStreamProvider]
/// — a `flutter test` process has no location plugin behind a method channel,
/// and a test that needed one would only ever run on a phone.
void main() {
  late AppDatabase db;
  late Repository repo;
  late ProviderContainer container;
  late StreamController<Position> fixes;
  late List<double> filtersAsked;

  Position at(double lat, double lng) => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 500,
        altitudeAccuracy: 3,
        heading: 0,
        headingAccuracy: 0,
        speed: 1.2,
        speedAccuracy: 0.5,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
    fixes = StreamController<Position>.broadcast();
    filtersAsked = [];
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      locationGateProvider.overrideWithValue(() async => null),
      positionStreamProvider.overrideWithValue(({required distanceFilter}) {
        filtersAsked.add(distanceFilter);
        return fixes.stream;
      }),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await fixes.close();
    await db.close();
  });

  Future<Layer> trackLayer({double spacing = 10}) async {
    final id = await repo.createLayer(
      name: 'Walks',
      colorArgb: 0xFF2196F3,
      type: 'track',
    );
    if (spacing != 10) {
      await repo.updateTrackLayerOptions(id, minDistanceMeters: spacing);
    }
    return (await repo.watchLayers().first).firstWhere((l) => l.id == id);
  }

  /// Feeds one fix and lets the recorder's awaited write finish.
  Future<void> feed(Position p) async {
    fixes.add(p);
    await pumpEventQueue();
  }

  test('recording appends fixes to the layer\'s track', () async {
    final layer = await trackLayer();
    final recorder = container.read(trackRecordingProvider.notifier);

    expect(await recorder.start(layer), isNull);
    await feed(at(48.10, 11.50));
    await feed(at(48.11, 11.51));

    final points = await repo.watchAllTrackPoints().first;
    expect(points, hasLength(2));
    expect(points.first.lat, 48.10);
    expect(points.map((p) => p.sortOrder), [0, 1]);
    expect(container.read(trackRecordingProvider).pointCount, 2);

    // The track was created on demand — a layer that has never recorded shows
    // no elements at all.
    expect((await repo.watchAllTracks().first).single.layerId, layer.id);
  });

  test('the stored bounds cover every fix', () async {
    // The painter culls on these before projecting a single point, so a fix
    // outside them would be invisible until something else rewrote them.
    final layer = await trackLayer();
    await container.read(trackRecordingProvider.notifier).start(layer);
    await feed(at(48.20, 11.40));
    await feed(at(48.10, 11.60));

    final track = (await repo.watchAllTracks().first).single;
    expect(track.south, 48.10);
    expect(track.north, 48.20);
    expect(track.west, 11.40);
    expect(track.east, 11.60);
  });

  test('a non-finite fix is dropped rather than stored', () async {
    // A NaN would poison the bounds and every projection made from them.
    final layer = await trackLayer();
    await container.read(trackRecordingProvider.notifier).start(layer);
    await feed(at(double.nan, 11.5));
    await feed(at(48.1, double.infinity));

    expect(await repo.watchAllTrackPoints().first, isEmpty);
    final track = (await repo.watchAllTracks().first).single;
    expect(track.south, isNull, reason: 'bounds must stay untouched');
  });

  test('stopping ends the subscription: later fixes are not stored', () async {
    final layer = await trackLayer();
    final recorder = container.read(trackRecordingProvider.notifier);
    await recorder.start(layer);
    await feed(at(48.10, 11.50));

    recorder.stop();
    expect(container.read(trackRecordingProvider).isRecording, isFalse);
    await feed(at(48.20, 11.60));

    expect(await repo.watchAllTrackPoints().first, hasLength(1));
  });

  test('a second recording continues the same track in a new segment',
      () async {
    // The user's choice: one track per layer. Two walks must be one element
    // with one colour — and still not be joined by a line across the map.
    final layer = await trackLayer();
    final recorder = container.read(trackRecordingProvider.notifier);

    await recorder.start(layer);
    await feed(at(48.10, 11.50));
    await feed(at(48.11, 11.51));
    recorder.stop();

    await recorder.start(layer);
    await feed(at(49.00, 12.00));
    recorder.stop();

    expect(await repo.watchAllTracks().first, hasLength(1),
        reason: 'a second run must not create a second track');
    final points = await repo.watchAllTrackPoints().first;
    expect(points.map((p) => p.segmentIndex), [0, 0, 1]);
  });

  test('the layer\'s spacing setting is what the stream is asked for', () async {
    await container
        .read(trackRecordingProvider.notifier)
        .start(await trackLayer(spacing: 25));
    expect(filtersAsked, [25]);
  });

  test('recording into a non-track layer is refused', () async {
    final id = await repo.createLayer(
        name: 'Circles', colorArgb: 0xFF000000, type: 'circles');
    final layer = (await repo.watchLayers().first).firstWhere((l) => l.id == id);
    final problem =
        await container.read(trackRecordingProvider.notifier).start(layer);
    expect(problem, isNotNull);
    expect(container.read(trackRecordingProvider).isRecording, isFalse);
  });

  test('a refused permission reports why and records nothing', () async {
    final blocked = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      locationGateProvider.overrideWithValue(() async => 'Permission denied.'),
      positionStreamProvider
          .overrideWithValue(({required distanceFilter}) => fixes.stream),
    ]);
    addTearDown(blocked.dispose);

    final problem =
        await blocked.read(trackRecordingProvider.notifier).start(await trackLayer());
    expect(problem, 'Permission denied.');
    expect(blocked.read(trackRecordingProvider).isRecording, isFalse);
    expect(await repo.watchAllTracks().first, isEmpty,
        reason: 'a refusal must not leave an empty track behind');
  });

  test('deleting the layer being recorded into stops the recording', () async {
    final layer = await trackLayer();
    final recorder = container.read(trackRecordingProvider.notifier);
    await recorder.start(layer);
    await repo.deleteLayer(layer.id);

    recorder.stopIfLayerGone(await repo.watchLayers().first);
    expect(container.read(trackRecordingProvider).isRecording, isFalse);
  });

  group('startsNewSegment', () {
    test('the first fix of a track never starts a segment', () {
      expect(startsNewSegment(null, DateTime(2026, 8, 20, 12)), isFalse);
    });

    test('fixes a few seconds apart stay in one segment', () {
      final t = DateTime(2026, 8, 20, 12);
      expect(startsNewSegment(t, t.add(const Duration(seconds: 8))), isFalse);
      expect(startsNewSegment(t, t.add(kTrackGapThreshold)), isFalse);
    });

    test('a long gap — background, tunnel, restart — breaks the line', () {
      final t = DateTime(2026, 8, 20, 12);
      expect(
        startsNewSegment(t, t.add(kTrackGapThreshold + const Duration(seconds: 1))),
        isTrue,
      );
      expect(startsNewSegment(t, t.add(const Duration(hours: 3))), isTrue);
    });
  });
}
