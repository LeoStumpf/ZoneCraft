import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../state/providers.dart';
import 'import_actions.dart';
import 'settings_screen.dart';

/// Left-hand drawer for managing layers: list, choose active, visibility,
/// reorder, colour, rename, inverse, delete, and add. Replaces the old bottom
/// sheet so the map stays usable alongside it.
class LayersDrawer extends ConsumerWidget {
  const LayersDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layersAsync = ref.watch(layersProvider);
    final poiSets =
        ref.watch(poiSetsProvider).asData?.value ?? const <PoiSet>[];
    final poiPoints =
        ref.watch(poiPointsProvider).asData?.value ?? const <PoiPoint>[];
    final circles = ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
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
    final selected = ref.watch(activeLayerProvider);
    final repo = ref.read(repositoryProvider);

    Future<void> addLayer(int count, String type) async {
      final id = await repo.createLayer(
        name: 'Layer ${count + 1}',
        colorArgb: _palette[count % _palette.length].toARGB32(),
        type: type,
      );
      ref.read(activeLayerProvider.notifier).select(id);
    }

    return Drawer(
      child: SafeArea(
        child: layersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (layers) {
            // Display top-of-stack first (reverse of draw order).
            final display = layers.reversed.toList();
            final activeId = effectiveActiveLayerId(layers, selected);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Text('Layers',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Import layer from file',
                        icon: const Icon(Icons.file_open_outlined),
                        onPressed: () =>
                            importLayerFlow(context, repo, layers),
                      ),
                      IconButton(
                        tooltip: 'Import map feature (city border, river…)',
                        icon: const Icon(Icons.public),
                        onPressed: () =>
                            importFeatureFlow(context, repo, layers),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Add layer',
                        onSelected: (type) => addLayer(layers.length, type),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'circles',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.circle_outlined),
                              title: Text('Circles layer'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'planes',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.change_history),
                              title: Text('Planes layer'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'subspace',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.scatter_plot_outlined),
                              title: Text('Subspace layer'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'freeline',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.polyline),
                              title: Text('Freehand line layer'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'freearea',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.hexagon_outlined),
                              title: Text('Freehand area layer'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'height',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.terrain),
                              title: Text('Height layer'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'poi',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.travel_explore),
                              title: Text('POI layer'),
                            ),
                          ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.add), SizedBox(width: 4), Text('Add')],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: display.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final reordered = [...display];
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);
                      // Persist as bottom-to-top draw order.
                      repo.reorderLayers(
                        reordered.reversed.map((l) => l.id).toList(),
                      );
                    },
                    itemBuilder: (context, index) {
                      final layer = display[index];
                      final int count;
                      if (layer.type == 'planes') {
                        count =
                            planes.where((p) => p.layerId == layer.id).length;
                      } else if (layer.type == 'subspace') {
                        // A subspace layer holds one object; show its point count.
                        final ids = subspaces
                            .where((s) => s.layerId == layer.id)
                            .map((s) => s.id)
                            .toSet();
                        count = subspacePoints
                            .where((p) => ids.contains(p.subspaceId))
                            .length;
                      } else if (layer.type == 'freeline') {
                        final ids = freeLines
                            .where((l) => l.layerId == layer.id)
                            .map((l) => l.id)
                            .toSet();
                        count = freeLinePoints
                            .where((p) => ids.contains(p.freeLineId))
                            .length;
                      } else if (layer.type == 'freearea') {
                        final ids = freeAreas
                            .where((a) => a.layerId == layer.id)
                            .map((a) => a.id)
                            .toSet();
                        count = freeAreaPoints
                            .where((p) => ids.contains(p.freeAreaId))
                            .length;
                      } else if (layer.type == 'height') {
                        count = heightRegions
                            .where((r) => r.layerId == layer.id)
                            .length;
                      } else if (layer.type == 'poi') {
                        final ids = poiSets
                            .where((s) => s.layerId == layer.id)
                            .map((s) => s.id)
                            .toSet();
                        count = poiPoints
                            .where((p) => ids.contains(p.poiSetId))
                            .length;
                      } else {
                        count =
                            circles.where((c) => c.layerId == layer.id).length;
                      }
                      return _LayerTile(
                        key: ValueKey(layer.id),
                        layer: layer,
                        objectCount: count,
                        isActive: layer.id == activeId,
                        canCombine: display.any(
                            (l) => l.type == layer.type && l.id != layer.id),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // The base map, pinned as the bottom-most layer: hideable and
                // opacity-adjustable like any layer, but never reorderable or
                // deletable.
                const _BasemapTile(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context); // close the drawer
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

IconData _typeIcon(String type) => switch (type) {
      'planes' => Icons.change_history,
      'subspace' => Icons.scatter_plot_outlined,
      'freeline' => Icons.polyline,
      'freearea' => Icons.hexagon_outlined,
      'height' => Icons.terrain,
      'poi' => Icons.travel_explore,
      _ => Icons.circle_outlined,
    };

class _LayerTile extends ConsumerWidget {
  const _LayerTile({
    super.key,
    required this.layer,
    required this.objectCount,
    required this.isActive,
    required this.canCombine,
  });

  final Layer layer;
  final int objectCount;
  final bool isActive;

  /// Whether another same-type layer exists to merge this one into.
  final bool canCombine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final noun = switch (layer.type) {
      'planes' => 'plane',
      'subspace' => 'point',
      'freeline' => 'point',
      'freearea' => 'point',
      'height' => 'area',
      'poi' => 'POI',
      _ => 'circle',
    };
    final subtitle =
        StringBuffer('$objectCount $noun${objectCount == 1 ? '' : 's'}');
    if (layer.isInverted) subtitle.write(' · inverted');
    // Show the opacity only when it isn't this type's default (region layers
    // default to a translucent fill, so the default value isn't 100%).
    final defaultOpacity =
        layer.type == 'poi' ? 1.0 : kDefaultRegionLayerOpacity;
    if ((layer.opacity - defaultOpacity).abs() > 0.005) {
      subtitle.write(' · ${(layer.opacity * 100).round()}% opacity');
    }

    return ListTile(
      selected: isActive,
      // Tap to make active; tap the active layer again to have no active layer.
      onTap: () => ref
          .read(activeLayerProvider.notifier)
          .toggle(layer.id, isActive: isActive),
      leading: IconButton(
        tooltip: layer.isVisible ? 'Hide' : 'Show',
        icon: Icon(layer.isVisible
            ? Icons.visibility
            : Icons.visibility_off_outlined),
        onPressed: () =>
            repo.updateLayer(layer.id, isVisible: !layer.isVisible),
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () => _pickColor(context, ref),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Color(layer.colorArgb),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(_typeIcon(layer.type), size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(layer.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
      subtitle: Text(subtitle.toString()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  await _rename(context, repo);
                case 'color':
                  await _pickColor(context, ref);
                case 'opacity':
                  await showOpacityDialog(
                    context,
                    title: 'Layer transparency',
                    value: layer.opacity,
                    onChanged: (v) => repo.updateLayer(layer.id, opacity: v),
                  );
                case 'inverse':
                  await repo.updateLayer(layer.id,
                      isInverted: !layer.isInverted);
                case 'importTrack':
                  await importTrackIntoLayer(context, repo, layer);
                case 'export':
                  await exportSingleLayer(context, repo, layer);
                case 'combine':
                  final layers =
                      ref.read(layersProvider).asData?.value ?? const <Layer>[];
                  final targets = layers
                      .where((l) => l.type == layer.type && l.id != layer.id)
                      .toList();
                  final mergedInto =
                      await combineLayerFlow(context, repo, layer, targets);
                  // If the combined-away layer was active, follow to the target.
                  if (mergedInto != null &&
                      ref.read(activeLayerProvider) == layer.id) {
                    ref.read(activeLayerProvider.notifier).select(mergedInto);
                  }
                case 'delete':
                  await repo.deleteLayer(layer.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'color', child: Text('Colour')),
              const PopupMenuItem(
                  value: 'opacity', child: Text('Transparency…')),
              // 'height' layers use an above/below toggle, not viewport
              // invert; 'poi' layers are markers with nothing to invert.
              if (layer.type != 'height' && layer.type != 'poi')
                PopupMenuItem(
                  value: 'inverse',
                  child: Text(layer.isInverted ? 'Un-invert' : 'Invert'),
                ),
              if (layer.type == 'freeline' || layer.type == 'freearea')
                const PopupMenuItem(
                  value: 'importTrack',
                  child: Text('Import track…'),
                ),
              const PopupMenuItem(value: 'export', child: Text('Export layer…')),
              if (canCombine)
                const PopupMenuItem(
                    value: 'combine', child: Text('Combine…')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          const Icon(Icons.drag_handle),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, Repository repo) async {
    final controller = TextEditingController(text: layer.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename layer'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await repo.updateLayer(layer.id, name: name);
    }
  }

  Future<void> _pickColor(BuildContext context, WidgetRef ref) async {
    Color picked = Color(layer.colorArgb);
    final result = await showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Layer colour'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, picked),
            child: const Text('Select'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(repositoryProvider)
          .updateLayer(layer.id, colorArgb: result.toARGB32());
    }
  }
}

/// The base map as a pinned bottom "layer": a hide toggle and a transparency
/// control, mirroring a layer tile — but with no rename/colour/reorder/delete,
/// since the map can be hidden but never removed. Its state lives in
/// `AppSettings` (`basemapVisible` / `basemapOpacity`).
class _BasemapTile extends ConsumerWidget {
  const _BasemapTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final settings = ref.watch(settingsProvider).asData?.value;
    final visible = settings?.basemapVisible ?? true;
    final opacity = settings?.basemapOpacity ?? 1.0;
    final subtitle = StringBuffer('Base map');
    if (opacity < 0.999) {
      subtitle.write(' · ${(opacity * 100).round()}% opacity');
    }
    return ListTile(
      leading: IconButton(
        tooltip: visible ? 'Hide' : 'Show',
        icon: Icon(
            visible ? Icons.visibility : Icons.visibility_off_outlined),
        onPressed:
            settings == null ? null : () => repo.updateBasemapVisible(!visible),
      ),
      title: Row(
        children: const [
          Icon(Icons.map_outlined, size: 16),
          SizedBox(width: 6),
          Expanded(child: Text('Map')),
        ],
      ),
      subtitle: Text(subtitle.toString()),
      trailing: IconButton(
        tooltip: 'Transparency',
        icon: const Icon(Icons.opacity),
        onPressed: settings == null
            ? null
            : () => showOpacityDialog(
                  context,
                  title: 'Map transparency',
                  value: opacity,
                  onChanged: (v) => repo.updateBasemapOpacity(v),
                ),
      ),
    );
  }
}

/// A modal 0–100% opacity slider shared by layer tiles and the base-map tile.
/// [onChanged] fires **live** as the slider moves so the map updates
/// immediately; there is no Save button — the change is already applied.
Future<void> showOpacityDialog(
  BuildContext context, {
  required String title,
  required double value,
  required ValueChanged<double> onChanged,
}) {
  var current = value.clamp(0.0, 1.0);
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${(current * 100).round()}% opaque'),
            Slider(
              min: 0,
              max: 1,
              divisions: 20,
              value: current,
              label: '${(current * 100).round()}%',
              onChanged: (v) {
                setState(() => current = v);
                onChanged(v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

const _palette = <Color>[
  Color(0xFF2196F3),
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];
