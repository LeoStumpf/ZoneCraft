import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
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
import '../data/overpass.dart';
import '../geo/geodesic.dart';
import '../geo/tiles.dart';
import '../state/providers.dart';
import 'circle_editor.dart';
import 'collapsible_sheet.dart';
import 'freearea_editor.dart';
import 'freeline_editor.dart';
import 'height_editor.dart';
import 'layers_panel.dart';
import 'plane_editor.dart';
import 'poi_import_dialog.dart';
import 'poi_layer.dart';
import 'region_geometry.dart';
import 'region_layer.dart';
import 'subspace_editor.dart';

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
  // Tap-to-place mode for seeding a new point-set object: while set, map taps
  // drop points into this (empty) layer instead of selecting. Holds the layer
  // id + type; a banner offers "Done".
  String? _placeLayerId;
  String? _placeType;
  // Vertex ids marked (by tapping their handle) for bulk delete; all belong to
  // the currently selected object. Cleared on any selection change.
  final Set<String> _markedPoints = {};
  static const _hitTest = Distance(calculator: Haversine());

  /// The user's last known position, shown as a marker. Null until the user
  /// opts in via the "Locate me" button. We never request location at launch.
  LatLng? _myPosition;
  bool _locating = false;
  bool _mapReady = false;

  /// Terrain elevation (m) at the current "Locate me" position, when known.
  double? _myElevation;

  // --- Elevation probe ------------------------------------------------------
  /// When on, a map tap measures the terrain elevation at that point instead of
  /// selecting/deselecting objects.
  bool _probeMode = false;
  LatLng? _probePoint;
  double? _probeElevation;
  bool _probing = false;

  // --- Distance probe -------------------------------------------------------
  /// When on, the first two map taps set the endpoints of a distance/bearing
  /// measurement; a third tap restarts from a fresh first point.
  bool _distanceMode = false;
  LatLng? _distA;
  LatLng? _distB;


  // --- Offline tile cache ---------------------------------------------------
  /// Tile URL templates, shared by the [TileLayer]s and the offline prefetcher
  /// so the two never drift apart.
  static const _baseTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _opnvTileUrl = 'https://tile.memomaps.de/tilegen/{z}/{x}/{y}.png';
  static const _railTileUrl =
      'https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png';
  static const _tileUserAgent =
      'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)';

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

  // --- Administrative borders (Overpass) ------------------------------------
  List<BorderLine> _borders = const [];
  Set<BorderLevel> _enabledBorders = const {};
  int _borderMask = 0;
  Timer? _bordersDebounce;
  LatLngBounds? _bordersFetchedBounds;
  // The set of levels (by bits) the current borders were fetched with. The
  // active set depends on zoom (coarse levels show out, fine ones only in).
  int _bordersFetchedActiveBits = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tileClient = http.Client();
    _tileProvider = CachedTileProvider(
      ref.read(repositoryProvider),
      _tileClient,
      headers: {'User-Agent': _tileUserAgent},
    );
    _loadCachedOverlays();
  }

  /// Seeds the border overlay from its last-persisted result so it appears
  /// instantly on launch — including offline — until a fresh fetch (if any)
  /// replaces it. Mirrors the in-memory coverage state so a redundant refetch
  /// is suppressed while the view stays inside the cached bounds.
  Future<void> _loadCachedOverlays() async {
    final repo = ref.read(repositoryProvider);
    final border = await repo.loadOverpassCache('border');
    if (!mounted) return;
    setState(() {
      if (border != null) {
        _borders = decodeBorderLines(border.payload);
        _bordersFetchedBounds = LatLngBounds(
            LatLng(border.south, border.west), LatLng(border.north, border.east));
        _bordersFetchedActiveBits = border.maskBits;
      }
    });
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
    _bordersDebounce?.cancel();
    _prefetchDebounce?.cancel();
    _tileClient.close();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  static bool _boundsContain(LatLngBounds outer, LatLngBounds inner) =>
      inner.south >= outer.south &&
      inner.north <= outer.north &&
      inner.west >= outer.west &&
      inner.east <= outer.east;

  static LatLngBounds _inflateBounds(LatLngBounds b, double margin) {
    final dLat = (b.north - b.south) * margin;
    final dLng = (b.east - b.west) * margin;
    return LatLngBounds(
      LatLng(b.south - dLat, b.west - dLng),
      LatLng(b.north + dLat, b.east + dLng),
    );
  }

  /// Debounced administrative-borders refresh (same coalescing as POIs).
  void _scheduleBordersRefresh() {
    _bordersDebounce?.cancel();
    _bordersDebounce = Timer(const Duration(milliseconds: 600), _refreshBorders);
  }

  /// Fetches border lines for the enabled levels that are visible at the
  /// current zoom (coarse levels show when zoomed out, fine ones only when
  /// zoomed in). Same view-coverage cache, inflated fetch, and keep-on-failure
  /// behaviour as POIs.
  Future<void> _refreshBorders() async {
    if (!_mapReady || !mounted) return;
    final cam = _mapController.camera;
    if (!cam.center.latitude.isFinite ||
        !cam.center.longitude.isFinite ||
        !cam.zoom.isFinite) {
      return;
    }
    final active = {
      for (final l in _enabledBorders)
        if (cam.zoom >= l.minZoom) l,
    };
    if (active.isEmpty) {
      _bordersFetchedBounds = null;
      if (_borders.isNotEmpty) setState(() => _borders = const []);
      return;
    }
    final activeBits = active.fold<int>(0, (acc, l) => acc | l.bit);
    final vp = cam.visibleBounds;
    if (_bordersFetchedActiveBits == activeBits &&
        _bordersFetchedBounds != null &&
        _boundsContain(_bordersFetchedBounds!, vp)) {
      return;
    }

    final q = _inflateBounds(vp, 0.3);
    final results = await fetchBorders(
      south: q.south,
      west: q.west,
      north: q.north,
      east: q.east,
      levels: active,
    );
    if (!mounted) return;
    if (results == null) {
      _bordersFetchedBounds = null;
      _bordersDebounce?.cancel();
      _bordersDebounce = Timer(const Duration(seconds: 4), _refreshBorders);
      return;
    }
    _bordersFetchedBounds = q;
    _bordersFetchedActiveBits = activeBits;
    setState(() => _borders = results);
    unawaited(ref.read(repositoryProvider).saveOverpassCache(
          'border',
          encodeBorderLines(results),
          south: q.south,
          west: q.west,
          north: q.north,
          east: q.east,
          maskBits: activeBits,
        ));
  }

  /// Debounced offline-tile prefetch (same coalescing as the overlays).
  void _schedulePrefetch() {
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(const Duration(milliseconds: 600), _prefetchTiles);
  }

  /// Best-effort: caches the tiles covering the current viewport plus a one-tile
  /// ring around it (and the transport overlays when enabled), so a short pan or
  /// scroll while offline still has tiles. Capped, sequential, and failure-safe
  /// so it never blocks the UI or hammers the tile servers.
  Future<void> _prefetchTiles() async {
    if (!_mapReady || !mounted) return;
    final cam = _mapController.camera;
    if (!cam.center.latitude.isFinite ||
        !cam.center.longitude.isFinite ||
        !cam.zoom.isFinite) {
      return;
    }
    final z = cam.zoom.round().clamp(0, 19);
    if (z < _prefetchMinZoom) return;

    final vp = cam.visibleBounds;
    final transport =
        ref.read(settingsProvider).asData?.value.transportOverlay ?? false;

    // Visible tiles widened by a one-tile ring, capped by a budget.
    final tiles = tilesCovering(
      west: vp.west,
      east: vp.east,
      north: vp.north,
      south: vp.south,
      z: z,
      ring: 1,
    );
    var budget = _prefetchMaxTiles;
    for (final t in tiles) {
      await _tileProvider.prefetch(_fillTileUrl(_baseTileUrl, z, t.x, t.y));
      if (transport) {
        await _tileProvider.prefetch(_fillTileUrl(_opnvTileUrl, z, t.x, t.y));
        await _tileProvider.prefetch(_fillTileUrl(_railTileUrl, z, t.x, t.y));
      }
      if (--budget <= 0) break;
    }
    if (!mounted) return;
    await ref
        .read(repositoryProvider)
        .evictTilesDownTo(CachedTileProvider.maxCacheBytes);
  }

  static String _fillTileUrl(String template, int z, int x, int y) => template
      .replaceAll('{z}', '$z')
      .replaceAll('{x}', '$x')
      .replaceAll('{y}', '$y');

  /// The tile URLs to cache for an explicit "download this area": the current
  /// viewport at the current zoom plus [_downloadExtraZoomLevels] deeper levels,
  /// base map and (when enabled) the transport overlays. Shallower levels come
  /// first, so when the [_downloadMaxTiles] ceiling trims the list it drops the
  /// deepest detail rather than the view you're looking at.
  List<String> _areaTileUrls(MapCamera cam) {
    final vp = cam.visibleBounds;
    final zBase = cam.zoom.round().clamp(0, 19);
    final transport =
        ref.read(settingsProvider).asData?.value.transportOverlay ?? false;
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
        urls.add(_fillTileUrl(_baseTileUrl, z, t.x, t.y));
        if (transport) {
          urls.add(_fillTileUrl(_opnvTileUrl, z, t.x, t.y));
          urls.add(_fillTileUrl(_railTileUrl, z, t.x, t.y));
        }
        if (urls.length >= _downloadMaxTiles) return urls;
      }
    }
    return urls;
  }

  /// Bulk-downloads the current area for guaranteed offline coverage: confirms
  /// with an estimate, then caches every tile with a cancellable progress
  /// dialog. Freshly written tiles are the most-recently-used, so the LRU cap
  /// evicts older areas first and keeps what you just downloaded.
  Future<void> _downloadArea() async {
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

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Downloading area…'),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, done, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: total == 0 ? null : done / total),
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
    ));

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
    _hint(cancelled
        ? 'Download cancelled — $downloaded new tiles saved'
        : 'Downloaded $downloaded new tiles for offline use');
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

  /// Requests the device's current position, handling permission/service state
  /// with dismissible hints. Returns the fix, or null on denial / disabled
  /// services / a bad (non-finite) fix / any error. Has no side effects on the
  /// map camera — callers decide what to do with the result.
  Future<LatLng?> _getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _hint('Location services are off. Enable them to use Locate me.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _hint('Location permission denied. ZoneCraft works fine without it.');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition();
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
      ..showSnackBar(SnackBar(
        content: Text('$what moved'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Undo', onPressed: revert),
      ));
  }

  /// Toggles tap-to-measure-elevation mode. Clears any previous probe result.
  /// Arming this disarms the distance probe — only one measure mode at a time.
  void _toggleProbe() {
    setState(() {
      _probeMode = !_probeMode;
      if (!_probeMode) {
        _probePoint = null;
        _probeElevation = null;
      } else {
        _distanceMode = false;
        _distA = null;
        _distB = null;
      }
    });
    if (_probeMode) _hint('Tap the map to measure elevation');
  }

  /// Toggles tap-two-points-to-measure-distance mode. Clears any endpoints on
  /// disarm and disarms the elevation probe on arm (one measure mode at a time).
  void _toggleDistance() {
    setState(() {
      _distanceMode = !_distanceMode;
      if (!_distanceMode) {
        _distA = null;
        _distB = null;
      } else {
        _probeMode = false;
        _probePoint = null;
        _probeElevation = null;
      }
    });
    if (_distanceMode) _hint('Tap two points to measure distance');
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
  Future<void> _probeAt(LatLng p) async {
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
      headers: const {'User-Agent': _tileUserAgent},
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
      headers: const {'User-Agent': _tileUserAgent},
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
      onLongPress:
          onMenu == null ? null : (latlng) => onMenu(_globalPosOf(latlng)),
      builder: (context, pos, isDragging) {
        // Marked (for bulk delete): an accent ring around the dot.
        final core = marked
            ? Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 3),
                ),
                child: Center(child: dot),
              )
            : dot;
        final child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasLabel) const SizedBox(height: pad),
            SizedBox(
                width: coreSize, height: coreSize, child: Center(child: core)),
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
              fontSize: 9, height: 1.0, color: Colors.black87),
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
          Text(text),
        ],
      ),
    );
  }

  /// Opens a context menu anchored at [globalPosition] with a disabled [title]
  /// header followed by [items], and returns the chosen value (or null).
  Future<String?> _showPointMenu(
    String title,
    Offset globalPosition,
    List<PopupMenuEntry<String>> items,
  ) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
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
          child: Text(title, style: Theme.of(context).textTheme.labelMedium),
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
      SubspacePoint p, List<SubspacePoint> siblings, Offset pos) async {
    final title =
        (p.label != null && p.label!.isNotEmpty) ? p.label! : 'Subspace point';
    final selected = await _showPointMenu(title, pos, [
      _pointMenuItem('main', p.isMain ? Icons.check_circle : Icons.radio_button_unchecked,
          p.isMain ? 'Already the main point' : 'Set as main point',
          enabled: !p.isMain),
      _pointMenuItem('rename', Icons.label_outline, 'Rename…'),
      _pointMenuItem('remove', Icons.remove_circle_outline, 'Remove point',
          enabled: siblings.length > 1),
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
        await repo.updateSubspacePoint(p.id,
            label: Value(name.isEmpty ? null : name));
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
      _pointMenuItem('remove', Icons.remove_circle_outline, 'Remove point',
          enabled: canRemove),
    ]);
    if (selected == 'remove' && mounted) {
      await onRemove();
      if (mounted) _hint('Point removed.');
    }
  }

  /// Popup menu for a long-pressed circle centre: rename the circle or delete it.
  Future<void> _showCircleMenu(Circle c, Offset pos) async {
    final title =
        (c.label != null && c.label!.isNotEmpty) ? c.label! : 'Circle';
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
    final title =
        (pl.label != null && pl.label!.isNotEmpty) ? pl.label! : 'Plane';
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

  /// The smallest circle in [layerId] that contains [latlng], or null. Hit
  /// testing is geographic (Haversine), independent of rendering.
  Circle? _circleInLayer(LatLng latlng, String layerId, List<Circle> circles) {
    Circle? best;
    for (final c in circles.where((c) => c.layerId == layerId)) {
      if (!c.radiusMeters.isFinite || c.radiusMeters <= 0) continue;
      final d = _hitTest.as(
        LengthUnit.Meter,
        LatLng(c.centerLat, c.centerLng),
        latlng,
      );
      if (d <= c.radiusMeters &&
          (best == null || c.radiusMeters < best.radiusMeters)) {
        best = c;
      }
    }
    return best;
  }

  /// A plane in [layerId] whose near side contains [latlng] (i.e. [latlng] is
  /// closer to its near point than its far point), or null.
  Plane? _planeInLayer(LatLng latlng, String layerId, List<Plane> planes) {
    for (final p in planes.where((p) => p.layerId == layerId)) {
      if (!p.aLat.isFinite ||
          !p.aLng.isFinite ||
          !p.bLat.isFinite ||
          !p.bLng.isFinite) {
        continue;
      }
      final near = p.nearA ? LatLng(p.aLat, p.aLng) : LatLng(p.bLat, p.bLng);
      final far = p.nearA ? LatLng(p.bLat, p.bLng) : LatLng(p.aLat, p.aLng);
      if (_hitTest.as(LengthUnit.Meter, near, latlng) <=
          _hitTest.as(LengthUnit.Meter, far, latlng)) {
        return p;
      }
    }
    return null;
  }

  /// A subspace in [layerId] whose main point is the nearest of its points to
  /// [latlng] (Haversine) — i.e. [latlng] lies inside the main cell — or null.
  Subspace? _subspaceInLayer(
    LatLng latlng,
    String layerId,
    List<Subspace> subspaces,
    List<SubspacePoint> points,
  ) {
    for (final s in subspaces.where((s) => s.layerId == layerId)) {
      final pts = points.where((p) => p.subspaceId == s.id).toList();
      if (pts.length < 2) continue;
      SubspacePoint? nearest;
      double bestD = double.infinity;
      for (final p in pts) {
        if (!p.lat.isFinite || !p.lng.isFinite) continue;
        final d = _hitTest.as(LengthUnit.Meter, LatLng(p.lat, p.lng), latlng);
        if (d < bestD) {
          bestD = d;
          nearest = p;
        }
      }
      if (nearest != null && nearest.isMain) return s;
    }
    return null;
  }

  /// A freehand line in [layerId] whose drawn polyline passes within a tap
  /// tolerance of [latlng], or null. Hit testing is done in screen space so the
  /// tolerance is a constant number of pixels at any zoom.
  FreeLine? _freeLineInLayer(
    LatLng latlng,
    String layerId,
    List<FreeLine> lines,
    List<FreeLinePoint> points,
  ) {
    const tol = 24.0;
    final cam = _mapController.camera;
    final tap = cam.latLngToScreenOffset(latlng);
    for (final l in lines.where((l) => l.layerId == layerId)) {
      final pts = points.where((p) => p.freeLineId == l.id).toList();
      for (var i = 0; i < pts.length - 1; i++) {
        final a = cam.latLngToScreenOffset(LatLng(pts[i].lat, pts[i].lng));
        final b =
            cam.latLngToScreenOffset(LatLng(pts[i + 1].lat, pts[i + 1].lng));
        if (_distToSegment(tap, a, b) <= tol) return l;
      }
    }
    return null;
  }

  /// A freehand area in [layerId] whose drawn ring contains [latlng], or null.
  /// Point-in-polygon is evaluated in screen space.
  FreeArea? _freeAreaInLayer(
    LatLng latlng,
    String layerId,
    List<FreeArea> areas,
    List<FreeAreaPoint> points,
  ) {
    final cam = _mapController.camera;
    final tap = cam.latLngToScreenOffset(latlng);
    for (final a in areas.where((a) => a.layerId == layerId)) {
      final pts = points.where((p) => p.freeAreaId == a.id).toList();
      if (pts.length < 3) continue;
      final ring = <Offset>[
        for (final p in pts) cam.latLngToScreenOffset(LatLng(p.lat, p.lng)),
      ];
      if (_pointInPolygon(tap, ring)) return a;
    }
    return null;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  static bool _pointInPolygon(Offset p, List<Offset> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final pi = poly[i], pj = poly[j];
      if (((pi.dy > p.dy) != (pj.dy > p.dy)) &&
          (p.dx <
              (pj.dx - pi.dx) * (p.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _clearSelection() {
    ref.read(selectedCircleProvider.notifier).select(null);
    ref.read(circlePlacementProvider.notifier).arm(false);
    ref.read(selectedPlaneProvider.notifier).select(null);
    ref.read(planePlacementProvider.notifier).arm(null);
    ref.read(selectedSubspaceProvider.notifier).select(null);
    ref.read(subspacePlacementProvider.notifier).arm(null);
    ref.read(selectedFreeLineProvider.notifier).select(null);
    ref.read(freeLinePlacementProvider.notifier).arm(null);
    ref.read(freeLineCenterPlacementProvider.notifier).arm(false);
    ref.read(selectedFreeAreaProvider.notifier).select(null);
    ref.read(freeAreaPlacementProvider.notifier).arm(null);
    ref.read(selectedHeightRegionProvider.notifier).select(null);
    ref.read(heightPlacementProvider.notifier).arm(false);
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
        final remaining =
            pts.where((p) => !_markedPoints.contains(p.id)).toList();
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

  void _selectCircle(String id) {
    _clearSelection();
    ref.read(selectedCircleProvider.notifier).select(id);
  }

  void _selectPlane(String id) {
    _clearSelection();
    ref.read(selectedPlaneProvider.notifier).select(id);
  }

  void _selectSubspace(String id) {
    _clearSelection();
    ref.read(selectedSubspaceProvider.notifier).select(id);
  }

  void _selectFreeLine(String id) {
    _clearSelection();
    ref.read(selectedFreeLineProvider.notifier).select(id);
  }

  void _selectFreeArea(String id) {
    _clearSelection();
    ref.read(selectedFreeAreaProvider.notifier).select(id);
  }

  void _selectHeightRegion(String id) {
    _clearSelection();
    ref.read(selectedHeightRegionProvider.notifier).select(id);
  }

  /// A height region in [layerId] whose bounded circle contains [latlng]
  /// (Haversine), preferring the smallest, or null.
  HeightRegion? _heightRegionInLayer(
    LatLng latlng,
    String layerId,
    List<HeightRegion> regions,
  ) {
    HeightRegion? best;
    for (final r in regions.where((r) => r.layerId == layerId)) {
      if (!r.radiusMeters.isFinite || r.radiusMeters <= 0) continue;
      final d = _hitTest.as(
        LengthUnit.Meter,
        LatLng(r.centerLat, r.centerLng),
        latlng,
      );
      if (d <= r.radiusMeters &&
          (best == null || r.radiusMeters < best.radiusMeters)) {
        best = r;
      }
    }
    return best;
  }

  /// Adds a height region to [layer] at [center] (un-generated — the editor's
  /// Generate fills it). A sensible default radius scales with the current zoom.
  Future<void> _addHeightRegionAt(LatLng center, Layer layer) async {
    final id = await ref.read(repositoryProvider).createHeightRegion(
          layerId: layer.id,
          centerLat: center.latitude,
          centerLng: center.longitude,
          radiusMeters: _defaultRadius().clamp(100.0, 25000.0),
        );
    _selectHeightRegion(id);
  }

  Future<void> _addCircleAt(LatLng latlng, Layer layer) async {
    final id = await ref
        .read(repositoryProvider)
        .createCircle(
          layerId: layer.id,
          centerLat: latlng.latitude,
          centerLng: latlng.longitude,
          radiusMeters: _defaultRadius(),
        );
    _selectCircle(id);
  }

  /// Imports nearby POIs into [layer]: prompts for a category + radius,
  /// fetches POIs of that type around the map centre **once**, then creates —
  /// per layer type — one named circle per POI (circles), appended named
  /// points (subspace; the nearest-to-centre promotes to main when the
  /// subspace has none yet), or a stored offline POI set with markers (poi).
  Future<void> _importPois(Layer layer) async {
    final isCircleLayer = layer.type == 'circles';
    final isPoiLayer = layer.type == 'poi';
    final config = await showPoiImportDialog(context,
        needsCircleRadius: isCircleLayer, allCategories: isPoiLayer);
    if (config == null || !mounted) return;

    final center = _mapController.camera.center;
    final r = config.searchRadiusMeters;
    // Bounding box from the centre + search radius (N/S/E/W offsets).
    final north = _hitTest.offset(center, r, 0).latitude;
    final south = _hitTest.offset(center, r, 180).latitude;
    final east = _hitTest.offset(center, r, 90).longitude;
    final west = _hitTest.offset(center, r, -90).longitude;

    final fetched = await fetchPois(
      south: south,
      west: west,
      north: north,
      east: east,
      categories: [config.category],
      client: _tileClient,
    );
    if (!mounted) return;
    if (fetched == null) {
      _hint('Could not fetch POIs (offline or rate-limited).');
      return;
    }
    // A POI layer stores everything the fetch returned (up to the Overpass
    // cap); circle/subspace seeding keeps the default tighter cap so the
    // created geometry stays manageable.
    final within = poisWithinRadius(
        center.latitude, center.longitude, r, fetched,
        cap: isPoiLayer ? overpassResultCap : 60);
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
      await repo.addPoiPoints(sid, [
        for (final p in within) (lat: p.lat, lng: p.lng, name: p.name),
      ]);
      if (mounted) _hint('Imported ${within.length} $label.');
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
    final points = ref.read(subspacePointsProvider).asData?.value ??
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
    _hint('Seeded ${within.length} $label '
        '(tap ● to mark the nearest).');
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
  /// Enters tap-to-place mode for [layer] (an empty point-set layer): the next
  /// map taps drop the object's initial points where tapped, instead of a fixed
  /// seed at the map centre. Clears any selection so the banner is unobstructed.
  void _enterPlacement(Layer layer) {
    _clearSelection();
    setState(() {
      _placeLayerId = layer.id;
      _placeType = layer.type;
    });
    _hint('Tap the map to drop points, then tap Done.');
  }

  /// Leaves tap-to-place mode and selects the object just built (so its editor
  /// and draggable handles appear).
  void _exitPlacement() {
    final layerId = _placeLayerId;
    final type = _placeType;
    setState(() {
      _placeLayerId = null;
      _placeType = null;
    });
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
    }
  }

  /// Drops one point at [latlng] while in tap-to-place mode, creating the object
  /// on the first tap and appending on later ones.
  Future<void> _placeTapAt(LatLng latlng) async {
    final repo = ref.read(repositoryProvider);
    final layerId = _placeLayerId!;
    switch (_placeType) {
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
              isMain: true);
        } else {
          await repo.addSubspacePoint(
              subspaceId: existing.id,
              lat: latlng.latitude,
              lng: latlng.longitude);
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
              freeLineId: id, lat: latlng.latitude, lng: latlng.longitude);
        } else {
          await repo.addFreeLinePoint(
              freeLineId: existing.id,
              lat: latlng.latitude,
              lng: latlng.longitude);
        }
      case 'freearea':
        final existing = (ref.read(freeAreasProvider).asData?.value ?? const [])
            .where((a) => a.layerId == layerId)
            .firstOrNull;
        if (existing == null) {
          final id = await repo.createFreeArea(layerId: layerId);
          await repo.addFreeAreaPoint(
              freeAreaId: id, lat: latlng.latitude, lng: latlng.longitude);
        } else {
          await repo.addFreeAreaPoint(
              freeAreaId: existing.id,
              lat: latlng.latitude,
              lng: latlng.longitude);
        }
    }
  }

  Future<void> _addSubspaceAt(
    LatLng center,
    Layer layer,
    List<Subspace> subspaces,
  ) async {
    final repo = ref.read(repositoryProvider);
    final dist = _defaultRadius();
    final existing =
        subspaces.where((s) => s.layerId == layer.id).firstOrNull;
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
        subspaceId: id, lat: w.latitude, lng: w.longitude);
    await repo.addSubspacePoint(
        subspaceId: id, lat: e.latitude, lng: e.longitude);
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
          freeLineId: existing.id, lat: p.latitude, lng: p.longitude);
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
        freeLineId: id, lat: w.latitude, lng: w.longitude);
    await repo.addFreeLinePoint(
        freeLineId: id, lat: e.latitude, lng: e.longitude);
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
          freeAreaId: existing.id, lat: p.latitude, lng: p.longitude);
      _selectFreeArea(existing.id);
      return;
    }
    final id = await repo.createFreeArea(layerId: layer.id);
    // Bearings must be within -180..180 (Distance.offset constraint).
    for (final bearing in [0.0, 120.0, -120.0]) {
      final p = _hitTest.offset(center, dist, bearing);
      await repo.addFreeAreaPoint(
          freeAreaId: id, lat: p.latitude, lng: p.longitude);
    }
    _selectFreeArea(id);
  }

  Future<void> _handleTap(
    LatLng latlng,
    List<Layer> layers,
    List<Circle> circles,
    List<Plane> planes,
    List<Subspace> subspaces,
    List<SubspacePoint> subspacePoints,
    List<FreeLine> freeLines,
    List<FreeLinePoint> freeLinePoints,
    List<FreeArea> freeAreas,
    List<FreeAreaPoint> freeAreaPoints,
    List<HeightRegion> heightRegions,
  ) async {
    // Tap-to-place mode: drop points into the new object instead of selecting.
    if (_placeLayerId != null) {
      await _placeTapAt(latlng);
      return;
    }

    // Placement mode: relocate the selected circle's centre.
    if (ref.read(circlePlacementProvider)) {
      final selId = ref.read(selectedCircleProvider);
      if (selId != null) {
        await ref.read(repositoryProvider).updateCircle(
              selId,
              centerLat: latlng.latitude,
              centerLng: latlng.longitude,
            );
        ref.read(circlePlacementProvider.notifier).arm(false);
        return;
      }
    }

    // Placement mode: relocate the selected height region's centre.
    if (ref.read(heightPlacementProvider)) {
      final selId = ref.read(selectedHeightRegionProvider);
      if (selId != null) {
        await ref.read(repositoryProvider).updateHeightRegion(
              selId,
              centerLat: latlng.latitude,
              centerLng: latlng.longitude,
            );
        ref.read(heightPlacementProvider.notifier).arm(false);
        return;
      }
    }

    // Placement mode: relocate the selected freehand line's inclusion centre.
    if (ref.read(freeLineCenterPlacementProvider)) {
      final selId = ref.read(selectedFreeLineProvider);
      if (selId != null) {
        await ref.read(repositoryProvider).updateFreeLine(
              selId,
              inclusionLat: latlng.latitude,
              inclusionLng: latlng.longitude,
            );
        ref.read(freeLineCenterPlacementProvider.notifier).arm(false);
        return;
      }
    }

    // Placement mode: relocate the armed freehand-line point.
    final armedLine = ref.read(freeLinePlacementProvider);
    final selLineId = ref.read(selectedFreeLineProvider);
    if (armedLine != null && selLineId != null) {
      await ref.read(repositoryProvider).updateFreeLinePoint(
            armedLine,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
      ref.read(freeLinePlacementProvider.notifier).arm(null);
      return;
    }

    // Placement mode: relocate the armed freehand-area point.
    final armedArea = ref.read(freeAreaPlacementProvider);
    final selAreaId = ref.read(selectedFreeAreaProvider);
    if (armedArea != null && selAreaId != null) {
      await ref.read(repositoryProvider).updateFreeAreaPoint(
            armedArea,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
      ref.read(freeAreaPlacementProvider.notifier).arm(null);
      return;
    }

    // Placement mode: relocate the armed subspace point.
    final armedSub = ref.read(subspacePlacementProvider);
    final selSubId = ref.read(selectedSubspaceProvider);
    if (armedSub != null && selSubId != null) {
      await ref.read(repositoryProvider).updateSubspacePoint(
            armedSub,
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
      ref.read(subspacePlacementProvider.notifier).arm(null);
      return;
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
      return;
    }

    // Elevation-probe mode: measure the tapped point instead of selecting (but
    // after any armed point-placement above, which takes priority).
    if (_probeMode) {
      await _probeAt(latlng);
      return;
    }

    // Distance-probe mode: collect two endpoints instead of selecting.
    if (_distanceMode) {
      _distanceTap(latlng);
      return;
    }

    // Only the active layer's objects are selectable: tapping an object in any
    // other layer does nothing (so you interact with exactly the layer you chose
    // in the drawer). With no active layer, nothing is selectable.
    final activeId =
        effectiveActiveLayerId(layers, ref.read(activeLayerProvider));
    for (final layer in layers.reversed) {
      if (layer.id != activeId || !layer.isVisible) continue;
      if (layer.type == 'circles') {
        final hit = _circleInLayer(latlng, layer.id, circles);
        if (hit != null) {
          _selectCircle(hit.id);
          return;
        }
      } else if (layer.type == 'planes') {
        final hit = _planeInLayer(latlng, layer.id, planes);
        if (hit != null) {
          _selectPlane(hit.id);
          return;
        }
      } else if (layer.type == 'subspace') {
        final hit =
            _subspaceInLayer(latlng, layer.id, subspaces, subspacePoints);
        if (hit != null) {
          _selectSubspace(hit.id);
          return;
        }
      } else if (layer.type == 'freeline') {
        final hit =
            _freeLineInLayer(latlng, layer.id, freeLines, freeLinePoints);
        if (hit != null) {
          _selectFreeLine(hit.id);
          return;
        }
      } else if (layer.type == 'freearea') {
        final hit =
            _freeAreaInLayer(latlng, layer.id, freeAreas, freeAreaPoints);
        if (hit != null) {
          _selectFreeArea(hit.id);
          return;
        }
      } else if (layer.type == 'height') {
        final hit = _heightRegionInLayer(latlng, layer.id, heightRegions);
        if (hit != null) {
          _selectHeightRegion(hit.id);
          return;
        }
      }
    }

    // No object hit: just deselect anything selected. Objects are created with
    // the Add button — tapping empty map never adds one.
    if (ref.read(selectedCircleProvider) != null ||
        ref.read(selectedPlaneProvider) != null ||
        ref.read(selectedSubspaceProvider) != null ||
        ref.read(selectedFreeLineProvider) != null ||
        ref.read(selectedFreeAreaProvider) != null ||
        ref.read(selectedHeightRegionProvider) != null) {
      _clearSelection();
    }
  }

  /// Long-press on the map: drop a point at the pressed location. In a
  /// **circles** layer it offers a new circle there; in a **subspace**,
  /// **freeline**, or **freearea** layer with an object selected it adds a
  /// vertex there — appended (subspace) or inserted on the nearest segment
  /// (freeline/freearea), so it's a quicker route than the Add button (which
  /// uses the map centre). The new vertex is immediately draggable.
  Future<void> _handleMapLongPress(
    Offset globalPosition,
    LatLng latlng,
    Layer? activeLayer,
  ) async {
    if (activeLayer == null) return;
    final repo = ref.read(repositoryProvider);
    switch (activeLayer.type) {
      case 'circles':
        if (await _longPressAddMenu(
            globalPosition, Icons.add_circle_outline, 'New circle here')) {
          if (mounted) await _addCircleAt(latlng, activeLayer);
        }
      case 'subspace':
        final selId = ref.read(selectedSubspaceProvider);
        if (selId == null) return;
        if (await _longPressAddMenu(globalPosition,
            Icons.add_location_alt_outlined, 'Add point here')) {
          await repo.addSubspacePoint(
              subspaceId: selId, lat: latlng.latitude, lng: latlng.longitude);
        }
      case 'freeline':
        final selId = ref.read(selectedFreeLineProvider);
        if (selId == null) return;
        if (await _longPressAddMenu(globalPosition,
            Icons.add_location_alt_outlined, 'Insert point here')) {
          final pts = (ref.read(freeLinePointsProvider).asData?.value ??
                  const <FreeLinePoint>[])
              .where((p) => p.freeLineId == selId)
              .map((p) => (ll: LatLng(p.lat, p.lng), order: p.sortOrder))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          await repo.insertFreeLinePointAt(
            freeLineId: selId,
            sortOrder: _insertOrderFor(pts, latlng, closed: false),
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
        }
      case 'freearea':
        final selId = ref.read(selectedFreeAreaProvider);
        if (selId == null) return;
        if (await _longPressAddMenu(globalPosition,
            Icons.add_location_alt_outlined, 'Insert point here')) {
          final pts = (ref.read(freeAreaPointsProvider).asData?.value ??
                  const <FreeAreaPoint>[])
              .where((p) => p.freeAreaId == selId)
              .map((p) => (ll: LatLng(p.lat, p.lng), order: p.sortOrder))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          await repo.insertFreeAreaPointAt(
            freeAreaId: selId,
            sortOrder: _insertOrderFor(pts, latlng, closed: true),
            lat: latlng.latitude,
            lng: latlng.longitude,
          );
        }
    }
  }

  /// Shows a one-item "add here" popup at [globalPosition]; returns whether it
  /// was chosen (vs. dismissed).
  Future<bool> _longPressAddMenu(
      Offset globalPosition, IconData icon, String text) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'ok',
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(text),
            ],
          ),
        ),
      ],
    );
    return selected == 'ok';
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
      final d = _distToSegment(t, a, b);
      if (d < bestDist) {
        bestDist = d;
        // Wrap edge (last→first) appends; otherwise the new point lands between
        // vertices i and i+1 by taking the follower's order and shifting it.
        bestOrder = (closed && i == n - 1) ? appendOrder : pts[i + 1].order;
      }
    }
    return bestOrder;
  }

  @override
  Widget build(BuildContext context) {
    // Triggers one-time seeding of a default layer.
    ref.watch(seedProvider);

    final layers = ref.watch(layersProvider).asData?.value ?? const <Layer>[];
    final circles =
        ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
    final planes = ref.watch(planesProvider).asData?.value ?? const <Plane>[];
    final subspaces =
        ref.watch(subspacesProvider).asData?.value ?? const <Subspace>[];
    final subspacePoints =
        ref.watch(subspacePointsProvider).asData?.value ??
        const <SubspacePoint>[];
    final freeLines =
        ref.watch(freeLinesProvider).asData?.value ?? const <FreeLine>[];
    final freeLinePoints =
        ref.watch(freeLinePointsProvider).asData?.value ??
        const <FreeLinePoint>[];
    final freeAreas =
        ref.watch(freeAreasProvider).asData?.value ?? const <FreeArea>[];
    final freeAreaPoints =
        ref.watch(freeAreaPointsProvider).asData?.value ??
        const <FreeAreaPoint>[];
    final heightRegions =
        ref.watch(heightRegionsProvider).asData?.value ??
        const <HeightRegion>[];
    final heightPolygons =
        ref.watch(heightPolygonsProvider).asData?.value ??
        const <HeightPolygon>[];
    final heightPolygonPoints =
        ref.watch(heightPolygonPointsProvider).asData?.value ??
        const <HeightPolygonPoint>[];
    final poiSets =
        ref.watch(poiSetsProvider).asData?.value ?? const <PoiSet>[];
    final poiPoints =
        ref.watch(poiPointsProvider).asData?.value ?? const <PoiPoint>[];
    final settings = ref.watch(settingsProvider).asData?.value;
    final uncertainty = settings?.uncertaintyMeters ?? 0;
    final transportOverlay = settings?.transportOverlay ?? false;
    final toolsExpanded = settings?.toolsExpanded ?? true;
    final basemapVisible = settings?.basemapVisible ?? true;
    final basemapOpacity = settings?.basemapOpacity ?? 1.0;
    // React to border-level changes.
    final borderMask = settings?.borderLevels ?? 0;
    if (borderMask != _borderMask) {
      _borderMask = borderMask;
      _enabledBorders = borderLevelsFromMask(borderMask);
      _scheduleBordersRefresh();
    }
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
        : subspacePoints
            .where((p) => p.subspaceId == selectedSubspace.id)
            .toList();
    final selectedFreeLine = freeLines
        .where((l) => l.id == ref.watch(selectedFreeLineProvider))
        .firstOrNull;
    final selectedFreeLinePoints = selectedFreeLine == null
        ? const <FreeLinePoint>[]
        : freeLinePoints
            .where((p) => p.freeLineId == selectedFreeLine.id)
            .toList();
    // The inclusion circle bounding the selected line, drawn as an edit guide
    // with a draggable-by-tap centre handle.
    final selectedFreeLineInclusion = selectedFreeLine == null
        ? null
        : effectiveInclusion(
            lat: selectedFreeLine.inclusionLat,
            lng: selectedFreeLine.inclusionLng,
            radiusMeters: selectedFreeLine.inclusionRadiusMeters,
            points: [for (final p in selectedFreeLinePoints) LatLng(p.lat, p.lng)],
          );
    final selectedFreeLineCircle = selectedFreeLineInclusion == null
        ? const <LatLng>[]
        : geodesicCircle(selectedFreeLineInclusion.center,
            selectedFreeLineInclusion.radiusMeters);
    final selectedFreeArea = freeAreas
        .where((a) => a.id == ref.watch(selectedFreeAreaProvider))
        .firstOrNull;
    final selectedFreeAreaPoints = selectedFreeArea == null
        ? const <FreeAreaPoint>[]
        : freeAreaPoints
            .where((p) => p.freeAreaId == selectedFreeArea.id)
            .toList();
    final selectedHeightRegion = heightRegions
        .where((r) => r.id == ref.watch(selectedHeightRegionProvider))
        .firstOrNull;
    final selectedHeightCircle = selectedHeightRegion == null
        ? const <LatLng>[]
        : geodesicCircle(
            LatLng(selectedHeightRegion.centerLat,
                selectedHeightRegion.centerLng),
            selectedHeightRegion.radiusMeters,
          );
    final hasSelection = selectedCircle != null ||
        selectedPlane != null ||
        selectedSubspace != null ||
        selectedFreeLine != null ||
        selectedFreeArea != null ||
        selectedHeightRegion != null;
    // First selection of the session: point out that handles now drag and that
    // long-press adds/edits — the gestures are otherwise invisible.
    if (hasSelection && !_editHintShown) {
      _editHintShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hint('Drag a point to move it · long-press it for options · '
              'long-press the map to add one');
        }
      });
    }
    final activeId = effectiveActiveLayerId(
      layers,
      ref.watch(activeLayerProvider),
    );
    final activeLayer = layers.where((l) => l.id == activeId).firstOrNull;
    final isPlaneLayer = activeLayer?.type == 'planes';
    final isSubspaceLayer = activeLayer?.type == 'subspace';
    final isCircleLayer = activeLayer?.type == 'circles';
    final isFreeLineLayer = activeLayer?.type == 'freeline';
    final isFreeAreaLayer = activeLayer?.type == 'freearea';
    final isHeightLayer = activeLayer?.type == 'height';
    final isPoiLayer = activeLayer?.type == 'poi';
    // In a subspace layer the Add FAB seeds a new object, or — once one exists —
    // appends a point to it.
    final subspaceExists = isSubspaceLayer &&
        subspaces.any((s) => s.layerId == activeLayer!.id);
    final freeLineExists = isFreeLineLayer &&
        freeLines.any((l) => l.layerId == activeLayer!.id);
    final freeAreaExists = isFreeAreaLayer &&
        freeAreas.any((a) => a.layerId == activeLayer!.id);

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
                    onMapReady: () {
                      _mapReady = true;
                      _scheduleBordersRefresh();
                      _schedulePrefetch();
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
                      // Keep the compass needle in sync with map rotation.
                      if (camera.rotation != _rotation) {
                        setState(() => _rotation = camera.rotation);
                      }
                      // Refresh overlays + prefetch tiles once the map settles.
                      _scheduleBordersRefresh();
                      _schedulePrefetch();
                    },
                    onTap: (_, latlng) => _handleTap(
                      latlng,
                      layers,
                      circles,
                      planes,
                      subspaces,
                      subspacePoints,
                      freeLines,
                      freeLinePoints,
                      freeAreas,
                      freeAreaPoints,
                      heightRegions,
                    ),
                    onLongPress: (tapPos, latlng) => _handleMapLongPress(
                        tapPos.global, latlng, activeLayer),
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
                          userAgentPackageName: 'com.zonecraft.zonecraft',
                          tileProvider: _tileProvider,
                          maxZoom: 19,
                        ),
                      ),
                    // Optional transparent public-transport overlays, above the
                    // base map but below the zone layers. ÖPNVKarte carries
                    // buses/trams/stops; OpenRailwayMap the rail network.
                    if (transportOverlay) ...[
                      TileLayer(
                        urlTemplate: _opnvTileUrl,
                        userAgentPackageName: 'com.zonecraft.zonecraft',
                        tileProvider: _tileProvider,
                        maxZoom: 18,
                      ),
                      TileLayer(
                        urlTemplate: _railTileUrl,
                        userAgentPackageName: 'com.zonecraft.zonecraft',
                        tileProvider: _tileProvider,
                        maxZoom: 19,
                      ),
                    ],
                    // One composited region per visible layer, bottom-to-top.
                    // POI layers hold markers, not a region — they render via
                    // their own clustering marker layer. Each layer is wrapped
                    // in Opacity so its per-layer transparency multiplies the
                    // whole layer's paint uniformly (a no-op at 1.0, so default
                    // layers are unchanged and pay nothing).
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
                              (_mapController.camera.zoom + 1.5)
                                  .clamp(2.0, 19.0),
                            ),
                          ),
                        )
                      else if (layer.isVisible)
                        Opacity(
                          opacity: layer.opacity.clamp(0.0, 1.0),
                          child: RegionLayer(
                            key: ValueKey(layer.id),
                            layer: layer,
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
                              : const <SubspacePoint>[],
                          freeLines: layer.type == 'freeline'
                              ? freeLines
                                    .where((l) => l.layerId == layer.id)
                                    .toList()
                              : const <FreeLine>[],
                          freeLinePoints: layer.type == 'freeline'
                              ? freeLinePoints
                              : const <FreeLinePoint>[],
                          freeAreas: layer.type == 'freearea'
                              ? freeAreas
                                    .where((a) => a.layerId == layer.id)
                                    .toList()
                              : const <FreeArea>[],
                          freeAreaPoints: layer.type == 'freearea'
                              ? freeAreaPoints
                              : const <FreeAreaPoint>[],
                          heightRegions: layer.type == 'height'
                              ? heightRegions
                                    .where((r) => r.layerId == layer.id)
                                    .toList()
                              : const <HeightRegion>[],
                          heightPolygons: layer.type == 'height'
                              ? heightPolygons
                              : const <HeightPolygon>[],
                          heightPolygonPoints: layer.type == 'height'
                              ? heightPolygonPoints
                              : const <HeightPolygonPoint>[],
                            uncertaintyMeters: uncertainty,
                          ),
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
                              LatLng(selectedFreeAreaPoints.first.lat,
                                  selectedFreeAreaPoints.first.lng),
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
                    // Administrative borders (Overpass), above the zones so the
                    // lines stay crisp. Present only when enabled at this zoom.
                    if (_borders.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          for (final b in _borders)
                            Polyline(
                              points: b.points,
                              color: Color(b.colorArgb),
                              strokeWidth: 2.5,
                            ),
                        ],
                      ),
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
                                const Icon(Icons.place,
                                    color: Colors.black87, size: 28),
                                Material(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    child: Text(
                                      _probing
                                          ? '…'
                                          : _probeElevation != null
                                              ? _formatElevation(
                                                  _probeElevation!)
                                              : 'n/a',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
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
                                child: const Icon(Icons.place,
                                    color: Colors.black87, size: 28),
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
                                  .updateCircle(selectedCircle.id,
                                      centerLat: ll.latitude,
                                      centerLng: ll.longitude),
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
                                  .updateCircle(selectedCircle.id,
                                      radiusMeters: m),
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
                                  .updatePlane(selectedPlane.id,
                                      aLat: ll.latitude, aLng: ll.longitude),
                              onMenu: (pos) =>
                                  _showPlaneMenu(selectedPlane, pos),
                            ),
                            _dragHandle(
                              LatLng(selectedPlane.bLat, selectedPlane.bLng),
                              key: ValueKey('plane-${selectedPlane.id}-B'),
                              undoLabel: 'Point',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updatePlane(selectedPlane.id,
                                      bLat: ll.latitude, bLng: ll.longitude),
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
                                  .updateSubspacePoint(p.id,
                                      lat: ll.latitude, lng: ll.longitude),
                              onMenu: (pos) => _showSubspacePointMenu(
                                  p, selectedSubspacePoints, pos),
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
                                  .updateFreeLinePoint(p.id,
                                      lat: ll.latitude, lng: ll.longitude),
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
                                  'fl-center-${selectedFreeLine!.id}'),
                              core: _crosshairCore(),
                              undoLabel: 'Centre',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateFreeLine(selectedFreeLine.id,
                                      inclusionLat: ll.latitude,
                                      inclusionLng: ll.longitude),
                            ),
                            _radiusHandle(
                              selectedFreeLineInclusion.center,
                              selectedFreeLineInclusion.radiusMeters,
                              key: ValueKey('fl-r-${selectedFreeLine.id}'),
                              onResize: (m) => ref
                                  .read(repositoryProvider)
                                  .updateFreeLine(selectedFreeLine.id,
                                      inclusionRadiusMeters: m),
                            ),
                          ],
                          for (final p in selectedFreeAreaPoints)
                            _dragHandle(
                              LatLng(p.lat, p.lng),
                              key: ValueKey('fa-${p.id}'),
                              undoLabel: 'Point',
                              marked: _markedPoints.contains(p.id),
                              onTapToggle: () => _toggleMarked(p.id),
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateFreeAreaPoint(p.id,
                                      lat: ll.latitude, lng: ll.longitude),
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
                              LatLng(selectedHeightRegion.centerLat,
                                  selectedHeightRegion.centerLng),
                              key: ValueKey(
                                  'height-${selectedHeightRegion.id}'),
                              core: _crosshairCore(),
                              undoLabel: 'Centre',
                              onMoved: (ll) => ref
                                  .read(repositoryProvider)
                                  .updateHeightRegion(selectedHeightRegion.id,
                                      centerLat: ll.latitude,
                                      centerLng: ll.longitude),
                            ),
                            _radiusHandle(
                              LatLng(selectedHeightRegion.centerLat,
                                  selectedHeightRegion.centerLng),
                              selectedHeightRegion.radiusMeters,
                              key: ValueKey(
                                  'height-r-${selectedHeightRegion.id}'),
                              onResize: (m) => ref
                                  .read(repositoryProvider)
                                  .updateHeightRegion(selectedHeightRegion.id,
                                      radiusMeters: m),
                            ),
                          ],
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [
                        const TextSourceAttribution(
                            '© OpenStreetMap contributors'),
                        if (transportOverlay) ...[
                          const TextSourceAttribution('Transit: ÖPNVKarte'),
                          const TextSourceAttribution(
                              'Rail: OpenRailwayMap (CC-BY-SA)'),
                        ],
                      ],
                    ),
                  ],
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
                // Tap-to-place banner: guides the user and offers Done.
                if (_placeLayerId != null)
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
                                const Text('Tap to add points'),
                                const SizedBox(width: 4),
                                TextButton(
                                  onPressed: _exitPlacement,
                                  child: const Text('Done'),
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
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
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
                if (_probeMode ||
                    _probePoint != null ||
                    _myElevation != null ||
                    _distanceMode ||
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
                                horizontal: 12, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_probeMode || _probePoint != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.place_outlined, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        _probing
                                            ? 'Measuring…'
                                            : _probeElevation != null
                                                ? 'Point: ${_formatElevation(_probeElevation!)}'
                                                : _probePoint != null
                                                    ? 'Point: n/a'
                                                    : 'Tap the map to measure',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                if (_distanceMode || _distA != null)
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      if (_distanceMode) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: _distanceFromMyLocation,
                                          icon: const Icon(Icons.my_location,
                                              size: 16),
                                          label: const Text('My location'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
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
                  FloatingActionButton.small(
                    heroTag: 'compass',
                    tooltip: 'Reset to north-up',
                    onPressed: () => _mapController.rotate(0),
                    child: Transform.rotate(
                      // Counter-rotate so the needle always points to map-north.
                      angle: -_rotation * math.pi / 180,
                      child: const Icon(Icons.navigation, color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    backgroundColor: _probeMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: _probeMode
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    onPressed: _toggleProbe,
                    child: const Icon(Icons.terrain),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'distance',
                    tooltip: 'Measure distance',
                    backgroundColor: _distanceMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: _distanceMode
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    onPressed: _toggleDistance,
                    child: const Icon(Icons.straighten),
                  ),
                  const SizedBox(height: 12),
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
                    FloatingActionButton.extended(
                      heroTag: 'add',
                      onPressed: activeLayer == null
                          ? null
                          : () {
                              final c = _mapController.camera.center;
                              // A POI layer's only "add" is importing a set.
                              if (isPoiLayer) {
                                _importPois(activeLayer);
                                return;
                              }
                              // Empty point-set layer: tap-to-place the initial
                              // points instead of dropping a fixed seed.
                              if ((isSubspaceLayer && !subspaceExists) ||
                                  (isFreeLineLayer && !freeLineExists) ||
                                  (isFreeAreaLayer && !freeAreaExists)) {
                                _enterPlacement(activeLayer);
                              } else if (isSubspaceLayer) {
                                _addSubspaceAt(c, activeLayer, subspaces);
                              } else if (isFreeLineLayer) {
                                _addFreeLineAt(c, activeLayer, freeLines);
                              } else if (isFreeAreaLayer) {
                                _addFreeAreaAt(c, activeLayer, freeAreas);
                              } else if (isHeightLayer) {
                                _addHeightRegionAt(c, activeLayer);
                              } else if (isPlaneLayer) {
                                _addPlaneAt(c, activeLayer);
                              } else {
                                _addCircleAt(c, activeLayer);
                              }
                            },
                      backgroundColor: activeLayer == null
                          ? Theme.of(context).disabledColor
                          : null,
                      icon: Icon(
                        isPoiLayer
                            ? Icons.travel_explore
                            : isSubspaceLayer
                                ? Icons.scatter_plot_outlined
                                : isFreeLineLayer
                                    ? Icons.polyline
                                    : isFreeAreaLayer
                                        ? Icons.hexagon_outlined
                                        : isHeightLayer
                                            ? Icons.terrain
                                            : isPlaneLayer
                                                ? Icons.change_history
                                                : Icons
                                                    .add_location_alt_outlined,
                      ),
                      label: Text(
                        isPoiLayer
                            ? 'Import POIs'
                            : isSubspaceLayer
                                ? (subspaceExists
                                    ? 'Add point'
                                    : 'Add subspace')
                                : isFreeLineLayer
                                    ? (freeLineExists
                                        ? 'Add point'
                                        : 'Add line')
                                    : isFreeAreaLayer
                                        ? (freeAreaExists
                                            ? 'Add point'
                                            : 'Add area')
                                        : isHeightLayer
                                            ? 'Add height area'
                                            : isPlaneLayer
                                                ? 'Add plane'
                                                : 'Add circle',
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
              key: ValueKey('sheet-'
                  '${selectedCircle?.id ?? selectedPlane?.id ?? selectedSubspace?.id ?? selectedFreeLine?.id ?? selectedFreeArea?.id ?? selectedHeightRegion?.id}'),
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
                layers.firstWhere((l) => l.id == selectedSubspace.layerId),
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
                layers.firstWhere((l) => l.id == selectedFreeLine.layerId),
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
                layers.firstWhere((l) => l.id == selectedFreeArea.layerId),
                freeAreas,
              ),
            )
          : selectedHeightRegion != null
          ? HeightEditorSheet(
              key: ValueKey(selectedHeightRegion.id),
              region: selectedHeightRegion,
              polygonCount: heightPolygons
                  .where((p) => p.heightRegionId == selectedHeightRegion.id)
                  .length,
              layers: layers,
            )
          : const SizedBox.shrink(),
            ),
    );
  }
}
