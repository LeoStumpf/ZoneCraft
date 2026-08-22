import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'element_color_dialog.dart';
import 'region_geometry.dart';

/// Docked bottom-sheet editor for a freehand line (polyline). Lists the line's
/// ordered points — each a single "lat, lng" field with a place-by-tap button
/// and a delete — plus an add-point button, a signed offset, the layer, a label
/// and delete-object. Writes every change live while the map stays interactive.
class FreeLineEditorSheet extends ConsumerStatefulWidget {
  const FreeLineEditorSheet({
    super.key,
    required this.freeLine,
    required this.points,
    required this.layers,
    required this.onAddPoint,
  });

  final FreeLine freeLine;

  /// The line's points, ordered.
  final List<FreeLinePoint> points;
  final List<Layer> layers;

  /// Adds a point near the map centre (visible, then draggable to fine-tune).
  final VoidCallback onAddPoint;

  @override
  ConsumerState<FreeLineEditorSheet> createState() =>
      _FreeLineEditorSheetState();
}

class _FreeLineEditorSheetState extends ConsumerState<FreeLineEditorSheet> {
  final Map<String, TextEditingController> _ctl = {};
  final Map<String, FocusNode> _focus = {};
  late final TextEditingController _label;
  late final TextEditingController _offset;
  late final TextEditingController _radius;

  Repository get _repo => ref.read(repositoryProvider);

