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
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/database.dart';
import '../data/layer_types.dart';
import '../data/repository.dart' show ColoredElement, ZMove;
import '../data/transit.dart' show transitMaskWith;
import '../state/providers.dart';
import 'elements_list_model.dart';
import 'import_actions.dart' show convertRingsToFreehandFlow;
import 'element_color.dart';
import 'layer_actions.dart' show emptyStateActions;
import 'element_color_dialog.dart';
import 'object_summary.dart';
import 'poi_groups.dart';
import 'transit_modes_sheet.dart'
    show TransitModeShortcuts, transitTallyProvider;

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
  const ElementResult(this.action, this.target)
      : request = null,
        points = null;

  const ElementResult.request(MapRequest this.request)
      : action = ElementAction.request,
        target = null,
        points = null;

  /// Frame [points] — a POI type group's "Zoom to", which has no one object
  /// behind it.
  const ElementResult.focus(List<LatLng> this.points)
      : action = ElementAction.zoom,
        target = null,
        request = null;

  final ElementAction action;

  /// Null for [ElementAction.request] and for [ElementResult.focus].
  final ObjectSummary? target;
  final MapRequest? request;
  final List<LatLng>? points;

  /// What a zoom frames: the target's geometry, or the bare points.
  List<LatLng> get fitPoints => target?.fitPoints ?? points ?? const [];
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
      ref.read(pendingFocusProvider.notifier).request(result.fitPoints);
      closeHost();
  }
}

/// Lists everything in [layer] — every element, and on a POI layer every
/// POI, filed by type — with search, a sort, and per-row edit / zoom / rename
/// / delete.
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

class _LayerObjectsList extends ConsumerStatefulWidget {
  const _LayerObjectsList({
    required this.layer,
    required this.scrollController,
  });

  final Layer layer;
  final ScrollController scrollController;

  @override
  ConsumerState<_LayerObjectsList> createState() => _LayerObjectsListState();
}

class _LayerObjectsListState extends ConsumerState<_LayerObjectsList> {
  Layer get layer => widget.layer;

  /// Null until chosen: stack order where anything stacks, else by name.
  /// Deliberately not persisted — a sort is a reading aid for this visit, and
  /// a column for it would be a schema change for a preference nobody asked
  /// to keep.
  ElementSort? _sort;
  final _search = TextEditingController();
  final _expanded = <String>{};
  bool _importsExpanded = false;

