import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/overpass.dart';
import '../data/repository.dart';
import '../state/providers.dart';

/// App-wide settings. Currently just the global uncertainty radius, applied as
/// a lighter band on every object's outer edge by the rendering engine.
///
/// Writes persist live via [Repository.updateUncertainty]; the map re-renders
/// because the engine watches [settingsProvider].
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Slider range for the uncertainty radius. The text field accepts any
  // non-negative value; the slider clamps to this range for usable resolution.
  static const _maxSlider = 2000.0;

  final _field = TextEditingController();
  bool _initialised = false;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _setUncertainty(double meters) {
    final clamped = meters.isFinite && meters >= 0 ? meters : 0.0;
    _repo.updateUncertainty(clamped);
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This deletes every layer and object and resets all settings. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all data'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Drop any selection that points at a now-deleted object before the wipe.
    ref.read(selectedCircleProvider.notifier).select(null);
    ref.read(selectedPlaneProvider.notifier).select(null);
    ref.read(activeLayerProvider.notifier).select(null);
    await _repo.clearAll();
    if (!mounted) return;
    // Resync the local field with the reset (default) uncertainty.
    _initialised = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).asData?.value;
    final uncertainty = settings?.uncertaintyMeters ?? 0;
    final transportOverlay = settings?.transportOverlay ?? false;
    final poiMask = settings?.poiCategories ?? 0;

    // Seed the text field once from the persisted value; afterwards the field
    // is the source of truth while editing (don't fight the user's cursor).
    if (!_initialised && settings != null) {
      _field.text = uncertainty.round().toString();
      _initialised = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Uncertainty', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'A measurement-uncertainty band drawn lighter on the outer edge of '
            'every object. Set to 0 to disable.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Radius: ${uncertainty.round()} m',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _field,
                  decoration: const InputDecoration(
                    labelText: 'Metres',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (s) {
                    final n = double.tryParse(s);
                    if (n != null && n.isFinite && n >= 0) {
                      _setUncertainty(n);
                    }
                  },
                ),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: _maxSlider,
            divisions: 200,
            value: uncertainty.clamp(0, _maxSlider).toDouble(),
            label: '${uncertainty.round()} m',
            onChanged: (v) {
              _field.text = v.round().toString();
              _setUncertainty(v);
            },
          ),
          const Divider(height: 48),
          Text('Map overlays', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Show the public-transport network on top of the map: bus/tram '
            'lines and stops (ÖPNVKarte) plus railways (OpenRailwayMap).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Public transport'),
            value: transportOverlay,
            onChanged: settings == null
                ? null
                : (v) => _repo.updateTransportOverlay(v),
          ),
          const Divider(height: 48),
          Text('Map points of interest',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Show OSM points of interest as markers — only when zoomed in, to '
            'match OSMAnd. Fetched from the Overpass API.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          for (final c in poiCategories)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(c.label),
              value: poiMask & c.bit != 0,
              onChanged: settings == null
                  ? null
                  : (v) => _repo
                      .updatePoiCategories(poiMaskWith(poiMask, c, v ?? false)),
            ),
          const Divider(height: 48),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Delete every layer and object and reset all settings to their '
            'defaults.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _clearAllData,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear all data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
