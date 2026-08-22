import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/database.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'element_color_dialog.dart';

/// Docked bottom-sheet editor for a plane ("closer to one of two points").
/// Like the circle editor it sits below the interactive map and writes every
/// change live. Points A and B can be typed in or placed by tapping the map
/// (via the "Move A"/"Move B" buttons, which arm [planePlacementProvider]).
class PlaneEditorSheet extends ConsumerStatefulWidget {
  const PlaneEditorSheet({
    super.key,
    required this.plane,
    required this.layers,
  });

  final Plane plane;
  final List<Layer> layers;

  @override
  ConsumerState<PlaneEditorSheet> createState() => _PlaneEditorSheetState();
}

class _PlaneEditorSheetState extends ConsumerState<PlaneEditorSheet> {
  late final TextEditingController _a;
  late final TextEditingController _b;
  late final TextEditingController _label;
  final _aFocus = FocusNode();
  final _bFocus = FocusNode();

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    final p = widget.plane;
    _a = TextEditingController(text: formatLatLng(p.aLat, p.aLng));
    _b = TextEditingController(text: formatLatLng(p.bLat, p.bLng));
    _label = TextEditingController(text: p.label ?? '');
  }

  @override
  void didUpdateWidget(PlaneEditorSheet old) {
    super.didUpdateWidget(old);
    // Reflect external changes (e.g. placing a point by map tap) in the field,
    // but never while the user is editing it.
    _syncIfUnfocused(_a, _aFocus, widget.plane.aLat, widget.plane.aLng);
    _syncIfUnfocused(_b, _bFocus, widget.plane.bLat, widget.plane.bLng);
  }

  void _syncIfUnfocused(
    TextEditingController c,
    FocusNode f,
    double lat,
    double lng,
  ) {
    if (f.hasFocus) return;
    final target = formatLatLng(lat, lng);
    if (c.text != target) c.text = target;
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _label.dispose();
    _aFocus.dispose();
    _bFocus.dispose();
    super.dispose();
  }

  void _armPlacement(String point) {
    ref.read(planePlacementProvider.notifier).arm(point);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Tap the map to place point $point')),
      );
  }

  /// The layers this plane can be moved to — see the note in `circle_editor`:
  /// these two pickers were the only unfiltered ones.
  List<Layer> get _planeLayers =>
      widget.layers.where((l) => l.type == 'planes').toList();

  /// The owning layer's colour, which the element's shade is derived from.
  /// Null when the layer is not in the list this sheet was handed (it was
  /// deleted under us) — the swatch then hides itself rather than throwing
  /// inside a build.
  Color? get _layerColor {
    for (final l in widget.layers) {
      if (l.id == widget.plane.layerId) return Color(l.colorArgb);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final armed = ref.watch(planePlacementProvider);
    final id = widget.plane.id;

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.change_history, size: 18),
            const SizedBox(width: 8),
            Text('Edit plane', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            ElementColorButton(
              kind: ColoredElement.plane,
              id: widget.plane.id,
              title: widget.plane.label?.trim().isNotEmpty == true
                  ? widget.plane.label!.trim()
                  : 'Plane',
              colorArgb: widget.plane.colorArgb,
              colorShade: widget.plane.colorShade,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () async {
                await _repo.deletePlane(id);
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
                'Nearer side:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('A')),
                ButtonSegment(value: false, label: Text('B')),
              ],
              selected: {widget.plane.nearA},
              onSelectionChanged: (s) => _repo.updatePlane(id, nearA: s.first),
            ),
            const SizedBox(width: 8),
            // The layer picker takes the slack and ellipsises: a layer named
            // after an imported border ("Ludwigsvorstadt-Isarvorstadt") is
            // far longer than this row is wide.
            EditorLayerPicker(
              layers: _planeLayers,
              selectedId: widget.plane.layerId,
              onChanged: (v) => _repo.updatePlane(widget.plane.id, layerId: v),
            ),
          ],
        ),
        _pointRow(
          'A',
          _a,
          _aFocus,
          armed == 'A',
          (p) => _repo.updatePlane(id, aLat: p.latitude, aLng: p.longitude),
        ),
        const SizedBox(height: 8),
        _pointRow(
          'B',
          _b,
          _bFocus,
          armed == 'B',
          (p) => _repo.updatePlane(id, bLat: p.latitude, bLng: p.longitude),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            isDense: true,
          ),
          onChanged: (s) {
            final t = s.trim();
            _repo.updatePlane(id, label: Value(t.isEmpty ? null : t));
          },
        ),
      ],
    );
  }

  /// One point's single "lat, lng" field plus a "Move by map tap" button.
  Widget _pointRow(
    String point,
    TextEditingController controller,
    FocusNode focus,
    bool armed,
    void Function(LatLng) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            decoration: InputDecoration(
              labelText: '$point (lat, lng)',
              hintText: '48.137154, 11.575382',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            onChanged: (s) {
              final p = parseLatLng(s);
              if (p != null) onChanged(p);
            },
          ),
        ),
        IconButton(
          tooltip: 'Move $point by tapping the map',
          icon: Icon(armed ? Icons.touch_app : Icons.touch_app_outlined),
          color: armed ? Theme.of(context).colorScheme.primary : null,
          onPressed: () => _armPlacement(point),
        ),
      ],
    );
  }

  void _close() {
    ref.read(planePlacementProvider.notifier).arm(null);
    ref.read(selectedPlaneProvider.notifier).select(null);
  }
}
