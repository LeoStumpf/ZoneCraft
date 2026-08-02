import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../data/serialization.dart';
import '../state/providers.dart';
import 'import_actions.dart';

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

  /// Bumped after clearing the tile cache to re-run the size [FutureBuilder].
  int _cacheTick = 0;

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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Exports every layer + object to a file and opens the system share sheet.
  /// GeoJSON is the lossless round-trip format; KML is for Google Earth / Maps.
  Future<void> _export() async {
    final data = await _repo.exportData();
    if (!mounted) return;
    if (data.objectCount == 0) {
      _snack('Nothing to export yet');
      return;
    }
    final fmt = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Export as'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'geojson'),
            child: const Text('GeoJSON (re-importable)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'kml'),
            child: const Text('KML (Google Earth / Maps)'),
          ),
        ],
      ),
    );
    if (fmt == null) return;

    try {
      final isKml = fmt == 'kml';
      final content = isKml ? exportToKml(data) : exportToGeoJson(data);
      final stamp = DateTime.now()
          .toIso8601String()
          .split('.')
          .first
          .replaceAll(':', '-');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zonecraft-$stamp.$fmt');
      await file.writeAsString(content);
      await SharePlus.instance.share(ShareParams(
        subject: 'ZoneCraft export',
        files: [
          XFile(
            file.path,
            mimeType: isKml
                ? 'application/vnd.google-earth.kml+xml'
                : 'application/geo+json',
          ),
        ],
      ));
    } catch (e) {
      _snack('Export failed: $e');
    }
  }

  /// Picks a geometry file (ZoneCraft GeoJSON, generic GeoJSON, KML/KMZ or GPX)
  /// and imports it, asking whether to add new layers or merge into an existing
  /// one.
  Future<void> _import() async {
    final layers = ref.read(layersProvider).asData?.value ?? const <Layer>[];
    await importLayerFlow(context, _repo, layers);
  }

  Future<void> _clearTileCache() async {
    await _repo.clearTileCache();
    if (!mounted) return;
    setState(() => _cacheTick++); // refresh the size readout
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cached map tiles cleared')),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
            'A measurement-uncertainty band drawn lighter just inside every '
            "object's border, before the fill turns solid. Set to 0 to disable.",
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
          Text('Offline map cache',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Map tiles you view (and a ring around them) are stored on the '
            'device so the map keeps working briefly with no reception, and '
            "doesn't re-download areas you revisit.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FutureBuilder<int>(
            // Keyed on _cacheTick so it re-queries after a clear.
            key: ValueKey(_cacheTick),
            future: _repo.tileCacheBytes(),
            builder: (context, snap) => Text(
              'Cached map tiles: ${_formatBytes(snap.data ?? 0)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _clearTileCache,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Clear cached map tiles'),
            ),
          ),
          const Divider(height: 48),
          Text('Import & export',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Save all layers and objects to a file to share or back up. GeoJSON '
            'imports back into the app; KML is for Google Earth / Maps. Import '
            'accepts ZoneCraft GeoJSON plus generic GeoJSON, KML/KMZ and GPX, '
            'either as new layers or merged into an existing one. You can also '
            'export or import a single layer from the layers drawer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.ios_share),
                label: const Text('Export'),
              ),
              OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.file_open),
                label: const Text('Import'),
              ),
            ],
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
