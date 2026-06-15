import 'package:flutter/material.dart';

import '../data/overpass.dart';

/// The user's choices from the POI import dialog.
class PoiImportConfig {
  const PoiImportConfig({
    required this.category,
    required this.searchRadiusMeters,
    this.circleRadiusMeters,
  });

  /// Which POI category to fetch.
  final PoiCategory category;

  /// How far from the map centre to pull POIs.
  final double searchRadiusMeters;

  /// For circle layers: the radius of each created circle. Null otherwise.
  final double? circleRadiusMeters;
}

/// Asks for a POI category + search radius (and, when [needsCircleRadius], a
/// per-circle radius). Returns null if cancelled.
Future<PoiImportConfig?> showPoiImportDialog(
  BuildContext context, {
  required bool needsCircleRadius,
}) {
  return showDialog<PoiImportConfig>(
    context: context,
    builder: (context) => _PoiImportDialog(needsCircleRadius: needsCircleRadius),
  );
}

class _PoiImportDialog extends StatefulWidget {
  const _PoiImportDialog({required this.needsCircleRadius});

  final bool needsCircleRadius;

  @override
  State<_PoiImportDialog> createState() => _PoiImportDialogState();
}

class _PoiImportDialogState extends State<_PoiImportDialog> {
  final _formKey = GlobalKey<FormState>();
  PoiCategory _category = seedablePoiCategories.first;
  final _searchRadius = TextEditingController(text: '1000');
  final _circleRadius = TextEditingController(text: '100');

  @override
  void dispose() {
    _searchRadius.dispose();
    _circleRadius.dispose();
    super.dispose();
  }

  String? _validateMeters(String? v, {required double max}) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null || !n.isFinite || n <= 0) return 'Enter metres > 0';
    if (n > max) return 'Max ${max.round()} m';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PoiImportConfig(
        category: _category,
        searchRadiusMeters: double.parse(_searchRadius.text.trim()),
        circleRadiusMeters: widget.needsCircleRadius
            ? double.parse(_circleRadius.text.trim())
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import nearby POIs'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<PoiCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in seedablePoiCategories)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _searchRadius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Search radius (m)',
                helperText: 'Around the map centre',
              ),
              validator: (v) => _validateMeters(v, max: 25000),
            ),
            if (widget.needsCircleRadius) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _circleRadius,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Circle radius (m)',
                  helperText: 'Radius of each created circle',
                ),
                validator: (v) => _validateMeters(v, max: 100000),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Import')),
      ],
    );
  }
}
