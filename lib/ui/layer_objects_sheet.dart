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

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/layer_types.dart';
import '../data/poi_sets.dart';
import '../data/repository.dart' show ColoredElement, ZMove;
import '../state/providers.dart';
import 'import_actions.dart' show convertRingsToFreehandFlow;
import 'element_color.dart';
import 'layer_actions.dart' show emptyStateActions;
import 'element_color_dialog.dart';
import 'object_summary.dart';
import 'transit_modes_sheet.dart' show TransitModeFilter, transitTallyProvider;

/// What the caller (the layer tile) must do after the sheet closes. Rename and
/// delete are applied inside the sheet — they don't need the map or the drawer.
enum ElementAction {
  /// Select the object and frame it: the docked editor opens over the map.
  edit,

  /// Frame the object without changing the selection.
  zoom,

  /// Re-run an import that never finished.
  retry,

  /// Start a map-owned action for the layer — an empty list's "Import…" /
  /// "Add" buttons. Carries a [MapRequest] rather than a target.
  request,
}

class ElementResult {
  const ElementResult(this.action, this.target) : request = null;

  const ElementResult.request(MapRequest this.request)
    : action = ElementAction.request,
      target = null;

  final ElementAction action;

  /// Null only for [ElementAction.request].
  final ObjectSummary? target;
  final MapRequest? request;
}

/// Carries out [result] on the map's providers: selects, focuses, or posts
/// the one-shot request the map answers.
///
/// Shared by the drawer and the layer sheet, which differ only in what has to
/// be closed so the map is visible — that is [closeHost]. A retry and a
/// request close it *before* posting: the map answers a retry by pushing a
/// progress dialog synchronously (a retry already has its set row, so nothing
/// is awaited first), and a pop issued afterwards would take that dialog
/// instead of the host.
void applyElementResult(
  WidgetRef ref,
  Layer layer,
  ElementResult result, {
  required VoidCallback closeHost,
}) {
  switch (result.action) {
    case ElementAction.retry:
      final retry = ref.read(pendingImportRetryProvider.notifier);
      closeHost();
      retry.request(result.target!.ref.id);
    case ElementAction.request:
      final requests = ref.read(mapRequestProvider.notifier);
      closeHost();
      requests.post(result.request!);
    case ElementAction.edit:
      // Selecting also makes the layer active, so the drag handles, the Add
      // button and the long-press context all follow the object being edited.
      final target = result.target!;
      ref.read(activeLayerProvider.notifier).select(layer.id);
      selectObject(ref, target.ref.kind, target.ref.id);
      ref.read(pendingFocusProvider.notifier).request(target.fitPoints);
      closeHost();
    case ElementAction.zoom:
      ref.read(pendingFocusProvider.notifier).request(result.target!.fitPoints);
      closeHost();
  }
}

/// Lists every object in [layer] with per-object edit / zoom / rename / delete.
///
/// Returns the action that needs the map (edit or zoom), or null if the user
/// just dismissed the sheet. The sheet never touches the drawer's navigator —
/// the caller owns that, so there is exactly one place popping routes.
Future<ElementResult?> showLayerObjects(BuildContext context, Layer layer) {
  return showModalBottomSheet<ElementResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, controller) =>
          _LayerObjectsList(layer: layer, scrollController: controller),
    ),
  );
}

class _LayerObjectsList extends ConsumerWidget {
  const _LayerObjectsList({
    required this.layer,
    required this.scrollController,
  });

