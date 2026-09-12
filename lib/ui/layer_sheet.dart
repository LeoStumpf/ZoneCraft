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

/// The layer sheet: the map's own route to the active layer.
///
/// Opened from the chrome row's active-layer chip. A switcher row of every
/// layer, then — for the active one — each of its settings as a direct
/// control: two taps from the map to anything the drawer's ⋮ menu offers,
/// without the drawer. The actions come from [layerActionsFor], the one
/// definition the drawer renders too; this sheet only decides *how* each is
/// shown (a switch, a tile, an overflow item) and when to get out of the way
/// first.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'layer_actions.dart';
import 'layer_objects_sheet.dart';
import 'object_summary.dart';

/// Shows the layer sheet over the map.
///
/// [mapContext] / [mapRef] are the **map's**, deliberately: several actions
/// pop this sheet before they run (an import's form lands in the map's sheet
/// slot; a deleted layer's UNDO snackbar belongs on the map, not behind a
/// modal), and a popped sheet's own context and ref are unusable afterwards.
Future<void> showLayerSheet(BuildContext mapContext, WidgetRef mapRef) {
  return showModalBottomSheet<void>(
    context: mapContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _LayerSheet(mapContext: mapContext, mapRef: mapRef),
  );
}

class _LayerSheet extends ConsumerWidget {
  const _LayerSheet({required this.mapContext, required this.mapRef});

  final BuildContext mapContext;
  final WidgetRef mapRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(layersProvider).asData?.value ?? const <Layer>[];
    final activeId = effectiveActiveLayerId(
      layers,
      ref.watch(activeLayerProvider),
    );
    final active = layers.where((l) => l.id == activeId).firstOrNull;
    // Watched so the sheet re-renders when a station import lands (the
    // "Stations…" tile) or a layer is recoloured / renamed under it.
    ref.watch(poiSetsProvider);
    final repo = ref.read(repositoryProvider);

    return EditorSheet(
      children: [
        _Switcher(
          layers: layers,
          activeId: activeId,
          onAdd: () => _addLayer(context, layers),
        ),
        const SizedBox(height: 8),
        if (active == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No active layer — pick one above.'),
          )
        else
          _ActiveLayerBody(
            key: ValueKey(active.id),
            layer: active,
            layers: layers,
            repo: repo,
            mapContext: mapContext,
            mapRef: mapRef,
          ),
      ],
    );
  }

  Future<void> _addLayer(BuildContext context, List<Layer> layers) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in kLayerTypeChoices)
              ListTile(
                leading: Icon(c.icon),
                title: Text(c.label),
                subtitle: c.subtitle == null ? null : Text(c.subtitle!),
                onTap: () => Navigator.pop(ctx, c.type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !context.mounted) return;
    await addLayerFlow(context, mapRef, layers, type);
  }
}

/// Every layer as a chip, top of the stack first — the drawer's order — plus
/// a trailing "+" to add one. Tapping the active chip again means "no active
/// layer", as tapping the active tile does in the drawer.
class _Switcher extends ConsumerWidget {
  const _Switcher({
    required this.layers,
    required this.activeId,
    required this.onAdd,
  });

