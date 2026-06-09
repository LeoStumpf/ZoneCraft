import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../state/providers.dart';
import 'circle_editor.dart';
import 'layers_panel.dart';
import 'region_layer.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  static const _hitTest = Distance(calculator: Haversine());

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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

  /// The smallest circle (in the top-most visible layer) that contains [latlng],
  /// or null. Hit testing is geographic (Haversine), independent of rendering.
  Circle? _circleAt(LatLng latlng, List<Layer> layers, List<Circle> circles) {
    for (final layer in layers.reversed) {
      if (!layer.isVisible) continue;
      Circle? best;
      for (final c in circles.where((c) => c.layerId == layer.id)) {
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
      if (best != null) return best;
    }
    return null;
  }

  Future<void> _handleTap(
    LatLng latlng,
    List<Layer> layers,
    List<Circle> circles,
  ) async {
    // Tapped an existing circle -> edit it.
    final hit = _circleAt(latlng, layers, circles);
    if (hit != null) {
      await showCircleEditor(context, circle: hit, layers: layers);
      return;
    }

    // Otherwise add a circle to the active layer (only circle-type layers).
    final activeId = effectiveActiveLayerId(layers, ref.read(activeLayerProvider));
    if (activeId == null) return;
    final activeLayer = layers.where((l) => l.id == activeId).firstOrNull;
    if (activeLayer == null || activeLayer.type != 'circles') return;
    await ref.read(repositoryProvider).createCircle(
          layerId: activeId,
          centerLat: latlng.latitude,
          centerLng: latlng.longitude,
          radiusMeters: _defaultRadius(),
        );
  }

  @override
  Widget build(BuildContext context) {
    // Triggers one-time seeding of a default layer.
    ref.watch(seedProvider);

    final layers = ref.watch(layersProvider).asData?.value ?? const <Layer>[];
    final circles = ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
    final uncertainty =
        ref.watch(settingsProvider).asData?.value.uncertaintyMeters ?? 0;
    final activeId = effectiveActiveLayerId(layers, ref.watch(activeLayerProvider));
    final activeLayer = layers.where((l) => l.id == activeId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonecraft'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              activeLayer == null
                  ? 'Tap the map to add a circle'
                  : 'Adding to: ${activeLayer.name}  ·  tap a circle to edit',
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
          onTap: (_, latlng) => _handleTap(latlng, layers, circles),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.zonecraft.zonecraft',
            maxZoom: 19,
          ),
          // One composited region per visible layer, bottom-to-top.
          for (final layer in layers)
            if (layer.isVisible && layer.type == 'circles')
              RegionLayer(
                key: ValueKey(layer.id),
                layer: layer,
                circles:
                    circles.where((c) => c.layerId == layer.id).toList(),
                uncertaintyMeters: uncertainty,
              ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLayersPanel(context),
        icon: const Icon(Icons.layers),
        label: Text('Layers (${layers.length})'),
      ),
    );
  }
}
