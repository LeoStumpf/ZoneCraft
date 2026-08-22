import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng, LengthUnit;

import '../data/database.dart';
import '../data/repository.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'element_color_dialog.dart';
import 'import_actions.dart' show convertBorderAreaFlow;
import 'hit_test.dart' show geoDistance;
import 'object_summary.dart' show formatMeters;

/// Docked editor for one imported administrative area.
///
/// A borders layer is an **offline OSM snapshot**, and this editor is shaped by
/// that rather than pretending otherwise. Three of its four sections cost the
/// snapshot nothing — the name, the name-plate anchor, and getting an editable
/// copy out via "Convert to freehand area". The fourth, **Reshape outline**,
/// genuinely forks the area from upstream, so it is a mode you turn on rather
/// than handles that are always there, and the moment it changes anything the
/// area is stamped `editedAt` and says so here and in the Elements list.
///
/// What it deliberately does **not** offer: moving the area, or editing its
/// `osmId`, `admin_level` or member way ids. Those are the identity the
/// re-import dedup and the neighbour-distinct colouring are computed from —
/// changing them wouldn't edit the area, it would make it a different area
/// wearing the same row.
class BorderAreaEditorSheet extends ConsumerStatefulWidget {
  const BorderAreaEditorSheet({
    super.key,
    required this.area,
    required this.layer,
  });

  final BorderArea area;

  /// The layer this area's import belongs to. There is no layer *picker*: an
  /// area belongs to the import that fetched it, so moving it between layers
  /// means moving its import — see the note in [build].
  final Layer layer;

  @override
  ConsumerState<BorderAreaEditorSheet> createState() =>
      _BorderAreaEditorSheetState();
}

class _BorderAreaEditorSheetState extends ConsumerState<BorderAreaEditorSheet> {
  late final TextEditingController _name;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.area.name ?? '');
  }

  @override
  void didUpdateWidget(BorderAreaEditorSheet old) {
    super.didUpdateWidget(old);
    // The row reloads while reshaping (every drag end rewrites it), and the
    // name field must not fight the user's cursor when it does.
    final incoming = widget.area.name ?? '';
    if (old.area.id != widget.area.id && _name.text != incoming) {
      _name.text = incoming;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() {
    ref.read(borderReshapeProvider.notifier).arm(false);
    ref.read(selectedBorderAreaProvider.notifier).select(null);
  }

  Future<void> _convert() async {
    final rings = await _repo.borderAreaRings(widget.area.id);
    if (!mounted) return;
    await convertBorderAreaFlow(
      context,
      _repo,
      ref.read(layersProvider).asData?.value ?? const [],
      name: widget.area.name ?? 'Area',
      rings: rings,
    );
  }

  Color get _layerColor => Color(widget.layer.colorArgb);

  @override
  Widget build(BuildContext context) {
    final a = widget.area;
    final reshaping = ref.watch(borderReshapeProvider);
    final edited = a.editedAt != null;
    final theme = Theme.of(context);

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.public, size: 20),
            const SizedBox(width: 8),
            Text('Edit area', style: theme.textTheme.titleMedium),
            const SizedBox(width: 12),
            // Read-only on purpose: an area belongs to the *import* that
            // fetched it, and one borders layer holds one admin level, so
            // "move this area to another layer" is really "move its import" —
            // which the Elements list offers on the import, where it means
            // something.
            Expanded(
              child: Text(
                widget.layer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            ElementColorButton(
              kind: ColoredElement.borderArea,
              id: widget.area.id,
              title: widget.area.name ?? 'Area',
              colorArgb: widget.area.colorArgb,
              colorShade: 0,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: 'Delete area',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () async {
                await _repo.deleteBorderArea(a.id);
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
        const SizedBox(height: 4),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Leave empty to clear',
            isDense: true,
          ),
          onChanged: (s) {
            final t = s.trim();
            _repo.updateBorderArea(a.id, name: Value(t.isEmpty ? null : t));
          },
        ),
        const SizedBox(height: 8),
        Text(
          [
            'OSM relation ${a.osmId}',
            'level ${widget.layer.borderLevel ?? '—'}',
            '${a.pointCount} points',
            formatMeters(_spanMeters(a)),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Drag the crosshair on the map to move the name plate. That is '
          'presentation, not geometry — it leaves the snapshot untouched.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        // The one control that forks the area from OSM, so it announces itself
        // rather than sitting on by default.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: reshaping,
          onChanged: (v) =>
              ref.read(borderReshapeProvider.notifier).arm(v),
          title: const Text('Reshape outline'),
          subtitle: Text(
            reshaping
                ? 'Drag a handle to move a point · long-press one to remove it '
                    '· long-press the outline to insert'
                : 'Edit the boundary by hand. This forks it from OSM.',
          ),
        ),
        if (edited)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Reshaped by hand — this outline is no longer what OSM '
                    'says. Importing the same area again keeps this version.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: _convert,
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Convert to freehand area…'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'A freehand copy is yours to reshape freely, and leaves this '
          'snapshot as OSM sent it.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Diagonal of the area's stored bounds — a one-number sense of scale that
  /// doesn't need the ring decoded.
  double _spanMeters(BorderArea a) => geoDistance.as(
      LengthUnit.Meter, LatLng(a.south, a.west), LatLng(a.north, a.east));
}