  /// The inclusion circle currently in effect (stored, or derived from the line
  /// when unset), for prefilling the radius field and persisting a stable centre.
  ({LatLng center, double radiusMeters}) get _inclusion => effectiveInclusion(
    lat: widget.freeLine.inclusionLat,
    lng: widget.freeLine.inclusionLng,
    radiusMeters: widget.freeLine.inclusionRadiusMeters,
    points: [for (final p in widget.points) LatLng(p.lat, p.lng)],
  );

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.freeLine.label ?? '');
    _offset = TextEditingController(
      text: widget.freeLine.offsetMeters.round().toString(),
    );
    _radius = TextEditingController(
      text: _inclusion.radiusMeters.round().toString(),
    );
  }

  @override
  void didUpdateWidget(FreeLineEditorSheet old) {
    super.didUpdateWidget(old);
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
    _offset.dispose();
    _radius.dispose();
    super.dispose();
  }

  TextEditingController _ctlFor(FreeLinePoint p) => _ctl.putIfAbsent(
    p.id,
    () => TextEditingController(text: formatLatLng(p.lat, p.lng)),
  );

  FocusNode _focusFor(String id) => _focus.putIfAbsent(id, () => FocusNode());

  void _armPlacement(String pointId, int displayIndex) {
    ref.read(freeLinePlacementProvider.notifier).arm(pointId);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Tap the map to place point ${displayIndex + 1}'),
        ),
      );
  }

  void _armCenter() {
    ref.read(freeLineCenterPlacementProvider.notifier).arm(true);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tap the map to place the inclusion circle’s centre'),
        ),
      );
  }

  void _setRadius(double r) {
    // Persist a stable centre alongside the radius, so a line whose circle was
    // only ever derived (legacy/unset) stops drifting when its points change.
    final inc = _inclusion;
    _repo.updateFreeLine(
      widget.freeLine.id,
      inclusionRadiusMeters: r,
      inclusionLat: widget.freeLine.inclusionLat ?? inc.center.latitude,
      inclusionLng: widget.freeLine.inclusionLng ?? inc.center.longitude,
    );
  }

  Future<void> _deletePoint(FreeLinePoint p) async {
    await _repo.deleteFreeLinePoint(p.id);
  }

  /// The owning layer's colour, which the element's shade is derived from.
  /// Null when the layer is not in the list this sheet was handed (it was
  /// deleted under us) — the swatch then hides itself rather than throwing
  /// inside a build.
  Color? get _layerColor {
    for (final l in widget.layers) {
      if (l.id == widget.freeLine.layerId) return Color(l.colorArgb);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final armed = ref.watch(freeLinePlacementProvider);
    final centerArmed = ref.watch(freeLineCenterPlacementProvider);
    final id = widget.freeLine.id;
    final lineLayers = widget.layers
        .where((l) => l.type == 'freeline')
        .toList();

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.polyline, size: 18),
            const SizedBox(width: 8),
            Text(
              'Edit freehand line',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 12),
            // The layer picker takes the slack and ellipsises: a layer named
            // after an imported border ("Ludwigsvorstadt-Isarvorstadt") is
            // far longer than this row is wide.
            EditorLayerPicker(
              layers: lineLayers,
              selectedId: widget.freeLine.layerId,
              onChanged: (v) =>
                  _repo.updateFreeLine(widget.freeLine.id, layerId: v),
            ),
            ElementColorButton(
              kind: ColoredElement.freeLine,
              id: widget.freeLine.id,
              title: widget.freeLine.label?.trim().isNotEmpty == true
                  ? widget.freeLine.label!.trim()
                  : 'Line',
              colorArgb: widget.freeLine.colorArgb,
              colorShade: widget.freeLine.colorShade,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: 'Delete line',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () async {
                await _repo.deleteFreeLine(id);
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
        Text(
          'Fills one half of an inclusion circle, split by the drawn line. '
          'Use the layer’s Invert to fill the other half. Set the circle’s '
          'radius below and move its centre by tapping the map.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: scaledPx(context, 220)),
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
        const SizedBox(height: 8),
        // Wrap rather than Row: two labelled buttons do not fit side by side
        // at a large system font, and a Row would silently clip the second.
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: widget.onAddPoint,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add point'),
            ),
            TextButton.icon(
              onPressed: _armCenter,
              icon: Icon(centerArmed ? Icons.adjust : Icons.adjust_outlined),
              style: centerArmed
                  ? TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              label: const Text('Move centre'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _radius,
                decoration: const InputDecoration(
                  labelText: 'Inclusion radius (m)',
                  helperText: 'Circle the line splits in two',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (s) {
                  final n = parseDecimal(s);
                  if (n != null && n.isFinite && n > 0) _setRadius(n);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: scaledPx(context, 130),
              child: TextField(
                controller: _offset,
                decoration: const InputDecoration(
                  labelText: 'Offset (m)',
                  helperText: '+ away, − past',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (s) {
                  final n = parseDecimal(s);
                  if (n != null && n.isFinite) {
                    _repo.updateFreeLine(id, offsetMeters: n);
                  }
                },
              ),
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
            _repo.updateFreeLine(id, label: Value(t.isEmpty ? null : t));
          },
        ),
      ],
    );
  }

  Widget _pointRow(FreeLinePoint p, int index, bool armed) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctlFor(p),
            focusNode: _focusFor(p.id),
            decoration: InputDecoration(
              labelText: 'Point ${index + 1} (lat, lng)',
              hintText: '48.137154, 11.575382',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            onChanged: (s) {
              final ll = parseLatLng(s);
              if (ll != null) {
                _repo.updateFreeLinePoint(
                  p.id,
                  lat: ll.latitude,
                  lng: ll.longitude,
                );
              }
            },
          ),
        ),
        IconButton(
          tooltip: 'Move point ${index + 1} by tapping the map',
          icon: Icon(armed ? Icons.touch_app : Icons.touch_app_outlined),
          color: armed ? Theme.of(context).colorScheme.primary : null,
          onPressed: () => _armPlacement(p.id, index),
        ),
        PopupMenuButton<String>(
          tooltip: 'Point ${index + 1} options',
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'up',
              enabled: index > 0,
              child: const Row(
                children: [
                  Icon(Icons.arrow_upward, size: 18),
                  SizedBox(width: 8),
                  Text('Move up'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'down',
              enabled: index < widget.points.length - 1,
              child: const Row(
                children: [
                  Icon(Icons.arrow_downward, size: 18),
                  SizedBox(width: 8),
                  Text('Move down'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'remove',
              // Keep at least two points so the line still divides the view.
              enabled: widget.points.length > 2,
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
              case 'up':
                _repo.swapFreeLinePointOrder(p.id, widget.points[index - 1].id);
              case 'down':
                _repo.swapFreeLinePointOrder(p.id, widget.points[index + 1].id);
              case 'remove':
                _deletePoint(p);
            }
          },
        ),
      ],
    );
  }

  void _close() {
    ref.read(freeLinePlacementProvider.notifier).arm(null);
    ref.read(selectedFreeLineProvider.notifier).select(null);
  }
}
