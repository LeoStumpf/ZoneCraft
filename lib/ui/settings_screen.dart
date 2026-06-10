import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).asData?.value;
    final uncertainty = settings?.uncertaintyMeters ?? 0;

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
        ],
      ),
    );
  }
}
