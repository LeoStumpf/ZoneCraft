// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../data/service_overrides.dart';
import '../data/tile_source.dart';
import '../geo/coords.dart';
import '../state/providers.dart';
import 'about_screen.dart';
import 'import_actions.dart';
import 'share_place.dart';

/// App-wide settings. Currently just the global uncertainty radius, applied as
/// a lighter band on every object's outer edge by the rendering engine.
///
/// Writes persist live via [Repository.updateUncertainty]; the map re-renders
/// because the engine watches [settingsProvider].
/// What the "Clear all data?" dialog came back with.
enum _ClearChoice { cancel, exportFirst, clear }

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

  /// Forgets every tip and switches them back on. The effect is invisible
  /// until the next button press, so it says so.
  Future<void> _resetTips() async {
    final messenger = ScaffoldMessenger.of(context);
    await _repo.resetHints();
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Tips will be shown again')));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _setUncertainty(double meters) {
    final clamped = meters.isFinite && meters >= 0 ? meters : 0.0;
    unawaited(_repo.updateUncertainty(clamped));
  }

  Future<void> _clearAllData() async {
    // A three-way answer, not a nullable bool: dismissing the dialog with the
    // back button also returns null, so "Export first" needs a value of its
    // own or a stray back press would start an export.
    final choice = await showDialog<_ClearChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This deletes every layer and object, empties your OpenStreetMap '
          'outbox and resets all settings. This cannot be undone. Reports you '
          'have already sent stay on OpenStreetMap — only this device\u2019s '
          'record of them goes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ClearChoice.cancel),
            child: const Text('Cancel'),
          ),
          // There is no backup to fall back on — Auto Backup is off (see the
          // AndroidManifest comment) and there is no account and no server. So
          // the way out has to be offered here, at the one moment the user is
          // about to lose everything, rather than left in a section of Settings
          // they have no reason to be reading.
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ClearChoice.exportFirst),
            child: const Text('Export first'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _ClearChoice.clear),
            child: const Text('Clear all data'),
          ),
        ],
      ),
    );
    if (choice == _ClearChoice.exportFirst) {
      await _export();
      return;
    }
    if (choice != _ClearChoice.clear) return;

    // Drop any selection that points at a now-deleted object before the wipe.
    ref.read(selectedCircleProvider.notifier).select(null);
    ref.read(activeLayerProvider.notifier).select(null);
    await _repo.clearAll();
    if (!mounted) return;
    // Resync the local field with the reset (default) uncertainty.
    _initialised = false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All data cleared')));
  }

  /// Exports every layer + object to a file and opens the system share sheet.
  /// GeoJSON is the lossless round-trip format; KML is for Google Earth / Maps.
  /// Parses a pasted position and hands it to the map, which is the only
  /// place that can show it. Closes Settings on success so the answer is
  /// visible immediately rather than behind this screen.
  Future<void> _pastePlace() async {
    final point = await showPastePlaceDialog(context);
    if (point == null || !mounted) return;
    ref.read(receivedPointProvider.notifier).receive(point);
    Navigator.of(context).pop();
  }

  Future<void> _export() => exportAllFlow(context, _repo);

  /// Picks a geometry file (ZoneCraft GeoJSON, generic GeoJSON, KML/KMZ or GPX)
  /// and imports it, asking whether to add new layers or merge into an existing
  /// one.
  Future<void> _import() async {
    final layers = ref.read(layersProvider).asData?.value ?? const <Layer>[];
    // Deliberately no `ref:` — and so no map preview. Settings is a full-screen
    // route *over* the map, so a preview drawn there would be invisible and its
    // Keep/Discard bar unreachable, which would not be a worse preview but a
    // hang. The same import from the layers drawer sits over the map and does
    // preview; this route stays the direct one.
    await importLayerFlow(context, _repo, layers);
  }

  Future<void> _clearTileCache() async {
    await _repo.clearTileCache();
    if (!mounted) return;
    setState(() => _cacheTick++); // refresh the size readout
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cached map tiles cleared')));
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (s) {
                    final n = parseDecimal(s);
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
          Text(
            'Offline map cache',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            TileSource.configured.allowsPrefetch
                ? 'Map tiles you view (and a ring around them) are stored on '
                      'the device so the map keeps working briefly with no '
                      "reception, and doesn't re-download areas you revisit."
                : 'Map tiles you view are stored on the device, so revisiting '
                      'an area works without re-downloading it — including with '
                      'no reception. Tiles are never fetched ahead of what you '
                      "are looking at: OpenStreetMap's tile policy does not "
                      'permit it.',
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
          Text(
            'Import & export',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Save all layers and objects to a file to share or back up. GeoJSON '
            'imports back into the app; KML is for Google Earth / Maps. Import '
            'accepts ZoneCraft GeoJSON plus generic GeoJSON, KML/KMZ and GPX, '
            'either as new layers or merged into an existing one. You can also '
            'export or import a single layer from the layers drawer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // Said plainly, because nothing else in the app will say it and the
          // consequence is total. There is no account, no sync and no device
          // backup: exporting is the only copy that survives this phone.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your map is stored only on this phone. It is not backed up '
                  'to Google, and uninstalling ZoneCraft or losing the phone '
                  'takes it with them \u2014 an export is the only copy that '
                  'survives. Keep one somewhere safe.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
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
          Text('Shared places', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Someone sent you a position? Paste their message here — a '
            'zonecraft:// link, a map link, or just the coordinates with the '
            'chat around them. Long-press anywhere on the map to share a place '
            'back, or use the share button for where you are.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _pastePlace,
              icon: const Icon(Icons.content_paste_go),
              label: const Text('Paste coordinates'),
            ),
          ),
          const Divider(height: 48),
          _TipsSection(
            enabled:
                ref.watch(settingsProvider).asData?.value.hintsEnabled ?? true,
            onEnabled: (v) => unawaited(_repo.updateHintsEnabled(enabled: v)),
            onReset: () => unawaited(_resetTips()),
          ),
          const Divider(height: 48),
          _DataSourcesSection(
            settings: ref.watch(settingsProvider).asData?.value,
            onSave: (which, value) =>
                unawaited(_repo.updateServiceOverride(which, value)),
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
          const Divider(height: 48),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('About ZoneCraft'),
            subtitle: const Text(
              'Version, the services it contacts, and what it deliberately '
              'will not do',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three service addresses, folded away.
///
/// Collapsed on purpose: this is an escape hatch, not a setup step. The app
/// works with every field empty, and an empty field is a real answer — "use
/// what the build shipped with" — which is why each one shows the default it is
/// standing in for rather than looking unset.
class _DataSourcesSection extends StatelessWidget {
  const _DataSourcesSection({required this.settings, required this.onSave});

  final AppSetting? settings;
  final void Function(ServiceOverride which, String? value) onSave;

  String? _valueOf(ServiceOverride which) => switch (which) {
    ServiceOverride.tiles => settings?.tileUrlOverride,
    ServiceOverride.overpass => settings?.overpassEndpointOverride,
    ServiceOverride.nominatim => settings?.nominatimHostOverride,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final set = ServiceOverride.values.where((w) => _valueOf(w) != null).length;
    return Theme(
      // The tile sits in a plain column of sections, not a card list.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.dns_outlined),
        title: Text('Data sources', style: theme.textTheme.titleMedium),
        subtitle: Text(
          set == 0
              ? 'Point the app at your own map, import or search server'
              : '$set of 3 changed from the default',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'ZoneCraft borrows three services that other people pay to run. '
              'Leave these empty unless you host your own — the app works as '
              'it is, and every request it makes is one you asked for.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final which in ServiceOverride.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ServiceOverrideField(
                which: which,
                // Rebuilt from scratch when the stored value changes under it
                // (a Clear all data, say), which a controller seeded once in
                // initState would otherwise ignore.
                key: ValueKey('${which.name}:${_valueOf(which)}'),
                initialValue: _valueOf(which),
                onSave: (v) => onSave(which, v),
              ),
            ),
        ],
      ),
    );
  }
}

/// One address field: validates on the way out, saves on submit or focus loss.
class _ServiceOverrideField extends StatefulWidget {
  const _ServiceOverrideField({
    required this.which,
    required this.initialValue,
    required this.onSave,
    super.key,
  });

  final ServiceOverride which;
  final String? initialValue;
  final ValueChanged<String?> onSave;

  @override
  State<_ServiceOverrideField> createState() => _ServiceOverrideFieldState();
}

class _ServiceOverrideFieldState extends State<_ServiceOverrideField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);
  String? _error;

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _save();
  }

  void _save() {
    final text = _controller.text;
    final error = widget.which.validate(text);
    setState(() => _error = error);
    // A rejected value is left in the field to be fixed rather than discarded,
    // but it is never written: a half-typed host would fail every request with
    // no sign of why.
    if (error == null) widget.onSave(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          // The clear button appears and the stale error clears as you type;
          // without this the field only catches up on submit.
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: widget.which.label,
            hintText: widget.which.hint,
            errorText: _error,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Use the default',
                    icon: const Icon(Icons.backspace_outlined),
                    onPressed: () {
                      _controller.clear();
                      _save();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(widget.which.help, style: theme.textTheme.bodySmall),
        Text(
          'Default: ${widget.which.builtInDefault}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Whether the map explains its own buttons, and a way to start over.
///
/// The map answers a pressed switch with a line saying what is now true, and
/// each of those falls silent after a few showings. That is a guess about one
/// person's patience, so both ends are here: stop them now without waiting the
/// showings out, or hand them all back — for someone returning after a long
/// time, or showing the app to somebody else.
class _TipsSection extends StatelessWidget {
  const _TipsSection({
    required this.enabled,
    required this.onEnabled,
    required this.onReset,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tips', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'The map\u2019s buttons are icons without labels. Pressing one of the '
          'layer switches answers with a line saying what is now true \u2014 a '
          'few times each, then it stops. “What the buttons do” in the layers '
          'menu explains all of them at any time.',
          style: theme.textTheme.bodySmall,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Explain what buttons do'),
          subtitle: const Text('Turn off to stop the tips now'),
          value: enabled,
          onChanged: onEnabled,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Show all tips again'),
          ),
        ),
      ],
    );
  }
}