  final Layer layer;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(layerSummariesProvider(layer.id));
    // The station-type section describes *imports that exist*, not a
    // capability: every POI layer *could* hold a station import, and gating on
    // that alone put "No stations imported yet" above a layer of cafés.
    final poiSets = ref.watch(poiSetsProvider).asData?.value ?? const [];
    final hasStations =
        layerHolds(layer, kPoi) &&
        poiSets.any((s) => s.layerId == layer.id && s.isStationImport);
    final canEdit = layerHasEditor(layer.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Icon(typeIcon(layer.type), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  layer.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // With a station import the headline number is how many
              // stations the filter is currently drawing — the element count
              // belongs to the Elements heading, where it can't be read as
              // "stations".
              Text(
                hasStations
                    ? () {
                        final t = ref.watch(transitTallyProvider(layer.id));
                        return '${t.shown} / ${t.total} shown';
                      }()
                    : '${summaries.length} '
                          'element${summaries.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: summaries.isEmpty
              ? _EmptyState(scrollController: scrollController, layer: layer)
              : ListView(
                  controller: scrollController,
                  children: [
                    // A layer with a station import has two very different
                    // lists in it, and reading one as the other is the obvious
                    // mistake: the *types* are tick boxes that hide markers,
                    // the *elements* are fetched sets that delete data. Both
                    // live here, each under a heading that says which it is.
                    if (hasStations) ...[
                      const _SectionHeader(
                        'Station types',
                        'Tick which kinds of stop to draw',
                      ),
                      TransitModeFilter(layer: layer),
                      const Divider(height: 1),
                      _SectionHeader(
                        'Elements',
                        'Everything on this layer — deleting an import '
                            'removes its points',
                        trailing: '${summaries.length}',
                      ),
                    ],
                    if (summaries.isEmpty)
                      _EmptyHint(layer: layer)
                    else
                      for (var i = 0; i < summaries.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _row(context, ref, summaries, i, canEdit: canEdit),
                      ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    List<ObjectSummary> summaries,
    int index, {
    required bool canEdit,
  }) {
    final s = summaries[index];
    // Stacking is per (layer, table), so a row can only move past rows of its
    // own kind — on a mixed layer a POI has no position relative to a circle to
    // begin with. Whether the ends are hidden is decided here rather than in
    // ObjectSummary because it is a fact about the *list*, not the element.
    final kind = ColoredElement.forObjectKindName(s.ref.kind.name);
    final sameKind = [
      for (final o in summaries)
        if (o.ref.kind == s.ref.kind) o.ref.id,
    ];
    final at = sameKind.indexOf(s.ref.id);
    // Border areas are listed by name, not by stack (finding "Maxvorstadt"
    // among 97 is the actual task there), so a "move up" would point at a row
    // that does not move. Their z is honoured on the map; it just is not
    // editable from a list that is not in that order — and areas at one admin
    // level do not overlap anyway.
    final canStack =
        kind != null &&
        kind != ColoredElement.borderArea &&
        sameKind.length > 1 &&
        at >= 0;
    final canMoveBack = canStack && at > 0;
    final canMoveForward = canStack && at < sameKind.length - 1;
    return ListTile(
      // The *element's* icon, not the layer's: a combined layer's rows are
      // of different kinds, and one shared icon would make the list
      // unreadable — a circle and a POI set would look identical.
      leading: Icon(
        s.isPending ? Icons.refresh : typeIcon(s.ref.kind.layerType),
      ),
      title: Text(s.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(s.subtitle),
      onTap: () => Navigator.pop(
        context,
        ElementResult(
          // An import that never finished offers a retry rather than a zoom to
          // an empty box.
          s.isPending
              ? ElementAction.retry
              : canEdit
              ? ElementAction.edit
              : ElementAction.zoom,
          s,
        ),
      ),
      // The shortcut for the one action people reach for most. It runs the
      // *same* confirm the menu entry does — a long-press must not become the
      // one unconfirmed delete path in the app. The menu entry stays: a
      // gesture nothing announces cannot be the only way to find this.
      onLongPress: () => unawaited(_delete(context, ref, s)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'edit':
              Navigator.pop(context, ElementResult(ElementAction.edit, s));
            case 'zoom':
              Navigator.pop(context, ElementResult(ElementAction.zoom, s));
            case 'retry':
              Navigator.pop(context, ElementResult(ElementAction.retry, s));
            case 'toFreehand':
              await _convertToFreehand(context, ref, s);
            case 'toFront':
              await _move(ref, kind, s, ZMove.toFront);
            case 'forward':
              await _move(ref, kind, s, ZMove.forward);
            case 'backward':
              await _move(ref, kind, s, ZMove.backward);
            case 'toBack':
              await _move(ref, kind, s, ZMove.toBack);
            case 'color':
              await _pickElementColor(context, ref, s);
            case 'rename':
              await _rename(context, ref, s);
            case 'delete':
              await _delete(context, ref, s);
          }
        },
        itemBuilder: (_) => [
          if (s.isPending)
            const PopupMenuItem(value: 'retry', child: Text('Try again')),
          if (canEdit && !s.isPending)
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'zoom', child: Text('Zoom to')),
          // A borders layer is a read-only snapshot and a height fill is
          // generated; this is how a shape gets out of either and into
          // geometry you can actually edit.
          if (s.ref.kind == ObjectKind.borderArea ||
              s.ref.kind == ObjectKind.heightRegion)
            const PopupMenuItem(
              value: 'toFreehand',
              child: Text('Convert to freehand area…'),
            ),
          // Named against the map, not against the list: the list reads
          // bottom-of-map first, so "front" is *down* it.
          if (canMoveForward) ...[
            const PopupMenuItem(
              value: 'toFront',
              child: Text('Bring to front'),
            ),
            const PopupMenuItem(value: 'forward', child: Text('Bring forward')),
          ],
          if (canMoveBack) ...[
            const PopupMenuItem(
              value: 'backward',
              child: Text('Send backward'),
            ),
            const PopupMenuItem(value: 'toBack', child: Text('Send to back')),
          ],
          if (canMoveBack || canMoveForward) const PopupMenuDivider(),
          const PopupMenuItem(value: 'color', child: Text('Colour…')),
          const PopupMenuItem(value: 'rename', child: Text('Rename…')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  /// Copies one imported border area, or one generated height fill, into a
  /// freehand area layer, so it becomes geometry the user owns. Reads the
  /// rings from the database rather than the summary row — the row carries a
  /// bounding box, not the outline.
  Future<void> _convertToFreehand(
    BuildContext context,
    WidgetRef ref,
    ObjectSummary s,
  ) async {
    final repo = ref.read(repositoryProvider);
    final rings = s.ref.kind == ObjectKind.heightRegion
        ? await repo.heightRegionRings(s.ref.id)
        : await repo.borderAreaRings(s.ref.id);
    if (!context.mounted) return;
    await convertRingsToFreehandFlow(
      context,
      repo,
      ref.read(layersProvider).asData?.value ?? const [],
      name: s.title,
      rings: rings,
    );
    if (context.mounted) Navigator.pop(context);
  }

  /// Gives one element its own colour, or hands it back to the layer.
  Future<void> _pickElementColor(
    BuildContext context,
    WidgetRef ref,
    ObjectSummary s,
  ) async {
    // Resolved from the *row's* kind, not the layer's type: a mixed layer holds
    // several kinds, so the layer can no longer answer for one element.
    final kind = ColoredElement.forObjectKindName(s.ref.kind.name);
    if (kind == null) return;
    final layerColor = Color(layer.colorArgb);
    final choice = await showElementColorDialog(
      context,
      title: s.title,
      current: elementColor(
        colorArgb: s.colorArgb,
        shadeIndex: s.colorShade,
        layerColor: layerColor,
      ),
      following: s.colorArgb == null,
      layerColor: layerColor,
      shadeIndex: s.colorShade,
    );
    if (choice == null) return; // cancelled
    await ref
        .read(repositoryProvider)
        .setElementColor(kind, s.ref.id, choice.argb);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ObjectSummary s,
  ) async {
    final controller = TextEditingController(text: s.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename element'),
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
    if (name == null) return;
    final label = Value<String?>(name.isEmpty ? null : name);
    final repo = ref.read(repositoryProvider);
    switch (s.ref.kind) {
      case ObjectKind.circle:
        await repo.updateCircle(s.ref.id, label: label);
      case ObjectKind.subspace:
        await repo.updateSubspace(s.ref.id, label: label);
      case ObjectKind.freeLine:
        await repo.updateFreeLine(s.ref.id, label: label);
      case ObjectKind.freeArea:
        await repo.updateFreeArea(s.ref.id, label: label);
      case ObjectKind.heightRegion:
        await repo.updateHeightRegion(s.ref.id, label: label);
      case ObjectKind.poiSet:
        await repo.updatePoiSet(s.ref.id, label: label);
      case ObjectKind.borderArea:
        await repo.updateBorderArea(s.ref.id, name: label);
      // Points inside an import are renamed from their own map editor; the
      // Elements list never lists them (see [ObjectKind]).
      case ObjectKind.poiPoint:
        await repo.updatePoiPoint(s.ref.id, name: label);
    }
  }

  /// Restacks one element. The sheet rebuilds off `layerSummariesProvider`,
  /// which watches the row streams, so there is nothing to refresh by hand.
  Future<void> _move(
    WidgetRef ref,
    ColoredElement? kind,
    ObjectSummary s,
    ZMove move,
  ) async {
    if (kind == null) return;
    await ref.read(repositoryProvider).moveElementZ(kind, s.ref.id, move);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ObjectSummary s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${s.title}?'),
        content: const Text('Undo will bring it back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(repositoryProvider);
    switch (s.ref.kind) {
      case ObjectKind.circle:
        await repo.deleteCircle(s.ref.id);
      case ObjectKind.subspace:
        await repo.deleteSubspace(s.ref.id);
      case ObjectKind.freeLine:
        await repo.deleteFreeLine(s.ref.id);
      case ObjectKind.freeArea:
        await repo.deleteFreeArea(s.ref.id);
      case ObjectKind.heightRegion:
        await repo.deleteHeightRegion(s.ref.id);
      case ObjectKind.poiSet:
        await repo.deletePoiSet(s.ref.id);
      case ObjectKind.borderArea:
        await repo.deleteBorderArea(s.ref.id);
      case ObjectKind.poiPoint:
        await repo.deletePoiPoint(s.ref.id);
    }
    // The editor sheet resolves its row from the global list, so a deleted
    // selection would just vanish — clear it explicitly to keep the state tidy.
    clearSelection(ref);
  }
}

/// Names one half of a two-part list, so neither half is read as the other.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.blurb, {this.trailing});

  final String title;
  final String blurb;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: theme.textTheme.bodySmall),
            ],
          ),
          Text(blurb, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scrollController, required this.layer});

  final ScrollController scrollController;
  final Layer layer;

  @override
  Widget build(BuildContext context) => ListView(
    controller: scrollController,
    children: [_EmptyHint(layer: layer)],
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.layer});

  final Layer layer;

  @override
  Widget build(BuildContext context) {
    final hint = switch (layer.type) {
      'poi' =>
        'No POI sets yet — fetch a category around the map centre or '
            'the transit stations of an area, or place your own.',
      'borders' =>
        'No areas yet — import every boundary that crosses the '
            'part of the map in view.',
      _ => 'No elements yet.',
    };
    // Buttons, not directions: the hint used to name buttons that live on
    // the map, behind this sheet and the drawer. Each of these closes both
    // and starts the action.
    final actions = emptyStateActions(layer.type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final a in actions)
                FilledButton.tonalIcon(
                  icon: Icon(a.icon),
                  label: Text(a.label),
                  onPressed: () => Navigator.pop(
                    context,
                    ElementResult.request(
                      MapRequest(a.kind, layerId: layer.id),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
