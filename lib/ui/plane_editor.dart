import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../state/providers.dart';

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
  late final TextEditingController _aLat;
  late final TextEditingController _aLng;
  late final TextEditingController _bLat;
  late final TextEditingController _bLng;
  late final TextEditingController _label;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    final p = widget.plane;
    _aLat = TextEditingController(text: p.aLat.toStringAsFixed(6));
    _aLng = TextEditingController(text: p.aLng.toStringAsFixed(6));
    _bLat = TextEditingController(text: p.bLat.toStringAsFixed(6));
    _bLng = TextEditingController(text: p.bLng.toStringAsFixed(6));
    _label = TextEditingController(text: p.label ?? '');
  }

  @override
  void dispose() {
    _aLat.dispose();
    _aLng.dispose();
    _bLat.dispose();
    _bLng.dispose();
    _label.dispose();
    super.dispose();
  }

  double? _parse(String s, {required double min, required double max}) {
    final n = double.tryParse(s);
    if (n == null || !n.isFinite || n < min || n > max) return null;
    return n;
  }

  void _armPlacement(String point) {
    ref.read(planePlacementProvider.notifier).arm(point);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Tap the map to place point $point')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final armed = ref.watch(planePlacementProvider);
    final id = widget.plane.id;

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
                  const Icon(Icons.change_history, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit plane',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
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
                    child: Text('Nearer side:',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('A')),
                      ButtonSegment(value: false, label: Text('B')),
                    ],
                    selected: {widget.plane.nearA},
                    onSelectionChanged: (s) =>
                        _repo.updatePlane(id, nearA: s.first),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: widget.layers.any((l) => l.id == widget.plane.layerId)
                        ? widget.plane.layerId
                        : null,
                    hint: const Text('Layer'),
                    items: [
                      for (final l in widget.layers)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) _repo.updatePlane(id, layerId: v);
                    },
                  ),
                ],
              ),
              _pointRow('A', _aLat, _aLng, armed == 'A',
                  (lat, lng) => _repo.updatePlane(id, aLat: lat, aLng: lng)),
              const SizedBox(height: 8),
              _pointRow('B', _bLat, _bLng, armed == 'B',
                  (lat, lng) => _repo.updatePlane(id, bLat: lat, bLng: lng)),
              const SizedBox(height: 8),
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Label (optional)', isDense: true),
                onChanged: (s) {
                  final t = s.trim();
                  _repo.updatePlane(id, label: Value(t.isEmpty ? null : t));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One point's lat/lng fields plus a "Move by map tap" button.
  Widget _pointRow(
    String point,
    TextEditingController lat,
    TextEditingController lng,
    bool armed,
    void Function(double lat, double lng) onLatLng,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: lat,
            decoration: InputDecoration(
                labelText: '$point lat', isDense: true),
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            onChanged: (s) {
              final n = _parse(s, min: -90, max: 90);
              final other = double.tryParse(lng.text);
              if (n != null && other != null) onLatLng(n, other);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: lng,
            decoration: InputDecoration(
                labelText: '$point lng', isDense: true),
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            onChanged: (s) {
              final n = _parse(s, min: -180, max: 180);
              final other = double.tryParse(lat.text);
              if (n != null && other != null) onLatLng(other, n);
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
