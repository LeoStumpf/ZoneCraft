import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/borders.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../state/providers.dart';
import 'import_actions.dart';
import 'layer_objects_sheet.dart';
import 'object_summary.dart';
import 'settings_screen.dart';
import 'transit_modes_sheet.dart';

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
    final transitSets =
        ref.watch(transitSetsProvider).asData?.value ?? const <TransitSet>[];
    final transitStations =
        ref.watch(transitStopsProvider).asData?.value ?? const <TransitStop>[];
    final borderSets =
        ref.watch(borderSetsProvider).asData?.value ?? const <BorderSet>[];
    final borderAreas =
        ref.watch(borderAreasProvider).asData?.value ?? const <BorderArea>[];
    final selected = ref.watch(activeLayerProvider);
    final repo = ref.read(repositoryProvider);

    Future<void> addLayer(int count, String type) async {
      // Borders is the one type with a creation-time sub-choice: a layer holds
      // exactly one admin level, which is what makes its colouring well
      // defined, so the level has to be settled before the layer exists.
      String? level;
      if (type == 'borders') {
        final picked = await showBorderLevelPicker(context);
        if (picked == null) return;
        level = picked.adminLevel;
      }
      final id = await repo.createLayer(
        name: 'Layer ${count + 1}',
        colorArgb: _palette[count % _palette.length].toARGB32(),
        type: type,
        borderLevel: level,
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
                      // (Importing a named map feature is not here any more: it
                      // always produces freehand geometry, so it lives on the
                      // freehand layers themselves, next to "Import track…".)
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
                          const PopupMenuItem(
                            value: 'transit',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.directions_transit),
                              title: Text('Transit layer'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'borders',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.public),
                              title: Text('Borders layer'),
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
                      } else if (layer.type == 'transit') {
                        // Stations are the unit the user sees and filters, so
                        // count those rather than imports (which would read 1).
                        final ids = transitSets
                            .where((t) => t.layerId == layer.id)
                            .map((t) => t.id)
                            .toSet();
                        count = transitStations
                            .where((s) => ids.contains(s.setId))
                            .length;
                      } else if (layer.type == 'borders') {
                        // Areas are the unit you see, so count those rather
                        // than imports (which would read 1).
                        final ids = borderSets
                            .where((s) => s.layerId == layer.id)
                            .map((s) => s.id)
                            .toSet();
                        count = borderAreas
                            .where((a) => ids.contains(a.setId))
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
                        canCombine:
                            display.any((l) => canCombineLayers(layer, l)),
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
      'transit' => 'station',
      'borders' => 'area',
      _ => 'circle',
    };
    final subtitle =
        StringBuffer('$objectCount $noun${objectCount == 1 ? '' : 's'}');
    // The level is what a borders layer *is* — two layers reading "12 areas"
    // are otherwise indistinguishable.
    if (layer.type == 'borders') {
      final level = borderLevelByAdminLevel(layer.borderLevel);
      if (level != null) subtitle.write(' · ${level.label.toLowerCase()}');
    }
    if (layer.isInverted) subtitle.write(' · inverted');
    // Show the opacity only when it isn't this type's default (region layers
    // default to a translucent fill, so the default value isn't 100%).
    final defaultOpacity = defaultLayerOpacity(layer.type);
    if ((layer.opacity - defaultOpacity).abs() > 0.005) {
      subtitle.write(' · ${(layer.opacity * 100).round()}% opacity');
    }

    return ListTile(
      selected: isActive,
      // Three trailing controls (elements, menu, drag) leave little room for the
      // name, so claw back the default paddings and keep every control compact.
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      horizontalTitleGap: 4,
      minLeadingWidth: 36,
      // Tap to make active; tap the active layer again to have no active layer.
      onTap: () => ref
          .read(activeLayerProvider.notifier)
          .toggle(layer.id, isActive: isActive),
      leading: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
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
          Icon(typeIcon(layer.type), size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(layer.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
      subtitle: Text(subtitle.toString()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Always present, for every layer type: the list of this layer's
          // objects. Deliberately not a popup-menu entry — reaching an element
          // must never depend on the layer's type or state.
          IconButton(
            tooltip: 'Elements',
            icon: const Icon(Icons.format_list_bulleted),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 36),
            onPressed: () => _openElements(context, ref),
          ),
          // NB: PopupMenuButton.constraints sizes the *menu*, not the button —
          // keep the button slim with iconSize/padding only.
          PopupMenuButton<String>(
            iconSize: 20,
            padding: EdgeInsets.zero,
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
                case 'stations':
                  await _openStations(context, ref);
                case 'fillAreas':
                  await repo.updateBorderLayerOptions(layer.id,
                      fillAreas: !layer.borderFillAreas);
                case 'showNames':
                  await repo.updateBorderLayerOptions(layer.id,
                      showNames: !layer.borderShowNames);
                case 'importFeature':
                  // The flow needs the full list only for its fallback picker
                  // (a line feature asked for from an area layer, or vice
                  // versa); normally it merges straight into this layer.
                  await importFeatureFlow(
                    context,
                    repo,
                    ref.read(layersProvider).asData?.value ?? const <Layer>[],
                    into: layer,
                  );
                case 'importTrack':
                  await importTrackIntoLayer(context, repo, layer);
                case 'export':
                  await exportSingleLayer(context, repo, layer);
                case 'combine':
                  final layers =
                      ref.read(layersProvider).asData?.value ?? const <Layer>[];
                  final targets =
                      layers.where((l) => canCombineLayers(layer, l)).toList();
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
              // invert; 'poi'/'transit' are markers with nothing to invert;
              // 'borders' draws many separate areas, so there is no single
              // region to take the complement of.
              if (layer.type != 'height' &&
                  layer.type != 'poi' &&
                  layer.type != 'transit' &&
                  layer.type != 'borders')
                PopupMenuItem(
                  value: 'inverse',
                  child: Text(layer.isInverted ? 'Un-invert' : 'Invert'),
                ),
              if (layer.type == 'transit')
                const PopupMenuItem(
                    value: 'stations', child: Text('Stations…')),
              if (layer.type == 'borders') ...[
                CheckedPopupMenuItem(
                  value: 'fillAreas',
                  checked: layer.borderFillAreas,
                  child: const Text('Colour areas'),
                ),
                CheckedPopupMenuItem(
                  value: 'showNames',
                  checked: layer.borderShowNames,
                  child: const Text('Show names'),
                ),
              ],
              if (layer.type == 'freeline' || layer.type == 'freearea') ...[
                const PopupMenuItem(
                  value: 'importFeature',
                  child: Text('Import map feature…'),
                ),
                const PopupMenuItem(
                  value: 'importTrack',
                  child: Text('Import track…'),
                ),
              ],
              const PopupMenuItem(value: 'export', child: Text('Export layer…')),
              if (canCombine)
                const PopupMenuItem(
                    value: 'combine', child: Text('Combine…')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.drag_handle, size: 20),
          ),
        ],
      ),
    );
  }

  /// Opens this layer's element list and applies whatever it asks for.
  ///
  /// The sheet handles rename/delete itself; only "edit" and "zoom to" need the
  /// map, and both end with the drawer closed so the result is visible. This is
  /// the single place that pops routes for the flow.
  Future<void> _openElements(BuildContext context, WidgetRef ref) async {
    final result = await showLayerObjects(context, layer);
    if (result == null || !context.mounted) return;
    final target = result.target;
    if (result.action == ElementAction.retry) {
      // The map screen owns the import machinery, so ask it to re-run this one.
      // Close the drawer *before* asking: the map answers by pushing a progress
      // dialog, and — because a retry already has its set row, so nothing is
      // awaited first — it pushes it synchronously. A pop issued afterwards
      // would take that dialog instead of the drawer, leaving the drawer up and
      // the spinner invisible while the import ran unseen.
      final retry = ref.read(pendingTransitRetryProvider.notifier);
      Navigator.pop(context);
      retry.request(target.ref.id);
      return;
    }
    if (result.action == ElementAction.edit) {
      // Selecting also makes the layer active, so the drag handles, the Add
      // button and the long-press context all follow the object being edited.
      ref.read(activeLayerProvider.notifier).select(layer.id);
      selectObject(ref, target.ref.kind, target.ref.id);
    }
    ref.read(pendingFocusProvider.notifier).request(target.fitPoints);
    Navigator.pop(context); // close the drawer so the map is visible
  }

  /// Opens the transit layer's station filter. Visibility is written inside the
  /// sheet, so nothing comes back and the drawer stays open — unlike
  /// [_openElements], which hands off to the map.
  Future<void> _openStations(BuildContext context, WidgetRef ref) =>
      showTransitModes(context, layer);

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
    if (result == null) return;
    final repo = ref.read(repositoryProvider);
    // Elements that follow the layer re-shade themselves the moment it changes
    // — that is the point of deriving the shade rather than storing it. The
    // ones that were given their own colour are the only open question, and
    // silently overwriting them would throw away deliberate work.
    final overridden = await repo.elementsWithColorOverride(
      layer.id,
      layer.type,
    );
    await repo.updateLayer(layer.id, colorArgb: result.toARGB32());
    if (overridden.isEmpty || !context.mounted) return;
    await _askAboutOverrides(context, ref, overridden);
  }

  /// After a layer recolour: what to do with the elements that carry their own
  /// colour and therefore did *not* follow it.
  Future<void> _askAboutOverrides(
    BuildContext context,
    WidgetRef ref,
    List<String> overridden,
  ) async {
    final kind = ColoredElement.forLayerType(layer.type);
    if (kind == null) return;
    final n = overridden.length;
    final answer = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elements with their own colour'),
        content: Text(
          n == 1
              ? '1 element has a colour of its own, so it kept it. '
                    'Everything else followed the layer.'
              : '$n elements have colours of their own, so they kept them. '
                    'Everything else followed the layer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Keep them'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'some'),
            child: const Text('Choose…'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: Text(n == 1 ? 'Reset it' : 'Reset all'),
          ),
        ],
      ),
    );
    if (answer == null || answer == 'keep') return;
    final repo = ref.read(repositoryProvider);
    if (answer == 'all') {
      await repo.clearElementColors(kind, overridden);
      return;
    }
    if (!context.mounted) return;
    final chosen = await _chooseOverrides(context, ref, overridden);
    if (chosen != null && chosen.isNotEmpty) {
      await repo.clearElementColors(kind, chosen);
    }
  }

  /// Ticks off which of the overridden elements should go back to following the
  /// layer. Named from the Elements-list summaries, because "3 elements" is not
  /// something anyone can act on.
  Future<List<String>?> _chooseOverrides(
    BuildContext context,
    WidgetRef ref,
    List<String> overridden,
  ) {
    final ids = overridden.toSet();
    final rows = [
      for (final s in ref.read(layerSummariesProvider(layer.id)))
        if (ids.contains(s.ref.id)) s,
    ];
    final picked = <String>{};
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Follow the layer again'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in rows)
                  CheckboxListTile(
                    dense: true,
                    value: picked.contains(s.ref.id),
                    secondary: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Color(s.colorArgb ?? layer.colorArgb),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    title: Text(s.title, overflow: TextOverflow.ellipsis),
                    onChanged: (on) => setState(() {
                      if (on ?? false) {
                        picked.add(s.ref.id);
                      } else {
                        picked.remove(s.ref.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, picked.toList()),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether [source] may be merged into [target]: same type, different layer —
/// and, for borders, the same admin level, since one layer holds one level.
/// Mirrors the guard in [Repository.combineLayers], so the menu never offers a
/// target the repository would refuse.
bool canCombineLayers(Layer source, Layer target) =>
    target.id != source.id &&
    target.type == source.type &&
    (source.type != 'borders' || target.borderLevel == source.borderLevel);

/// Picks the admin level for a new borders layer.
///
/// This is the only creation-time sub-choice any layer type has, and it is
/// deliberate: one layer holds one level, which is what makes "no two
/// neighbours share a colour" mean anything (levels nest, they don't tile).
Future<BorderLevel?> showBorderLevelPicker(BuildContext context) {
  return showDialog<BorderLevel>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Which borders?'),
      children: [
        for (final l in borderLevels)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, l),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text(l.label),
              subtitle: Text(l.blurb),
              isThreeLine: true,
            ),
          ),
      ],
    ),
  );
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
