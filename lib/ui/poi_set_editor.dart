import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/overpass.dart' show poiCategories;
import '../data/repository.dart';
import '../geo/coords.dart' show formatLatLng;
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'object_summary.dart' show formatMeters;

/// Docked editor for one **POI import** — a category fetched once inside a
/// circle and stored offline.
///
/// What it can change is the label, and which `poi` layer the import lives on.
/// What it cannot is the category, the search centre or the radius: those three
/// describe a *query that already ran*, and editing them would leave a row
/// claiming to hold something it never fetched. Wanting a different area or
/// category is wanting another import, which the FAB does in two taps.
///
/// The POIs themselves are edited one at a time by tapping them on the map
/// (`ImportedPointEditorSheet`) — a city import is thousands of them, so they
/// are never listed here.
class PoiSetEditorSheet extends ConsumerStatefulWidget {
  const PoiSetEditorSheet({
    super.key,
    required this.set,
    required this.pointCount,
    required this.layers,
  });

  final PoiSet set;

  /// How many POIs this import currently holds — it drops as they are curated
  /// away, so it is read from the rows rather than stored.
  final int pointCount;

  /// Every `poi` layer, for the layer picker.
  final List<Layer> layers;

  @override
  ConsumerState<PoiSetEditorSheet> createState() => _PoiSetEditorSheetState();
}

class _PoiSetEditorSheetState extends ConsumerState<PoiSetEditorSheet> {
  late final TextEditingController _label;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.set.label ?? '');
  }

  @override
  void didUpdateWidget(PoiSetEditorSheet old) {
    super.didUpdateWidget(old);
    if (old.set.id != widget.set.id) _label.text = widget.set.label ?? '';
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _close() => ref.read(selectedPoiSetProvider.notifier).select(null);

  @override
  Widget build(BuildContext context) {
    final s = widget.set;
    final theme = Theme.of(context);
    final category = poiCategories
        .where((c) => c.key == s.categoryKey)
        .firstOrNull;

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.travel_explore, size: 20),
            const SizedBox(width: 8),
            Text('Edit POI import', style: theme.textTheme.titleMedium),
            const SizedBox(width: 12),
            EditorLayerPicker(
              layers: widget.layers,
              selectedId: s.layerId,
              onChanged: (v) => _repo.updatePoiSet(s.id, layerId: v),
            ),
            IconButton(
              tooltip: 'Delete import',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () async {
                await _repo.deletePoiSet(s.id);
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
            _repo.updatePoiSet(s.id, label: Value(v.isEmpty ? null : v));
          },
        ),
        const SizedBox(height: 8),
        Text(
          [
            category?.label ?? s.categoryKey,
            '${widget.pointCount} '
                'POI${widget.pointCount == 1 ? '' : 's'} stored',
            'within ${formatMeters(s.radiusMeters)} of '
                '${formatLatLng(s.centerLat, s.centerLng)}',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Fetched once and kept offline. The area and category describe the '
          'search that already ran, so another area means another import — tap '
          'Import POIs.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a marker on the map to rename or remove that one POI.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
