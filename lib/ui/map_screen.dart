import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../state/providers.dart';
import 'circle_editor.dart';
import 'layers_panel.dart';
import 'plane_editor.dart';
import 'region_layer.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  static const _hitTest = Distance(calculator: Haversine());

  /// The user's last known position, shown as a marker. Null until the user
  /// opts in via the "Locate me" button. We never request location at launch.
  LatLng? _myPosition;
  bool _locating = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
  /// endpoint). The white ring keeps it visible over any map colour.
  Marker _editPointMarker(LatLng point) {
    return Marker(
      point: point,
      width: 18,
      height: 18,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      ),
    );
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

  Layer? _activeLayer(List<Layer> layers) {
    final activeId =
        effectiveActiveLayerId(layers, ref.read(activeLayerProvider));
    return layers.where((l) => l.id == activeId).firstOrNull;
  }

  void _clearSelection() {
    ref.read(selectedCircleProvider.notifier).select(null);
    ref.read(selectedPlaneProvider.notifier).select(null);
    ref.read(planePlacementProvider.notifier).arm(null);
  }

  void _selectCircle(String id) {
    _clearSelection();
    ref.read(selectedCircleProvider.notifier).select(id);
  }

  void _selectPlane(String id) {
    _clearSelection();
    ref.read(selectedPlaneProvider.notifier).select(id);
  }

  Future<void> _addCircleAt(LatLng latlng, Layer layer) async {
    final id = await ref.read(repositoryProvider).createCircle(
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
    final id = await ref.read(repositoryProvider).createPlane(
          layerId: layer.id,
          aLat: a.latitude,
          aLng: a.longitude,
          bLat: b.latitude,
          bLng: b.longitude,
        );
    _selectPlane(id);
  }

  Future<void> _handleTap(
    LatLng latlng,
    List<Layer> layers,
    List<Circle> circles,
    List<Plane> planes,
  ) async {
    // Placement mode: relocate the armed endpoint of the selected plane.
    final armed = ref.read(planePlacementProvider);
    final selPlaneId = ref.read(selectedPlaneProvider);
    if (armed != null && selPlaneId != null) {
      final repo = ref.read(repositoryProvider);
      if (armed == 'A') {
        await repo.updatePlane(selPlaneId,
            aLat: latlng.latitude, aLng: latlng.longitude);
      } else {
        await repo.updatePlane(selPlaneId,
            bLat: latlng.latitude, bLng: latlng.longitude);
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
      }
    }

    // No hit: deselect if something is selected, else add to the active layer.
    if (ref.read(selectedCircleProvider) != null ||
        ref.read(selectedPlaneProvider) != null) {
      _clearSelection();
      return;
    }
    final active = _activeLayer(layers);
    if (active != null && active.type == 'circles') {
      await _addCircleAt(latlng, active);
    }
    // Planes need two points, so they're added via the FAB, not a single tap.
  }

  @override
  Widget build(BuildContext context) {
    // Triggers one-time seeding of a default layer.
    ref.watch(seedProvider);

    final layers = ref.watch(layersProvider).asData?.value ?? const <Layer>[];
    final circles = ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
    final planes = ref.watch(planesProvider).asData?.value ?? const <Plane>[];
    final uncertainty =
        ref.watch(settingsProvider).asData?.value.uncertaintyMeters ?? 0;
    final selectedCircle = circles
        .where((c) => c.id == ref.watch(selectedCircleProvider))
        .firstOrNull;
    final selectedPlane =
        planes.where((p) => p.id == ref.watch(selectedPlaneProvider)).firstOrNull;
    final activeId = effectiveActiveLayerId(layers, ref.watch(activeLayerProvider));
    final activeLayer = layers.where((l) => l.id == activeId).firstOrNull;
    final isPlaneLayer = activeLayer?.type == 'planes';

    return Scaffold(
      drawer: const LayersDrawer(),
      appBar: AppBar(
        title: const Text('ZoneCraft'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              activeLayer == null
                  ? 'Add a layer to start'
                  : isPlaneLayer
                      ? 'Active: ${activeLayer.name}  ·  use ＋ to add a plane'
                      : 'Active: ${activeLayer.name}  ·  tap to add, tap a circle to edit',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(48.137, 11.575), // Munich
          initialZoom: 5,
          onTap: (_, latlng) => _handleTap(latlng, layers, circles, planes),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.zonecraft.zonecraft',
            maxZoom: 19,
          ),
          // One composited region per visible layer, bottom-to-top.
          for (final layer in layers)
            if (layer.isVisible)
              RegionLayer(
                key: ValueKey(layer.id),
                layer: layer,
                circles: layer.type == 'circles'
                    ? circles.where((c) => c.layerId == layer.id).toList()
                    : const <Circle>[],
                planes: layer.type == 'planes'
                    ? planes.where((p) => p.layerId == layer.id).toList()
                    : const <Plane>[],
                uncertaintyMeters: uncertainty,
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
          // Visual handles for the object being edited: the circle's centre, or
          // the plane's two points.
          if (selectedCircle != null || selectedPlane != null)
            MarkerLayer(
              markers: [
                if (selectedCircle != null)
                  _editPointMarker(
                      LatLng(selectedCircle.centerLat, selectedCircle.centerLng)),
                if (selectedPlane != null) ...[
                  _editPointMarker(
                      LatLng(selectedPlane.aLat, selectedPlane.aLng)),
                  _editPointMarker(
                      LatLng(selectedPlane.bLat, selectedPlane.bLng)),
                ],
              ],
            ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
      // While an editor sheet is open it provides its own delete/close, and the
      // FABs would overlap it — so show them only when nothing is selected.
      floatingActionButton: (selectedCircle != null || selectedPlane != null)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                          if (isPlaneLayer) {
                            _addPlaneAt(c, activeLayer);
                          } else {
                            _addCircleAt(c, activeLayer);
                          }
                        },
                  backgroundColor: activeLayer == null
                      ? Theme.of(context).disabledColor
                      : null,
                  icon: Icon(isPlaneLayer
                      ? Icons.change_history
                      : Icons.add_location_alt_outlined),
                  label: Text(isPlaneLayer ? 'Add plane' : 'Add circle'),
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
              : null,
    );
  }
}
