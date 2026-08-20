import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/database.dart';
import '../data/location.dart' as loc;
import 'providers.dart';

/// A fix arriving more than this long after the previous stored one starts a
/// new **segment** — a break in the drawn line rather than a straight jump
/// across whatever happened in between.
///
/// One rule covers every way a recording loses time: the user stopped and
/// started again, the signal died in a tunnel, or the app was in the background
/// (recording is foreground-only, so that is a normal and expected gap). A
/// minute of no movement is not a gap — `distanceFilter` means standing still
/// emits nothing at all — so this only ever fires on time the track genuinely
/// knows nothing about.
const Duration kTrackGapThreshold = Duration(seconds: 60);

/// Whether a fix at [now] belongs to a new segment, given the previous stored
/// fix's time [previous] (null = the recording has no points yet).
///
/// Pure, and separated out because it is the whole correctness of the drawn
/// line: get it wrong in one direction and two walks are joined by a line
/// across the map, wrong in the other and one walk is drawn as dashes.
bool startsNewSegment(DateTime? previous, DateTime now) {
  if (previous == null) return false;
  return now.difference(previous) > kTrackGapThreshold;
}

/// What the recorder is doing. [layerId] null means "not recording", which is
/// the only state check the UI needs.
class TrackRecording {
  const TrackRecording({
    this.layerId,
    this.trackId,
    this.segment = 0,
    this.pointCount = 0,
    this.startedAt,
    this.lastFixAt,
  });

  final String? layerId;
  final String? trackId;
  final int segment;

  /// Points stored **in this run**, not in the track — what the banner counts
  /// so that "Recording · 3 points" means the last three minutes, not a total
  /// dominated by yesterday's walk.
  final int pointCount;
  final DateTime? startedAt;
  final DateTime? lastFixAt;

  bool get isRecording => layerId != null;

  TrackRecording copyWith({
    int? segment,
    int? pointCount,
    DateTime? lastFixAt,
  }) =>
      TrackRecording(
        layerId: layerId,
        trackId: trackId,
        segment: segment ?? this.segment,
        pointCount: pointCount ?? this.pointCount,
        startedAt: startedAt,
        lastFixAt: lastFixAt ?? this.lastFixAt,
      );
}

/// The position stream the recorder subscribes to, injected so tests can feed
/// it fixes without a device (and without a plugin channel, which a `flutter
/// test` process does not have).
final positionStreamProvider =
    Provider<Stream<Position> Function({required double distanceFilter})>(
        (ref) => loc.positionStream);

/// The permission/service gate, injected for the same reason.
final locationGateProvider =
    Provider<Future<String?> Function()>((ref) => loc.ensureLocationReady);

/// Records the phone's positions into a `track` layer.
///
/// Owns the app's only `StreamSubscription<Position>`. It lives in Riverpod
/// rather than in the map screen's `State` because recording has to survive
/// everything the UI does — opening the drawer, pushing Settings, rebuilding on
/// every camera tick — and stop only when the user says so.
///
/// **Foreground only** by construction: a plain `getPositionStream` with no
/// foreground service, so Android stops delivering while the app is in the
/// background and the gap becomes a segment break. That is the promise the
/// manifest and `PRIVACY.md` make, and this class is where it is kept.
class TrackRecorder extends Notifier<TrackRecording> {
  StreamSubscription<Position>? _sub;

  @override
  TrackRecording build() {
    ref.onDispose(() => _sub?.cancel());
    return const TrackRecording();
  }

  /// Starts recording into [layer]'s track, creating that track if this is the
  /// layer's first recording. Returns null on success, or a message to show.
  Future<String?> start(Layer layer) async {
    if (layer.type != 'track') return 'That layer does not record tracks.';
    if (state.isRecording) return null;

    final problem = await ref.read(locationGateProvider)();
    if (problem != null) return problem;

    final repo = ref.read(repositoryProvider);
    final trackId = await repo.ensureTrackForLayer(layer.id);
    // One past whatever is stored: continuing a track must not join this walk
    // to the end of the last one.
    final segment = await repo.nextTrackSegment(trackId);

    final stream = ref.read(positionStreamProvider)(
      distanceFilter: layer.trackMinDistanceMeters,
    );
    _sub = stream.listen(
      _onFix,
      onError: (Object _) {
        // The stream is dead either way; keeping a "recording" FAB lit over a
        // subscription that will never emit again is the worse failure.
        stop();
      },
      cancelOnError: true,
    );

    state = TrackRecording(
      layerId: layer.id,
      trackId: trackId,
      segment: segment,
      startedAt: DateTime.now(),
    );
    return null;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    state = const TrackRecording();
  }

  /// Stops if the layer being recorded into has gone away (deleted from the
  /// drawer while recording), so the subscription cannot outlive its target.
  void stopIfLayerGone(List<Layer> layers) {
    final id = state.layerId;
    if (id == null) return;
    if (!layers.any((l) => l.id == id)) stop();
  }

  Future<void> _onFix(Position pos) async {
    final trackId = state.trackId;
    if (trackId == null) return;
    // A NaN fix would poison the track's bounds and every projection made from
    // them — the same guard the one-shot "Locate me" makes.
    if (!pos.latitude.isFinite || !pos.longitude.isFinite) return;

    final now = DateTime.now();
    final segment =
        startsNewSegment(state.lastFixAt, now) ? state.segment + 1 : state.segment;

    await ref.read(repositoryProvider).appendTrackPoint(
          trackId: trackId,
          lat: pos.latitude,
          lng: pos.longitude,
          segmentIndex: segment,
          recordedAt: now,
        );

    // Guard against a fix landing after `stop()`: the write is awaited, so the
    // recording may have ended in between, and resurrecting the state would
    // relight the Stop button over a cancelled subscription.
    if (!state.isRecording) return;
    state = state.copyWith(
      segment: segment,
      pointCount: state.pointCount + 1,
      lastFixAt: now,
    );
  }
}

final trackRecordingProvider =
    NotifierProvider<TrackRecorder, TrackRecording>(TrackRecorder.new);