  @override
  void initState() {
    super.initState();
    // The list is also how you find out what is selected, so the group
    // holding the selected POI opens with the sheet rather than hiding it.
    final selected = ref.read(selectedPoiPointProvider);
    if (selected != null) {
      for (final g in ref.read(poiTypeGroupsProvider(layer.id))) {
        if (g.points.any((p) => p.ref.id == selected)) _expanded.add(g.key);
      }
    }
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaries = ref.watch(layerSummariesProvider(layer.id));
    final groups = ref.watch(poiTypeGroupsProvider(layer.id));
    final canEdit = layerHasEditor(layer.type);
    // The station-type tally describes *imports that exist*, not a
    // capability: every POI layer *could* hold a station import, and gating on
    // that alone put station counts above a layer of cafés.
    final hasStations = groups.any((g) => g.kind == PoiGroupKind.station);
    final tally = hasStations ? ref.watch(transitTallyProvider(layer.id)) : null;
    // Read once here, not per row: a station import is thousands of rows.
    final selectedIds = watchSelectedIds(ref);

    final stackable = canSortByStack(summaries);
    final sizable = canSortBySize(summaries);
    final sort = _sort ?? (stackable ? ElementSort.stack : ElementSort.name);
    final choices = [
      if (stackable) ElementSort.stack,
      ElementSort.name,
      if (sizable) ElementSort.size,
    ];

    final model = buildElementRows(
      layer: layer,
      summaries: summaries,
      poiGroups: groups,
      sort: sort,
      query: _search.text,
      expandedGroups: _expanded,
      importsExpanded: _importsExpanded,
    );

    // The headline number: POIs on a POI layer (the tally when stations are
    // filtered, so the number is the one the map draws), elements otherwise,
    // both on a combined layer.
    final elements = summaries.length;
    final String count;
    if (tally != null) {
      count = '${tally.shown} / ${tally.total} shown';
    } else if (layer.type == kPoi) {
      count = _plural(model.poiCount, 'POI');
    } else if (model.poiCount > 0) {
      count = '${_plural(elements, 'element')} · ${_plural(model.poiCount, 'POI')}';
    } else {
      count = _plural(elements, 'element');
    }

    final empty = summaries.isEmpty && groups.isEmpty;

    return Padding(
      // The search field raises a keyboard, and a modal sheet does not move
      // for one: without this the bottom rows sit under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Icon(typeIcon(layer.type), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    layer.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(count, style: theme.textTheme.bodySmall),
                if (choices.length > 1)
                  PopupMenuButton<ElementSort>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort',
                    initialValue: sort,
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      for (final c in choices)
                        CheckedPopupMenuItem(
                          value: c,
                          checked: c == sort,
                          child: Text(switch (c) {
                            ElementSort.stack => 'Stack order',
                            ElementSort.name => 'By name',
                            ElementSort.size => 'By size',
                          }),
                        ),
                    ],
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
          if (!empty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search elements',
                  border: const OutlineInputBorder(),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear',
                          onPressed: _search.clear,
                        ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: empty
                ? _EmptyState(
                    scrollController: widget.scrollController,
                    layer: layer,
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: model.rows.length,
                    itemBuilder: (context, i) => _buildRow(
                      context,
                      model.rows[i],
                      canEdit: canEdit,
                      selectedIds: selectedIds,
                      summaries: summaries,
                      tallyVisible: tally?.visible,
                      tallySetIds: tally?.setIds,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ListRow row, {
    required bool canEdit,
    required Set<String> selectedIds,
    required List<ObjectSummary> summaries,
    required int? tallyVisible,
    required Set<String>? tallySetIds,
  }) {
    switch (row) {
      case ElementRow():
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            _elementTile(
              context,
              row,
              canEdit: canEdit,
              isSelected: selectedIds.contains(row.summary.ref.id),
            ),
          ],
        );
      case GroupHeaderRow():
        return _groupHeader(
          context,
          row,
          summaries: summaries,
          tallyVisible: tallyVisible,
          tallySetIds: tallySetIds,
        );
      case StationToolsRow():
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TransitModeShortcuts(layer: layer),
        );
      case SectionRow():
        return _SectionHeader(
          row.title,
          row.blurb,
          trailing: row.trailing,
          expanded: row.expanded,
          onTap: () => setState(() => _importsExpanded = !_importsExpanded),
        );
      case KindHeaderRow():
        return _SectionHeader(
          _kindHeading(row.kind),
          _kindBlurb(row.kind),
          trailing: '${row.count}',
        );
      case NoMatchesRow():
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Text(
            'Nothing matches "${row.query}".',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
    }
  }

  Widget _groupHeader(
    BuildContext context,
    GroupHeaderRow row, {
    required List<ObjectSummary> summaries,
    required int? tallyVisible,
    required Set<String>? tallySetIds,
  }) {
    final theme = Theme.of(context);
    final g = row.group;
    final mode = g.mode;
    final manualSet = g.manualSetId == null
        ? null
        : summaries.where((s) => s.ref.id == g.manualSetId).firstOrNull;
    return ListTile(
      leading: Icon(g.icon),
      title: Text(g.label, overflow: TextOverflow.ellipsis),
      subtitle: mode == null && g.kind == PoiGroupKind.station
          ? const Text('Shown whenever anything is — never orphaned')
          : null,
      onTap: () => setState(() {
        if (!_expanded.remove(g.key)) _expanded.add(g.key);
      }),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${row.shown}', style: theme.textTheme.bodySmall),
          // The same switch the Stations sheet offers, on the heading of the
          // type it switches: ticked means the map draws these.
          if (mode != null && tallyVisible != null && tallySetIds != null)
            Checkbox(
              value: tallyVisible & mode.bit != 0,
              onChanged: (v) => ref.read(repositoryProvider).setPoiVisibleModes(
                    tallySetIds.toList(),
                    transitMaskWith(tallyVisible, mode, on: v ?? false),
                  ),
            ),
          Icon(row.expanded ? Icons.expand_less : Icons.expand_more),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'zoom':
                  Navigator.pop(context, ElementResult.focus(g.fitPoints));
                case 'edit' when manualSet != null:
                  Navigator.pop(
                    context,
                    ElementResult(ElementAction.edit, manualSet),
                  );
                case 'delete' when manualSet != null:
                  await _delete(context, ref, manualSet);
              }
            },
            itemBuilder: (_) => [
              if (g.points.isNotEmpty)
                const PopupMenuItem(value: 'zoom', child: Text('Zoom to')),
              // A hand-made category is its own set: this heading is where it
              // is renamed, re-iconed or removed.
              if (manualSet != null) ...[
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit category'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _elementTile(
    BuildContext context,
    ElementRow row, {
    required bool canEdit,
    required bool isSelected,
  }) {
    final s = row.summary;
    final kind = ColoredElement.forObjectKindName(s.ref.kind.name);
    final scheme = Theme.of(context).colorScheme;
    final isPoint = s.ref.kind == ObjectKind.poiPoint;
    return ListTile(
      selected: isSelected,
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.onPrimaryContainer,
      shape: isSelected
          ? Border(left: BorderSide(color: scheme.primary, width: 4))
          : null,
      // A POI sits under its type's heading, which already carries the icon;
      // the indent says which heading. Everything else shows the *element's*
      // icon, not the layer's: a combined layer's rows are of different
      // kinds, and one shared icon would make the list unreadable.
      contentPadding: row.inGroup
          ? const EdgeInsets.only(left: 40, right: 16)
          : null,
      leading: isPoint
          ? null
          : Icon(s.isPending ? Icons.refresh : typeIcon(s.ref.kind.layerType)),
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
          // Named against the map, not against the list: the stack reads
          // bottom-of-map first, so "front" is *down* it — and the flags come
          // from that order even when the list is sorted some other way.
          if (row.canMoveForward) ...[
            const PopupMenuItem(
              value: 'toFront',
              child: Text('Bring to front'),
            ),
            const PopupMenuItem(value: 'forward', child: Text('Bring forward')),
          ],
          if (row.canMoveBack) ...[
            const PopupMenuItem(
              value: 'backward',
              child: Text('Send backward'),
            ),
            const PopupMenuItem(value: 'toBack', child: Text('Send to back')),
          ],
          if (row.canMoveBack || row.canMoveForward) const PopupMenuDivider(),
          // A POI has no colour of its own (its set's, or its modes') and no
          // stacking, so those never apply to it.
          if (kind != null)
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
    final controller = TextEditingController(text: s.sortName);
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

String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

String _kindHeading(ObjectKind kind) => switch (kind) {
      ObjectKind.circle => 'Circles',
      ObjectKind.subspace => 'Subspaces',
      ObjectKind.freeLine => 'Lines',
      ObjectKind.freeArea => 'Areas',
      ObjectKind.heightRegion => 'Height areas',
      ObjectKind.poiSet => 'POIs',
      ObjectKind.borderArea => 'Border areas',
      ObjectKind.poiPoint => 'POIs',
    };

String _kindBlurb(ObjectKind kind) => switch (kind) {
      ObjectKind.poiSet || ObjectKind.poiPoint => 'By type, then the imports',
      _ => 'Bottom of the map first',
    };

/// Names one part of a list that holds several, so none is read as another.
/// With [onTap] it is a collapsible heading, and says so with a chevron.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
    this.title,
    this.blurb, {
    this.trailing,
    this.expanded,
    this.onTap,
  });

  final String title;
  final String blurb;
  final String? trailing;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
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
                if (expanded != null)
                  Icon(
                    expanded! ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            Text(blurb, style: theme.textTheme.bodySmall),
          ],
        ),
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
        'No POIs yet — fetch a category around the map centre or '
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
