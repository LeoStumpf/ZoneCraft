import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../geo/coords.dart' show formatLatLng;
import '../state/providers.dart';
import 'editor_sheet.dart';

/// Docked editor for **one imported point** — a stored POI or a transit
/// station. One widget for both, because the two rows differ only in which
/// table they came from and what the subtitle says; the thing being edited is
/// identical.
///
/// This is the level *below* an element: a POI belongs to a set, a station to
/// an import, and it is the set or import that appears in the Elements list.
/// The point is reachable only by tapping it on the map, which is where you
/// noticed it was wrong.
///
/// **Rename and delete, nothing else.** The position is the fetched fact the
/// layer exists to record — there is no column that would say a coordinate had
/// been moved, so moving one would quietly turn a record of where things are
/// into a drawing of where you think they are. Deleting is honest by contrast:
/// it removes a copy, and the upstream original is still there to re-import.
class ImportedPointEditorSheet extends ConsumerStatefulWidget {
  const ImportedPointEditorSheet({
    super.key,
    required this.id,
    required this.kind,
    required this.name,
    required this.lat,
    required this.lng,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  /// The row id, in the table [kind] names.
  final String id;

  /// Which of the two point kinds this is ([ObjectKind.poiPoint] or
  /// [ObjectKind.transitStop]) — decides the repository calls.
  final ObjectKind kind;

  final String? name;
  final double lat;
  final double lng;

  final IconData icon;

  /// Sheet heading ("Edit POI" / "Edit station").
  final String title;

  /// One line of context under the name — the category, or which modes serve
  /// the station.
  final String subtitle;

  @override
  ConsumerState<ImportedPointEditorSheet> createState() =>
      _ImportedPointEditorSheetState();
}

class _ImportedPointEditorSheetState
    extends ConsumerState<ImportedPointEditorSheet> {
  late final TextEditingController _name;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name ?? '');
  }

  @override
  void didUpdateWidget(ImportedPointEditorSheet old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _name.text = widget.name ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() {
    switch (widget.kind) {
      case ObjectKind.poiPoint:
        ref.read(selectedPoiPointProvider.notifier).select(null);
      default:
        ref.read(selectedTransitStopProvider.notifier).select(null);
    }
  }

  Future<void> _rename(String text) {
    final label = Value<String?>(text.trim().isEmpty ? null : text.trim());
    return widget.kind == ObjectKind.poiPoint
        ? _repo.updatePoiPoint(widget.id, name: label)
        : _repo.updateTransitStop(widget.id, name: label);
  }

  Future<void> _delete() async {
    if (widget.kind == ObjectKind.poiPoint) {
      await _repo.deletePoiPoint(widget.id);
    } else {
      await _repo.deleteTransitStop(widget.id);
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorSheet(
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 20),
            const SizedBox(width: 8),
            Text(widget.title, style: theme.textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: 'Remove from this import',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: _delete,
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
          onChanged: _rename,
        ),
        const SizedBox(height: 8),
        Text(
          [widget.subtitle, formatLatLng(widget.lat, widget.lng)].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Imported from OSM. The position is what was fetched and stays as it '
          'is; removing this one leaves the rest of the import alone.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
