import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart' show ColoredElement;
import '../state/providers.dart';
import 'import_actions.dart' show convertBorderAreaFlow;
import 'element_color.dart';
import 'element_color_dialog.dart';
import 'object_summary.dart';
import 'transit_modes_sheet.dart'
    show TransitModeFilter, transitTallyProvider;

/// What the caller (the layer tile) must do after the sheet closes. Rename and
/// delete are applied inside the sheet — they don't need the map or the drawer.
enum ElementAction {
  /// Select the object and frame it: the docked editor opens over the map.
  edit,

  /// Frame the object without changing the selection.
  zoom,

  /// Re-run an import that never finished.
  retry,
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
    final summaries = ref.watch(layerSummariesProvider(layer.id));
    // Imports (POI, transit, borders) have no editor sheet, so their row taps
    // frame the object instead of selecting it.
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
              // A transit layer's headline number is how many stations the
              // filter is currently drawing — the import count belongs to the
              // Imports heading, where it can't be read as "stations".
              Text(
                layer.type == 'transit'
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
          child: summaries.isEmpty && layer.type != 'transit'
              ? _EmptyState(scrollController: scrollController, layer: layer)
              : ListView(
                  controller: scrollController,
                  children: [
                    // A transit layer has two very different lists in it, and
                    // reading one as the other is the obvious mistake: the
                    // *types* are tick boxes that hide markers, the *imports*
                    // are fetched areas that delete data. Both live here, each
                    // under a heading that says which it is.
                    if (layer.type == 'transit') ...[
                      const _SectionHeader('Station types',
                          'Tick which kinds of stop to draw'),
                      TransitModeFilter(layer: layer),
                      const Divider(height: 1),
                      _SectionHeader(
                        'Imports',
                        'Areas you fetched — deleting one removes its stations',
                        trailing: '${summaries.length}',
                      ),
                    ],
                    if (summaries.isEmpty)
                      _EmptyHint(layer: layer)
                    else
                      for (var i = 0; i < summaries.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _row(context, ref, summaries[i], canEdit: canEdit),
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
    ObjectSummary s, {
    required bool canEdit,
  }) {
    return ListTile(
      leading: Icon(s.isPending ? Icons.refresh : typeIcon(layer.type)),
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
          // A borders layer is a read-only snapshot; this is how a shape gets
          // out of it and into geometry you can actually edit.
          if (s.ref.kind == ObjectKind.borderArea)
            const PopupMenuItem(
              value: 'toFreehand',
              child: Text('Convert to freehand area…'),
            ),
          const PopupMenuItem(value: 'color', child: Text('Colour…')),
          const PopupMenuItem(value: 'rename', child: Text('Rename…')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  /// Copies one imported border area into a freehand area layer, so it becomes
  /// geometry the user owns. Reads the rings from the database rather than the
  /// summary row — the row carries a bounding box, not the outline.
  Future<void> _convertToFreehand(
      BuildContext context, WidgetRef ref, ObjectSummary s) async {
    final repo = ref.read(repositoryProvider);
    final rings = await repo.borderAreaRings(s.ref.id);
    if (!context.mounted) return;
    await convertBorderAreaFlow(
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
      BuildContext context, WidgetRef ref, ObjectSummary s) async {
    final kind = ColoredElement.forLayerType(layer.type);
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
    await ref.read(repositoryProvider).setElementColor(
          kind,
          s.ref.id,
          choice.argb,
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
      case ObjectKind.transitSet:
        await repo.updateTransitSet(s.ref.id, label: label);
      case ObjectKind.borderArea:
        await repo.updateBorderArea(s.ref.id, name: label);
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
      case ObjectKind.transitSet:
        await repo.deleteTransitSet(s.ref.id);
      case ObjectKind.borderArea:
        await repo.deleteBorderArea(s.ref.id);
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
      'poi' => 'No POI sets yet — use Import POIs to fetch some for an area.',
      'transit' =>
        'No imports yet — tap Import transit, then tap two corners of an area.',
      'borders' =>
        'No areas yet — tap Import borders, then tap two corners of an area to '
            'fetch every boundary that crosses it.',
      _ => 'No elements yet — tap Add, then tap the map to place one.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
