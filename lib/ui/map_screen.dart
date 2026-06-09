import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../geo/geodesic.dart';
import '../state/providers.dart';
import 'circle_editor.dart';
import 'layers_panel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();

  /// Updated by [PolygonLayer] on every gesture; tells us which circle (if any)
  /// was under the tap so we can edit it instead of adding a new one.
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _mapController.dispose();
    _hitNotifier.dispose();
    super.dispose();
  }

  /// A default radius (metres) scaled so a new circle is visible at the current
  /// zoom: roughly 15% of the visible map width.
  double _defaultRadius() {
    final cam = _mapController.camera;
    final bounds = cam.visibleBounds;
    final widthMeters = const Distance().as(
      LengthUnit.Meter,
      LatLng(cam.center.latitude, bounds.west),
      LatLng(cam.center.latitude, bounds.east),
    );
    return (widthMeters * 0.15).clamp(10.0, 2000000.0);
  }

  Future<void> _handleTap(TapPosition _, LatLng latlng, List<Layer> layers) async {
    final hit = _hitNotifier.value;
    final circles = ref.read(circlesProvider).asData?.value ?? const <Circle>[];

    // Tapped an existing circle -> edit it.
    if (hit != null && hit.hitValues.isNotEmpty) {
      final id = hit.hitValues.first;
      final circle = circles.where((c) => c.id == id).firstOrNull;
      if (circle != null) {
        await showCircleEditor(context, circle: circle, layers: layers);
        return;
      }
    }

    // Otherwise add a circle to the active layer.
    final activeId = effectiveActiveLayerId(layers, ref.read(activeLayerProvider));
    if (activeId == null) return;
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
    final activeId = effectiveActiveLayerId(layers, ref.watch(activeLayerProvider));
    final activeLayer = layers.where((l) => l.id == activeId).firstOrNull;

    final polygons = _buildPolygons(layers, circles);

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
          onTap: (pos, latlng) => _handleTap(pos, latlng, layers),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.zonecraft.zonecraft',
            maxZoom: 19,
          ),
          PolygonLayer<String>(
            hitNotifier: _hitNotifier,
            polygons: polygons,
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

  /// Builds circle polygons across all visible layers in draw order
  /// (bottom-to-top), so higher layers overlay lower ones.
  List<Polygon<String>> _buildPolygons(List<Layer> layers, List<Circle> circles) {
    final polygons = <Polygon<String>>[];
    for (final layer in layers) {
      if (!layer.isVisible) continue;
      final color = Color(layer.colorArgb);
      for (final c in circles.where((c) => c.layerId == layer.id)) {
        polygons.add(
          Polygon<String>(
            points: geodesicCircle(
              LatLng(c.centerLat, c.centerLng),
              c.radiusMeters,
            ),
            color: color.withValues(alpha: 0.22),
            borderColor: color,
            borderStrokeWidth: 2,
            hitValue: c.id,
          ),
        );
      }
    }
    return polygons;
  }
}
