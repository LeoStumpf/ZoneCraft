// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/borders.dart';
import '../data/database.dart';
import '../data/layer_types.dart';
import '../state/providers.dart';
import 'import_actions.dart';
import 'layer_actions.dart';
import 'layer_objects_sheet.dart';
import 'object_summary.dart';
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
    final circles =
        ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
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
    final borderSets =
        ref.watch(borderSetsProvider).asData?.value ?? const <BorderSet>[];
    final borderAreas =
        ref.watch(borderAreasProvider).asData?.value ?? const <BorderArea>[];
    final selected = ref.watch(activeLayerProvider);
    final repo = ref.read(repositoryProvider);

    // The drawer gets its own messenger: a Scaffold draws its drawer *above*
    // its snackbars, so "Deleted … UNDO" raised from here would otherwise be
    // hidden behind the very drawer it was raised from.
    return Drawer(
      child: ScaffoldMessenger(
        child: Scaffold(
          body: SafeArea(
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
                          Text(
                            'Layers',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Import layer from file',
                            icon: const Icon(Icons.file_open_outlined),
                            onPressed: () => importLayerFlow(
                              context,
                              repo,
                              layers,
                              ref: ref,
                            ),
                          ),
                          // Export lives here too, not only in Settings: it is an
                          // action on the map, and this is where the map's layers
                          // are.
                          IconButton(
                            tooltip: 'Export all layers',
                            icon: const Icon(Icons.ios_share),
                            onPressed: () => exportAllFlow(context, repo),
                          ),
                          // (Importing a named map feature is not here any more: it
                          // always produces freehand geometry, so it lives on the
                          // freehand layers themselves, next to "Import track…".)
                          PopupMenuButton<String>(
                            tooltip: 'Add layer',
                            onSelected: (type) =>
                                addLayerFlow(context, ref, layers, type),
                            itemBuilder: (_) => [
                              for (final c in kLayerTypeChoices) ...[
                                // The combined layer sits apart: it is not an
                                // eighth kind of content but a way to hold the
                                // other seven.
                                if (c.type == kMixedType)
                                  const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: c.type,
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(c.icon),
                                    title: Text(c.label),
                                    subtitle: c.subtitle == null
                                        ? null
                                        : Text(c.subtitle!),
                                  ),
                                ),
                              ],
                            ],
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add),
                                  SizedBox(width: 4),
                                  Text('Add'),
                                ],
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
                          unawaited(
                            repo.reorderLayers(
                              reordered.reversed.map((l) => l.id).toList(),
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final layer = display[index];
                          final int count;
                          if (layer.type == kMixedType) {
                            // A combined layer's natural unit is the *element* —
                            // the rows the Elements list shows — because its
                            // contents have no shared unit to count in. (Every
                            // other branch below counts each type's own: points
                            // for a subspace, POIs for an import.)
                            count = ref
                                .read(layerSummariesProvider(layer.id))
                                .length;
                          } else if (layer.type == 'subspace') {
                            // A subspace layer shows its point count.
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
                            count = circles
                                .where((c) => c.layerId == layer.id)
                                .length;
                          }
                          return _LayerTile(
                            key: ValueKey(layer.id),
                            index: index,
                            layer: layer,
                            layers: layers,
                            objectCount: count,
                            isActive: layer.id == activeId,
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
                        unawaited(
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerTile extends ConsumerWidget {
  const _LayerTile({
    super.key,
    required this.index,
    required this.layer,
    required this.layers,
    required this.objectCount,
    required this.isActive,
  });

  /// Position in the drawer's list (top of stack first) — what the drag
  /// handle needs.
  final int index;
  final Layer layer;

  /// The whole stack, **bottom-to-top** — the order [Repository.watchLayers]
  /// hands out. Every stacking decision is computed against this, never
  /// against the drawer's reversed display list.
  final List<Layer> layers;
  final int objectCount;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final noun = switch (layer.type) {
      'subspace' => 'point',
      'freeline' => 'point',
      'freearea' => 'point',
      'height' => 'area',
      'poi' => 'POI',
      'borders' => 'area',
      // A combined layer holds several kinds, so the only honest collective
      // noun is the generic one.
      kMixedType => 'element',
      _ => 'circle',
    };
    final subtitle = StringBuffer(
      '$objectCount $noun${objectCount == 1 ? '' : 's'}',
    );
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
    // Watched so the menu re-evaluates "Stations…" when a station import
    // lands; the predicate itself lives in [layerActionsFor].
    ref.watch(poiSetsProvider);

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
        icon: Icon(
          layer.isVisible ? Icons.visibility : Icons.visibility_off_outlined,
        ),
        onPressed: () =>
            repo.updateLayer(layer.id, isVisible: !layer.isVisible),
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () => pickLayerColor(context, ref, layer),
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
          //
          // The items come from [layerActionsFor], the one definition the
          // map's layer sheet renders too. Explicit stacking items are there
          // because dragging a tile is fiddly on a phone and impossible to
          // aim at "all the way to the top" with twenty layers.
          Builder(
            builder: (context) {
              final actions = layerActionsFor(context, ref, layer, layers);
              return PopupMenuButton<LayerAction>(
                iconSize: 20,
                padding: EdgeInsets.zero,
                onSelected: (action) {
                  // A map-owned action needs the drawer out of the way: the
                  // map answers with a form, a preview or a banner, all of
                  // which this drawer would cover.
                  if (action.needsMap) Navigator.pop(context);
                  unawaited(action.run());
                },
                itemBuilder: (_) => [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0 &&
                        layerActionGroup(actions[i].id) !=
                            layerActionGroup(actions[i - 1].id))
                      const PopupMenuDivider(),
                    if (actions[i].checked != null)
                      CheckedPopupMenuItem(
                        value: actions[i],
                        checked: actions[i].checked!,
                        child: Text(actions[i].label),
                      )
                    else
                      PopupMenuItem(
                        value: actions[i],
                        child: Text(actions[i].label),
                      ),
                  ],
                ],
              );
            },
          ),
          // A real handle, not a hint of one: dragging anywhere on the tile
          // also reorders (after a long press), but a handle that looks like a
          // handle should grab at once.
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.drag_handle, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens this layer's element list and applies whatever it asks for.
  ///
  /// The sheet handles rename/delete itself; what needs the map goes through
  /// [applyElementResult], which ends with the drawer closed so the result is
  /// visible. This is the single place that pops routes for the flow.
  Future<void> _openElements(BuildContext context, WidgetRef ref) async {
    final result = await showLayerObjects(context, layer);
    if (result == null || !context.mounted) return;
    applyElementResult(
      ref,
      layer,
      result,
      closeHost: () => Navigator.pop(context),
    );
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
        icon: Icon(visible ? Icons.visibility : Icons.visibility_off_outlined),
        onPressed: settings == null
            ? null
            : () => repo.updateBasemapVisible(visible: !visible),
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