  final List<Layer> layers;
  final String? activeId;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: scaledPx(context, 48),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final l in layers.reversed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(l.colorArgb),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                label: Text(
                  l.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: l.id == activeId,
                onSelected: (_) => ref
                    .read(activeLayerProvider.notifier)
                    .toggle(l.id, isActive: l.id == activeId),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Layer'),
            tooltip: 'Add layer',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ActiveLayerBody extends ConsumerWidget {
  const _ActiveLayerBody({
    super.key,
    required this.layer,
    required this.layers,
    required this.repo,
    required this.mapContext,
    required this.mapRef,
  });

  final Layer layer;
  final List<Layer> layers;
  final Repository repo;
  final BuildContext mapContext;
  final WidgetRef mapRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = layerActionsFor(mapContext, mapRef, layer, layers);
    LayerAction? byId(LayerActionId id) =>
        actions.where((a) => a.id == id).firstOrNull;
    final count = ref.watch(layerSummariesProvider(layer.id)).length;
    final theme = Theme.of(context);

    // Runs [action] with the sheet out of the way when it has to be: a
    // map-owned action answers with a form, a preview or a banner, and a
    // delete's UNDO snackbar shows on the map. Everything else runs in place
    // and the sheet re-renders through its providers.
    Future<void> run(LayerAction action) async {
      if (action.needsMap ||
          action.id == LayerActionId.delete ||
          action.id == LayerActionId.makeMixed) {
        Navigator.pop(context);
      }
      await action.run();
    }

    final overflowIds = {
      LayerActionId.toTop,
      LayerActionId.toBottom,
      LayerActionId.export,
      LayerActionId.combine,
      LayerActionId.makeMixed,
      LayerActionId.delete,
    };
    final toggles = [
      for (final a in actions)
        if (a.checked != null) a,
    ];
    final tiles = [
      for (final a in actions)
        if (a.checked == null &&
            !overflowIds.contains(a.id) &&
            a.id != LayerActionId.up &&
            a.id != LayerActionId.down &&
            a.id != LayerActionId.rename &&
            a.id != LayerActionId.color &&
            a.id != LayerActionId.opacity)
          a,
    ];
    final overflow = [
      for (final a in actions)
        if (overflowIds.contains(a.id)) a,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identity row: visibility, colour, name, rename, overflow.
        Row(
          children: [
            IconButton(
              tooltip: layer.isVisible ? 'Hide' : 'Show',
              icon: Icon(
                layer.isVisible
                    ? Icons.visibility
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () =>
                  repo.updateLayer(layer.id, isVisible: !layer.isVisible),
            ),
            InkWell(
              onTap: () => run(byId(LayerActionId.color)!),
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: 'Colour',
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(layer.colorArgb),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(typeIcon(layer.type), size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                layer.name,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => run(byId(LayerActionId.rename)!),
            ),
            PopupMenuButton<LayerAction>(
              tooltip: 'More',
              onSelected: (a) => unawaited(run(a)),
              itemBuilder: (_) => [
                for (var i = 0; i < overflow.length; i++) ...[
                  if (i > 0 &&
                      layerActionGroup(overflow[i].id) !=
                          layerActionGroup(overflow[i - 1].id))
                    const PopupMenuDivider(),
                  PopupMenuItem(
                    value: overflow[i],
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(overflow[i].icon),
                      title: Text(overflow[i].label),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            '$count element${count == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        // Transparency, inline: a slider is the control, not a dialog.
        Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.opacity, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: OpacityControl(
                key: ValueKey('opacity-${layer.id}'),
                value: layer.opacity,
                inline: true,
                onChanged: (v) => repo.updateLayer(layer.id, opacity: v),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        for (final a in toggles)
          SwitchListTile(
            dense: true,
            secondary: Icon(a.icon),
            title: Text(a.label),
            value: a.checked!,
            onChanged: (_) => unawaited(run(a)),
          ),
        for (final a in tiles)
          ListTile(
            dense: true,
            leading: Icon(a.icon),
            title: Text(a.label),
            onTap: () => unawaited(run(a)),
          ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.format_list_bulleted),
          title: const Text('Elements'),
          trailing: Text('$count'),
          onTap: () => _openElements(context),
        ),
      ],
    );
  }

  /// The Elements list, over the map: this sheet closes first so what the
  /// list asks for (edit, zoom, an import) lands on a visible map.
  Future<void> _openElements(BuildContext context) async {
    Navigator.pop(context);
    final result = await showLayerObjects(mapContext, layer);
    if (result == null || !mapContext.mounted) return;
    applyElementResult(mapRef, layer, result, closeHost: () {});
  }
}
