import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/overpass.dart' show poiCategories;
import '../data/repository.dart';
import '../geo/coords.dart' show formatLatLng;
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'poi_category_dialog.dart';
import 'poi_icons.dart';
import 'element_color_dialog.dart';
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

  /// Renames the category and/or changes its icon, in one dialog — the same
  /// one that created it, so the two can never offer different choices.
  Future<void> _editCategory() async {
    final choice = await showPoiCategoryDialog(context, initial: widget.set);
    if (choice == null) return;
    await _repo.updatePoiSet(
      widget.set.id,
      label: Value(choice.name),
      categoryKey: choice.iconKey,
      iconKey: Value(choice.iconKey),
    );
    if (mounted) _label.text = choice.name;
  }

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
            Icon(s.isManual ? poiSetIcon(s) : Icons.travel_explore, size: 20),
            const SizedBox(width: 8),
            Text(
              s.isManual ? 'Edit category' : 'Edit POI import',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(width: 12),
            EditorLayerPicker(
              layers: widget.layers,
              selectedId: s.layerId,
              onChanged: (v) => _repo.updatePoiSet(s.id, layerId: v),
            ),
            ElementColorButton(
              kind: ColoredElement.poiSet,
              id: widget.set.id,
              title: widget.set.label?.trim().isNotEmpty == true
                  ? widget.set.label!.trim()
                  : (s.isManual ? 'Category' : 'POI import'),
              colorArgb: widget.set.colorArgb,
              colorShade: widget.set.colorShade,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: s.isManual ? 'Delete category' : 'Delete import',
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
        if (s.isManual) ...[
          // A hand-made category has no query to describe, so what an import
          // shows read-only is editable here instead: the marker every point in
          // it draws as.
          Row(
            children: [
              Text(
                '${widget.pointCount} '
                    'POI${widget.pointCount == 1 ? '' : 's'} placed',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _editCategory,
                icon: Icon(poiSetIcon(s), size: 18),
                label: const Text('Icon'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your own category. Tap Add POI and then the map to place points, '
            'and tap one to rename, move or remove it.',
            style: theme.textTheme.bodySmall,
          ),
        ] else ...[
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
            'search that already ran, so another area means another import — '
            'tap Import POIs.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a marker on the map to rename or remove that one POI.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
