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
import '../data/error_log.dart';
import '../data/layer_types.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'edit_value_dialog.dart';
import 'element_color_dialog.dart';
import 'poi_move.dart' show PointMoveButton;
import 'confirm_delete.dart';

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
  late final TextEditingController _label;

  /// The subspace as it was when this editor opened — what **Reset** puts
  /// back. Taken once: an editor is one sitting, and "abort what I did here"
  /// means back to how it looked when I started, not to the last keystroke.
  late List<_PointSnap> _snapshot;
  late String? _labelSnapshot;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.subspace.label ?? '');
    _snapshot = [for (final p in widget.points) _PointSnap.of(p)];
    _labelSnapshot = widget.subspace.label;
  }

  @override
  void didUpdateWidget(SubspaceEditorSheet old) {
    super.didUpdateWidget(old);
    // A different subspace in the same slot is a new sitting.
    if (old.subspace.id != widget.subspace.id) {
      _snapshot = [for (final p in widget.points) _PointSnap.of(p)];
      _labelSnapshot = widget.subspace.label;
      _label.text = widget.subspace.label ?? '';
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  /// Whether anything differs from [_snapshot] — what enables Reset.
  bool get _changed {
    if (widget.subspace.label != _labelSnapshot) return true;
    if (widget.points.length != _snapshot.length) return true;
    for (var i = 0; i < _snapshot.length; i++) {
      if (_PointSnap.of(widget.points[i]) != _snapshot[i]) return true;
    }
    return false;
  }

  /// Puts the subspace back the way it was when the editor opened: points
  /// added since go, points removed come back, moved and renamed ones return,
  /// and the main point is the one it was. One undo step, so Reset itself can
  /// be taken back.
  Future<void> _reset() async {
    ref.read(pointMoveProvider.notifier).cancel();
    final id = widget.subspace.id;
    final current = {for (final p in widget.points) p.id: p};
    final keep = {for (final s in _snapshot) s.id};
    final restored = <_PointSnap>[];
    await _repo.undo.group('Reset subspace', () async {
      for (final p in widget.points) {
        if (!keep.contains(p.id)) await _repo.deleteSubspacePoint(p.id);
      }
      String? mainId;
      for (final snap in _snapshot) {
        final now = current[snap.id];
        var rowId = snap.id;
        if (now == null) {
          rowId = await _repo.addSubspacePoint(
            subspaceId: id,
            lat: snap.lat,
            lng: snap.lng,
            label: snap.label,
          );
        } else if (_PointSnap.of(now) != snap) {
          await _repo.updateSubspacePoint(
            snap.id,
            lat: snap.lat,
            lng: snap.lng,
            label: Value(snap.label),
          );
        }
        if (snap.isMain) mainId = rowId;
        restored.add(snap.withId(rowId));
      }
      if (mainId != null) await _repo.setMainPoint(id, mainId);
      await _repo.updateSubspace(id, label: Value(_labelSnapshot));
    });
    if (!mounted) return;
    // A point that had to be re-created has a new id; the snapshot follows
    // it, so a second Reset still knows it.
    setState(() => _snapshot = restored);
    _label.text = _labelSnapshot ?? '';
  }

  Future<void> _editPosition(SubspacePoint p, int index) async {
    final answer = await showPositionDialog(
      context,
      lat: p.lat,
      lng: p.lng,
      title: p.label?.trim().isNotEmpty == true
          ? p.label!.trim()
          : 'Point ${index + 1}',
    );
    if (answer == null || !mounted) return;
    ref.read(pointMoveProvider.notifier).cancel();
    await _repo.updateSubspacePoint(
      p.id,
      lat: answer.at.latitude,
      lng: answer.at.longitude,
    );
    await _repo.undo.sealStep(label: 'Move point');
  }

  Future<void> _deletePoint(SubspacePoint p) async {
    if (!await confirmDelete(context, title: 'Remove this point?')) return;
    final wasMain = p.isMain;
    final remaining = widget.points.where((q) => q.id != p.id).toList();
    await _repo.deleteSubspacePoint(p.id);
    // Keep exactly one main: promote another point if the main was removed.
    if (wasMain && remaining.isNotEmpty) {
      await _repo.setMainPoint(widget.subspace.id, remaining.first.id);
    }
  }

  /// The owning layer's colour, which the element's shade is derived from.
  /// Null when the layer is not in the list this sheet was handed (it was
  /// deleted under us) — the swatch then hides itself rather than throwing
  /// inside a build.
  Color? get _layerColor {
    for (final l in widget.layers) {
      if (l.id == widget.subspace.layerId) return Color(l.colorArgb);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.subspace.id;
    final mainId = widget.points.where((p) => p.isMain).firstOrNull?.id;
    final subspaceLayers = widget.layers
        .where((l) => layerHolds(l, kSubspace))
        .toList();

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.scatter_plot_outlined, size: 18),
            const SizedBox(width: 8),
            Text(
              'Edit subspace',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 12),
            // The layer picker takes the slack and ellipsises: a layer named
            // after an imported border ("Ludwigsvorstadt-Isarvorstadt") is
            // far longer than this row is wide.
            EditorLayerPicker(
              layers: subspaceLayers,
              selectedId: widget.subspace.layerId,
              onChanged: (v) =>
                  _repo.updateSubspace(widget.subspace.id, layerId: v),
            ),
            ElementColorButton(
              kind: ColoredElement.subspace,
              id: widget.subspace.id,
              title: widget.subspace.label?.trim().isNotEmpty == true
                  ? widget.subspace.label!.trim()
                  : 'Subspace',
              colorArgb: widget.subspace.colorArgb,
              colorShade: widget.subspace.colorShade,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: 'Delete subspace',
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              onPressed: () async {
                if (!await confirmDelete(
                  context,
                  title: 'Delete this subspace and all its points?',
                )) {
                  return;
                }
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
          constraints: BoxConstraints(maxHeight: scaledPx(context, 240)),
          child: RadioGroup<String>(
            groupValue: mainId,
            onChanged: (v) {
              if (v != null) {
                logAsyncFailure(
                  _repo.setMainPoint(widget.subspace.id, v),
                  'Setting the main point',
                );
              }
            },
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.points.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = widget.points[i];
                return _pointRow(p, i);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: widget.onAddPoint,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add point'),
            ),
            // Abandon this sitting: back to how the subspace looked when
            // the editor opened.
            TextButton.icon(
              onPressed: _changed ? () => unawaited(_reset()) : null,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            isDense: true,
          ),
          onChanged: (s) {
            final t = s.trim();
            logAsyncFailure(
              _repo.updateSubspace(id, label: Value(t.isEmpty ? null : t)),
              'Saving the name',
            );
          },
        ),
      ],
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
    await _repo.updateSubspacePoint(
      p.id,
      label: Value(name.isEmpty ? null : name),
    );
  }

  Widget _pointRow(SubspacePoint p, int index) {
    final theme = Theme.of(context);
    final name = p.label?.trim();
    return Row(
      children: [
        Radio<String>(value: p.id),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name != null && name.isNotEmpty ? name : 'Point ${index + 1}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              Text(
                formatLatLng(p.lat, p.lng),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit the coordinates of point ${index + 1}',
          icon: const Icon(Icons.edit_location_alt_outlined),
          onPressed: () => unawaited(_editPosition(p, index)),
        ),
        PointMoveButton(
          pointId: p.id,
          lat: p.lat,
          lng: p.lng,
          target: PointMoveTarget.subspacePoint,
          tooltip: 'Move point ${index + 1} on the map',
        ),
        PopupMenuButton<String>(
          tooltip: 'Point ${index + 1} options',
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.label_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Rename…'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'remove',
              // Keep at least one point so the object isn't left empty.
              enabled: widget.points.length > 1,
              child: const Row(
                children: [
                  Icon(Icons.remove_circle_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Remove'),
                ],
              ),
            ),
          ],
          onSelected: (v) {
            switch (v) {
              case 'rename':
                unawaited(_renamePoint(p));
              case 'remove':
                logAsyncFailure(_deletePoint(p), 'Removing the point');
            }
          },
        ),
      ],
    );
  }

  void _close() {
    ref.read(pointMoveProvider.notifier).cancel();
    ref.read(selectedSubspaceProvider.notifier).select(null);
  }
}

/// One point of a subspace as the editor found it, for Reset.
@immutable
class _PointSnap {
  const _PointSnap({
    required this.id,
    required this.lat,
    required this.lng,
    required this.label,
    required this.isMain,
  });

  factory _PointSnap.of(SubspacePoint p) => _PointSnap(
    id: p.id,
    lat: p.lat,
    lng: p.lng,
    label: p.label,
    isMain: p.isMain,
  );

  final String id;
  final double lat;
  final double lng;
  final String? label;
  final bool isMain;

  _PointSnap withId(String id) =>
      _PointSnap(id: id, lat: lat, lng: lng, label: label, isMain: isMain);

  @override
  bool operator ==(Object other) =>
      other is _PointSnap &&
      other.id == id &&
      other.lat == lat &&
      other.lng == lng &&
      other.label == label &&
      other.isMain == isMain;

  @override
  int get hashCode => Object.hash(id, lat, lng, label, isMain);
}
