import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/providers.dart';
import 'object_summary.dart';

/// What the caller (the layer tile) must do after the sheet closes. Rename and
/// delete are applied inside the sheet — they don't need the map or the drawer.
enum ElementAction {
  /// Select the object and frame it: the docked editor opens over the map.
  edit,

  /// Frame the object without changing the selection.
  zoom,
}

class ElementResult {
  const ElementResult(this.action, this.target);

  final ElementAction action;
  final ObjectSummary target;
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
  const _LayerObjectsList({required this.layer, required this.scrollController});

  final Layer layer;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The row providers are global (not per-layer); summariseLayer filters.
    final summaries = summariseLayer(
      layer,
      circles: ref.watch(circlesProvider).asData?.value ?? const [],
      planes: ref.watch(planesProvider).asData?.value ?? const [],
      subspaces: ref.watch(subspacesProvider).asData?.value ?? const [],
      subspacePoints:
          ref.watch(subspacePointsProvider).asData?.value ?? const [],
      freeLines: ref.watch(freeLinesProvider).asData?.value ?? const [],
      freeLinePoints:
          ref.watch(freeLinePointsProvider).asData?.value ?? const [],
      freeAreas: ref.watch(freeAreasProvider).asData?.value ?? const [],
      freeAreaPoints:
          ref.watch(freeAreaPointsProvider).asData?.value ?? const [],
      heightRegions: ref.watch(heightRegionsProvider).asData?.value ?? const [],
      poiSets: ref.watch(poiSetsProvider).asData?.value ?? const [],
      poiPoints: ref.watch(poiPointsProvider).asData?.value ?? const [],
    );
    // POI sets have no editor sheet, so their row taps frame instead of select.
    final canEdit = layer.type != 'poi';

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
              Text(
                '${summaries.length} element${summaries.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: summaries.isEmpty
              ? _EmptyState(scrollController: scrollController, layer: layer)
              : ListView.separated(
                  controller: scrollController,
                  itemCount: summaries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = summaries[i];
                    return ListTile(
                      leading: Icon(typeIcon(layer.type)),
                      title: Text(s.title, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.subtitle),
                      onTap: () => Navigator.pop(
                        context,
                        ElementResult(
                          canEdit ? ElementAction.edit : ElementAction.zoom,
                          s,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              Navigator.pop(context,
                                  ElementResult(ElementAction.edit, s));
                            case 'zoom':
                              Navigator.pop(context,
                                  ElementResult(ElementAction.zoom, s));
                            case 'rename':
                              await _rename(context, ref, s);
                            case 'delete':
                              await _delete(context, ref, s);
                          }
                        },
                        itemBuilder: (_) => [
                          if (canEdit)
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                              value: 'zoom', child: Text('Zoom to')),
                          const PopupMenuItem(
                              value: 'rename', child: Text('Rename…')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, ObjectSummary s) async {
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
      case ObjectKind.plane:
        await repo.updatePlane(s.ref.id, label: label);
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
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, ObjectSummary s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${s.title}?'),
        content: const Text('This cannot be undone.'),
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
      case ObjectKind.plane:
        await repo.deletePlane(s.ref.id);
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
    }
    // The editor sheet resolves its row from the global list, so a deleted
    // selection would just vanish — clear it explicitly to keep the state tidy.
    clearSelection(ref);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scrollController, required this.layer});

  final ScrollController scrollController;
  final Layer layer;

  @override
  Widget build(BuildContext context) {
    final hint = layer.type == 'poi'
        ? 'No POI sets yet — use Import POIs to fetch some for an area.'
        : 'No elements yet — tap Add, then tap the map to place one.';
    return ListView(
      controller: scrollController,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
