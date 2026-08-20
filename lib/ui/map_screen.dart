import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/borders.dart';
import '../data/cached_tile_provider.dart';
import '../data/database.dart';
import '../data/height_generator.dart';
import '../data/location.dart';
import '../data/overpass.dart';
import '../data/overpass_client.dart'
    show OverpassCancel, OverpassOutcome, kOverpassPreferenceMaxElapsed;
import '../data/repository.dart' show Repository;
import '../data/tile_source.dart';
import '../data/transit.dart';
import '../geo/border_areas.dart';
import '../geo/coords.dart';
import '../geo/geodesic.dart';
import '../geo/tiles.dart';
import '../state/map_mode.dart';
import '../state/providers.dart';
import '../state/track_recorder.dart';
import 'circle_editor.dart';
import 'collapsible_sheet.dart';
import 'freearea_editor.dart';
import 'freeline_editor.dart';
import 'border_area_editor.dart';
import 'border_reshape.dart';
import 'camera_viewport.dart';
import 'height_editor.dart';
import 'imported_point_editor.dart';
import 'poi_set_editor.dart';
import 'transit_set_editor.dart';
import 'hit_test.dart';
import 'import_progress.dart';
import 'layers_panel.dart';
import 'object_summary.dart';
import 'plane_editor.dart';
import 'draw_stroke.dart';
import 'poi_import_dialog.dart';
import 'poi_layer.dart';
import 'area_geometry.dart';
import 'border_import_dialog.dart';
import 'border_layer.dart';
import 'region_geometry.dart';
import 'region_layer.dart';
import 'subspace_editor.dart';
import 'transit_import_dialog.dart';
import 'track_layer.dart';
import 'transit_layer.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  final _mapController = MapController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // Wraps the FlutterMap so a handle's lat/lng can be projected to a global
  // screen position (for popup menus anchored on a dragged point).
  final _mapKey = GlobalKey();
  // Live-drag throttle: at most one point drags at a time, so a single gate
  // keeps the persisted-per-frame writes off the UI thread's back.
  DateTime _lastDragWriteAt = DateTime.fromMillisecondsSinceEpoch(0);
  // The position a handle held when its drag began, so a move can be undone.
  LatLng? _dragOrigin;
  // Shows the "handles are draggable" hint once per app session, the first time
  // an object is selected.
  bool _editHintShown = false;
  // Shown once per session, the first time a view-mode tap lands on an object
  // (i.e. the user tried the old tap-to-select and nothing happened).
  bool _viewTapHintShown = false;
  // --- Add mode -------------------------------------------------------------
  // While [MapMode.add] is armed these hold the layer being added to. Sticky:
  // each tap places one object (or one vertex, for the point-set types) and the
  // mode stays on until Done.
  String? _placeLayerId;
  String? _placeType;

  /// Buffered first tap of a two-tap type (a plane's point A).
  LatLng? _pendingPlaneA;

  /// Buffered first corner of a transit import box. While set, the live second
  /// corner is the map centre (a phone has no hover), so the rubber band
  /// follows as you pan.
  LatLng? _pendingBoxA;

  /// Everything placed in the current Add session, newest last: the object each
  /// tap belongs to (for "Edit last") and how to undo that one tap.
  final List<({ObjectRef object, Future<void> Function() undo})> _addSteps = [];

  // --- Draw mode ------------------------------------------------------------
  // While [MapMode.draw] is armed one finger draws instead of panning, and each
  // completed stroke becomes one freehand line/area. Shares [_addSteps] with Add
  // mode, so Undo / Edit / Done behave identically.
  String? _drawLayerId;
  String? _drawType;

  /// The stroke under the finger, in the map widget's screen coordinates. It is
  /// converted to lat/lng only on release ([strokeToPoints]) — the camera can't
  /// move mid-stroke, because a second finger abandons the stroke.
  final List<Offset> _stroke = [];

  /// Pointers currently down on the map, and which one owns [_stroke]. A stroke
  /// is only ever a **single** finger: the moment a second lands the gesture is
  /// a pan/pinch, not a drawing.
  final Set<int> _strokePointers = {};
  int? _strokeOwner;

  /// Bumped per collected point so only the stroke preview repaints — a
  /// setState per pointer move would rebuild the whole map screen.
  final ValueNotifier<int> _strokeRevision = ValueNotifier(0);
  // Vertex ids marked (by tapping their handle) for bulk delete; all belong to
  // the currently selected object. Cleared on any selection change.
  final Set<String> _markedPoints = {};

  /// The border outline currently being reshaped, held in memory while the
  /// drag is in flight.
  ///
  /// A border area is one ring **blob**, not point rows, so there is no cheap
  /// per-vertex write: every change re-encodes the whole outline and makes
  /// `borderShapesProvider` re-decode every area in the layer behind it. At
  /// 119 238 points that is impossible at drag rate and wasteful at any size.
  /// So the draft is the truth while reshaping — the painter and the handles
  /// both read it — and the database is written once per completed gesture.
  String? _reshapeAreaId;
  List<List<LatLng>>? _reshapeRings;

  /// Closest two outline handles may be drawn (screen px).
  ///
  /// An administrative boundary carries a vertex every few metres — Alleshausen
  /// is 105 of them across 6 km — so at any zoom that shows the whole area the
  /// dots overlap into a solid band and there is nothing to aim at. Handles are
  /// therefore thinned in *screen* space: one per [_reshapeHandleSpacingPx],
  /// and the rest appear as you zoom in. Each drawn handle is still a real
  /// vertex, so a drag moves the boundary itself and never an interpolation.
  static const double _reshapeHandleSpacingPx = 30;

  /// Backstop for the pathological case (a whole state on screen at once):
  /// beyond this many *thinned* handles even the thinning can't help, so none
  /// are drawn and the user is told the one thing that does help.
  static const int _maxReshapeHandles = 400;
  bool _reshapeZoomHintShown = false;
  // Haversine — shared with the hit-test helpers so the two never drift.
  static const _hitTest = geoDistance;

  /// The user's last known position, shown as a marker. Null until the user
  /// opts in via the "Locate me" button. We never request location at launch.
  LatLng? _myPosition;
  bool _locating = false;
  bool _mapReady = false;

  /// Terrain elevation (m) at the current "Locate me" position, when known.
  double? _myElevation;

  // --- Elevation probe ------------------------------------------------------
  /// Scratch for [MapMode.elevation]: the measured point and its result.
  LatLng? _probePoint;
  double? _probeElevation;
  bool _probing = false;

  // --- Distance probe -------------------------------------------------------
  /// Scratch for [MapMode.distance]: the two endpoints. A third tap restarts
  /// from a fresh first point.
  LatLng? _distA;
  LatLng? _distB;

  MapMode get _mode => ref.read(mapModeProvider);

  // --- Offline tile cache ---------------------------------------------------
  /// The tile source in force, shared by the [TileLayer]s, the attribution
  /// control and the offline prefetcher so the four never drift apart. It also
  /// decides whether the offline features exist at all — see
  /// `data/tile_source.dart`, which explains why they are off by default.
  static const _tiles = TileSource.current;
  static String get _baseTileUrl => _tiles.urlTemplate;

  /// HTTP client owned by this screen and shared by [_tileProvider] for both
  /// browse-caching and prefetching. Closed in [dispose].
  late final http.Client _tileClient;
  late final CachedTileProvider _tileProvider;

  /// Don't prefetch when zoomed far out — a 1-tile ring then spans a huge area
  /// and the tiles are rarely useful.
  static const double _prefetchMinZoom = 10;

  /// Cap on tile coordinates prefetched per settle, to bound network/disk use.
  static const int _prefetchMaxTiles = 60;
  Timer? _prefetchDebounce;

  /// True while a prefetch run is in flight. The debounce timer only coalesces
  /// *scheduling*; without this gate, panning during a slow run starts a second
  /// 60-request run on top of the first, and so on.
  bool _prefetching = false;

  /// "Download this area": how many zoom levels *deeper* than the current view to
  /// also cache (so you can still zoom in offline), the hard ceiling on tiles per
  /// download, and the rough per-tile size used only for the up-front estimate.
  static const int _downloadExtraZoomLevels = 2;
  static const int _downloadMaxTiles = 4000;
  static const int _avgTileBytes = 20 * 1024;

  /// True while a "download this area" run is in progress (disables its button).
  bool _downloading = false;

  /// Current map rotation in degrees (clockwise). Drives the compass needle.
  double _rotation = 0;

  /// Last finite camera, used to snap back if a gesture produces a NaN camera.
  LatLng _lastGoodCenter = const LatLng(48.137, 11.575);
  double _lastGoodZoom = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tileClient = http.Client();
    _tileProvider = CachedTileProvider(
      ref.read(repositoryProvider),
      _tileClient,
      headers: {'User-Agent': tileUserAgent},
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist the view when the app is backgrounded/closed so it reopens here.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _saveCamera();
    }
  }

  @override
  void dispose() {
    _saveCamera();
    _prefetchDebounce?.cancel();
    _tileClient.close();
    _strokeRevision.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  /// Debounced offline-tile prefetch (same coalescing as the overlays).
  void _schedulePrefetch() {
    if (!_tiles.allowsPrefetch) return; // see [_prefetchTiles]
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(
      const Duration(milliseconds: 600),
      _prefetchTiles,
    );
  }

  /// Best-effort: caches the tiles covering the current viewport plus a one-tile
  /// ring around it, so a short pan or scroll while offline still has tiles.
  /// Capped, sequential, and failure-safe so it never blocks the UI or hammers
  /// the tile servers.
  ///
  /// **Only runs when the tile source permits pre-emptive fetching.** The ring
  /// is the whole point and the ring is exactly what OpenStreetMap's tile
  /// policy calls bulk downloading — "any pre-emptive fetching of tiles other
  /// than those a user is actively viewing" — so on the default community
  /// server this never runs at all. Shrinking the ring would not help; there is
  /// no compliant size. See `data/tile_source.dart`.
  Future<void> _prefetchTiles() async {
    if (!_tiles.allowsPrefetch) return;
    if (!_mapReady || !mounted || _prefetching) return;
    final cam = _mapController.camera;
    if (!cam.center.latitude.isFinite ||
        !cam.center.longitude.isFinite ||
        !cam.zoom.isFinite) {
      return;
    }
    final z = cam.zoom.round().clamp(0, 19);
    if (z < _prefetchMinZoom) return;

    final vp = cam.visibleBounds;

    // Visible tiles widened by a one-tile ring, capped by a budget.
    final tiles = tilesCovering(
      west: vp.west,
      east: vp.east,
      north: vp.north,
      south: vp.south,
      z: z,
      ring: 1,
    );
    _prefetching = true;
    try {
      var budget = _prefetchMaxTiles;
      for (final t in tiles) {
        // The screen can go away mid-run (a 60-tile ring on a slow link takes a
        // while); stop rather than keep fetching for a dead widget.
        if (!mounted) return;
        await _tileProvider.prefetch(fillTileUrl(_baseTileUrl, z, t.x, t.y));
        if (--budget <= 0) break;
      }
      if (!mounted) return;
      await ref
          .read(repositoryProvider)
          .evictTilesDownTo(CachedTileProvider.maxCacheBytes);
    } finally {
      _prefetching = false;
    }
  }

  /// The tile URLs to cache for an explicit "download this area": the current
  /// viewport at the current zoom plus [_downloadExtraZoomLevels] deeper levels.
  /// Shallower levels come first, so when the [_downloadMaxTiles] ceiling trims
  /// the list it drops the deepest detail rather than the view you're looking at.
  List<String> _areaTileUrls(MapCamera cam) {
    final vp = cam.visibleBounds;
    final zBase = cam.zoom.round().clamp(0, 19);
    final urls = <String>[];
    for (var dz = 0; dz <= _downloadExtraZoomLevels; dz++) {
      final z = zBase + dz;
      if (z > 19) break;
      for (final t in tilesCovering(
        west: vp.west,
        east: vp.east,
        north: vp.north,
        south: vp.south,
        z: z,
      )) {
        urls.add(fillTileUrl(_baseTileUrl, z, t.x, t.y));
        if (urls.length >= _downloadMaxTiles) return urls;
      }
    }
    return urls;
  }

  /// Bulk-downloads the current area for guaranteed offline coverage: confirms
  /// with an estimate, then caches every tile with a cancellable progress
  /// dialog. Freshly written tiles are the most-recently-used, so the LRU cap
  /// evicts older areas first and keeps what you just downloaded.
  ///
  /// **Unreachable unless the tile source permits it** — its button is not
  /// built otherwise. OpenStreetMap's policy says plainly that "offline use is
  /// not permitted on `tile.openstreetmap.org`", so this is a feature you get
  /// by pointing the app at your own provider, not one the community servers
  /// can fund. Guarded here as well as at the button, so a future caller can't
  /// reintroduce it by accident.
  Future<void> _downloadArea() async {
    if (!_tiles.allowsPrefetch) return;
    if (!_mapReady || _downloading) return;
    final cam = _mapController.camera;
    if (!cam.center.latitude.isFinite ||
        !cam.center.longitude.isFinite ||
        !cam.zoom.isFinite) {
      return;
    }
    final urls = _areaTileUrls(cam);
    if (urls.isEmpty) {
      _hint('Nothing to download for this view');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download this area?'),
        content: Text(
          'Caches up to ${urls.length} map tiles (~${_formatBytes(urls.length * _avgTileBytes)}) '
          'for offline use — the current view plus $_downloadExtraZoomLevels '
          'zoom levels of detail. Tiles you already have are skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final progress = ValueNotifier<int>(0);
    var cancelled = false;
    final total = urls.length;
    setState(() => _downloading = true);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Downloading area…'),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, done, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: total == 0 ? null : done / total,
                ),
                const SizedBox(height: 12),
                Text('$done / $total tiles'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    var downloaded = 0;
    for (var i = 0; i < urls.length; i++) {
      if (cancelled || !mounted) break;
      if (await _tileProvider.prefetch(urls[i])) downloaded++;
      progress.value = i + 1;
    }
    // Close the progress dialog unless the user already dismissed it via Cancel.
    if (!cancelled && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    progress.dispose();

    if (!mounted) return;
    setState(() => _downloading = false);
    await ref
        .read(repositoryProvider)
        .evictTilesDownTo(CachedTileProvider.maxCacheBytes);
    _hint(
      cancelled
          ? 'Download cancelled — $downloaded new tiles saved'
          : 'Downloaded $downloaded new tiles for offline use',
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Writes the current camera (centre + zoom) to settings. No-op until the map
  /// is ready or if the camera is somehow non-finite.
  void _saveCamera() {
    if (!_mapReady) return;
    final cam = _mapController.camera;
    final c = cam.center;
    if (!c.latitude.isFinite || !c.longitude.isFinite || !cam.zoom.isFinite) {
      return;
    }
    ref.read(repositoryProvider).saveCamera(c.latitude, c.longitude, cam.zoom);
  }

  /// Opt-in location. Only ever runs on an explicit button tap. Requests
  /// permission *now* (not at launch); on grant, centres the map and drops a
  /// position marker; on denial or disabled services, shows a dismissible hint
  /// and changes nothing else.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final here = await _getCurrentPosition();
      if (here == null || !mounted) return;
      setState(() {
        _myPosition = here;
        _myElevation = null;
      });
      _mapController.move(here, 14);
      unawaited(_updateMyElevation(here));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Starts or stops recording into [layer].
  ///
  /// Starting asks for location permission the same way "Locate me" does — on
  /// the tap, never before — and says so if it is refused. There is no
  /// background service behind this: recording runs while the app is open, and
  /// a gap becomes a break in the line rather than an invented straight one.
  Future<void> _toggleRecording(Layer layer) async {
    final recorder = ref.read(trackRecordingProvider.notifier);
    if (ref.read(trackRecordingProvider).isRecording) {
      recorder.stop();
      _hint('Recording stopped.');
      return;
    }
    final problem = await recorder.start(layer);
    if (problem != null) {
      _hint(problem);
      return;
    }
    _hint('Recording. Keep ZoneCraft open — it does not record in the '
        'background.');
  }

  /// "Recording · 12 points · 8 s ago". The age of the last fix is the part
  /// that matters: a recording that has stopped receiving (indoors, no signal)
  /// looks exactly like a working one otherwise.
  static String _recordingBannerText(TrackRecording r) {
    final b = StringBuffer('Recording · ');
    b.write('${r.pointCount} point${r.pointCount == 1 ? '' : 's'}');
    final last = r.lastFixAt;
    if (last == null) {
      b.write(' · waiting for a fix');
    } else {
      final secs = DateTime.now().difference(last).inSeconds;
      if (secs >= 30) b.write(' · last fix ${_ago(secs)}');
    }
    return b.toString();
  }

  static String _ago(int seconds) => seconds < 120
      ? '${seconds}s ago'
      : '${(seconds / 60).round()} min ago';

  /// Requests the device's current position, handling permission/service state
  /// with dismissible hints. Returns the fix, or null on denial / disabled
  /// services / a bad (non-finite) fix / any error. Has no side effects on the
  /// map camera — callers decide what to do with the result.
  Future<LatLng?> _getCurrentPosition() async {
    try {
      // Service + permission live in `data/location.dart`, shared with the
      // track recorder — the two used to be the same twenty lines twice.
      final problem = await ensureLocationReady();
      if (problem != null) {
        _hint(problem);
        return null;
      }

      // A time limit, because indoors or with a cold GPS `getCurrentPosition`
      // simply never returns — and the caller's `_locating` flag would keep the
      // button disabled for the rest of the session. The plugin throws
      // TimeoutException, which the catch below turns into a hint.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 20),
        ),
      );
      // Guard against a non-finite fix: a NaN LatLng would corrupt the map
      // camera and crash every subsequent projection.
      if (!pos.latitude.isFinite || !pos.longitude.isFinite) {
        _hint('Could not get a valid location fix. Try again outdoors.');
        return null;
      }
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      _hint('Could not get your location.');
      return null;
    }
  }

  void _hint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// SnackBar shown after a handle drag, offering to put the point back where it
  /// started ([revert] rewrites the original lat/lng).
  void _showMoveUndo(String what, VoidCallback revert) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$what moved'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: 'Undo', onPressed: revert),
        ),
      );
  }

  /// Toggles tap-to-measure-elevation mode. Modes are mutually exclusive by
  /// construction now, so this only has to clear the *scratch* of whichever
  /// measurement is being left behind.
  void _toggleProbe() {
    final on = _mode != MapMode.elevation;
    _enterMode(on ? MapMode.elevation : MapMode.view);
    if (on) _hint('Tap the map to measure elevation');
  }

  /// Toggles tap-two-points-to-measure-distance mode.
  void _toggleDistance() {
    final on = _mode != MapMode.distance;
    _enterMode(on ? MapMode.distance : MapMode.view);
    if (on) _hint('Tap two points to measure distance');
  }

  /// Switches the map mode, dropping the scratch state of the mode being left.
  /// Arming anything other than [MapMode.edit] also clears the selection, so a
  /// docked editor never covers a mode's banner.
  void _enterMode(MapMode mode) {
    final previous = _mode;
    if (previous == mode) return;
    setState(() {
      if (previous == MapMode.elevation) {
        _probePoint = null;
        _probeElevation = null;
      }
      if (previous == MapMode.distance) {
        _distA = null;
        _distB = null;
      }
      if (previous == MapMode.add) {
        _placeLayerId = null;
        _placeType = null;
      }
      if (previous == MapMode.draw) {
        _drawLayerId = null;
        _drawType = null;
        _stroke.clear();
        _strokePointers.clear();
        _strokeOwner = null;
      }
      if (previous == MapMode.add || previous == MapMode.draw) {
        _addSteps.clear();
      }
    });
    if (mode == MapMode.add ||
        mode == MapMode.draw ||
        mode == MapMode.elevation ||
        mode == MapMode.distance) {
      _clearSelection();
    }
    ref.read(mapModeProvider.notifier).set(mode);
  }

  /// Records [p] as the next distance endpoint: first/restart point when none
  /// or both are set, otherwise the second point.
  void _distanceTap(LatLng p) {
    setState(() {
      if (_distA == null || _distB != null) {
        _distA = p;
        _distB = null;
      } else {
        _distB = p;
      }
    });
  }

  /// Snaps the next distance endpoint to the device's current location.
  Future<void> _distanceFromMyLocation() async {
    final here = _myPosition ?? await _getCurrentPosition();
    if (here == null || !mounted) return;
    setState(() => _myPosition = here);
    _distanceTap(here);
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// Measures the terrain elevation at [p] (cache-first terrain tile) and shows
  /// it. Shares the screen's tile client.
  ///
  /// One at a time: tapping again while a probe is in flight used to start a
  /// second overlapping fetch whose result raced the first into `_probeElevation`
  /// — so an impatient double-tap could leave the *earlier* point's height on
  /// screen under the later point's marker.
  Future<void> _probeAt(LatLng p) async {
    if (_probing) return;
    setState(() {
      _probing = true;
      _probePoint = p;
      _probeElevation = null;
    });
    final e = await queryElevation(
      repo: ref.read(repositoryProvider),
      client: _tileClient,
      lat: p.latitude,
      lng: p.longitude,
      headers: const {'User-Agent': tileUserAgent},
    );
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probeElevation = e;
    });
    if (e == null) _hint('Elevation data unavailable here (offline?)');
  }

  /// Looks up and stores the elevation at the current location for the readout.
  Future<void> _updateMyElevation(LatLng p) async {
    final e = await queryElevation(
      repo: ref.read(repositoryProvider),
      client: _tileClient,
      lat: p.latitude,
      lng: p.longitude,
      headers: const {'User-Agent': tileUserAgent},
    );
    if (!mounted) return;
    setState(() => _myElevation = e);
  }

  static String _formatElevation(double meters) {
    final m = meters.round();
    final s = m.abs().toString();
    // Thousands separator for readability (e.g. 2,962 m).
    final withSep = s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (mm) => '${mm[1]},',
    );
    return '${m < 0 ? '−' : ''}$withSep m';
  }

  /// A draggable edit handle centred on [point]: drag it to move the underlying
  /// point — persisted live via [onMoved] as it moves (throttled) so the region
  /// reshapes under the finger, with a "· UNDO" offered on release — and
  /// long-press it to open a menu ([onMenu], given the handle's global screen
  /// position). The dot sits inside a generous 40 px box so it is easy to grab;
  /// [main] draws it larger/white (the subspace main point), [core] overrides the
  /// dot (e.g. a centre crosshair), and [label] shows a tiny name plate below it.
  /// [undoLabel] names the thing moved in the undo SnackBar (null suppresses it —
  /// e.g. for bounding-circle centres where there's no natural single-step undo).
  /// [onTapToggle] (vertex handles) marks the point for bulk delete, drawn with
  /// an accent ring when [marked].
  DragMarker _dragHandle(
    LatLng point, {
    required Key key,
    required void Function(LatLng) onMoved,
    bool main = false,
    String? label,
    Widget? core,
    void Function(Offset globalPos)? onMenu,
    String? undoLabel,
    bool live = true,
    bool marked = false,
    VoidCallback? onTapToggle,
    VoidCallback? onDragEnded,
  }) {
    const labelHeight = 14.0;
    const gap = 1.0;
    const coreSize = 40.0;
    const pad = gap + labelHeight;
    final hasLabel = label != null && label.isNotEmpty;
    // Equal top/bottom padding keeps the core at the box centre = the point,
    // so DragMarker's default centre alignment anchors the dot on [point].
    final width = hasLabel ? 140.0 : coreSize;
    final height = hasLabel ? coreSize + 2 * pad : coreSize;
    final dot = core ?? _editPointDot(main: main);
    return DragMarker(
      key: key,
      point: point,
      size: Size(width, height),
      onTap: onTapToggle == null ? null : (_) => onTapToggle(),
      onDragStart: (_, latlng) => _dragOrigin = latlng,
      onDragUpdate: !live
          ? null
          : (_, latlng) {
              // Persist at ~20 fps so the region redraws live without flooding
              // the DB.
              final now = DateTime.now();
              if (now.difference(_lastDragWriteAt).inMilliseconds < 50) return;
              _lastDragWriteAt = now;
              if (latlng.latitude.isFinite && latlng.longitude.isFinite) {
                onMoved(latlng);
              }
            },
      onDragEnd: (_, latlng) {
        if (!latlng.latitude.isFinite || !latlng.longitude.isFinite) return;
        onMoved(latlng);
        // Handles whose [onMoved] only touches memory persist here instead —
        // one write per completed gesture (border outline reshaping).
        onDragEnded?.call();
        final origin = _dragOrigin;
        _dragOrigin = null;
        // Only worth an undo if the point actually moved.
        if (undoLabel != null &&
            origin != null &&
            (origin.latitude != latlng.latitude ||
                origin.longitude != latlng.longitude)) {
          _showMoveUndo(undoLabel, () => onMoved(origin));
        }
      },
      onLongPress: onMenu == null
          ? null
          : (latlng) => onMenu(_globalPosOf(latlng)),
      builder: (context, pos, isDragging) {
        // Marked (for bulk delete): an accent ring around the dot.
        final core = marked
            ? Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
                child: Center(child: dot),
              )
            : dot;
        final child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasLabel) const SizedBox(height: pad),
            SizedBox(
              width: coreSize,
              height: coreSize,
              child: Center(child: core),
            ),
            if (hasLabel) ...[
              const SizedBox(height: gap),
              SizedBox(height: labelHeight, child: _markerLabel(label)),
            ],
          ],
        );
        // A slight lift while dragging gives tactile feedback.
        return isDragging ? Transform.scale(scale: 1.25, child: child) : child;
      },
    );
  }

  /// The crosshair core used for a bounding-circle centre handle (freehand-line
  /// inclusion / height region) — reads differently from the plain point dots.
  Widget _crosshairCore() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87, width: 2),
      ),
      child: const Icon(Icons.add, size: 18, color: Colors.black87),
    );
  }

  /// A handle on the east edge of a bounding circle: drag it to resize, setting
  /// the radius to its geodesic distance from [center] (applied via [onResize]
  /// on release — resize is end-only to avoid the ring chasing the finger).
  DragMarker _radiusHandle(
    LatLng center,
    double radiusMeters, {
    required Key key,
    required void Function(double meters) onResize,
  }) {
    return _dragHandle(
      _hitTest.offset(center, radiusMeters, 90), // due east of the centre
      key: key,
      live: false,
      undoLabel: null,
      core: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black87, width: 2),
        ),
        child: const Icon(Icons.open_in_full, size: 13, color: Colors.black87),
      ),
      onMoved: (ll) {
        final m = _hitTest.distance(center, ll);
        if (m.isFinite && m > 1) onResize(m);
      },
    );
  }

  /// Projects a handle's [point] to a global screen position, used to anchor a
  /// popup menu on it (DragMarker's long-press callback only reports lat/lng).
  Offset _globalPosOf(LatLng point) {
    final local = _mapController.camera.latLngToScreenOffset(point);
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(local) ?? local;
  }

  /// The decorated dot used by edit-point markers. The [main] subspace point is
  /// drawn larger and white-filled so it stands out from the others.
  Widget _editPointDot({bool main = false}) {
    final size = main ? 22.0 : 18.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: main ? Colors.white : Colors.black87,
        shape: BoxShape.circle,
        border: Border.all(
          color: main ? Colors.black87 : Colors.white,
          width: main ? 4 : 2.5,
        ),
      ),
    );
  }

  /// The tiny name plate drawn under labelled markers — small text on a faint
  /// white plate so it reads over any map colour.
  Widget _markerLabel(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            height: 1.0,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  /// One row in an on-map point menu.
  static PopupMenuItem<String> _pointMenuItem(
    String value,
    IconData icon,
    String text, {
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          // Ellipsise, don't overflow. A hit row names the object *and* its
          // subtitle, and an administrative area's is the longest text in the
          // app — "Uttenweiler · 9.91 km × 10 km · 459 points" ran 106 px past
          // the menu the first time borders became tappable.
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  /// Opens a context menu anchored at [globalPosition] with a disabled [title]
  /// header followed by [items], and returns the chosen value (or null).
  Future<String?> _showPointMenu(
    String title,
    Offset globalPosition,
    List<PopupMenuEntry<String>> items, [
    String? subtitle,
  ]) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              if (subtitle != null)
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...items,
      ],
    );
  }

  /// Prompts for a point/object name, pre-filled with [current]. Returns the new
  /// name (empty string clears it) or null if the user cancelled.
  Future<String?> _promptPointName(String title, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Leave empty to clear',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Popup menu for a long-pressed subspace point: set as main, rename, or
  /// remove (honouring the editor's invariants — keep ≥1 point and promote a new
  /// main when the current main is removed).
  Future<void> _showSubspacePointMenu(
    SubspacePoint p,
    List<SubspacePoint> siblings,
    Offset pos,
  ) async {
    final title = (p.label != null && p.label!.isNotEmpty)
        ? p.label!
        : 'Subspace point';
    final selected = await _showPointMenu(title, pos, [
      _pointMenuItem(
        'main',
        p.isMain ? Icons.check_circle : Icons.radio_button_unchecked,
        p.isMain ? 'Already the main point' : 'Set as main point',
        enabled: !p.isMain,
      ),
      _pointMenuItem('rename', Icons.label_outline, 'Rename…'),
      _pointMenuItem(
        'remove',
        Icons.remove_circle_outline,
        'Remove point',
        enabled: siblings.length > 1,
      ),
    ]);
    if (selected == null || !mounted) return;
    final repo = ref.read(repositoryProvider);
    switch (selected) {
      case 'main':
        await repo.setMainPoint(p.subspaceId, p.id);
        if (mounted) _hint('Main point updated.');
      case 'rename':
        final name = await _promptPointName('Name point', p.label);
        if (name == null || !mounted) return;
        await repo.updateSubspacePoint(
          p.id,
          label: Value(name.isEmpty ? null : name),
        );
      case 'remove':
        final wasMain = p.isMain;
        final remaining = siblings.where((q) => q.id != p.id).toList();
        await repo.deleteSubspacePoint(p.id);
        if (wasMain && remaining.isNotEmpty) {
          await repo.setMainPoint(p.subspaceId, remaining.first.id);
        }
        if (mounted) _hint('Point removed.');
    }
  }

  /// Popup menu for a long-pressed freehand vertex (line or area). Vertices have
  /// no label, so the only action is removal — guarded so a line keeps ≥2 points
  /// and an area keeps ≥3.
  Future<void> _showFreeVertexMenu(
    Offset pos, {
    required String title,
    required bool canRemove,
    required Future<void> Function() onRemove,
  }) async {
    final selected = await _showPointMenu(title, pos, [
      _pointMenuItem(
        'remove',
        Icons.remove_circle_outline,
        'Remove point',
        enabled: canRemove,
      ),
    ]);
    if (selected == 'remove' && mounted) {
      await onRemove();
      if (mounted) _hint('Point removed.');
    }
  }

  /// Popup menu for a long-pressed circle centre: rename the circle or delete it.
  Future<void> _showCircleMenu(Circle c, Offset pos) async {
    final title = (c.label != null && c.label!.isNotEmpty)
        ? c.label!
        : 'Circle';
    final selected = await _showPointMenu(title, pos, [
      _pointMenuItem('rename', Icons.label_outline, 'Rename…'),
      _pointMenuItem('delete', Icons.delete_outline, 'Delete circle'),
    ]);
    if (selected == null || !mounted) return;
    final repo = ref.read(repositoryProvider);
    switch (selected) {
      case 'rename':
        final name = await _promptPointName('Name circle', c.label);
        if (name == null || !mounted) return;
        await repo.updateCircle(c.id, label: Value(name.isEmpty ? null : name));
      case 'delete':
        await repo.deleteCircle(c.id);
        if (mounted) _hint('Circle deleted.');
    }
  }

  /// Popup menu for a long-pressed plane endpoint: rename the plane, swap which
  /// side is included, or delete it.
  Future<void> _showPlaneMenu(Plane pl, Offset pos) async {
    final title = (pl.label != null && pl.label!.isNotEmpty)
        ? pl.label!
        : 'Plane';
    final selected = await _showPointMenu(title, pos, [
      _pointMenuItem('rename', Icons.label_outline, 'Rename…'),
      _pointMenuItem('swap', Icons.swap_horiz, 'Swap included side'),
      _pointMenuItem('delete', Icons.delete_outline, 'Delete plane'),
    ]);
    if (selected == null || !mounted) return;
    final repo = ref.read(repositoryProvider);
    switch (selected) {
      case 'rename':
        final name = await _promptPointName('Name plane', pl.label);
        if (name == null || !mounted) return;
        await repo.updatePlane(pl.id, label: Value(name.isEmpty ? null : name));
      case 'swap':
        await repo.updatePlane(pl.id, nearA: !pl.nearA);
        if (mounted) _hint('Included side swapped.');
      case 'delete':
        await repo.deletePlane(pl.id);
        if (mounted) _hint('Plane deleted.');
    }
  }

  /// A default radius (metres) scaled so a new circle is visible at the current
  /// zoom: roughly 15% of the visible map width.
  ///
  /// Uses Haversine (not the default Vincenty, which returns NaN for the
  /// near-antipodal edges of a zoomed-out viewport) and guards the result so a
  /// circle is never created with a non-finite radius.
  double _defaultRadius() {
    const fallback = 1000.0;
    final cam = _mapController.camera;
    final bounds = cam.visibleBounds;
    final widthMeters = const Distance(calculator: Haversine()).as(
      LengthUnit.Meter,
      LatLng(cam.center.latitude, bounds.west),
      LatLng(cam.center.latitude, bounds.east),
    );
    if (!widthMeters.isFinite || widthMeters <= 0) return fallback;
    return (widthMeters * 0.15).clamp(10.0, 2000000.0);
  }

  /// Clears every selection + armed placement (shared with the layers drawer,
  /// see `clearSelection`), then drops this screen's own vertex marks.
  void _clearSelection() {
    clearSelection(ref);
    // Marks belong to the object being edited; drop them when it deselects.
    if (_markedPoints.isNotEmpty) _markedPoints.clear();
  }

  /// Toggles whether [pointId] is marked for bulk delete.
  void _toggleMarked(String pointId) {
    setState(() {
      if (!_markedPoints.remove(pointId)) _markedPoints.add(pointId);
    });
  }

  /// Deletes every marked vertex of the selected object at once, keeping the
  /// type's minimum (subspace ≥1, line ≥2, area ≥3) — refuses (with a hint) if
  /// the deletion would drop below it. Promotes a new subspace main if needed.
  Future<void> _deleteMarked() async {
    final repo = ref.read(repositoryProvider);
    final marked = _markedPoints.toList();
    if (marked.isEmpty) return;
    final subId = ref.read(selectedSubspaceProvider);
    final lineId = ref.read(selectedFreeLineProvider);
    final areaId = ref.read(selectedFreeAreaProvider);
    if (subId != null) {
      final pts = (ref.read(subspacePointsProvider).asData?.value ?? const [])
          .where((p) => p.subspaceId == subId)
          .toList();
      final toDelete = pts.where((p) => _markedPoints.contains(p.id)).toList();
      if (pts.length - toDelete.length < 1) {
        _hint('Keep at least one point.');
        return;
      }
      final removingMain = toDelete.any((p) => p.isMain);
      for (final p in toDelete) {
        await repo.deleteSubspacePoint(p.id);
      }
      if (removingMain) {
        final remaining = pts
            .where((p) => !_markedPoints.contains(p.id))
            .toList();
        if (remaining.isNotEmpty) {
          await repo.setMainPoint(subId, remaining.first.id);
        }
      }
    } else if (lineId != null) {
      final pts = (ref.read(freeLinePointsProvider).asData?.value ?? const [])
          .where((p) => p.freeLineId == lineId)
          .toList();
      final toDelete = pts.where((p) => _markedPoints.contains(p.id)).toList();
      if (pts.length - toDelete.length < 2) {
        _hint('Keep at least two points.');
        return;
      }
      for (final p in toDelete) {
        await repo.deleteFreeLinePoint(p.id);
      }
    } else if (areaId != null) {
      final pts = (ref.read(freeAreaPointsProvider).asData?.value ?? const [])
          .where((p) => p.freeAreaId == areaId)
          .toList();
      final toDelete = pts.where((p) => _markedPoints.contains(p.id)).toList();
      if (pts.length - toDelete.length < 3) {
        _hint('Keep at least three points.');
        return;
      }
      for (final p in toDelete) {
        await repo.deleteFreeAreaPoint(p.id);
      }
    }
    setState(() => _markedPoints.clear());
    if (mounted) _hint('${marked.length} points removed.');
  }

  /// Selects one object of [kind], clearing every other selection and this
  /// screen's vertex marks.
  void _select(ObjectKind kind, String id) {
    if (_markedPoints.isNotEmpty) _markedPoints.clear();
    selectObject(ref, kind, id);
  }

  void _selectCircle(String id) => _select(ObjectKind.circle, id);

  void _selectPlane(String id) => _select(ObjectKind.plane, id);

  void _selectSubspace(String id) => _select(ObjectKind.subspace, id);

  void _selectFreeLine(String id) => _select(ObjectKind.freeLine, id);

  void _selectFreeArea(String id) => _select(ObjectKind.freeArea, id);

  void _selectHeightRegion(String id) => _select(ObjectKind.heightRegion, id);

  /// Adds a height region to [layer] at [center] (un-generated — the editor's
  /// Generate fills it). A sensible default radius scales with the current zoom.
  /// Returns its id; [select] opens its editor (off while Add mode is sticky).
  Future<String> _addHeightRegionAt(
    LatLng center,
    Layer layer, {
    bool select = true,
  }) async {
    final id = await ref
        .read(repositoryProvider)
        .createHeightRegion(
          layerId: layer.id,
          centerLat: center.latitude,
          centerLng: center.longitude,
          radiusMeters: _defaultRadius().clamp(100.0, 25000.0),
        );
    if (select) _selectHeightRegion(id);
    return id;
  }

  Future<String> _addCircleAt(
    LatLng latlng,
    Layer layer, {
    bool select = true,
  }) async {
    final id = await ref
        .read(repositoryProvider)
        .createCircle(
          layerId: layer.id,
          centerLat: latlng.latitude,
          centerLng: latlng.longitude,
          radiusMeters: _defaultRadius(),
        );
    if (select) _selectCircle(id);
    return id;
  }

  /// Imports nearby POIs into [layer]: prompts for a category + radius,
  /// fetches POIs of that type around the map centre **once**, then creates —
  /// per layer type — one named circle per POI (circles), appended named
  /// points (subspace; the nearest-to-centre promotes to main when the
  /// subspace has none yet), or a stored offline POI set with markers (poi).
  /// The search centre defaults to the map centre; Add mode passes the tap.
  Future<void> _importPois(Layer layer, {LatLng? at}) async {
    final isCircleLayer = layer.type == 'circles';
    final isPoiLayer = layer.type == 'poi';
    final config = await showPoiImportDialog(
      context,
      needsCircleRadius: isCircleLayer,
      allCategories: isPoiLayer,
    );
    if (config == null || !mounted) return;

    final center = at ?? _mapController.camera.center;
    final r = config.searchRadiusMeters;
    // Bounding box from the centre + search radius (N/S/E/W offsets).
    final north = _hitTest.offset(center, r, 0).latitude;
    final south = _hitTest.offset(center, r, 180).latitude;
    final east = _hitTest.offset(center, r, 90).longitude;
    final west = _hitTest.offset(center, r, -90).longitude;

    // Same spinner transit and borders use: a public Overpass instance can sit
    // on a request for a minute, and an unexplained frozen UI is what that
    // looked like before.
    final cancel = OverpassCancel();
    final progress = showImportProgress(
      context,
      title: 'Importing ${config.category.label.toLowerCase()}',
      message: 'Preparing the query…',
      onCancel: cancel.cancel,
    );
    final repoForEndpoint = ref.read(repositoryProvider);
    final settings = ref.read(settingsProvider).asData?.value;
    final elapsed = Stopwatch()..start();
    final OverpassOutcome<List<PoiResult>> outcome;
    try {
      outcome = await fetchPois(
        south: south,
        west: west,
        north: north,
        east: east,
        categories: [config.category],
        client: _tileClient,
        preferEndpoint: settings?.transitEndpoint,
        onProgress: progress.report,
        cancel: cancel,
      );
    } finally {
      progress.close(); // idempotent; guarantees the spinner never sticks
    }
    if (!mounted) return;
    if (outcome.cancelled) {
      _hint('Import cancelled.');
      return;
    }
    if (!outcome.ok) {
      _hint(outcome.message!);
      return;
    }
    _rememberEndpoint(
      repoForEndpoint,
      outcome.endpoint,
      settings?.transitEndpoint,
      elapsed.elapsed,
    );
    final fetched = outcome.value!;
    // A POI layer stores everything the fetch returned (up to the Overpass
    // cap); circle/subspace seeding keeps the default tighter cap so the
    // created geometry stays manageable.
    final within = poisWithinRadius(
      center.latitude,
      center.longitude,
      r,
      fetched,
      cap: isPoiLayer ? overpassResultCap : 60,
    );
    final label = config.category.label.toLowerCase();
    if (within.isEmpty) {
      _hint('No $label found within ${r.round()} m.');
      return;
    }

    final repo = ref.read(repositoryProvider);
    if (isPoiLayer) {
      // Stored as-is (unnamed POIs stay unnamed — the icon carries the type),
      // bounded to the searched circle so the import is a single offline set.
      final sid = await repo.createPoiSet(
        layerId: layer.id,
        categoryKey: config.category.key,
        centerLat: center.latitude,
        centerLng: center.longitude,
        radiusMeters: r,
        label: config.category.label,
      );
      final tally = await repo.addPoiPoints(sid, within);
      // Everything was already here, so the set would be an empty row that
      // draws nothing — drop it rather than leave litter behind.
      if (tally.added == 0) await repo.deletePoiSet(sid);
      if (mounted) _hint(describeImportTally(tally, label));
      return;
    }

    // Many OSM categories (benches, post boxes, toilets…) carry no `name` tag,
    // so fall back to the category plus an index — every imported POI is named.
    String labelFor(int i) =>
        within[i].name ?? '${config.category.label} ${i + 1}';

    if (isCircleLayer) {
      for (var i = 0; i < within.length; i++) {
        await repo.createCircle(
          layerId: layer.id,
          centerLat: within[i].lat,
          centerLng: within[i].lng,
          radiusMeters: config.circleRadiusMeters!,
          label: labelFor(i),
        );
      }
      if (mounted) _hint('Imported ${within.length} $label as circles.');
      return;
    }

    // Subspace: append to the layer's existing object, or create one.
    final subspaces =
        ref.read(subspacesProvider).asData?.value ?? const <Subspace>[];
    final points =
        ref.read(subspacePointsProvider).asData?.value ??
        const <SubspacePoint>[];
    final existing = subspaces.where((s) => s.layerId == layer.id).firstOrNull;
    final subId = existing?.id ?? await repo.createSubspace(layerId: layer.id);
    var hasMain = points.any((pt) => pt.subspaceId == subId && pt.isMain);
    // `within` is nearest-first, so the first point promotes to main when none.
    for (var i = 0; i < within.length; i++) {
      final makeMain = !hasMain;
      await repo.addSubspacePoint(
        subspaceId: subId,
        lat: within[i].lat,
        lng: within[i].lng,
        isMain: makeMain,
        label: labelFor(i),
      );
      if (makeMain) hasMain = true;
    }
    if (!mounted) return;
    _selectSubspace(subId);
    _hint(
      'Seeded ${within.length} $label '
      '(tap ● to mark the nearest).',
    );
  }

  /// The Add button's label for a layer type. A nested ternary got unreadable
  /// at seven types; this is the same mapping as a switch.
  static String _addFabLabel(String? type) => switch (type) {
    'poi' => 'Import POIs',
    'transit' => 'Import transit',
    'borders' => 'Import borders',
    'subspace' => 'Add subspace',
    'freeline' => 'Add line',
    'freearea' => 'Add area',
    'height' => 'Add height area',
    'planes' => 'Add plane',
    _ => 'Add circle',
  };

  /// The four lat/lng-axis-aligned corners spanned by two opposite points.
  /// `Polygon` closes itself, so the first vertex is not repeated.
  static List<LatLng> _bboxRing(LatLng a, LatLng b) {
    final s = math.min(a.latitude, b.latitude);
    final n = math.max(a.latitude, b.latitude);
    final w = math.min(a.longitude, b.longitude);
    final e = math.max(a.longitude, b.longitude);
    return [LatLng(s, w), LatLng(s, e), LatLng(n, e), LatLng(n, w)];
  }

  /// Imports every public-transport **station** in [box] into [layer], once,
  /// offline. One cheap Overpass query — see `data/transit.dart` for why line
  /// geometry is not fetched.
  ///
  /// The set row is written **before** the fetch, so a failure leaves a retry
  /// row on the layer instead of a snackbar the user might miss.
  Future<void> _importTransit(Layer layer, {required LatLngBounds box}) async {
    final config = await showTransitImportDialog(context, initial: box);
    if (config == null || !mounted) return;
    await _runTransitImport(
      layerId: layer.id,
      south: config.south,
      west: config.west,
      north: config.north,
      east: config.east,
      diagonalMeters: config.diagonalMeters,
      modeMask: config.modeMask,
    );
  }

  /// Retries an import that didn't finish, using the box **and the types** it
  /// remembered — a retry has to ask the same question, or the row would come
  /// back holding something other than what was asked for.
  Future<void> retryTransitImport(TransitSet set) {
    return _runTransitImport(
      layerId: set.layerId,
      south: set.south,
      west: set.west,
      north: set.north,
      east: set.east,
      diagonalMeters: bboxDiagonalMeters(
        set.south,
        set.west,
        set.north,
        set.east,
      ),
      modeMask: set.modeMask,
      existingSetId: set.id,
    );
  }

  Future<void> _runTransitImport({
    required String layerId,
    required double south,
    required double west,
    required double north,
    required double east,
    required double diagonalMeters,
    required int modeMask,
    String? existingSetId,
  }) async {
    final repo = ref.read(repositoryProvider);
    final setId =
        existingSetId ??
        await repo.createPendingTransitSet(
          layerId: layerId,
          south: south,
          west: west,
          north: north,
          east: east,
          modeMask: modeMask,
          // Never show what wasn't fetched; within that, a city-sized import
          // still starts with buses hidden so it doesn't open as a wall of pins.
          visibleModeMask: modeMask & defaultVisibleModes(diagonalMeters),
        );
    if (!mounted) return;

    // The handle is captured, so the spinner is dismissed by identity rather
    // than by popping whatever happens to be on top of the ambient navigator.
    final cancel = OverpassCancel();
    final progress = showImportProgress(
      context,
      title: 'Importing transit stations',
      message: diagonalMeters > kTransitRegionalMaxMeters
          ? 'A large area can take a minute…'
          : 'Preparing the query…',
      onCancel: cancel.cancel,
    );
    final elapsed = Stopwatch()..start();
    try {
      final settings = ref.read(settingsProvider).asData?.value;
      final outcome = await fetchTransitStations(
        south: south,
        west: west,
        north: north,
        east: east,
        modeMask: modeMask,
        client: _tileClient,
        preferEndpoint: settings?.transitEndpoint,
        onProgress: progress.report,
        cancel: cancel,
      );

      if (outcome.cancelled) {
        // Nothing went wrong, so nothing may be recorded as having gone wrong:
        // a set this import created is removed, while a retry of an existing
        // row leaves that row exactly as it found it.
        if (existingSetId == null) await repo.deleteTransitSet(setId);
        progress.close();
        if (!mounted) return;
        _hint('Import cancelled.');
        return;
      }
      if (!outcome.ok) {
        await repo.markTransitImportFailed(setId, outcome.message!);
        progress.close();
        if (!mounted) return;
        _hint('${outcome.message!} It\'s saved — retry it from Elements.');
        return;
      }
      _rememberEndpoint(
        repo,
        outcome.endpoint,
        settings?.transitEndpoint,
        elapsed.elapsed,
      );

      final stations = outcome.value!;
      progress.update('Saving ${stations.length} stations…');
      final tally = await repo.fillTransitSet(setId, [
        for (final s in stations)
          (
            osmId: s.osmId,
            lat: s.lat,
            lng: s.lng,
            name: s.name,
            modeMask: s.modeMask,
            nodeCount: s.nodeCount,
            routeRef: s.routeRef,
          ),
      ]);
      progress.close();
      if (!mounted) return;
      if (stations.isEmpty) {
        _hint(
          modeMask == transitAllModesMask
              ? 'No transit stations found in that area.'
              : 'No ${transitModeLabels(modeMask).toLowerCase()} stations found '
                    'in that area.',
        );
        return;
      }
      // Everything this box holds is already on the layer from an earlier,
      // overlapping import. Say so plainly — the map does not change, so
      // silence would read as a failed import.
      if (tally.allSkipped) {
        _hint(describeImportTally(tally, 'stations'));
        return;
      }
      // Hidden *within what was imported* — saying "bus hidden" about buses
      // that were never fetched would send people to a filter that can't help.
      final hidden =
          modeMask &
          ~(await repo.watchAllTransitSets().first)
              .firstWhere((t) => t.id == setId)
              .visibleModeMask;
      _hint(
        hidden == 0
            ? describeImportTally(tally, 'stations')
            : '${describeImportTally(tally, 'stations')} '
                  '${transitModeLabels(hidden).toLowerCase()} hidden for now '
                  '(Stations… to show).',
      );
    } catch (e) {
      // A write failure used to become an unhandled async error with no
      // message at all. Say so, and leave the retry row behind.
      await repo.markTransitImportFailed(setId, 'Could not save the import.');
      progress.close();
      if (mounted) _hint('Could not save the import — retry from Elements.');
    } finally {
      progress.close(); // idempotent; guarantees the spinner never sticks
    }
  }

  /// Remembers the instance that answered, so the next import can skip one that
  /// is down — but **only if it answered quickly**.
  ///
  /// A slow instance that merely finished is not a good default: pinning to it
  /// made every later import take minutes. See [kOverpassPreferenceMaxElapsed].
  static void _rememberEndpoint(
    Repository repo,
    String? endpoint,
    String? current,
    Duration elapsed,
  ) {
    if (endpoint == null || endpoint == current) return;
    if (elapsed > kOverpassPreferenceMaxElapsed) return;
    unawaited(repo.updateTransitEndpoint(endpoint));
  }

  /// Imports every administrative area of [layer]'s level intersecting [box],
  /// once, offline.
  ///
  /// Whole relations come down — the only shape that yields a fillable
  /// interior — and are assembled, clipped to the box, and thinned in an
  /// isolate before anything is written. Nothing is written until that
  /// succeeds: unlike a transit import there is no retry row, because
  /// re-running this is two taps and a half-written set would carry no less
  /// state than the query itself.
  Future<void> _importBorders(Layer layer, {required LatLngBounds box}) async {
    final level = borderLevelByAdminLevel(layer.borderLevel);
    if (level == null) {
      _hint('This layer has no border level set — make a new borders layer.');
      return;
    }
    final config = await showBorderImportDialog(
      context,
      initial: box,
      level: level,
    );
    if (config == null || !mounted) return;

    final repo = ref.read(repositoryProvider);
    final cancel = OverpassCancel();
    final progress = showImportProgress(
      context,
      title: 'Importing ${level.label.toLowerCase()}',
      message: 'Preparing the query…',
      onCancel: cancel.cancel,
    );
    final elapsed = Stopwatch()..start();
    try {
      final settings = ref.read(settingsProvider).asData?.value;
      final outcome = await fetchBorderAreas(
        south: config.south,
        west: config.west,
        north: config.north,
        east: config.east,
        adminLevel: level.adminLevel,
        client: _tileClient,
        preferEndpoint: settings?.transitEndpoint,
        onProgress: progress.report,
        cancel: cancel,
      );
      if (outcome.cancelled) {
        progress.close();
        if (mounted) _hint('Import cancelled.');
        return;
      }
      if (!outcome.ok) {
        progress.close();
        if (mounted) _hint(outcome.message!);
        return;
      }
      _rememberEndpoint(
        repo,
        outcome.endpoint,
        settings?.transitEndpoint,
        elapsed.elapsed,
      );

      // Assemble → clip → simplify off the UI thread: a state-level import is
      // over 100 000 points through RDP.
      final relations = outcome.value!;
      progress.update(
        'Building ${relations.length} '
        'area${relations.length == 1 ? '' : 's'} — stitching and thinning…',
      );
      final built = await compute(buildBorderAreas, relations);
      // The isolate can't be interrupted, so Cancel pressed during the stitch
      // is honoured the moment it returns: the work is thrown away rather than
      // written. Nothing has touched the database yet at this point.
      if (cancel.isCancelled) {
        progress.close();
        if (mounted) _hint('Import cancelled.');
        return;
      }
      if (built.isEmpty) {
        progress.close();
        // Overpass matches a relation when one of its *members* is in the box,
        // so a box sitting wholly inside one municipality matches nothing at
        // all. That reads as a bug unless the message says what to do about it.
        if (mounted) {
          _hint(
            'No ${level.label.toLowerCase()} found — the box has to reach '
            'a boundary, not sit inside one. Try a wider area.',
          );
        }
        return;
      }

      progress.update(
        'Saving ${built.length} areas '
        '(${totalPointCount(built)} points) and colouring them…',
      );
      final result = await repo.addBorderSet(
        layerId: layer.id,
        south: config.south,
        west: config.west,
        north: config.north,
        east: config.east,
        adminLevel: level.adminLevel,
        areas: [
          for (final a in built)
            (
              osmId: a.osmId,
              name: a.name,
              south: a.south,
              west: a.west,
              north: a.north,
              east: a.east,
              labelLat: a.labelLat,
              labelLng: a.labelLng,
              pointCount: a.pointCount,
              rings: a.rings,
              wayIds: a.wayIds,
            ),
        ],
      );
      progress.close();
      if (!mounted) return;
      final tally = result.tally;
      _hint(
        layer.borderFillAreas || tally.allSkipped
            ? describeImportTally(tally, 'areas')
            : '${describeImportTally(tally, 'areas')} Colour areas in the '
                  'layer menu to fill them.',
      );
    } catch (e) {
      progress.close();
      if (mounted) _hint('Could not save the import.');
    } finally {
      progress.close(); // idempotent; guarantees the spinner never sticks
    }
  }

  Future<void> _addPlaneAt(LatLng center, Layer layer) async {
    // Seed A and B offset west/east of the map centre, so the new plane is
    // immediately visible with its dividing line through the centre.
    final dist = _defaultRadius();
    final a = _hitTest.offset(center, dist, -90); // west
    final b = _hitTest.offset(center, dist, 90); // east
    final id = await ref
        .read(repositoryProvider)
        .createPlane(
          layerId: layer.id,
          aLat: a.latitude,
          aLng: a.longitude,
          bLat: b.latitude,
          bLng: b.longitude,
        );
    _selectPlane(id);
  }

  /// Adds to a subspace layer: a point to the layer's existing object, or a new
  /// object seeded with a main point at [center] plus two flanking points (so
  /// the main cell is immediately visible). Selects the object either way.
  /// The pre-mode "add at the map centre" path, kept as the Add FAB's
  /// long-press: creates one object from a fixed seed around the map centre and
  /// opens its editor. Useful one-handed, and the only route that doesn't need
  /// you to aim.
  void _addAtMapCentre(
    Layer layer, {
    required List<Subspace> subspaces,
    required List<FreeLine> freeLines,
    required List<FreeArea> freeAreas,
  }) {
    final c = _mapController.camera.center;
    switch (layer.type) {
      case 'poi':
        _importPois(layer);
      case 'transit':
        // The no-aim analogue of two corner taps: import what you can see.
        _importTransit(layer, box: _mapController.camera.visibleBounds);
      case 'borders':
        _importBorders(layer, box: _mapController.camera.visibleBounds);
      case 'subspace':
        _addSubspaceAt(c, layer, subspaces);
      case 'freeline':
        _addFreeLineAt(c, layer, freeLines);
      case 'freearea':
        _addFreeAreaAt(c, layer, freeAreas);
      case 'height':
        _addHeightRegionAt(c, layer);
      case 'planes':
        _addPlaneAt(c, layer);
      default:
        _addCircleAt(c, layer);
    }
  }

  /// Arms Add mode for [layer]: from now on every map tap places something of
  /// that layer's type, until Done. Clears any selection so the banner and the
  /// map are unobstructed.
  void _enterAddMode(Layer layer) {
    _enterMode(MapMode.add);
    setState(() {
      _placeLayerId = layer.id;
      _placeType = layer.type;
      _pendingPlaneA = null;
      _pendingBoxA = null;
      _addSteps.clear();
    });
    _hint(_addBannerText(layer.type, 0));
  }

  /// What Done does. With an import corner already buffered it **commits the
  /// box you can see** — the rubber band runs from that corner to the map
  /// centre, so discarding it on Done would throw away the thing being aimed.
  /// It is also the one path to an import that no gesture can swallow.
  Future<void> _finishAdd() async {
    final a = _pendingBoxA;
    if (a != null && _isBoxImport(_placeType)) {
      final layerId = _placeLayerId;
      final layer = (ref.read(layersProvider).asData?.value ?? const <Layer>[])
          .where((l) => l.id == layerId)
          .firstOrNull;
      final b = _mapController.camera.center;
      setState(() => _pendingBoxA = null);
      _exitAddMode();
      if (layer != null) await _importBox(layer, LatLngBounds(a, b));
      return;
    }
    _exitAddMode();
  }

  /// The layer types whose Add mode marks two opposite corners of an import
  /// box, rather than placing an object per tap.
  static bool _isBoxImport(String? type) =>
      type == 'transit' || type == 'borders';

  /// Runs whichever box import [layer] is for.
  Future<void> _importBox(Layer layer, LatLngBounds box) =>
      layer.type == 'borders'
      ? _importBorders(layer, box: box)
      : _importTransit(layer, box: box);

  /// Leaves Add mode. For the point-set types the object just built is selected
  /// (so its editor and draggable handles appear) — the long-standing "Done ⇒
  /// now edit it" behaviour.
  void _exitAddMode() {
    final layerId = _placeLayerId;
    final type = _placeType;
    final lastPlaced = _addSteps.lastOrNull?.object;
    setState(() {
      _placeLayerId = null;
      _placeType = null;
      _pendingPlaneA = null;
      _pendingBoxA = null;
      _addSteps.clear();
    });
    ref.read(mapModeProvider.notifier).set(MapMode.view);
    if (layerId == null) return;
    switch (type) {
      case 'subspace':
        final o = (ref.read(subspacesProvider).asData?.value ?? const [])
            .where((s) => s.layerId == layerId)
            .firstOrNull;
        if (o != null) _selectSubspace(o.id);
      case 'freeline':
        final o = (ref.read(freeLinesProvider).asData?.value ?? const [])
            .where((l) => l.layerId == layerId)
            .firstOrNull;
        if (o != null) _selectFreeLine(o.id);
      case 'freearea':
        final o = (ref.read(freeAreasProvider).asData?.value ?? const [])
            .where((a) => a.layerId == layerId)
            .firstOrNull;
        if (o != null) _selectFreeArea(o.id);
      case 'height':
        // A height area is inert until Generate has run, so a Done that closed
        // everything left a bare circle drawn on the map with nothing to say
        // what was missing — which is what "Add and Edit seem swapped" meant.
        // Unlike the point-set types a layer holds several, so this is the one
        // just placed, not the layer's first.
        if (lastPlaced != null) _selectHeightRegion(lastPlaced.id);
    }
  }

  /// Records one placement so the banner can Undo it and "Edit last" can open
  /// the object it belongs to.
  void _pushAddStep(ObjectRef object, Future<void> Function() undo) {
    setState(() => _addSteps.add((object: object, undo: undo)));
  }

  /// Arms Draw mode for [layer]: one finger now draws a freehand line/area
  /// instead of panning the map. Sticky like Add mode — each stroke becomes one
  /// object and the mode stays on until Done.
  void _enterDrawMode(Layer layer) {
    _enterMode(MapMode.draw);
    setState(() {
      _drawLayerId = layer.id;
      _drawType = layer.type;
    });
    _hint(_drawBannerText(0));
  }

  /// Leaves Draw mode, selecting the last stroke so its handles and editor
  /// appear — the same "Done ⇒ now edit it" contract Add mode has, and the
  /// point of drawing into ordinary freehand objects in the first place.
  void _finishDraw() {
    final last = _addSteps.lastOrNull?.object;
    setState(() {
      _drawLayerId = null;
      _drawType = null;
      _stroke.clear();
      _strokePointers.clear();
      _strokeOwner = null;
      _addSteps.clear();
    });
    ref.read(mapModeProvider.notifier).set(MapMode.view);
    if (last != null) _select(last.kind, last.id);
  }

  String _drawBannerText(int drawn) {
    final noun = _drawType == 'freearea' ? 'area' : 'line';
    if (drawn > 0) {
      return '$drawn $noun${drawn == 1 ? '' : 's'} · draw another';
    }
    return 'Drag one finger to draw · two fingers pan';
  }

  // --- Draw mode gestures ---------------------------------------------------
  // Raw pointer events, not a gesture recogniser: flutter_map owns the gesture
  // arena for pan/pinch, and a [Listener] sees every pointer regardless of who
  // wins there. One-finger drag is disabled on the map while drawing (see
  // [_interactionOptions]), so the two never fight over the same finger.

  void _strokeDown(PointerDownEvent e) {
    _strokePointers.add(e.pointer);
    if (_strokePointers.length > 1) {
      // A second finger means pan/pinch. Abandon the stroke rather than commit
      // a half-drawn shape the user never meant to leave behind.
      _strokeOwner = null;
      _stroke.clear();
      _strokeRevision.value++;
      return;
    }
    _strokeOwner = e.pointer;
    _stroke
      ..clear()
      ..add(e.localPosition);
    _strokeRevision.value++;
  }

  void _strokeMove(PointerMoveEvent e) {
    if (e.pointer != _strokeOwner) return;
    _stroke.add(e.localPosition);
    _strokeRevision.value++;
  }

  Future<void> _strokeUp(PointerEvent e) async {
    _strokePointers.remove(e.pointer);
    if (e.pointer != _strokeOwner) return;
    _strokeOwner = null;
    final stroke = List<Offset>.of(_stroke);
    _stroke.clear();
    _strokeRevision.value++;
    await _commitStroke(stroke);
  }

  /// Writes one finished stroke as an ordinary freehand object, so every
  /// existing affordance — drag handles, insert/reorder points, offset, export
  /// — works on it with no special cases.
  Future<void> _commitStroke(List<Offset> stroke) async {
    final layerId = _drawLayerId;
    if (layerId == null || !mounted) return;
    final closed = _drawType == 'freearea';
    final pts = strokeToPoints(stroke, _mapController.camera, closed: closed);
    // A tap or a twitch: silently nothing. Saying "too short" after every
    // stray touch would be noisier than the mistake.
    if (pts == null) return;
    final repo = ref.read(repositoryProvider);
    if (closed) {
      final id = await repo.createFreeArea(layerId: layerId);
      await repo.addFreeAreaPoints(id, pts);
      _pushAddStep(
        ObjectRef(kind: ObjectKind.freeArea, id: id, layerId: layerId),
        () => repo.deleteFreeArea(id),
      );
    } else {
      // A freehand line splits an inclusion circle, so the circle has to be
      // *visible at the zoom the stroke was drawn at*. The stored-null default
      // won't do: `effectiveInclusion` caps its derived radius at 5 km, which is
      // right for a whole-river import (it would otherwise derive a
      // continent-sized circle) and wrong here, where a stroke across the screen
      // would come back as a sub-pixel dot. The stroke can't be bigger than the
      // viewport, so its own size is a safe radius — floored by the usual
      // viewport-relative default for a short one.
      final inc = effectiveInclusion(
        lat: null,
        lng: null,
        radiusMeters: null,
        points: pts,
      );
      final radius = math.max(
        ViewBound.ofCorners(pts).diagonalMeters * 0.75,
        _defaultRadius(),
      );
      final id = await repo.createFreeLine(
        layerId: layerId,
        inclusionLat: inc.center.latitude,
        inclusionLng: inc.center.longitude,
        inclusionRadiusMeters: radius,
      );
      await repo.addFreeLinePoints(id, pts);
      _pushAddStep(
        ObjectRef(kind: ObjectKind.freeLine, id: id, layerId: layerId),
        () => repo.deleteFreeLine(id),
      );
    }
  }

  /// Undoes the most recent placement of this Add session (a pending plane
  /// point A first, since it isn't committed yet).
  Future<void> _undoLastAdd() async {
    if (_pendingPlaneA != null || _pendingBoxA != null) {
      setState(() {
        _pendingPlaneA = null;
        _pendingBoxA = null;
      });
      return;
    }
    if (_addSteps.isEmpty) return;
    final step = _addSteps.last;
    setState(() => _addSteps.removeLast());
    await step.undo();
  }

  /// Leaves Add mode and opens the editor for the object placed last.
  void _editLastAdded() {
    final object = _addSteps.lastOrNull?.object;
    setState(() {
      _placeLayerId = null;
      _placeType = null;
      _pendingPlaneA = null;
      _pendingBoxA = null;
      _addSteps.clear();
    });
    ref.read(mapModeProvider.notifier).set(MapMode.view);
    if (object != null) _select(object.kind, object.id);
  }

  /// What the Add banner says for [layerType] after [placed] taps.
  ///
  /// The count comes **first** so it survives when the row runs out of width
  /// and the prose ellipsises — the count is the part that changes.
  String _addBannerText(String? layerType, int placed) {
    if (layerType == 'poi') return 'Tap the search centre';
    if (_isBoxImport(layerType)) {
      // Once a corner is down the rubber band tracks the map centre, so Done is
      // a real second way to finish — say so, rather than leaving it looking
      // like "cancel".
      return _pendingBoxA == null
          ? 'Tap one corner of the area'
          : 'Tap the opposite corner · or Done for the centre';
    }
    if (layerType == 'planes' && _pendingPlaneA != null) {
      return 'Tap point B';
    }
    if (placed > 0) return '$placed added · tap for more';
    return switch (layerType) {
      'planes' => 'Tap point A, then B',
      'subspace' || 'freeline' || 'freearea' => 'Tap to drop points',
      'height' => 'Tap to place a height area',
      _ => 'Tap the map to add a circle',
    };
  }

  /// Places one thing at [latlng] while Add mode is armed. Sticky: the mode
  /// stays on afterwards so several objects can be dropped in a row.
  Future<void> _addTapAt(LatLng latlng) async {
    final layerId = _placeLayerId;
    if (layerId == null) return;
    final layer = (ref.read(layersProvider).asData?.value ?? const <Layer>[])
        .where((l) => l.id == layerId)
        .firstOrNull;
    if (layer == null) {
      _exitAddMode(); // the layer was deleted under us
      return;
    }
    final repo = ref.read(repositoryProvider);
    switch (layer.type) {
      case 'circles':
        final id = await _addCircleAt(latlng, layer, select: false);
        _pushAddStep(
          ObjectRef(kind: ObjectKind.circle, id: id, layerId: layer.id),
          () => repo.deleteCircle(id),
        );
      case 'height':
        final id = await _addHeightRegionAt(latlng, layer, select: false);
        _pushAddStep(
          ObjectRef(kind: ObjectKind.heightRegion, id: id, layerId: layer.id),
          () => repo.deleteHeightRegion(id),
        );
      case 'planes':
        // Two taps per plane: the first is buffered (and shown as a pin).
        final a = _pendingPlaneA;
        if (a == null) {
          setState(() => _pendingPlaneA = latlng);
          return;
        }
        setState(() => _pendingPlaneA = null);
        final id = await repo.createPlane(
          layerId: layer.id,
          aLat: a.latitude,
          aLng: a.longitude,
          bLat: latlng.latitude,
          bLng: latlng.longitude,
        );
        _pushAddStep(
          ObjectRef(kind: ObjectKind.plane, id: id, layerId: layer.id),
          () => repo.deletePlane(id),
        );
      case 'subspace':
        final existing = (ref.read(subspacesProvider).asData?.value ?? const [])
            .where((s) => s.layerId == layerId)
            .firstOrNull;
        if (existing == null) {
          final id = await repo.createSubspace(layerId: layerId);
          await repo.addSubspacePoint(
            subspaceId: id,
            lat: latlng.latitude,
            lng: latlng.longitude,
            isMain: true,
          );
          // The first tap made the object too, so undoing it removes both.
          _pushAddStep(
            ObjectRef(kind: ObjectKind.subspace, id: id, layerId: layerId),
            () => repo.deleteSubspace(id),
          );
        } else {
          final pid = await repo.addSubspacePoint(
            subspaceId: existing.id,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
          _pushAddStep(
            ObjectRef(
              kind: ObjectKind.subspace,
              id: existing.id,
              layerId: layerId,
            ),
            () => repo.deleteSubspacePoint(pid),
          );
        }
      case 'freeline':
        final existing = (ref.read(freeLinesProvider).asData?.value ?? const [])
            .where((l) => l.layerId == layerId)
            .firstOrNull;
        if (existing == null) {
          final id = await repo.createFreeLine(
            layerId: layerId,
            inclusionLat: latlng.latitude,
            inclusionLng: latlng.longitude,
            inclusionRadiusMeters: _defaultRadius() * 3,
          );
          await repo.addFreeLinePoint(
            freeLineId: id,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
          _pushAddStep(
            ObjectRef(kind: ObjectKind.freeLine, id: id, layerId: layerId),
            () => repo.deleteFreeLine(id),
          );
        } else {
          final pid = await repo.addFreeLinePoint(
            freeLineId: existing.id,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
          _pushAddStep(
            ObjectRef(
              kind: ObjectKind.freeLine,
              id: existing.id,
              layerId: layerId,
            ),
            () => repo.deleteFreeLinePoint(pid),
          );
        }
      case 'freearea':
        final existing = (ref.read(freeAreasProvider).asData?.value ?? const [])
            .where((a) => a.layerId == layerId)
            .firstOrNull;
        if (existing == null) {
          final id = await repo.createFreeArea(layerId: layerId);
          await repo.addFreeAreaPoint(
            freeAreaId: id,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
          _pushAddStep(
            ObjectRef(kind: ObjectKind.freeArea, id: id, layerId: layerId),
            () => repo.deleteFreeArea(id),
          );
        } else {
          final pid = await repo.addFreeAreaPoint(
            freeAreaId: existing.id,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
          _pushAddStep(
            ObjectRef(
              kind: ObjectKind.freeArea,
              id: existing.id,
              layerId: layerId,
            ),
            () => repo.deleteFreeAreaPoint(pid),
          );
        }
      case 'poi':
        // A POI set is an Overpass import around a centre — one tap picks the
        // centre, the dialog does the rest, then Add mode is done.
        _exitAddMode();
        await _importPois(layer, at: latlng);
      case 'transit':
      case 'borders':
        // Two taps mark opposite corners of the import box (the plane pattern),
        // then the dialog takes over and Add mode is done — an import is a
        // heavyweight action, not something to stay armed for.
        final a = _pendingBoxA;
        if (a == null) {
          setState(() => _pendingBoxA = latlng);
          return;
        }
        setState(() => _pendingBoxA = null);
        _exitAddMode();
        await _importBox(layer, LatLngBounds(a, latlng));
    }
  }

  Future<void> _addSubspaceAt(
    LatLng center,
    Layer layer,
    List<Subspace> subspaces,
  ) async {
    final repo = ref.read(repositoryProvider);
    final dist = _defaultRadius();
    final existing = subspaces.where((s) => s.layerId == layer.id).firstOrNull;
    if (existing != null) {
      final p = _hitTest.offset(center, dist, 45); // north-east of centre
      await repo.addSubspacePoint(
        subspaceId: existing.id,
        lat: p.latitude,
        lng: p.longitude,
      );
      _selectSubspace(existing.id);
      return;
    }
    final id = await repo.createSubspace(layerId: layer.id);
    await repo.addSubspacePoint(
      subspaceId: id,
      lat: center.latitude,
      lng: center.longitude,
      isMain: true,
    );
    final w = _hitTest.offset(center, dist, -90); // west
    final e = _hitTest.offset(center, dist, 90); // east
    await repo.addSubspacePoint(
      subspaceId: id,
      lat: w.latitude,
      lng: w.longitude,
    );
    await repo.addSubspacePoint(
      subspaceId: id,
      lat: e.latitude,
      lng: e.longitude,
    );
    _selectSubspace(id);
  }

  /// Adds to a freehand-line layer: a point to the layer's existing line, or a
  /// new line seeded with two points across the map centre (so it immediately
  /// divides the view). Selects the line either way.
  Future<void> _addFreeLineAt(
    LatLng center,
    Layer layer,
    List<FreeLine> lines,
  ) async {
    final repo = ref.read(repositoryProvider);
    final dist = _defaultRadius();
    final existing = lines.where((l) => l.layerId == layer.id).firstOrNull;
    if (existing != null) {
      final p = _hitTest.offset(center, dist, 45); // north-east of centre
      await repo.addFreeLinePoint(
        freeLineId: existing.id,
        lat: p.latitude,
        lng: p.longitude,
      );
      _selectFreeLine(existing.id);
      return;
    }
    // Bound the new line to an inclusion circle centred on the map, sized so the
    // two seed points sit comfortably inside it; the line fills a clean half of
    // this disk (Invert flips to the other half).
    final id = await repo.createFreeLine(
      layerId: layer.id,
      inclusionLat: center.latitude,
      inclusionLng: center.longitude,
      inclusionRadiusMeters: dist * 3,
    );
    final w = _hitTest.offset(center, dist, -90); // west
    final e = _hitTest.offset(center, dist, 90); // east
    await repo.addFreeLinePoint(
      freeLineId: id,
      lat: w.latitude,
      lng: w.longitude,
    );
    await repo.addFreeLinePoint(
      freeLineId: id,
      lat: e.latitude,
      lng: e.longitude,
    );
    _selectFreeLine(id);
  }

  /// Adds to a freehand-area layer: a point to the layer's existing area, or a
  /// new area seeded with a triangle of points around the map centre. Selects
  /// the area either way.
  Future<void> _addFreeAreaAt(
    LatLng center,
    Layer layer,
    List<FreeArea> areas,
  ) async {
    final repo = ref.read(repositoryProvider);
    final dist = _defaultRadius();
    final existing = areas.where((a) => a.layerId == layer.id).firstOrNull;
    if (existing != null) {
      final p = _hitTest.offset(center, dist, 0); // north of centre
      await repo.addFreeAreaPoint(
        freeAreaId: existing.id,
        lat: p.latitude,
        lng: p.longitude,
      );
      _selectFreeArea(existing.id);
      return;
    }
    final id = await repo.createFreeArea(layerId: layer.id);
    // Bearings must be within -180..180 (Distance.offset constraint).
    for (final bearing in [0.0, 120.0, -120.0]) {
      final p = _hitTest.offset(center, dist, bearing);
      await repo.addFreeAreaPoint(
        freeAreaId: id,
        lat: p.latitude,
        lng: p.longitude,
      );
    }
    _selectFreeArea(id);
  }

  /// Map gestures, minus double-tap zoom whenever a tap *places* something.
  ///
  /// Double-tap-to-zoom swallows **both** taps when two land near each other in
  /// quick succession: flutter_map holds a single tap back until the double-tap
  /// window closes, then reports a zoom and never delivers `onTap`. That is
  /// exactly the gesture for marking the two corners of a transit import box, a
  /// plane's A and B, or dropping freehand points — measured on device: two taps
  /// 60 px apart placed *nothing* and zoomed the map instead, which reads as
  /// "I drew the rectangle and nothing happened".
  ///
  /// So while a tap means something the zoom gesture is off; pinch, the zoom
  /// buttons and plain view mode are untouched.
  /// While [drawing], one-finger drag belongs to the stroke, so the map's own
  /// drag (and its fling, and the one-finger double-tap-drag zoom) is off and
  /// panning moves to two fingers. That is a big change to make silently —
  /// hence the banner, which says so in as many words.
  InteractionOptions _interactionOptions(
    bool tapPlaces, {
    bool drawing = false,
  }) {
    var flags = InteractiveFlag.all;
    if (tapPlaces || drawing) {
      flags &=
          ~InteractiveFlag.doubleTapZoom & ~InteractiveFlag.doubleTapDragZoom;
    }
    if (drawing) {
      flags &= ~InteractiveFlag.drag & ~InteractiveFlag.flingAnimation;
    }
    return InteractionOptions(flags: flags);
  }

  /// A map tap. Everything it can do is decided by exactly two things: whether
  /// an editor armed the next tap, and the current [MapMode]. In the default
  /// [MapMode.view] it does nothing at all.
  Future<void> _handleTap(LatLng latlng) async {
    // The editors' "the next tap places this coordinate" flows. These exist
    // only while an object is selected and always win over the map mode.
    if (await _consumeArmedPlacement(latlng)) return;

    switch (_mode) {
      case MapMode.elevation:
        await _probeAt(latlng);
        return;
      case MapMode.distance:
        _distanceTap(latlng);
        return;
      case MapMode.add:
        await _addTapAt(latlng);
        return;
      case MapMode.draw:
        // A tap is a zero-length stroke: nothing to draw, and nothing to
        // select either — the finger is the pen while this mode is on.
        return;
      case MapMode.view:
        // A plain tap is a complete no-op — no select, no create, no deselect.
        // Panning and pinching must never disturb what's on screen; objects are
        // reached by long-press, by Edit mode, or from the Elements list.
        //
        // Once per session, if the tap *did* land on something, say so: that's
        // exactly the moment someone expects the old tap-to-select and needs to
        // learn where it went. The hit-test only runs until the hint is shown.
        if (!_viewTapHintShown && _hitsAt(latlng).isNotEmpty) {
          _viewTapHintShown = true;
          _hint('Long-press to select · or turn on ✎ to select by tapping');
        }
        return;
      case MapMode.edit:
        break; // fall through to the hit-test below
    }

    // Edit mode: the best-ranked object under the tap wins; a miss deselects.
    // Objects are never *created* here — that's Add mode.
    final hits = _hitsAt(latlng);
    if (hits.isNotEmpty) {
      _select(hits.first.ref.kind, hits.first.ref.id);
      return;
    }
    if (hasAnySelection(ref)) _clearSelection();
  }

  /// The active layer's objects under [latlng], best guess first (see
  /// [rankCandidates]). Empty when there is no active *visible* layer —
  /// selection stays gated to the layer chosen in the drawer, so you only ever
  /// interact with the layer you meant to.
  List<HitCandidate> _hitsAt(LatLng latlng) {
    final layers = ref.read(layersProvider).asData?.value ?? const <Layer>[];
    final activeId = effectiveActiveLayerId(
      layers,
      ref.read(activeLayerProvider),
    );
    final layer = layers
        .where((l) => l.id == activeId && l.isVisible)
        .firstOrNull;
    if (layer == null) return const [];
    final freeAreaPoints =
        ref.read(freeAreaPointsProvider).asData?.value ??
        const <FreeAreaPoint>[];
    final uncertainty =
        ref.read(settingsProvider).asData?.value.uncertaintyMeters ?? 0;
    return rankCandidates(
      collectCandidates(
        camera: _mapController.camera,
        tap: latlng,
        layer: layer,
        circles: ref.read(circlesProvider).asData?.value ?? const [],
        planes: ref.read(planesProvider).asData?.value ?? const [],
        subspaces: ref.read(subspacesProvider).asData?.value ?? const [],
        subspacePoints:
            ref.read(subspacePointsProvider).asData?.value ?? const [],
        freeLines: ref.read(freeLinesProvider).asData?.value ?? const [],
        freeLinePoints:
            ref.read(freeLinePointsProvider).asData?.value ?? const [],
        freeAreas: ref.read(freeAreasProvider).asData?.value ?? const [],
        freeAreaPoints: freeAreaPoints,
        heightRegions:
            ref.read(heightRegionsProvider).asData?.value ?? const [],
        poiSets: ref.read(poiSetsProvider).asData?.value ?? const [],
        poiPoints: ref.read(poiPointsProvider).asData?.value ?? const [],
        transitSets: ref.read(transitSetsProvider).asData?.value ?? const [],
        transitStops: ref.read(transitStopsProvider).asData?.value ?? const [],
        // Already-decoded geometry: `borderShapesProvider` parses each area's
        // ring blob once per stream emission, and a state boundary is 119 238
        // points — re-parsing that per tap is not a thing that can be done.
        borderShapes: layer.type != 'borders'
            ? const []
            : [
                for (final sh in ref.read(borderShapesProvider(layer.id)))
                  BorderShapeRef(
                    id: sh.id,
                    rings: sh.rings,
                    south: sh.south,
                    west: sh.west,
                    north: sh.north,
                    east: sh.east,
                  ),
              ],
        // Same arguments the painter uses, so this is a cache hit and the hit
        // area matches the outline actually drawn (offset included).
        areaContours: (a) => areaGeometryCache
            .resolve(
              a,
              [
                for (final p in freeAreaPoints)
                  if (p.freeAreaId == a.id) p,
              ],
              bandMeters: uncertainty,
              inverted: layer.isInverted,
            )
            .core,
      ),
    );
  }

  /// Consumes the tap if one of the editors has armed "the next map tap places
  /// this coordinate", writing [latlng] to the armed point and disarming.
  /// Returns whether the tap was consumed.
  Future<bool> _consumeArmedPlacement(LatLng latlng) async {
    // Placement mode: relocate the selected circle's centre.
    if (ref.read(circlePlacementProvider)) {
      final selId = ref.read(selectedCircleProvider);
      if (selId != null) {
        await ref
            .read(repositoryProvider)
            .updateCircle(
              selId,
              centerLat: latlng.latitude,
              centerLng: latlng.longitude,
            );
        ref.read(circlePlacementProvider.notifier).arm(false);
        return true;
      }
    }

    // Placement mode: relocate the selected height region's centre.
    if (ref.read(heightPlacementProvider)) {
      final selId = ref.read(selectedHeightRegionProvider);
      if (selId != null) {
        await ref
            .read(repositoryProvider)
            .updateHeightRegion(
              selId,
              centerLat: latlng.latitude,
              centerLng: latlng.longitude,
            );
        ref.read(heightPlacementProvider.notifier).arm(false);
        return true;
      }
    }

    // Placement mode: relocate the selected freehand line's inclusion centre.
    if (ref.read(freeLineCenterPlacementProvider)) {
      final selId = ref.read(selectedFreeLineProvider);
      if (selId != null) {
        await ref
            .read(repositoryProvider)
            .updateFreeLine(
              selId,
              inclusionLat: latlng.latitude,
              inclusionLng: latlng.longitude,
            );
        ref.read(freeLineCenterPlacementProvider.notifier).arm(false);
        return true;
      }
    }

    // Placement mode: relocate the armed freehand-line point.
    final armedLine = ref.read(freeLinePlacementProvider);
    final selLineId = ref.read(selectedFreeLineProvider);
    if (armedLine != null && selLineId != null) {
      await ref
          .read(repositoryProvider)
          .updateFreeLinePoint(
            armedLine,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
      ref.read(freeLinePlacementProvider.notifier).arm(null);
      return true;
    }

    // Placement mode: relocate the armed freehand-area point.
    final armedArea = ref.read(freeAreaPlacementProvider);
    final selAreaId = ref.read(selectedFreeAreaProvider);
    if (armedArea != null && selAreaId != null) {
      await ref
          .read(repositoryProvider)
          .updateFreeAreaPoint(
            armedArea,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
      ref.read(freeAreaPlacementProvider.notifier).arm(null);
      return true;
    }

    // Placement mode: relocate the armed subspace point.
    final armedSub = ref.read(subspacePlacementProvider);
    final selSubId = ref.read(selectedSubspaceProvider);
    if (armedSub != null && selSubId != null) {
      await ref
          .read(repositoryProvider)
          .updateSubspacePoint(
            armedSub,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
      ref.read(subspacePlacementProvider.notifier).arm(null);
      return true;
    }

    // Placement mode: relocate the armed endpoint of the selected plane.
    final armed = ref.read(planePlacementProvider);
    final selPlaneId = ref.read(selectedPlaneProvider);
    if (armed != null && selPlaneId != null) {
      final repo = ref.read(repositoryProvider);
      if (armed == 'A') {
        await repo.updatePlane(
          selPlaneId,
          aLat: latlng.latitude,
          aLng: latlng.longitude,
        );
      } else {
        await repo.updatePlane(
          selPlaneId,
          bLat: latlng.latitude,
          bLng: latlng.longitude,
        );
      }
      ref.read(planePlacementProvider.notifier).arm(null);
      return true;
    }

    return false;
  }

  /// Long-press on the map — the deliberate gesture that reaches an object
  /// without leaving view mode.
  ///
  /// It opens one menu listing (a) the active layer's objects under the finger,
  /// ranked most-likely first, and (b) the contextual "add a point exactly
  /// here" actions the long-press used to perform directly. Everything goes
  /// through the menu on purpose: an accidental long-press must never silently
  /// pop an editor open.
  Future<void> _handleMapLongPress(
    Offset globalPosition,
    LatLng latlng,
    Layer? activeLayer,
  ) async {
    if (activeLayer == null) return;
    // While placing, a long-press would fight the tap-to-place flow.
    if (_mode == MapMode.add) return;

    final hits = _hitsAt(latlng);
    final summaries = _summariesFor(activeLayer);
    final selectedSubspaceId = ref.read(selectedSubspaceProvider);
    final selectedFreeLineId = ref.read(selectedFreeLineProvider);
    final selectedFreeAreaId = ref.read(selectedFreeAreaProvider);
    final selectedBorderAreaId = ref.read(selectedBorderAreaProvider);

    final items = <PopupMenuEntry<String>>[];
    for (var i = 0; i < hits.length; i++) {
      final ref_ = hits[i].ref;
      final s = summaries[ref_];
      // Individual POIs and stations are never in [summaries] — they are one
      // level below an element and deliberately unlisted (see [ObjectKind]) —
      // so they name themselves from their own row.
      final label = s != null
          ? '${s.title} · ${s.subtitle}'
          : _importedPointLabel(ref_) ?? 'Element ${i + 1}';
      items.add(_pointMenuItem('hit:$i', typeIcon(activeLayer.type), label));
    }

    // Contextual add actions — a strict superset of what long-press used to do.
    final actions = <PopupMenuEntry<String>>[];
    switch (activeLayer.type) {
      case 'circles':
        actions.add(
          _pointMenuItem(
            'newCircle',
            Icons.add_circle_outline,
            'New circle here',
          ),
        );
      case 'height':
        // The other single-object-per-tap type. Its absence here was the reason
        // a height layer felt like it could only be added to from the FAB.
        actions.add(
          _pointMenuItem('newHeight', Icons.terrain, 'New height area here'),
        );
      case 'subspace':
        if (selectedSubspaceId != null) {
          actions.add(
            _pointMenuItem(
              'addPoint',
              Icons.add_location_alt_outlined,
              'Add point here',
            ),
          );
        }
      case 'freeline':
        if (selectedFreeLineId != null) {
          actions.add(
            _pointMenuItem(
              'insertLine',
              Icons.add_location_alt_outlined,
              'Insert point here',
            ),
          );
        }
      case 'borders':
        // Only while Reshape is armed: on a read-only snapshot an "insert
        // point" that appears unasked is an invitation to fork it by accident.
        if (selectedBorderAreaId != null && ref.read(borderReshapeProvider)) {
          actions.add(
            _pointMenuItem(
              'insertBorder',
              Icons.add_location_alt_outlined,
              'Insert outline point here',
            ),
          );
        }
      case 'freearea':
        if (selectedFreeAreaId != null) {
          actions.add(
            _pointMenuItem(
              'insertArea',
              Icons.add_location_alt_outlined,
              'Insert point here',
            ),
          );
        }
    }
    if (actions.isNotEmpty) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.addAll(actions);
    }
    if (hasAnySelection(ref)) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add(_pointMenuItem('deselect', Icons.close, 'Deselect'));
    }
    if (items.isEmpty) {
      // Imports are selectable now, so "nothing here" means exactly that —
      // except on a transit layer, where a station may be present but hidden by
      // the type filter, which looks identical to empty ground.
      _hint(switch (activeLayer.type) {
        'transit' =>
          'Nothing here. Hidden station types don\'t respond — check '
              'Stations… in the layer menu.',
        _ => 'Nothing here in "${activeLayer.name}".',
      });
      return;
    }

    final selected = await _showPointMenu(
      activeLayer.name,
      globalPosition,
      items,
      formatLatLng(latlng.latitude, latlng.longitude),
    );
    if (selected == null || !mounted) return;
    final repo = ref.read(repositoryProvider);
    if (selected.startsWith('hit:')) {
      final hit = hits[int.parse(selected.substring(4))];
      _select(hit.ref.kind, hit.ref.id);
      return;
    }
    switch (selected) {
      case 'deselect':
        _clearSelection();
        setState(() {});
      case 'newCircle':
        await _addCircleAt(latlng, activeLayer);
      case 'newHeight':
        // Selected on creation (unlike a circle), because the region is empty
        // until the editor's Generate has run.
        await _addHeightRegionAt(latlng, activeLayer);
      case 'addPoint':
        await repo.addSubspacePoint(
          subspaceId: selectedSubspaceId!,
          lat: latlng.latitude,
          lng: latlng.longitude,
        );
      case 'insertLine':
        final pts =
            (ref.read(freeLinePointsProvider).asData?.value ??
                    const <FreeLinePoint>[])
                .where((p) => p.freeLineId == selectedFreeLineId)
                .map((p) => (ll: LatLng(p.lat, p.lng), order: p.sortOrder))
                .toList()
              ..sort((a, b) => a.order.compareTo(b.order));
        await repo.insertFreeLinePointAt(
          freeLineId: selectedFreeLineId!,
          sortOrder: _insertOrderFor(pts, latlng, closed: false),
          lat: latlng.latitude,
          lng: latlng.longitude,
        );
      case 'insertBorder':
        await _insertReshapeVertex(latlng);
      case 'insertArea':
        final pts =
            (ref.read(freeAreaPointsProvider).asData?.value ??
                    const <FreeAreaPoint>[])
                .where((p) => p.freeAreaId == selectedFreeAreaId)
                .map((p) => (ll: LatLng(p.lat, p.lng), order: p.sortOrder))
                .toList()
              ..sort((a, b) => a.order.compareTo(b.order));
        await repo.insertFreeAreaPointAt(
          freeAreaId: selectedFreeAreaId!,
          sortOrder: _insertOrderFor(pts, latlng, closed: true),
          lat: latlng.latitude,
          lng: latlng.longitude,
        );
    }
  }

  // --- Border outline reshaping ---------------------------------------------

  /// Keeps the in-memory draft in step with what is selected and armed.
  ///
  /// Called from `build`, so it must never call `setState` synchronously; the
  /// post-frame hop is what lets the draft be *loaded* during a build that is
  /// already reading it.
  void _syncReshapeDraft(BorderShape? shape, {required bool armed}) {
    if (!armed || shape == null) {
      if (_reshapeAreaId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _reshapeAreaId = null;
            _reshapeRings = null;
          });
        });
      }
      return;
    }
    if (_reshapeAreaId == shape.id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        // A different outline is a different density question — the hint has to
        // be able to fire again, or the first crowded area silences it for the
        // rest of the session.
        _reshapeZoomHintShown = false;
        _reshapeAreaId = shape.id;
        // A deep copy: the provider's lists are rebuilt per emission and shared
        // with the painter, so mutating them in place would edit geometry
        // nobody asked to edit and survive a cancelled gesture.
        _reshapeRings = [
          for (final r in shape.rings) [...r],
        ];
      });
    });
  }

  /// The draft as a [BorderShape] the painter can swap in for the stored one.
  BorderShape? _reshapeDraftShape(BorderShape? stored) {
    final rings = _reshapeRings;
    if (stored == null || rings == null || _reshapeAreaId != stored.id) {
      return null;
    }
    return BorderShape(
      id: stored.id,
      name: stored.name,
      colorIndex: stored.colorIndex,
      colorArgb: stored.colorArgb,
      // The stored bounds, deliberately: they only drive viewport culling, and
      // an area being dragged must not cull itself out from under the finger.
      south: stored.south,
      west: stored.west,
      north: stored.north,
      east: stored.east,
      labelPoint: stored.labelPoint,
      rings: rings,
    );
  }

  /// Drag handles for the outline being reshaped, or null when nothing is.
  ///
  /// Which vertices get one is [reshapeHandles]' decision (cull to the
  /// viewport, then thin to one per [_reshapeHandleSpacingPx]); this only
  /// projects the draft for it and turns the answer into markers.
  List<DragMarker>? _reshapeHandles(BorderShape? draft) {
    final rings = _reshapeRings;
    if (draft == null || rings == null) return null;
    final cam = _mapController.camera;
    final projected = [
      for (final r in rings)
        [for (final p in r) cam.latLngToScreenOffset(p)],
    ];
    final picked = reshapeHandles(
      projected,
      // A margin, so a handle just off the edge is still grabbable after a
      // nudge.
      bounds: cameraViewport(cam).inflate(48),
      spacingPx: _reshapeHandleSpacingPx,
      max: _maxReshapeHandles,
    );
    if (picked.tooMany) {
      if (!_reshapeZoomHintShown) {
        _reshapeZoomHintShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _hint('Too many outline points here to edit — zoom in.');
          }
        });
      }
      return const [];
    }
    return [
      for (final k in picked.handles)
        _dragHandle(
          rings[k.ring][k.index],
          key: ValueKey('ba-${draft.id}-${k.ring}-${k.index}'),
          undoLabel: null, // the whole gesture is one write; see _commitReshape
          onMoved: (ll) => _moveReshapeVertex(k.ring, k.index, ll),
          onDragEnded: _commitReshape,
          onMenu: (pos) => _showFreeVertexMenu(
            pos,
            title: 'Outline point',
            canRemove: rings[k.ring].length > 3,
            onRemove: () => _removeReshapeVertex(k.ring, k.index),
          ),
        ),
    ];
  }

  /// The handle that moves an area's **name plate**.
  ///
  /// Offered whenever an area is selected, reshaping or not, because unlike the
  /// outline it costs the snapshot nothing: the anchor is presentation, so
  /// moving it is not a fork of OSM geometry and deliberately never stamps
  /// `editedAt`. It earns its place after a reshape in particular — the plate
  /// is anchored at a stored point, so an outline dragged away from it leaves
  /// the name floating over ground the area no longer covers.
  List<DragMarker> _labelHandles(BorderArea? area, Layer? layer) {
    if (area == null) return const [];
    if (!area.labelLat.isFinite || !area.labelLng.isFinite) return const [];
    return [
      _dragHandle(
        LatLng(area.labelLat, area.labelLng),
        key: ValueKey('ba-label-${area.id}'),
        core: _crosshairCore(),
        // The name only when the layer isn't already drawing it there —
        // otherwise the handle stacks a second copy on top of the real plate.
        label: layer?.borderShowNames == true ? null : area.name,
        undoLabel: 'Name plate',
        onMoved: (ll) => ref.read(repositoryProvider).updateBorderArea(
              area.id,
              labelLat: ll.latitude,
              labelLng: ll.longitude,
            ),
      ),
    ];
  }

  /// Writes the finished outline. Called on drag end and after an insert or a
  /// remove — one write per completed gesture, never per frame.
  Future<void> _commitReshape() async {
    final id = _reshapeAreaId;
    final rings = _reshapeRings;
    if (id == null || rings == null) return;
    final ok = await ref.read(repositoryProvider).reshapeBorderArea(id, rings);
    if (!ok && mounted) {
      _hint('That would leave the area with no outline, so it was not saved.');
    }
  }

  /// Moves one draft vertex. Cheap on purpose — this runs under the finger.
  void _moveReshapeVertex(int ring, int index, LatLng to) {
    final rings = _reshapeRings;
    if (rings == null || ring >= rings.length) return;
    if (index >= rings[ring].length) return;
    setState(() => rings[ring][index] = to);
  }

  /// Removes one draft vertex, refusing to take a ring below a triangle — a
  /// two-point "ring" has no interior and would silently drop out of the area.
  Future<void> _removeReshapeVertex(int ring, int index) async {
    final rings = _reshapeRings;
    if (rings == null || ring >= rings.length) return;
    if (rings[ring].length <= 3) {
      _hint('An outline ring needs at least three points.');
      return;
    }
    setState(() => rings[ring].removeAt(index));
    await _commitReshape();
  }

  /// Inserts [at] into the draft on whichever ring segment is nearest on
  /// screen, so the new point lands on the outline rather than at the end of an
  /// arbitrary ring.
  Future<void> _insertReshapeVertex(LatLng at) async {
    final rings = _reshapeRings;
    if (rings == null) return;
    final cam = _mapController.camera;
    final where = nearestInsertion(
      [
        for (final r in rings)
          [for (final p in r) cam.latLngToScreenOffset(p)],
      ],
      cam.latLngToScreenOffset(at),
    );
    if (where == null) return;
    setState(() => rings[where.ring].insert(where.index, at));
    await _commitReshape();
  }

  /// A menu label for an individual POI or station: its OSM name, or the kind
  /// of thing it is when OSM never gave it one (most benches don't have names).
  /// Null for anything that is a proper element and therefore already in the
  /// summaries.
  String? _importedPointLabel(ObjectRef ref_) {
    switch (ref_.kind) {
      case ObjectKind.poiPoint:
        final p = (ref.read(poiPointsProvider).asData?.value ?? const [])
            .where((x) => x.id == ref_.id)
            .firstOrNull;
        if (p == null) return null;
        final category = _poiCategoryLabel(
          ref.read(poiSetsProvider).asData?.value ?? const [],
          p.poiSetId,
        );
        return p.name?.isNotEmpty == true ? '${p.name} · $category' : category;
      case ObjectKind.transitStop:
        final st = (ref.read(transitStopsProvider).asData?.value ?? const [])
            .where((x) => x.id == ref_.id)
            .firstOrNull;
        if (st == null) return null;
        final modes = transitModeLabels(st.modeMask);
        return st.name?.isNotEmpty == true ? '${st.name} · $modes' : modes;
      default:
        return null;
    }
  }

  /// The human name of the category a POI's set imported ("Cafés"), for the
  /// point editor's subtitle. Falls back to the raw key so an old set whose
  /// category has since been renamed still says something.
  static String _poiCategoryLabel(List<PoiSet> sets, String setId) {
    final key = sets.where((s) => s.id == setId).firstOrNull?.categoryKey;
    if (key == null) return 'POI';
    return poiCategories.where((c) => c.key == key).firstOrNull?.label ?? key;
  }

  /// This layer's element summaries, keyed by ref — used to label hit-menu rows
  /// with the same names the Elements list shows.
  Map<ObjectRef, ObjectSummary> _summariesFor(Layer layer) {
    final rows = summariseLayer(
      layer,
      circles: ref.read(circlesProvider).asData?.value ?? const [],
      planes: ref.read(planesProvider).asData?.value ?? const [],
      subspaces: ref.read(subspacesProvider).asData?.value ?? const [],
      subspacePoints:
          ref.read(subspacePointsProvider).asData?.value ?? const [],
      freeLines: ref.read(freeLinesProvider).asData?.value ?? const [],
      freeLinePoints:
          ref.read(freeLinePointsProvider).asData?.value ?? const [],
      freeAreas: ref.read(freeAreasProvider).asData?.value ?? const [],
      freeAreaPoints:
          ref.read(freeAreaPointsProvider).asData?.value ?? const [],
      heightRegions: ref.read(heightRegionsProvider).asData?.value ?? const [],
      poiSets: ref.read(poiSetsProvider).asData?.value ?? const [],
      poiPoints: ref.read(poiPointsProvider).asData?.value ?? const [],
      transitSets: ref.read(transitSetsProvider).asData?.value ?? const [],
      transitStops: ref.read(transitStopsProvider).asData?.value ?? const [],
      borderSets: ref.read(borderSetsProvider).asData?.value ?? const [],
      borderAreas: ref.read(borderAreasProvider).asData?.value ?? const [],
    );
    return {for (final r in rows) r.ref: r};
  }

  /// The sort_order to give a vertex inserted at [tap] so it lands on the
  /// nearest segment of the ordered [pts] (measured in screen space). For a
  /// [closed] ring the wrap-around edge (last→first) is considered; inserting on
  /// it appends after the last point.
  int _insertOrderFor(
    List<({LatLng ll, int order})> pts,
    LatLng tap, {
    required bool closed,
  }) {
    if (pts.isEmpty) return 0;
    final cam = _mapController.camera;
    final t = cam.latLngToScreenOffset(tap);
    final n = pts.length;
    final appendOrder = pts.last.order + 1;
    var bestDist = double.infinity;
    var bestOrder = appendOrder;
    final segCount = closed ? n : n - 1;
    for (var i = 0; i < segCount; i++) {
      final a = cam.latLngToScreenOffset(pts[i].ll);
      final b = cam.latLngToScreenOffset(pts[(i + 1) % n].ll);
      final d = distToSegment(t, a, b);
      if (d < bestDist) {
        bestDist = d;
        // Wrap edge (last→first) appends; otherwise the new point lands between
        // vertices i and i+1 by taking the follower's order and shifting it.
        bestOrder = (closed && i == n - 1) ? appendOrder : pts[i + 1].order;
      }
    }
    return bestOrder;
  }

  /// Frames [points] — a single point centres (a camera fit on a degenerate
  /// box zooms to the maximum), several points fit with padding.
  void _applyFocus(MapFocusRequest req) {
    final pts = [
      for (final p in req.points)
        if (p.latitude.isFinite && p.longitude.isFinite) p,
    ];
    if (pts.isEmpty) return;
    if (pts.length < 2) {
      _mapController.move(
        pts.first,
        math.max(_mapController.camera.zoom, 14.0).clamp(2.0, 19.0),
      );
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(64),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Triggers one-time seeding of a default layer.
    ref.watch(seedProvider);

    // "Zoom to"/"Edit" from the layers drawer: it has no MapController, so it
    // posts a focus request here. Applied post-frame (never move the camera
    // during a build) and only once the map is ready (fitCamera throws before).
    // A retry asked for from the drawer's Elements list.
    ref.listen(pendingTransitRetryProvider, (_, req) {
      if (req == null) return;
      ref.read(pendingTransitRetryProvider.notifier).clear();
      final set = (ref.read(transitSetsProvider).asData?.value ?? const [])
          .where((t) => t.id == req.setId)
          .firstOrNull;
      if (set != null) unawaited(retryTransitImport(set));
    });

    ref.listen(pendingFocusProvider, (_, req) {
      if (req == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        _applyFocus(req);
        ref.read(pendingFocusProvider.notifier).clear();
      });
    });

    final layers = ref.watch(layersProvider).asData?.value ?? const <Layer>[];
    final circles =
        ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
    final planes = ref.watch(planesProvider).asData?.value ?? const <Plane>[];
    final subspaces =
        ref.watch(subspacesProvider).asData?.value ?? const <Subspace>[];
    // Points arrive grouped by their owning object, built once per stream
    // emission rather than re-scanned per object per frame — see the grouping
    // providers in `state/providers.dart`.
    final subspacePoints = ref.watch(subspacePointsBySubspaceProvider);
    final freeLines =
        ref.watch(freeLinesProvider).asData?.value ?? const <FreeLine>[];
    final freeLinePoints = ref.watch(freeLinePointsByLineProvider);
    final freeAreas =
        ref.watch(freeAreasProvider).asData?.value ?? const <FreeArea>[];
    final freeAreaPoints = ref.watch(freeAreaPointsByAreaProvider);
    final tracks = ref.watch(tracksProvider).asData?.value ?? const <Track>[];
    final trackPointsByTrack = ref.watch(trackPointsByTrackProvider);
    final heightRegions =
        ref.watch(heightRegionsProvider).asData?.value ??
        const <HeightRegion>[];
    final heightPolygons = ref.watch(heightPolygonsByRegionProvider);
    final heightPolygonPoints = ref.watch(heightPolygonPointsByPolygonProvider);
    final poiSets =
        ref.watch(poiSetsProvider).asData?.value ?? const <PoiSet>[];
    final poiPoints =
        ref.watch(poiPointsProvider).asData?.value ?? const <PoiPoint>[];
    final transitSets =
        ref.watch(transitSetsProvider).asData?.value ?? const <TransitSet>[];
    final transitStations =
        ref.watch(transitStopsProvider).asData?.value ?? const <TransitStop>[];
    final borderSets =
        ref.watch(borderSetsProvider).asData?.value ?? const <BorderSet>[];
    // The undecoded rows — the editor edits a row, while the painter and the
    // reshape handles work from `borderShapesProvider`'s decoded geometry.
    final borderAreaRows =
        ref.watch(borderAreasProvider).asData?.value ?? const <BorderArea>[];
    // Stations hang off a *set*, not the layer, so resolve the layer→sets
    // index (and each set's mode filter) once rather than per station.
    final transitSetIds = <String, Set<String>>{};
    final transitVisibleMask = <String, int>{};
    for (final s in transitSets) {
      transitSetIds.putIfAbsent(s.layerId, () => {}).add(s.id);
      transitVisibleMask[s.id] = s.visibleModeMask;
    }
    final mode = ref.watch(mapModeProvider);
    final recording = ref.watch(trackRecordingProvider);
    // Whether a map tap currently *does* something — see [_interactionOptions].
    final tapPlaces =
        mode != MapMode.view ||
        ref.watch(circlePlacementProvider) ||
        ref.watch(heightPlacementProvider) ||
        ref.watch(freeLineCenterPlacementProvider) ||
        ref.watch(freeLinePlacementProvider) != null ||
        ref.watch(freeAreaPlacementProvider) != null ||
        ref.watch(subspacePlacementProvider) != null ||
        ref.watch(planePlacementProvider) != null;
    final settings = ref.watch(settingsProvider).asData?.value;
    final uncertainty = settings?.uncertaintyMeters ?? 0;
    final toolsExpanded = settings?.toolsExpanded ?? true;
    final basemapVisible = settings?.basemapVisible ?? true;
    final basemapOpacity = settings?.basemapOpacity ?? 1.0;
    final selectedCircle = circles
        .where((c) => c.id == ref.watch(selectedCircleProvider))
        .firstOrNull;
    final selectedPlane = planes
        .where((p) => p.id == ref.watch(selectedPlaneProvider))
        .firstOrNull;
    final selectedSubspace = subspaces
        .where((s) => s.id == ref.watch(selectedSubspaceProvider))
        .firstOrNull;
    final selectedSubspacePoints = selectedSubspace == null
        ? const <SubspacePoint>[]
        : subspacePoints[selectedSubspace.id] ?? const <SubspacePoint>[];
    final selectedFreeLine = freeLines
        .where((l) => l.id == ref.watch(selectedFreeLineProvider))
        .firstOrNull;
    final selectedFreeLinePoints = selectedFreeLine == null
        ? const <FreeLinePoint>[]
        : freeLinePoints[selectedFreeLine.id] ?? const <FreeLinePoint>[];
    // The inclusion circle bounding the selected line, drawn as an edit guide
    // with a draggable-by-tap centre handle.
    final selectedFreeLineInclusion = selectedFreeLine == null
        ? null
        : effectiveInclusion(
            lat: selectedFreeLine.inclusionLat,
            lng: selectedFreeLine.inclusionLng,
            radiusMeters: selectedFreeLine.inclusionRadiusMeters,
            points: [
              for (final p in selectedFreeLinePoints) LatLng(p.lat, p.lng),
            ],
          );
    final selectedFreeLineCircle = selectedFreeLineInclusion == null
        ? const <LatLng>[]
        : geodesicCircle(
            selectedFreeLineInclusion.center,
            selectedFreeLineInclusion.radiusMeters,
          );
    final selectedFreeArea = freeAreas
        .where((a) => a.id == ref.watch(selectedFreeAreaProvider))
        .firstOrNull;
    final selectedFreeAreaPoints = selectedFreeArea == null
        ? const <FreeAreaPoint>[]
        : freeAreaPoints[selectedFreeArea.id] ?? const <FreeAreaPoint>[];
    final selectedHeightRegion = heightRegions
        .where((r) => r.id == ref.watch(selectedHeightRegionProvider))
        .firstOrNull;
    final selectedHeightCircle = selectedHeightRegion == null
        ? const <LatLng>[]
        : geodesicCircle(
            LatLng(
              selectedHeightRegion.centerLat,
              selectedHeightRegion.centerLng,
            ),
            selectedHeightRegion.radiusMeters,
          );
    // The three import types. Their editors are scoped to what an offline OSM
    // snapshot can honestly offer, but they are selections like any other — the
    // point of giving them editors was to stop Edit mode and long-press being
    // dead over them.
    final selectedPoiSet = poiSets
        .where((s) => s.id == ref.watch(selectedPoiSetProvider))
        .firstOrNull;
    final selectedPoiPoint = poiPoints
        .where((p) => p.id == ref.watch(selectedPoiPointProvider))
        .firstOrNull;
    final selectedTransitSet = transitSets
        .where((t) => t.id == ref.watch(selectedTransitSetProvider))
        .firstOrNull;
    final selectedTransitStop = transitStations
        .where((x) => x.id == ref.watch(selectedTransitStopProvider))
        .firstOrNull;
    final selectedBorderArea = borderAreaRows
        .where((a) => a.id == ref.watch(selectedBorderAreaProvider))
        .firstOrNull;
    // The layer behind the selected area, reached through its import — areas
    // belong to a set, and the editor needs the layer's admin level.
    final selectedBorderLayer = selectedBorderArea == null
        ? null
        : () {
            final set = borderSets
                .where((x) => x.id == selectedBorderArea.setId)
                .firstOrNull;
            return set == null
                ? null
                : layers.where((l) => l.id == set.layerId).firstOrNull;
          }();
    // The decoded geometry of the selected area (the editor edits the row; the
    // handles and the painter need the rings), plus the in-flight draft.
    final reshapeArmed =
        ref.watch(borderReshapeProvider) && selectedBorderArea != null;
    final selectedBorderShape = selectedBorderLayer == null
        ? null
        : ref
            .watch(borderShapesProvider(selectedBorderLayer.id))
            .where((sh) => sh.id == selectedBorderArea!.id)
            .firstOrNull;
    _syncReshapeDraft(selectedBorderShape, armed: reshapeArmed);
    final reshapeDraft = _reshapeDraftShape(selectedBorderShape);
    final hasSelection =
        selectedCircle != null ||
        selectedPlane != null ||
        selectedSubspace != null ||
        selectedFreeLine != null ||
        selectedFreeArea != null ||
        selectedHeightRegion != null ||
        selectedPoiSet != null ||
        selectedPoiPoint != null ||
        selectedTransitSet != null ||
        selectedTransitStop != null ||
        (selectedBorderArea != null && selectedBorderLayer != null);
    // First selection of the session: point out that handles now drag and that
    // long-press adds/edits — the gestures are otherwise invisible.
    if (hasSelection && !_editHintShown) {
      _editHintShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hint(
            'Drag a point to move it · long-press it for options · '
            'long-press the map to select or add',
          );
        }
      });
    }
    final activeId = effectiveActiveLayerId(
      layers,
      ref.watch(activeLayerProvider),
    );
    final activeLayer = layers.where((l) => l.id == activeId).firstOrNull;
    // Only the types that still gate a *widget* need a flag; the Add button's
    // per-type wording now lives in _addFabLabel.
    final isSubspaceLayer = activeLayer?.type == 'subspace';
    final isCircleLayer = activeLayer?.type == 'circles';

    // Edit mode arms tap-to-select, so it is meaningful only when the active
    // layer has an editor *and* holds something to select. Left always-on it
    // was a button that visibly did nothing on an import layer or an empty one.
    // `any` rather than a count: the answer is a boolean and this runs on every
    // camera tick.
    final activeHasEditor =
        activeLayer != null && layerHasEditor(activeLayer.type);
    final activeHasElements = activeLayer == null
        ? false
        : switch (activeLayer.type) {
            'circles' => circles.any((c) => c.layerId == activeLayer.id),
            'planes' => planes.any((p) => p.layerId == activeLayer.id),
            'subspace' => subspaces.any((s) => s.layerId == activeLayer.id),
            'freeline' => freeLines.any((l) => l.layerId == activeLayer.id),
            'freearea' => freeAreas.any((a) => a.layerId == activeLayer.id),
            'height' => heightRegions.any((r) => r.layerId == activeLayer.id),
            // Imports count as elements to select: a POI layer offers its
            // markers, a transit layer its stations, a borders layer its areas.
            'poi' => poiSets.any((s) => s.layerId == activeLayer.id),
            'transit' => transitSets.any((s) => s.layerId == activeLayer.id),
            'borders' => borderSets.any((s) => s.layerId == activeLayer.id),
            // A track is not selectable by tap — it has no editor to open —
            // so Edit mode stays unarmed over one however many are recorded.
            'track' => false,
            _ => false,
          };
    final canEditByTap = activeHasEditor && activeHasElements;
    // Only the two freehand types can be drawn into — everything else is built
    // from points, radii or an import.
    final canDraw =
        activeLayer?.type == 'freeline' || activeLayer?.type == 'freearea';
    // Same reasoning as Edit below: switching to a non-freehand layer while
    // Draw is armed would leave one-finger pan off with nothing to draw into.
    if (mode == MapMode.draw && !canDraw) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(mapModeProvider) == MapMode.draw) {
          _finishDraw();
        }
      });
    }
    // Deleting the layer being recorded into has to end the recording: the
    // track went with it (cascade), so every further fix would be written to a
    // row that no longer exists. Guarded on a *loaded* layer list, so the
    // stream's first empty frame doesn't stop a recording on its own.
    if (recording.isRecording &&
        ref.watch(layersProvider).hasValue &&
        !layers.any((l) => l.id == recording.layerId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(trackRecordingProvider.notifier).stopIfLayerGone(layers);
        }
      });
    }
    // Switching to an import layer (or emptying the current one) while Edit is
    // armed would otherwise leave a lit button that no longer does anything.
    if (mode == MapMode.edit && !canEditByTap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(mapModeProvider) == MapMode.edit) {
          ref.read(mapModeProvider.notifier).set(MapMode.view);
        }
      });
    }

    // Restore the last camera; fall back to Munich on first launch. Resolved
    // once, when settings first load — FlutterMap ignores these after creation.
    final savedLat = settings?.lastLat;
    final savedLng = settings?.lastLng;
    final savedZoom = settings?.lastZoom;
    final hasSavedCamera =
        savedLat != null &&
        savedLng != null &&
        savedZoom != null &&
        savedLat.isFinite &&
        savedLng.isFinite &&
        savedZoom.isFinite;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const LayersDrawer(),
      // No app bar: the map is full-bleed and the only chrome is the menu
      // button floating at the top-left (below).
      body: settings == null
          ? const SizedBox.shrink() // loads instantly from the local database
          : Stack(
              children: [
                FlutterMap(
                  key: _mapKey,
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: hasSavedCamera
                        ? LatLng(savedLat, savedLng)
                        : const LatLng(48.137, 11.575), // Munich
                    initialZoom: hasSavedCamera ? savedZoom : 5,
                    // OSM tiles exist up to z19; cap here so zooming further
                    // doesn't leave a blank (tile-less) screen. A minZoom keeps
                    // zoom-out gestures from degenerating into a NaN camera.
                    maxZoom: 19,
                    minZoom: 2,
                    interactionOptions: _interactionOptions(
                      tapPlaces,
                      drawing: mode == MapMode.draw,
                    ),
                    onMapReady: () {
                      _mapReady = true;
                      _schedulePrefetch();
                    },
                    // Rotation is tracked off the event stream, not
                    // onPositionChanged: flutter_map calls that one only for
                    // move/zoom, so a pure rotate (two-finger twist, or our own
                    // `rotate(0)`) would leave the compass pointing the wrong
                    // way — and now also stuck on screen, since it shows only
                    // while rotated.
                    onMapEvent: (event) {
                      final r = event.camera.rotation;
                      if (r != _rotation) setState(() => _rotation = r);
                    },
                    onPositionChanged: (camera, _) {
                      // Recover from a degenerate gesture that produced a
                      // non-finite camera: snap back to the last valid view so
                      // flutter_map's tile layer (and our code) don't throw
                      // "LatLng is not finite".
                      final c = camera.center;
                      if (!c.latitude.isFinite ||
                          !c.longitude.isFinite ||
                          !camera.zoom.isFinite) {
                        _mapController.move(_lastGoodCenter, _lastGoodZoom);
                        return;
                      }
                      _lastGoodCenter = c;
                      _lastGoodZoom = camera.zoom;
                      // An import box's live corner *is* the map centre, so it
                      // has to follow the camera. Only runs while a corner is
                      // buffered.
                      if (_pendingBoxA != null) setState(() {});
                      // Prefetch tiles once the map settles.
                      _schedulePrefetch();
                    },
                    onTap: (_, latlng) => _handleTap(latlng),
                    onLongPress: (tapPos, latlng) =>
                        _handleMapLongPress(tapPos.global, latlng, activeLayer),
                    // Desktop right-click reaches the same context menu.
                    onSecondaryTap: (tapPos, latlng) =>
                        _handleMapLongPress(tapPos.global, latlng, activeLayer),
                  ),
                  children: [
                    // Base OSM tiles — a pinned bottom "layer": hideable and
                    // opacity-adjustable from the layers drawer. Opacity is a
                    // no-op at 1.0 (Flutter skips the layer), so the common case
                    // costs nothing; when hidden the tiles are dropped entirely
                    // and the map's background colour shows through.
                    if (basemapVisible)
                      Opacity(
                        opacity: basemapOpacity.clamp(0.0, 1.0),
                        child: TileLayer(
                          urlTemplate: _baseTileUrl,
                          // Must match the real application id: the policy
                          // requires a User-Agent that identifies the app, and
                          // forbids relying on a library default.
                          userAgentPackageName: 'com.leostumpf.zonecraft',
                          tileProvider: _tileProvider,
                          maxZoom: 19,
                        ),
                      ),
                    // One composited region per visible layer, bottom-to-top.
                    // Region layers apply their opacity inside the painter (so
                    // it can push the fill all the way to fully opaque). POI
                    // layers hold markers, not a fill, so they wrap in Opacity
                    // to fade the markers uniformly (a no-op at 1.0).
                    for (final layer in layers)
                      if (layer.isVisible && layer.type == 'poi')
                        Opacity(
                          opacity: layer.opacity.clamp(0.0, 1.0),
                          child: PoiMarkersLayer(
                            key: ValueKey(layer.id),
                            layer: layer,
                            sets: poiSets
                                .where((s) => s.layerId == layer.id)
                                .toList(),
                            points: poiPoints,
                            onClusterTap: (center) => _mapController.move(
                              center,
                              (_mapController.camera.zoom + 1.5).clamp(
                                2.0,
                                19.0,
                              ),
                            ),
                          ),
                        )
                      else if (layer.isVisible && layer.type == 'transit')
                        Opacity(
                          opacity: layer.opacity.clamp(0.0, 1.0),
                          child: TransitStationsLayer(
                            key: ValueKey(layer.id),
                            layer: layer,
                            sets: transitSets
                                .where((s) => s.layerId == layer.id)
                                .toList(),
                            stations: visibleTransitStations(
                              transitStations.where(
                                (s) => (transitSetIds[layer.id] ?? const {})
                                    .contains(s.setId),
                              ),
                              transitVisibleMask,
                            ),
                            onClusterTap: (center) => _mapController.move(
                              center,
                              (_mapController.camera.zoom + 1.5).clamp(
                                2.0,
                                19.0,
                              ),
                            ),
                          ),
                        )
                      else if (layer.isVisible && layer.type == 'borders')
                        // Not wrapped in Opacity: the fill takes the layer's
                        // opacity inside the painter, and the outline stays
                        // crisp regardless (a half-visible border line is just
                        // a worse border line).
                        BorderAreasLayer(
                          key: ValueKey(layer.id),
                          layer: layer,
                          shapes: ref.watch(borderShapesProvider(layer.id)),
                          draft: reshapeDraft,
                        )
                      else if (layer.isVisible && layer.type == 'track')
                        // Not wrapped in Opacity: the painter applies it to the
                        // stroke itself, which is the only thing a track has.
                        TracksLayer(
                          key: ValueKey(layer.id),
                          layer: layer,
                          tracks: tracks
                              .where((t) => t.layerId == layer.id)
                              .toList(),
                          pointsByTrack: trackPointsByTrack,
                        )
                      else if (layer.isVisible)
                        RegionLayer(
                          key: ValueKey(layer.id),
                          layer: layer,
                          opacity: layer.opacity,
                          circles: layer.type == 'circles'
                              ? circles
                                    .where((c) => c.layerId == layer.id)
                                    .toList()
                              : const <Circle>[],
                          planes: layer.type == 'planes'
                              ? planes
                                    .where((p) => p.layerId == layer.id)
                                    .toList()
                              : const <Plane>[],
                          subspaces: layer.type == 'subspace'
                              ? subspaces
                                    .where((s) => s.layerId == layer.id)
                                    .toList()
                              : const <Subspace>[],
                          subspacePoints: layer.type == 'subspace'
                              ? subspacePoints
                              : const <String, List<SubspacePoint>>{},
                          freeLines: layer.type == 'freeline'
                              ? freeLines
                                    .where((l) => l.layerId == layer.id)
                                    .toList()
                              : const <FreeLine>[],
                          freeLinePoints: layer.type == 'freeline'
                              ? freeLinePoints
                              : const <String, List<FreeLinePoint>>{},
                          freeAreas: layer.type == 'freearea'
                              ? freeAreas
                                    .where((a) => a.layerId == layer.id)
                                    .toList()
                              : const <FreeArea>[],
                          freeAreaPoints: layer.type == 'freearea'
                              ? freeAreaPoints
                              : const <String, List<FreeAreaPoint>>{},
                          heightRegions: layer.type == 'height'
                              ? heightRegions
                                    .where((r) => r.layerId == layer.id)
                                    .toList()
                              : const <HeightRegion>[],
                          heightPolygons: layer.type == 'height'
                              ? heightPolygons
                              : const <String, List<HeightPolygon>>{},
                          heightPolygonPoints: layer.type == 'height'
                              ? heightPolygonPoints
                              : const <String, List<HeightPolygonPoint>>{},
                          uncertaintyMeters: uncertainty,
                        ),
                    // Outline of the selected line's inclusion circle, so the
                    // half-disk it splits is visible while editing.
                    if (selectedFreeLineCircle.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              ...selectedFreeLineCircle,
                              selectedFreeLineCircle.first,
                            ],
                            color: Colors.black54,
                            strokeWidth: 1.5,
                          ),
                        ],
                      ),
                    // Dashed outline of the freehand object being edited, so the
                    // drawn polyline/ring is visible while placing points.
                    if (selectedFreeLine != null &&
                        selectedFreeLinePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              for (final p in selectedFreeLinePoints)
                                LatLng(p.lat, p.lng),
                            ],
                            color: Colors.black87,
                            strokeWidth: 1.5,
                          ),
                        ],
                      ),
                    if (selectedFreeArea != null &&
                        selectedFreeAreaPoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              for (final p in selectedFreeAreaPoints)
                                LatLng(p.lat, p.lng),
                              LatLng(
                                selectedFreeAreaPoints.first.lat,
                                selectedFreeAreaPoints.first.lng,
                              ),
                            ],
                            color: Colors.black87,
                            strokeWidth: 1.5,
                          ),
                        ],
                      ),
                    // Outline of the selected height region's circle, so its
                    // bounded area is visible while editing / before generating.
                    if (selectedHeightCircle.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              ...selectedHeightCircle,
                              selectedHeightCircle.first,
                            ],
                            color: Colors.black87,
                            strokeWidth: 1.5,
                          ),
                        ],
                      ),
                    // Box import (transit / borders): the rubber-band box
                    // between the two corner taps. The live corner is the map
                    // centre, so panning reshapes it (no hover on a phone).
                    if (_pendingBoxA != null) ...[
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _bboxRing(
                              _pendingBoxA!,
                              _mapController.camera.center,
                            ),
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            borderColor: Theme.of(context).colorScheme.primary,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pendingBoxA!,
                            width: 32,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.place,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Marker(
                            point: _mapController.camera.center,
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.add,
                              size: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_myPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _myPosition!,
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    // Add mode, planes: the buffered first tap (point A), shown
                    // until the second tap completes the plane.
                    if (_pendingPlaneA != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pendingPlaneA!,
                            width: 32,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.place,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    // Elevation-probe pin + value at the measured point.
                    if (_probePoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _probePoint!,
                            width: 120,
                            height: 56,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.place,
                                  color: Colors.black87,
                                  size: 28,
                                ),
                                Material(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      _probing
                                          ? '…'
                                          : _probeElevation != null
                                          ? _formatElevation(_probeElevation!)
                                          : 'n/a',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    // Distance probe: a line between the two endpoints plus a
                    // pin at each.
                    if (_distA != null && _distB != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_distA!, _distB!],
                            strokeWidth: 3,
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    if (_distA != null || _distB != null)
                      MarkerLayer(
                        markers: [
                          for (final p in [_distA, _distB])
                            if (p != null)
                              Marker(
                                point: p,
                                width: 28,
                                height: 28,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.place,
                                  color: Colors.black87,
                                  size: 28,
                                ),
                              ),
                        ],
                      ),
                    // Draggable handles for the object being edited: drag to
                    // move a point (persisted on release), long-press for its
                    // menu. Circle/plane/subspace/freehand points and the
                    // freehand-line & height bounding-circle centres.
                    if (hasSelection)
                      DragMarkers(
                        markers: [
                          if (selectedCircle != null) ...[
                            _dragHandle(
                              LatLng(
                                selectedCircle.centerLat,
                                selectedCircle.centerLng,
                              ),
                              key: ValueKey('circle-${selectedCircle.id}'),
                              label: selectedCircle.label,
                              undoLabel: 'Circle',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateCircle(
                                    selectedCircle.id,
                                    centerLat: ll.latitude,
                                    centerLng: ll.longitude,
                                  ),
                              onMenu: (pos) =>
                                  _showCircleMenu(selectedCircle, pos),
                            ),
                            _radiusHandle(
                              LatLng(
                                selectedCircle.centerLat,
                                selectedCircle.centerLng,
                              ),
                              selectedCircle.radiusMeters,
                              key: ValueKey('circle-r-${selectedCircle.id}'),
                              onResize: (m) => ref
                                  .read(repositoryProvider)
                                  .updateCircle(
                                    selectedCircle.id,
                                    radiusMeters: m,
                                  ),
                            ),
                          ],
                          if (selectedPlane != null) ...[
                            _dragHandle(
                              LatLng(selectedPlane.aLat, selectedPlane.aLng),
                              key: ValueKey('plane-${selectedPlane.id}-A'),
                              label: selectedPlane.label,
                              undoLabel: 'Point',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updatePlane(
                                    selectedPlane.id,
                                    aLat: ll.latitude,
                                    aLng: ll.longitude,
                                  ),
                              onMenu: (pos) =>
                                  _showPlaneMenu(selectedPlane, pos),
                            ),
                            _dragHandle(
                              LatLng(selectedPlane.bLat, selectedPlane.bLng),
                              key: ValueKey('plane-${selectedPlane.id}-B'),
                              undoLabel: 'Point',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updatePlane(
                                    selectedPlane.id,
                                    bLat: ll.latitude,
                                    bLng: ll.longitude,
                                  ),
                              onMenu: (pos) =>
                                  _showPlaneMenu(selectedPlane, pos),
                            ),
                          ],
                          for (final p in selectedSubspacePoints)
                            _dragHandle(
                              LatLng(p.lat, p.lng),
                              key: ValueKey('sub-${p.id}'),
                              main: p.isMain,
                              label: p.label,
                              undoLabel: 'Point',
                              marked: _markedPoints.contains(p.id),
                              onTapToggle: () => _toggleMarked(p.id),
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateSubspacePoint(
                                    p.id,
                                    lat: ll.latitude,
                                    lng: ll.longitude,
                                  ),
                              onMenu: (pos) => _showSubspacePointMenu(
                                p,
                                selectedSubspacePoints,
                                pos,
                              ),
                            ),
                          for (final p in selectedFreeLinePoints)
                            _dragHandle(
                              LatLng(p.lat, p.lng),
                              key: ValueKey('fl-${p.id}'),
                              undoLabel: 'Point',
                              marked: _markedPoints.contains(p.id),
                              onTapToggle: () => _toggleMarked(p.id),
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateFreeLinePoint(
                                    p.id,
                                    lat: ll.latitude,
                                    lng: ll.longitude,
                                  ),
                              onMenu: (pos) => _showFreeVertexMenu(
                                pos,
                                title: 'Line point',
                                canRemove: selectedFreeLinePoints.length > 2,
                                onRemove: () => ref
                                    .read(repositoryProvider)
                                    .deleteFreeLinePoint(p.id),
                              ),
                            ),
                          if (selectedFreeLineInclusion != null) ...[
                            _dragHandle(
                              selectedFreeLineInclusion.center,
                              key: ValueKey(
                                'fl-center-${selectedFreeLine!.id}',
                              ),
                              core: _crosshairCore(),
                              undoLabel: 'Centre',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateFreeLine(
                                    selectedFreeLine.id,
                                    inclusionLat: ll.latitude,
                                    inclusionLng: ll.longitude,
                                  ),
                            ),
                            _radiusHandle(
                              selectedFreeLineInclusion.center,
                              selectedFreeLineInclusion.radiusMeters,
                              key: ValueKey('fl-r-${selectedFreeLine.id}'),
                              onResize: (m) => ref
                                  .read(repositoryProvider)
                                  .updateFreeLine(
                                    selectedFreeLine.id,
                                    inclusionRadiusMeters: m,
                                  ),
                            ),
                          ],
                          ...?_reshapeHandles(reshapeDraft),
                          ..._labelHandles(selectedBorderArea, selectedBorderLayer),
                          for (final p in selectedFreeAreaPoints)
                            _dragHandle(
                              LatLng(p.lat, p.lng),
                              key: ValueKey('fa-${p.id}'),
                              undoLabel: 'Point',
                              marked: _markedPoints.contains(p.id),
                              onTapToggle: () => _toggleMarked(p.id),
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateFreeAreaPoint(
                                    p.id,
                                    lat: ll.latitude,
                                    lng: ll.longitude,
                                  ),
                              onMenu: (pos) => _showFreeVertexMenu(
                                pos,
                                title: 'Area point',
                                canRemove: selectedFreeAreaPoints.length > 3,
                                onRemove: () => ref
                                    .read(repositoryProvider)
                                    .deleteFreeAreaPoint(p.id),
                              ),
                            ),
                          if (selectedHeightRegion != null) ...[
                            _dragHandle(
                              LatLng(
                                selectedHeightRegion.centerLat,
                                selectedHeightRegion.centerLng,
                              ),
                              key: ValueKey(
                                'height-${selectedHeightRegion.id}',
                              ),
                              core: _crosshairCore(),
                              undoLabel: 'Centre',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateHeightRegion(
                                    selectedHeightRegion.id,
                                    centerLat: ll.latitude,
                                    centerLng: ll.longitude,
                                  ),
                            ),
                            _radiusHandle(
                              LatLng(
                                selectedHeightRegion.centerLat,
                                selectedHeightRegion.centerLng,
                              ),
                              selectedHeightRegion.radiusMeters,
                              key: ValueKey(
                                'height-r-${selectedHeightRegion.id}',
                              ),
                              onResize: (m) => ref
                                  .read(repositoryProvider)
                                  .updateHeightRegion(
                                    selectedHeightRegion.id,
                                    radiusMeters: m,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [TextSourceAttribution(_tiles.attribution)],
                    ),
                  ],
                ),
                // The stroke being drawn. Translucent so the map underneath
                // still receives the pointers it needs for two-finger
                // pan/pinch — the Listener only *watches*, and the one-finger
                // conflict is resolved by turning the map's drag off instead.
                if (mode == MapMode.draw)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _strokeDown,
                      onPointerMove: _strokeMove,
                      onPointerUp: _strokeUp,
                      onPointerCancel: _strokeUp,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: StrokePainter(
                            points: _stroke,
                            repaint: _strokeRevision,
                            closed: _drawType == 'freearea',
                            color: Color(
                              layers
                                      .where((l) => l.id == _drawLayerId)
                                      .firstOrNull
                                      ?.colorArgb ??
                                  0xFF2196F3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // The only chrome over the map: a menu button at the top-left.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 2,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Layers',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                    ),
                  ),
                ),
                // …and a compass at the top-right, but only while the map is
                // rotated. It is map chrome rather than a FAB on purpose: a
                // two-finger pinch also rotates, and the FAB column is hidden
                // both when the tools are collapsed and while an editor sheet
                // is open — so as a FAB it was invisible in exactly the states
                // where an accidental rotation gets noticed.
                if (_rotation != 0)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 2,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: 'Reset to north-up',
                            onPressed: () => _mapController.rotate(0),
                            icon: Transform.rotate(
                              // Counter-rotate so the needle points to
                              // map-north.
                              angle: -_rotation * math.pi / 180,
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Add-mode banner: what to tap, plus Undo / Edit last / Done.
                if (mode == MapMode.add && _placeLayerId != null)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.touch_app_outlined, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _addBannerText(
                                      _placeType,
                                      _addSteps.length,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      (_addSteps.isEmpty &&
                                          _pendingPlaneA == null)
                                      ? null
                                      : _undoLastAdd,
                                  child: const Text('Undo'),
                                ),
                                if (_addSteps.isNotEmpty)
                                  TextButton(
                                    onPressed: _editLastAdded,
                                    child: const Text('Edit'),
                                  ),
                                TextButton(
                                  onPressed: _finishAdd,
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Draw-mode banner. It earns its place twice over: it is the
                // only thing that says one-finger pan is off for the moment.
                if (mode == MapMode.draw && _drawLayerId != null)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.gesture, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _drawBannerText(_addSteps.length),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _addSteps.isEmpty
                                      ? null
                                      : _undoLastAdd,
                                  child: const Text('Undo'),
                                ),
                                TextButton(
                                  onPressed: _finishDraw,
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Recording banner. Deliberately unmissable and always on
                // screen while recording: the phone is reading its position,
                // which is the one thing this app does that the user must
                // never be able to forget is running.
                if (recording.isRecording)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Material(
                          color: Colors.red.shade600,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fiber_manual_record,
                                    size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _recordingBannerText(recording),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => ref
                                      .read(trackRecordingProvider.notifier)
                                      .stop(),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.white),
                                  child: const Text('Stop'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Bulk-delete banner: appears while any vertices are marked.
                if (_markedPoints.isNotEmpty)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${_markedPoints.length} selected'),
                                TextButton.icon(
                                  onPressed: _deleteMarked,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Delete'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _markedPoints.clear()),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Elevation readout: the measured point and/or current location.
                if (mode == MapMode.elevation ||
                    _probePoint != null ||
                    _myElevation != null ||
                    mode == MapMode.distance ||
                    _distA != null)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (mode == MapMode.elevation ||
                                    _probePoint != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.place_outlined,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _probing
                                            ? 'Measuring…'
                                            : _probeElevation != null
                                            ? 'Point: ${_formatElevation(_probeElevation!)}'
                                            : _probePoint != null
                                            ? 'Point: n/a'
                                            : 'Tap the map to measure',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                if (_myElevation != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.my_location, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'You: ${_formatElevation(_myElevation!)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                if (mode == MapMode.distance || _distA != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.straighten, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        _distA != null && _distB != null
                                            ? '${_formatDistance(_hitTest(_distA!, _distB!))} · '
                                                  '${_hitTest.bearing(_distA!, _distB!).round()}°'
                                            : _distA != null
                                            ? 'Tap the second point'
                                            : 'Tap two points',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      if (mode == MapMode.distance) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: _distanceFromMyLocation,
                                          icon: const Icon(
                                            Icons.my_location,
                                            size: 16,
                                          ),
                                          label: const Text('My location'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            minimumSize: const Size(0, 32),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      // While an editor sheet is open it provides its own delete/close, and the
      // FABs would overlap it — so show them only when nothing is selected.
      floatingActionButton: hasSelection
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (toolsExpanded) ...[
                  // Offline download exists only where the tile source allows
                  // pre-emptive fetching — not on the community OSM servers.
                  // See `data/tile_source.dart`.
                  if (_tiles.allowsPrefetch) ...[
                    FloatingActionButton.small(
                      heroTag: 'download',
                      tooltip: 'Download this area for offline use',
                      onPressed: _downloading ? null : _downloadArea,
                      child: _downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_for_offline_outlined),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // (The compass lives on the map itself, top-right, and only
                  // while the map is rotated — see the map chrome above.)
                  FloatingActionButton.small(
                    heroTag: 'locate',
                    tooltip: 'Locate me',
                    onPressed: _locating ? null : _locateMe,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'probe',
                    tooltip: 'Measure elevation',
                    backgroundColor: mode == MapMode.elevation
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: mode == MapMode.elevation
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    onPressed: _toggleProbe,
                    child: const Icon(Icons.terrain),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'distance',
                    tooltip: 'Measure distance',
                    backgroundColor: mode == MapMode.distance
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: mode == MapMode.distance
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    onPressed: _toggleDistance,
                    child: const Icon(Icons.straighten),
                  ),
                  const SizedBox(height: 12),
                  // Freehand layers only: there is nothing to draw into on a
                  // circle, a plane or an import layer.
                  if (canDraw) ...[
                    FloatingActionButton.small(
                      heroTag: 'draw',
                      tooltip: 'Draw with your finger',
                      backgroundColor: mode == MapMode.draw
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      foregroundColor: mode == MapMode.draw
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                      onPressed: () => mode == MapMode.draw
                          ? _finishDraw()
                          : _enterDrawMode(activeLayer!),
                      child: const Icon(Icons.gesture),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                // Bottom row: the tools toggle, an optional POI-import button
                // (circle/subspace layers only), then the primary Add button.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fabsToggle',
                      tooltip: toolsExpanded ? 'Hide tools' : 'Show tools',
                      onPressed: () => ref
                          .read(repositoryProvider)
                          .updateToolsExpanded(!toolsExpanded),
                      child: Icon(
                        toolsExpanded ? Icons.unfold_less : Icons.unfold_more,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Edit mode: while on, a plain tap selects the object under
                    // it. Kept outside the collapsible tools group — selecting
                    // by tap must always be one press away.
                    FloatingActionButton.small(
                      heroTag: 'editMode',
                      // Disabled states say *why*, so a grey button reads as an
                      // answer rather than as breakage.
                      tooltip: activeLayer == null
                          ? 'No layer to edit'
                          : !activeHasEditor
                          ? 'Imported layers have no editor — use '
                                'Elements to find an item'
                          : !activeHasElements
                          ? 'Nothing to edit yet — add something '
                                'first'
                          : mode == MapMode.edit
                          ? 'Stop selecting by tap'
                          : 'Select by tapping the map',
                      // A FAB does not grey itself when onPressed is null, so
                      // the disabled colour is explicit — same as the Add FAB.
                      backgroundColor: !canEditByTap
                          ? Theme.of(context).disabledColor
                          : mode == MapMode.edit
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      foregroundColor: mode == MapMode.edit
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                      onPressed: !canEditByTap
                          ? null
                          : () => _enterMode(
                              mode == MapMode.edit
                                  ? MapMode.view
                                  : MapMode.edit,
                            ),
                      child: Icon(
                        mode == MapMode.edit ? Icons.edit : Icons.edit_outlined,
                      ),
                    ),
                    if (isCircleLayer || isSubspaceLayer) ...[
                      const SizedBox(width: 12),
                      FloatingActionButton.small(
                        heroTag: 'poiImport',
                        tooltip: 'Import nearby POIs',
                        onPressed: activeLayer == null
                            ? null
                            : () => _importPois(activeLayer),
                        child: const Icon(Icons.travel_explore),
                      ),
                    ],
                    const SizedBox(width: 12),
                    // Add is a sticky *mode*, not an instant create: tapping it
                    // arms the map so a tap places the object exactly where you
                    // point. Long-press keeps the old one-shot behaviour (place
                    // at the map centre, open the editor) as a no-aim fallback.
                    if (activeLayer?.type == 'track')
                      // A track layer records rather than places: the primary
                      // action is the recorder, and Add mode is never armed
                      // (there is no such thing as tapping a fix onto the map).
                      FloatingActionButton.extended(
                        heroTag: 'add',
                        tooltip: recording.isRecording
                            ? 'Stop recording'
                            : 'Record your position into this layer',
                        onPressed: () => _toggleRecording(activeLayer!),
                        backgroundColor:
                            recording.isRecording ? Colors.red.shade600 : null,
                        foregroundColor:
                            recording.isRecording ? Colors.white : null,
                        icon: Icon(recording.isRecording
                            ? Icons.stop
                            : Icons.fiber_manual_record),
                        label: Text(recording.isRecording ? 'Stop' : 'Record'),
                      )
                    else
                    GestureDetector(
                      onLongPress: activeLayer == null
                          ? null
                          : () => _addAtMapCentre(
                              activeLayer,
                              subspaces: subspaces,
                              freeLines: freeLines,
                              freeAreas: freeAreas,
                            ),
                      child: FloatingActionButton.extended(
                        heroTag: 'add',
                        tooltip:
                            'Tap the map to add · long-press for the '
                            'map centre',
                        onPressed: activeLayer == null
                            ? null
                            : () => mode == MapMode.add
                                  ? _finishAdd()
                                  : _enterAddMode(activeLayer),
                        backgroundColor: activeLayer == null
                            ? Theme.of(context).disabledColor
                            : mode == MapMode.add
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        foregroundColor: mode == MapMode.add
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                        icon: Icon(
                          mode == MapMode.add
                              ? Icons.check
                              : typeIcon(activeLayer?.type ?? 'circles'),
                        ),
                        label: Text(
                          mode == MapMode.add
                              ? 'Done'
                              : _addFabLabel(activeLayer?.type),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      bottomSheet: !hasSelection
          ? null
          : CollapsibleSheet(
              // Reset to expanded whenever the selected object changes.
              key: ValueKey(
                'sheet-'
                '${selectedCircle?.id ?? selectedPlane?.id ?? selectedSubspace?.id ?? selectedFreeLine?.id ?? selectedFreeArea?.id ?? selectedHeightRegion?.id ?? selectedPoiSet?.id ?? selectedPoiPoint?.id ?? selectedTransitSet?.id ?? selectedTransitStop?.id ?? selectedBorderArea?.id}',
              ),
              child: selectedCircle != null
                  ? CircleEditorSheet(
                      key: ValueKey(selectedCircle.id),
                      circle: selectedCircle,
                      layers: layers,
                    )
                  : selectedPlane != null
                  ? PlaneEditorSheet(
                      key: ValueKey(selectedPlane.id),
                      plane: selectedPlane,
                      layers: layers,
                    )
                  : selectedSubspace != null
                  ? SubspaceEditorSheet(
                      key: ValueKey(selectedSubspace.id),
                      subspace: selectedSubspace,
                      points: selectedSubspacePoints,
                      layers: layers,
                      onAddPoint: () => _addSubspaceAt(
                        _mapController.camera.center,
                        layers.firstWhere(
                          (l) => l.id == selectedSubspace.layerId,
                        ),
                        subspaces,
                      ),
                    )
                  : selectedFreeLine != null
                  ? FreeLineEditorSheet(
                      key: ValueKey(selectedFreeLine.id),
                      freeLine: selectedFreeLine,
                      points: selectedFreeLinePoints,
                      layers: layers,
                      onAddPoint: () => _addFreeLineAt(
                        _mapController.camera.center,
                        layers.firstWhere(
                          (l) => l.id == selectedFreeLine.layerId,
                        ),
                        freeLines,
                      ),
                    )
                  : selectedFreeArea != null
                  ? FreeAreaEditorSheet(
                      key: ValueKey(selectedFreeArea.id),
                      freeArea: selectedFreeArea,
                      points: selectedFreeAreaPoints,
                      layers: layers,
                      onAddPoint: () => _addFreeAreaAt(
                        _mapController.camera.center,
                        layers.firstWhere(
                          (l) => l.id == selectedFreeArea.layerId,
                        ),
                        freeAreas,
                      ),
                    )
                  : selectedHeightRegion != null
                  ? HeightEditorSheet(
                      key: ValueKey(selectedHeightRegion.id),
                      region: selectedHeightRegion,
                      polygonCount:
                          heightPolygons[selectedHeightRegion.id]?.length ?? 0,
                      layers: layers,
                    )
                  : selectedPoiPoint != null
                  ? ImportedPointEditorSheet(
                      key: ValueKey(selectedPoiPoint.id),
                      id: selectedPoiPoint.id,
                      kind: ObjectKind.poiPoint,
                      name: selectedPoiPoint.name,
                      lat: selectedPoiPoint.lat,
                      lng: selectedPoiPoint.lng,
                      icon: Icons.place_outlined,
                      title: 'Edit POI',
                      subtitle: _poiCategoryLabel(
                        poiSets,
                        selectedPoiPoint.poiSetId,
                      ),
                    )
                  : selectedTransitStop != null
                  ? ImportedPointEditorSheet(
                      key: ValueKey(selectedTransitStop.id),
                      id: selectedTransitStop.id,
                      kind: ObjectKind.transitStop,
                      name: selectedTransitStop.name,
                      lat: selectedTransitStop.lat,
                      lng: selectedTransitStop.lng,
                      icon: Icons.directions_transit,
                      title: 'Edit station',
                      subtitle:
                          transitModeLabels(selectedTransitStop.modeMask),
                    )
                  : selectedPoiSet != null
                  ? PoiSetEditorSheet(
                      key: ValueKey(selectedPoiSet.id),
                      set: selectedPoiSet,
                      pointCount: poiPoints
                          .where((p) => p.poiSetId == selectedPoiSet.id)
                          .length,
                      layers: [
                        for (final l in layers)
                          if (l.type == 'poi') l,
                      ],
                    )
                  : selectedTransitSet != null
                  ? TransitSetEditorSheet(
                      key: ValueKey(selectedTransitSet.id),
                      set: selectedTransitSet,
                      stopCount: transitStations
                          .where((x) => x.setId == selectedTransitSet.id)
                          .length,
                      layers: [
                        for (final l in layers)
                          if (l.type == 'transit') l,
                      ],
                    )
                  : selectedBorderArea != null && selectedBorderLayer != null
                  ? BorderAreaEditorSheet(
                      key: ValueKey(selectedBorderArea.id),
                      area: selectedBorderArea,
                      layer: selectedBorderLayer,
                    )
                  : const SizedBox.shrink(),
            ),
    );
  }
}
