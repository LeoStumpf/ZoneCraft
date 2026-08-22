import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../data/transit.dart' show transitModeLabels, transitModes;
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'element_color_dialog.dart';

/// Docked editor for one **transit import** — every station of the chosen types
/// inside a box, fetched once and stored offline.
///
/// The label and the owning layer are editable; the box and the imported types
/// are not, for the same reason a POI import's circle isn't — they describe a
/// query that already ran, and what a narrower mask omitted was never stored,
/// so widening it here would show nothing.
///
/// The **shown** types are a different thing entirely and *are* editable: they
/// filter rows that exist. They live on this sheet as well as in the layer's
/// Stations… menu, because someone who tapped an import to edit it should not
/// have to go looking for the reason half of it is invisible.
class TransitSetEditorSheet extends ConsumerStatefulWidget {
  const TransitSetEditorSheet({
    super.key,
    required this.set,
    required this.stopCount,
    required this.layers,
  });

  final TransitSet set;

  /// Stations currently stored in this import (drops as they are curated away).
  final int stopCount;

  /// Every `transit` layer, for the layer picker.
  final List<Layer> layers;

  @override
  ConsumerState<TransitSetEditorSheet> createState() =>
      _TransitSetEditorSheetState();
}

class _TransitSetEditorSheetState
    extends ConsumerState<TransitSetEditorSheet> {
  late final TextEditingController _label;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.set.label ?? '');
  }

  @override
  void didUpdateWidget(TransitSetEditorSheet old) {
    super.didUpdateWidget(old);
    if (old.set.id != widget.set.id) _label.text = widget.set.label ?? '';
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _close() => ref.read(selectedTransitSetProvider.notifier).select(null);

  /// The owning layer's colour, which the element's shade is derived from.
  /// Null when the layer is not in the list this sheet was handed (it was
  /// deleted under us) — the swatch then hides itself rather than throwing
  /// inside a build.
  Color? get _layerColor {
    for (final l in widget.layers) {
      if (l.id == widget.set.layerId) return Color(l.colorArgb);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.set;
    final theme = Theme.of(context);
    // Only the types this import actually fetched can be shown or hidden —
    // offering the others would be a tick box that can never draw anything.
    final imported =
        [for (final m in transitModes) if (s.modeMask & m.bit != 0) m];

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.directions_transit, size: 20),
            const SizedBox(width: 8),
            Text('Edit transit import', style: theme.textTheme.titleMedium),
            const SizedBox(width: 12),
            EditorLayerPicker(
              layers: widget.layers,
              selectedId: s.layerId,
              onChanged: (v) => _repo.updateTransitSet(s.id, layerId: v),
            ),
            ElementColorButton(
              kind: ColoredElement.transitSet,
              id: widget.set.id,
              title: widget.set.label?.trim().isNotEmpty == true
                  ? widget.set.label!.trim()
                  : 'Transit import',
              colorArgb: widget.set.colorArgb,
              colorShade: widget.set.colorShade,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: 'Delete import',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () async {
                await _repo.deleteTransitSet(s.id);
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
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            isDense: true,
          ),
          onChanged: (t) {
            final v = t.trim();
            _repo.updateTransitSet(s.id, label: Value(v.isEmpty ? null : v));
          },
        ),
        const SizedBox(height: 8),
        Text(
          [
            '${widget.stopCount} '
                'station${widget.stopCount == 1 ? '' : 's'} stored',
            'imported: ${transitModeLabels(s.modeMask)}',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (imported.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Show', style: theme.textTheme.labelLarge),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in imported)
                FilterChip(
                  label: Text(m.label),
                  selected: s.visibleModeMask & m.bit != 0,
                  onSelected: (on) => _repo.setTransitVisibleModes(
                    [s.id],
                    on
                        ? s.visibleModeMask | m.bit
                        : s.visibleModeMask & ~m.bit,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Fetched once and kept offline. The area and the imported types '
          'describe the query that ran — what they left out was never stored, '
          'so a wider area or more types means another import.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a station on the map to rename or remove that one.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
