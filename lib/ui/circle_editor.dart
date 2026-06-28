import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';

/// Docked bottom-sheet editor for a circle. Unlike a dialog, this sits below the
/// map (which stays interactive) and applies every change live to the database,
/// so the map updates as you edit. Close just deselects; delete removes the
/// circle.
class CircleEditorSheet extends ConsumerStatefulWidget {
  const CircleEditorSheet({
    super.key,
    required this.circle,
    required this.layers,
  });

  final Circle circle;
  final List<Layer> layers;

  @override
  ConsumerState<CircleEditorSheet> createState() => _CircleEditorSheetState();
}

class _CircleEditorSheetState extends ConsumerState<CircleEditorSheet> {
  // Radius slider works on a log scale so both small and huge radii are usable.
  static const _minRadius = 10.0;
  static const _maxRadius = 1000000.0;

  late final TextEditingController _center;
  final FocusNode _centerFocus = FocusNode();
  late final TextEditingController _label;
  late double _radius;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    final c = widget.circle;
    _center =
        TextEditingController(text: formatLatLng(c.centerLat, c.centerLng));
    _label = TextEditingController(text: c.label ?? '');
    _radius = c.radiusMeters;
  }

  @override
  void didUpdateWidget(CircleEditorSheet old) {
    super.didUpdateWidget(old);
    // Keep the centre field in sync when the centre is moved by tapping the map.
    if (!_centerFocus.hasFocus) {
      final t = formatLatLng(widget.circle.centerLat, widget.circle.centerLng);
      if (_center.text != t) _center.text = t;
    }
    if (widget.circle.radiusMeters != _radius) {
      _radius = widget.circle.radiusMeters;
    }
  }

  @override
  void dispose() {
    _center.dispose();
    _centerFocus.dispose();
    _label.dispose();
    super.dispose();
  }

  void _armPlacement() {
    ref.read(circlePlacementProvider.notifier).arm(true);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Tap the map to place the centre')),
      );
  }

  void _close() {
    ref.read(circlePlacementProvider.notifier).arm(false);
    ref.read(selectedCircleProvider.notifier).select(null);
  }

  void _setRadius(double meters) {
    setState(() => _radius = meters);
    _repo.updateCircle(widget.circle.id, radiusMeters: meters);
  }

  String _radiusLabel(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1)} km' : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    final armed = ref.watch(circlePlacementProvider);
    final sliderValue =
        (math.log(_radius.clamp(_minRadius, _maxRadius)) / math.ln10)
            .clamp(math.log(_minRadius) / math.ln10, math.log(_maxRadius) / math.ln10);

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
                  const Icon(Icons.circle_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit circle',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () async {
                      await _repo.deleteCircle(widget.circle.id);
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
                  Expanded(child: Text('Radius: ${_radiusLabel(_radius)}')),
                  DropdownButton<String>(
                    value: widget.layers.any((l) => l.id == widget.circle.layerId)
                        ? widget.circle.layerId
                        : null,
                    hint: const Text('Layer'),
                    items: [
                      for (final l in widget.layers)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _repo.updateCircle(widget.circle.id, layerId: v);
                      }
                    },
                  ),
                ],
              ),
              Slider(
                min: math.log(_minRadius) / math.ln10,
                max: math.log(_maxRadius) / math.ln10,
                value: sliderValue.toDouble(),
                onChanged: (v) => _setRadius(math.pow(10, v).toDouble()),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _center,
                      focusNode: _centerFocus,
                      decoration: const InputDecoration(
                        labelText: 'Centre (lat, lng)',
                        hintText: '48.137154, 11.575382',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      onChanged: (s) {
                        final p = parseLatLng(s);
                        if (p != null) {
                          _repo.updateCircle(widget.circle.id,
                              centerLat: p.latitude, centerLng: p.longitude);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move centre by tapping the map',
                    icon: Icon(
                        armed ? Icons.touch_app : Icons.touch_app_outlined),
                    color:
                        armed ? Theme.of(context).colorScheme.primary : null,
                    onPressed: _armPlacement,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Label (optional)', isDense: true),
                onChanged: (s) {
                  final t = s.trim();
                  _repo.updateCircle(widget.circle.id,
                      label: Value(t.isEmpty ? null : t));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
