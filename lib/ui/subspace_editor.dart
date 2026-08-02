import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';

/// Docked bottom-sheet editor for a "closest subspace" object. Lists the
/// object's points — each a single "lat, lng" field with a "main" radio, a
/// place-by-tap button and a delete — plus an add-point button, the layer,
/// a label and delete-object. Like the other editors it writes every change
/// live while the map stays interactive.
class SubspaceEditorSheet extends ConsumerStatefulWidget {
  const SubspaceEditorSheet({
    super.key,
    required this.subspace,
    required this.points,
    required this.layers,
    required this.onAddPoint,
  });

  final Subspace subspace;

  /// The subspace's points, ordered.
  final List<SubspacePoint> points;
  final List<Layer> layers;

  /// Adds a point near the map centre (visible, then draggable to fine-tune).
  final VoidCallback onAddPoint;

  @override
  ConsumerState<SubspaceEditorSheet> createState() =>
      _SubspaceEditorSheetState();
}

class _SubspaceEditorSheetState extends ConsumerState<SubspaceEditorSheet> {
  final Map<String, TextEditingController> _ctl = {};
  final Map<String, FocusNode> _focus = {};
  late final TextEditingController _label;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.subspace.label ?? '');
  }

  @override
  void didUpdateWidget(SubspaceEditorSheet old) {
    super.didUpdateWidget(old);
    // Reflect external changes (e.g. placing a point by map tap) in the fields,
    // but never while the user is editing one, and prune removed points.
    final ids = widget.points.map((p) => p.id).toSet();
    for (final p in widget.points) {
      final c = _ctl[p.id];
      if (c != null && !(_focus[p.id]?.hasFocus ?? false)) {
        final t = formatLatLng(p.lat, p.lng);
        if (c.text != t) c.text = t;
      }
    }
    for (final id in _ctl.keys.toList()) {
      if (!ids.contains(id)) {
        _ctl.remove(id)?.dispose();
        _focus.remove(id)?.dispose();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    _label.dispose();
    super.dispose();
  }

  TextEditingController _ctlFor(SubspacePoint p) => _ctl.putIfAbsent(
        p.id,
        () => TextEditingController(text: formatLatLng(p.lat, p.lng)),
      );

  FocusNode _focusFor(String id) =>
      _focus.putIfAbsent(id, () => FocusNode());

  void _armPlacement(String pointId, int displayIndex) {
    ref.read(subspacePlacementProvider.notifier).arm(pointId);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Tap the map to place point ${displayIndex + 1}')),
      );
  }

  Future<void> _deletePoint(SubspacePoint p) async {
    final wasMain = p.isMain;
    final remaining = widget.points.where((q) => q.id != p.id).toList();
    await _repo.deleteSubspacePoint(p.id);
    // Keep exactly one main: promote another point if the main was removed.
    if (wasMain && remaining.isNotEmpty) {
      await _repo.setMainPoint(widget.subspace.id, remaining.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armed = ref.watch(subspacePlacementProvider);
    final id = widget.subspace.id;
    final mainId = widget.points.where((p) => p.isMain).firstOrNull?.id;
    final subspaceLayers =
        widget.layers.where((l) => l.type == 'subspace').toList();

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.scatter_plot_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit subspace',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 12),
                  // The layer picker takes the slack and ellipsises: a layer named
                  // after an imported border ("Ludwigsvorstadt-Isarvorstadt") is
                  // far longer than this row is wide.
                  Flexible(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: subspaceLayers.any((l) => l.id == widget.subspace.layerId)
                          ? widget.subspace.layerId
                          : null,
                      hint: const Text('Layer'),
                      items: [
                        for (final l in subspaceLayers)
                          DropdownMenuItem(value: l.id, child: Text(l.name)),
                      ],
                      onChanged: (v) {
                        if (v != null) _repo.updateSubspace(id, layerId: v);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete subspace',
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () async {
                      await _repo.deleteSubspace(id);
                      _close();
                    },
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: _close,
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'The filled region is everywhere closer to the main '
                      'point (●) than to any other point.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // The point list can grow; keep the sheet from eating the screen.
              // RadioGroup carries the "main point" selection for the rows.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: RadioGroup<String>(
                  groupValue: mainId,
                  onChanged: (v) {
                    if (v != null) _repo.setMainPoint(widget.subspace.id, v);
                  },
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.points.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = widget.points[i];
                      return _pointRow(p, i, armed == p.id);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: widget.onAddPoint,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add point'),
                  ),
                ],
              ),
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Label (optional)', isDense: true),
                onChanged: (s) {
                  final t = s.trim();
                  _repo.updateSubspace(id, label: Value(t.isEmpty ? null : t));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Prompts for a point name, pre-filled with the current label, and writes it
  /// back (empty clears it). The same rename is available from the map handle's
  /// long-press menu; this is the in-editor route.
  Future<void> _renamePoint(SubspacePoint p) async {
    final controller = TextEditingController(text: p.label ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name point'),
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
    if (name == null || !mounted) return;
    await _repo.updateSubspacePoint(p.id,
        label: Value(name.isEmpty ? null : name));
  }

  Widget _pointRow(SubspacePoint p, int index, bool armed) {
    return Row(
      children: [
        Radio<String>(value: p.id),
        Expanded(
          child: TextField(
            controller: _ctlFor(p),
            focusNode: _focusFor(p.id),
            decoration: InputDecoration(
              labelText: p.label != null && p.label!.isNotEmpty
                  ? '${p.label} (lat, lng)'
                  : 'Point ${index + 1} (lat, lng)',
              hintText: '48.137154, 11.575382',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            onChanged: (s) {
              final ll = parseLatLng(s);
              if (ll != null) {
                _repo.updateSubspacePoint(p.id,
                    lat: ll.latitude, lng: ll.longitude);
              }
            },
          ),
        ),
        IconButton(
          tooltip: 'Rename point ${index + 1}',
          icon: const Icon(Icons.label_outline),
          onPressed: () => _renamePoint(p),
        ),
        IconButton(
          tooltip: 'Move point ${index + 1} by tapping the map',
          icon: Icon(armed ? Icons.touch_app : Icons.touch_app_outlined),
          color: armed ? Theme.of(context).colorScheme.primary : null,
          onPressed: () => _armPlacement(p.id, index),
        ),
        IconButton(
          tooltip: 'Delete point ${index + 1}',
          icon: const Icon(Icons.remove_circle_outline),
          // Keep at least one point so the object isn't left empty.
          onPressed:
              widget.points.length <= 1 ? null : () => _deletePoint(p),
        ),
      ],
    );
  }

  void _close() {
    ref.read(subspacePlacementProvider.notifier).arm(null);
    ref.read(selectedSubspaceProvider.notifier).select(null);
  }
}
