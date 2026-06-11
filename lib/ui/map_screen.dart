import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/borders.dart';
import '../data/database.dart';
import '../data/overpass.dart';
import '../state/providers.dart';
import 'circle_editor.dart';
import 'layers_panel.dart';
import 'plane_editor.dart';
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
  static const _hitTest = Distance(calculator: Haversine());

  /// The user's last known position, shown as a marker. Null until the user
  /// opts in via the "Locate me" button. We never request location at launch.
  LatLng? _myPosition;
  bool _locating = false;
  bool _mapReady = false;

  /// Current map rotation in degrees (clockwise). Drives the compass needle.
  double _rotation = 0;

  /// Last finite camera, used to snap back if a gesture produces a NaN camera.
  LatLng _lastGoodCenter = const LatLng(48.137, 11.575);
  double _lastGoodZoom = 5;

  // --- Map POIs (Overpass) --------------------------------------------------
  /// Only fetch POIs at this zoom or closer (matches OSMAnd's detail level;
  /// avoids clutter and heavy queries when zoomed out).
  static const double _poiFetchZoom = 15;

  /// Keep already-shown POIs until the zoom drops below this (hysteresis), so
  /// markers don't flicker when the zoom hovers around the fetch threshold.
  static const double _poiHideZoom = 13.5;
  List<PoiResult> _pois = const [];
  Set<PoiCategory> _enabledPois = const {};
  int _poiMask = 0;
  Timer? _poiDebounce;
  // The (inflated) area the current markers were fetched for, and the category
  // mask they were fetched with. While the viewport stays inside this area and
  // the categories are unchanged, no refetch happens — so markers don't churn.
  LatLngBounds? _poiFetchedBounds;
  int _poiFetchedMask = -1;

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
    _poiDebounce?.cancel();
    _bordersDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  /// Debounced POI refresh: coalesces rapid pan/zoom into one fetch when the
  /// map settles.
  void _schedulePoiRefresh() {
    _poiDebounce?.cancel();
    _poiDebounce = Timer(const Duration(milliseconds: 600), _refreshPois);
  }

  /// Fetches POIs for the current view if enabled and zoomed in enough; clears
  /// them otherwise. Skips the request while the viewport stays inside the
  /// already-fetched area (no churn), fetches an inflated area so small pans
  /// don't re-query, and on a failed/rate-limited request keeps the existing
  /// markers rather than clearing them.
  Future<void> _refreshPois() async {
    if (!_mapReady || !mounted) return;
    final cam = _mapController.camera;
    // Bail on a non-finite camera (a degenerate gesture can briefly produce a
    // NaN centre/zoom). Reading visibleBounds would throw; recovery happens in
    // onPositionChanged.
    if (!cam.center.latitude.isFinite ||
        !cam.center.longitude.isFinite ||
        !cam.zoom.isFinite) {
      return;
    }
    if (_enabledPois.isEmpty || cam.zoom < _poiHideZoom) {
      _poiFetchedBounds = null;
      if (_pois.isNotEmpty) setState(() => _pois = const []);
      return;
    }
    if (cam.zoom < _poiFetchZoom) {
      // Hysteresis band: keep whatever is shown, but don't fetch more yet.
      return;
    }
    final vp = cam.visibleBounds;
    // Still covered by the last fetch (same categories)? keep the markers.
    if (_poiFetchedMask == _poiMask &&
        _poiFetchedBounds != null &&
        _boundsContain(_poiFetchedBounds!, vp)) {
      return;
    }

    final q = _inflateBounds(vp, 0.4); // ~40% margin each side
    final results = await fetchPois(
      south: q.south,
      west: q.west,
      north: q.north,
      east: q.east,
      categories: _enabledPois,
    );
    if (!mounted) return;
    if (results == null) {
      // Failed/rate-limited: keep current markers and retry after a short
      // backoff (a later pan/zoom reschedules this and cancels the backoff).
      _poiFetchedBounds = null;
      _poiDebounce?.cancel();
      _poiDebounce = Timer(const Duration(seconds: 4), _refreshPois);
      return;
    }
    _poiFetchedBounds = q;
    _poiFetchedMask = _poiMask;
    setState(() => _pois = results);
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
      if (!await Geolocator.isLocationServiceEnabled()) {
        _hint('Location services are off. Enable them to use Locate me.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _hint('Location permission denied. ZoneCraft works fine without it.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      // Guard against a non-finite fix: a NaN LatLng would corrupt the map
      // camera and crash every subsequent projection.
      if (!pos.latitude.isFinite || !pos.longitude.isFinite) {
        _hint('Could not get a valid location fix. Try again outdoors.');
        return;
      }
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _myPosition = here);
      _mapController.move(here, 14);
    } catch (e) {
      _hint('Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _hint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// A small non-interactive dot marking an edit point (circle centre / plane
  /// endpoint / subspace point). The white ring keeps it visible over any map
  /// colour; the [main] point of a subspace is drawn larger and white-filled.
  Marker _editPointMarker(LatLng point, {bool main = false}) {
    final size = main ? 22.0 : 18.0;
    return Marker(
      point: point,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: main ? Colors.white : Colors.black87,
          shape: BoxShape.circle,
          border: Border.all(
            color: main ? Colors.black87 : Colors.white,
            width: main ? 4 : 2.5,
          ),
        ),
      ),
    );
  }

  /// A small icon marker for one POI, coloured by category.
  Marker _poiMarker(PoiResult p) {
    return Marker(
      point: LatLng(p.lat, p.lng),
      width: 26,
      height: 26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
        child: Icon(_poiIcon(p.categoryKey), size: 16, color: Colors.black87),
      ),
    );
  }

  static IconData _poiIcon(String categoryKey) => switch (categoryKey) {
        'bench' => Icons.chair_outlined,
        'post_box' => Icons.markunread_mailbox_outlined,
        'drinking_water' => Icons.water_drop_outlined,
        'toilets' => Icons.wc_outlined,
        'waste_basket' => Icons.delete_outline,
        'cafe' => Icons.local_cafe_outlined,
        'restaurant' => Icons.restaurant_outlined,
        'pharmacy' => Icons.local_pharmacy_outlined,
        _ => Icons.place_outlined,
      };

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

  void _clearSelection() {
    ref.read(selectedCircleProvider.notifier).select(null);
    ref.read(selectedPlaneProvider.notifier).select(null);
    ref.read(planePlacementProvider.notifier).arm(null);
    ref.read(selectedSubspaceProvider.notifier).select(null);
    ref.read(subspacePlacementProvider.notifier).arm(null);
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

  Future<void> _handleTap(
    LatLng latlng,
    List<Layer> layers,
    List<Circle> circles,
    List<Plane> planes,
    List<Subspace> subspaces,
    List<SubspacePoint> subspacePoints,
  ) async {
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

    // Topmost object across visible layers (regardless of type) wins.
    for (final layer in layers.reversed) {
      if (!layer.isVisible) continue;
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
      }
    }

    // No object hit: just deselect anything selected. Objects are created with
    // the Add button — tapping empty map never adds one.
    if (ref.read(selectedCircleProvider) != null ||
        ref.read(selectedPlaneProvider) != null ||
        ref.read(selectedSubspaceProvider) != null) {
      _clearSelection();
    }
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
    final settings = ref.watch(settingsProvider).asData?.value;
    final uncertainty = settings?.uncertaintyMeters ?? 0;
    final transportOverlay = settings?.transportOverlay ?? false;
    // React to POI-category changes: update the enabled set and refetch.
    final poiMask = settings?.poiCategories ?? 0;
    if (poiMask != _poiMask) {
      _poiMask = poiMask;
      _enabledPois = poiCategoriesFromMask(poiMask);
      // _poiFetchedMask now differs, so the next refresh refetches.
      _schedulePoiRefresh();
    }
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
    final hasSelection = selectedCircle != null ||
        selectedPlane != null ||
        selectedSubspace != null;
    final activeId = effectiveActiveLayerId(
      layers,
      ref.watch(activeLayerProvider),
    );
    final activeLayer = layers.where((l) => l.id == activeId).firstOrNull;
    final isPlaneLayer = activeLayer?.type == 'planes';
    final isSubspaceLayer = activeLayer?.type == 'subspace';
    // In a subspace layer the Add FAB seeds a new object, or — once one exists —
    // appends a point to it.
    final subspaceExists = isSubspaceLayer &&
        subspaces.any((s) => s.layerId == activeLayer!.id);

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
                      _schedulePoiRefresh();
                      _scheduleBordersRefresh();
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
                      // Refresh overlays once the map settles.
                      _schedulePoiRefresh();
                      _scheduleBordersRefresh();
                    },
                    onTap: (_, latlng) => _handleTap(
                      latlng,
                      layers,
                      circles,
                      planes,
                      subspaces,
                      subspacePoints,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zonecraft.zonecraft',
                      maxZoom: 19,
                    ),
                    // Optional transparent public-transport overlays, above the
                    // base map but below the zone layers. ÖPNVKarte carries
                    // buses/trams/stops; OpenRailwayMap the rail network.
                    if (transportOverlay) ...[
                      TileLayer(
                        urlTemplate:
                            'https://tile.memomaps.de/tilegen/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.zonecraft.zonecraft',
                        maxZoom: 18,
                      ),
                      TileLayer(
                        urlTemplate:
                            'https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.zonecraft.zonecraft',
                        maxZoom: 19,
                      ),
                    ],
                    // One composited region per visible layer, bottom-to-top.
                    for (final layer in layers)
                      if (layer.isVisible)
                        RegionLayer(
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
                          uncertaintyMeters: uncertainty,
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
                    // Map POIs (Overpass), above the zones. Only present when
                    // enabled and zoomed in past the threshold.
                    if (_pois.isNotEmpty)
                      MarkerLayer(
                        markers: [for (final p in _pois) _poiMarker(p)],
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
                    // Visual handles for the object being edited: the circle's
                    // centre, the plane's two points, or the subspace's points
                    // (its main point shown distinct).
                    if (hasSelection)
                      MarkerLayer(
                        markers: [
                          if (selectedCircle != null)
                            _editPointMarker(
                              LatLng(
                                selectedCircle.centerLat,
                                selectedCircle.centerLng,
                              ),
                            ),
                          if (selectedPlane != null) ...[
                            _editPointMarker(
                              LatLng(selectedPlane.aLat, selectedPlane.aLng),
                            ),
                            _editPointMarker(
                              LatLng(selectedPlane.bLat, selectedPlane.bLng),
                            ),
                          ],
                          for (final p in selectedSubspacePoints)
                            _editPointMarker(
                              LatLng(p.lat, p.lng),
                              main: p.isMain,
                            ),
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
                FloatingActionButton.extended(
                  heroTag: 'add',
                  onPressed: activeLayer == null
                      ? null
                      : () {
                          final c = _mapController.camera.center;
                          if (isSubspaceLayer) {
                            _addSubspaceAt(c, activeLayer, subspaces);
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
                    isSubspaceLayer
                        ? Icons.scatter_plot_outlined
                        : isPlaneLayer
                            ? Icons.change_history
                            : Icons.add_location_alt_outlined,
                  ),
                  label: Text(
                    isSubspaceLayer
                        ? (subspaceExists ? 'Add point' : 'Add subspace')
                        : isPlaneLayer
                            ? 'Add plane'
                            : 'Add circle',
                  ),
                ),
              ],
            ),
      bottomSheet: selectedCircle != null
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
            )
          : null,
    );
  }
}
