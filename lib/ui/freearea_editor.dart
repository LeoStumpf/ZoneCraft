import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';

/// Docked bottom-sheet editor for a freehand area (closed polygon). Lists the
/// ring's ordered points — each a single "lat, lng" field with a place-by-tap
/// button and a delete — plus an add-point button, a signed offset, the layer, a
/// label and delete-object. Writes every change live while the map stays
/// interactive.
class FreeAreaEditorSheet extends ConsumerStatefulWidget {
  const FreeAreaEditorSheet({
    super.key,
    required this.freeArea,
    required this.points,
    required this.layers,
  });

  final FreeArea freeArea;

  /// The area's ring points, ordered.
  final List<FreeAreaPoint> points;
  final List<Layer> layers;

  @override
  ConsumerState<FreeAreaEditorSheet> createState() =>
      _FreeAreaEditorSheetState();
}

class _FreeAreaEditorSheetState extends ConsumerState<FreeAreaEditorSheet> {
  final Map<String, TextEditingController> _ctl = {};
  final Map<String, FocusNode> _focus = {};
  late final TextEditingController _label;
  late final TextEditingController _offset;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.freeArea.label ?? '');
    _offset =
        TextEditingController(text: widget.freeArea.offsetMeters.round().toString());
  }

  @override
  void didUpdateWidget(FreeAreaEditorSheet old) {
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
    super.dispose();
  }

  TextEditingController _ctlFor(FreeAreaPoint p) => _ctl.putIfAbsent(
        p.id,
        () => TextEditingController(text: formatLatLng(p.lat, p.lng)),
      );

  FocusNode _focusFor(String id) => _focus.putIfAbsent(id, () => FocusNode());

  void _armPlacement(String pointId, int displayIndex) {
    ref.read(freeAreaPlacementProvider.notifier).arm(pointId);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Tap the map to place point ${displayIndex + 1}')),
      );
  }

  Future<void> _addPoint() async {
    final anchor = widget.points.lastOrNull;
    final lat = anchor?.lat ?? 0.0;
    final lng = (anchor?.lng ?? 0.0) + 0.005;
    final id = await _repo.addFreeAreaPoint(
      freeAreaId: widget.freeArea.id,
      lat: lat,
      lng: lng,
    );
    if (!mounted) return;
    _armPlacement(id, widget.points.length);
  }

  Future<void> _deletePoint(FreeAreaPoint p) async {
    await _repo.deleteFreeAreaPoint(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final armed = ref.watch(freeAreaPlacementProvider);
    final id = widget.freeArea.id;
    final areaLayers = widget.layers.where((l) => l.type == 'freearea').toList();

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
                  const Icon(Icons.hexagon_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit freehand area',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  DropdownButton<String>(
                    value: areaLayers.any((l) => l.id == widget.freeArea.layerId)
                        ? widget.freeArea.layerId
                        : null,
                    hint: const Text('Layer'),
                    items: [
                      for (final l in areaLayers)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) _repo.updateFreeArea(id, layerId: v);
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete area',
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () async {
                      await _repo.deleteFreeArea(id);
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
                'Fills the inside of the drawn shape. Use the layer’s Invert to '
                'fill the outside instead.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
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
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _addPoint,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add point'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _offset,
                      decoration: const InputDecoration(
                        labelText: 'Offset (m)',
                        helperText: '+ inward, − outward',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      onChanged: (s) {
                        final n = double.tryParse(s);
                        if (n != null && n.isFinite) {
                          _repo.updateFreeArea(id, offsetMeters: n);
                        }
                      },
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Label (optional)', isDense: true),
                onChanged: (s) {
                  final t = s.trim();
                  _repo.updateFreeArea(id, label: Value(t.isEmpty ? null : t));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pointRow(FreeAreaPoint p, int index, bool armed) {
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
                decimal: true, signed: true),
            onChanged: (s) {
              final ll = parseLatLng(s);
              if (ll != null) {
                _repo.updateFreeAreaPoint(p.id,
                    lat: ll.latitude, lng: ll.longitude);
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
        IconButton(
          tooltip: 'Delete point ${index + 1}',
          icon: const Icon(Icons.remove_circle_outline),
          // Keep at least three points so the ring stays a polygon.
          onPressed: widget.points.length <= 3 ? null : () => _deletePoint(p),
        ),
      ],
    );
  }

  void _close() {
    ref.read(freeAreaPlacementProvider.notifier).arm(null);
    ref.read(selectedFreeAreaProvider.notifier).select(null);
  }
}
