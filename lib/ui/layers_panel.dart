import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../state/providers.dart';

/// Left-hand drawer for managing layers: list, choose active, visibility,
/// reorder, colour, rename, inverse, delete, and add. Replaces the old bottom
/// sheet so the map stays usable alongside it.
class LayersDrawer extends ConsumerWidget {
  const LayersDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layersAsync = ref.watch(layersProvider);
    final circles = ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
    final selected = ref.watch(activeLayerProvider);
    final repo = ref.read(repositoryProvider);

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
                      TextButton.icon(
                        onPressed: () async {
                          final id = await repo.createLayer(
                            name: 'Layer ${layers.length + 1}',
                            colorArgb:
                                _palette[layers.length % _palette.length]
                                    .toARGB32(),
                          );
                          ref.read(activeLayerProvider.notifier).select(id);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
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
                      final count =
                          circles.where((c) => c.layerId == layer.id).length;
                      return _LayerTile(
                        key: ValueKey(layer.id),
                        layer: layer,
                        circleCount: count,
                        isActive: layer.id == activeId,
                        canDelete: layers.length > 1,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

IconData _typeIcon(String type) =>
    type == 'planes' ? Icons.change_history : Icons.circle_outlined;

class _LayerTile extends ConsumerWidget {
  const _LayerTile({
    super.key,
    required this.layer,
    required this.circleCount,
    required this.isActive,
    required this.canDelete,
  });

  final Layer layer;
  final int circleCount;
  final bool isActive;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final subtitle = StringBuffer('$circleCount circle${circleCount == 1 ? '' : 's'}');
    if (layer.isInverted) subtitle.write(' · inverted');

    return ListTile(
      selected: isActive,
      onTap: () => ref.read(activeLayerProvider.notifier).select(layer.id),
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
                case 'inverse':
                  await repo.updateLayer(layer.id,
                      isInverted: !layer.isInverted);
                case 'delete':
                  await repo.deleteLayer(layer.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'color', child: Text('Colour')),
              PopupMenuItem(
                value: 'inverse',
                child: Text(layer.isInverted ? 'Un-invert' : 'Invert'),
              ),
              if (canDelete)
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

const _palette = <Color>[
  Color(0xFF2196F3),
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];
