import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../state/providers.dart';

/// Opens a dialog to edit (or delete) an existing [circle].
Future<void> showCircleEditor(
  BuildContext context, {
  required Circle circle,
  required List<Layer> layers,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CircleEditorDialog(circle: circle, layers: layers),
  );
}

class _CircleEditorDialog extends ConsumerStatefulWidget {
  const _CircleEditorDialog({required this.circle, required this.layers});

  final Circle circle;
  final List<Layer> layers;

  @override
  ConsumerState<_CircleEditorDialog> createState() =>
      _CircleEditorDialogState();
}

class _CircleEditorDialogState extends ConsumerState<_CircleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  late final TextEditingController _label;
  late String _layerId;

  @override
  void initState() {
    super.initState();
    final c = widget.circle;
    _lat = TextEditingController(text: c.centerLat.toStringAsFixed(6));
    _lng = TextEditingController(text: c.centerLng.toStringAsFixed(6));
    _radius = TextEditingController(text: c.radiusMeters.toStringAsFixed(0));
    _label = TextEditingController(text: c.label ?? '');
    _layerId = c.layerId;
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final labelText = _label.text.trim();
    await ref.read(repositoryProvider).updateCircle(
          widget.circle.id,
          centerLat: double.parse(_lat.text),
          centerLng: double.parse(_lng.text),
          radiusMeters: double.parse(_radius.text),
          layerId: _layerId,
          label: Value(labelText.isEmpty ? null : labelText),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await ref.read(repositoryProvider).deleteCircle(widget.circle.id);
    if (mounted) Navigator.of(context).pop();
  }

  String? _validateNum(String? v, {double? min, double? max}) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null || !n.isFinite) return 'Not a number';
    if (min != null && n < min) return '≥ $min';
    if (max != null && n > max) return '≤ $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit circle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _layerId,
                decoration: const InputDecoration(labelText: 'Layer'),
                items: [
                  for (final l in widget.layers)
                    DropdownMenuItem(value: l.id, child: Text(l.name)),
                ],
                onChanged: (v) => setState(() => _layerId = v ?? _layerId),
              ),
              TextFormField(
                controller: _lat,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                validator: (v) => _validateNum(v, min: -90, max: 90),
              ),
              TextFormField(
                controller: _lng,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                validator: (v) => _validateNum(v, min: -180, max: 180),
              ),
              TextFormField(
                controller: _radius,
                decoration:
                    const InputDecoration(labelText: 'Radius (metres)'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                validator: (v) => _validateNum(v, min: 0.001),
              ),
              TextFormField(
                controller: _label,
                decoration:
                    const InputDecoration(labelText: 'Label (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _delete,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
