import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/borders.dart';
import '../geo/coords.dart';
import 'hit_test.dart' show geoDistance;
import 'object_summary.dart' show formatMeters;
import 'transit_import_dialog.dart'
    show bboxDiagonalMeters, validateLat, validateLng;

/// The area to import borders for. The **level** isn't asked here — it belongs
/// to the layer, chosen when the layer was created, because one layer holds one
/// level (see `Layers.borderLevel`). The dialog shows it so the choice is still
/// in front of you at the moment it costs something.
class BorderImportConfig {
  const BorderImportConfig({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  double get diagonalMeters => bboxDiagonalMeters(south, west, north, east);
}

/// Whether a box is orderable, and small enough for the level being imported.
enum BorderBboxVerdict {
  ok,
  warn,

  /// Too large for this level — a coarser level means bigger boundaries, not
  /// fewer of them.
  tooLarge,

  /// Unparseable numbers.
  malformed,

  /// Parseable, but south ≥ north or west ≥ east.
  misordered,
}

/// The verdict for a box at [level]. Size alone can't decide: 110 km of states
/// is one relation and fine, while 20 km on a national border is 17 MB.
BorderBboxVerdict checkBorderBbox(
  double? south,
  double? west,
  double? north,
  double? east, {
  required BorderLevel level,
}) {
  if (south == null || west == null || north == null || east == null) {
    return BorderBboxVerdict.malformed;
  }
  if (![south, west, north, east].every((v) => v.isFinite)) {
    return BorderBboxVerdict.malformed;
  }
  if (south >= north || west >= east) return BorderBboxVerdict.misordered;
  final d = bboxDiagonalMeters(south, west, north, east);
  if (!d.isFinite) return BorderBboxVerdict.malformed;
  if (d > level.maxDiagonalMeters) return BorderBboxVerdict.tooLarge;
  if (d > level.warnDiagonalMeters) return BorderBboxVerdict.warn;
  return BorderBboxVerdict.ok;
}

/// Asks which area to import administrative areas for, at [level].
Future<BorderImportConfig?> showBorderImportDialog(
  BuildContext context, {
  required LatLngBounds initial,
  required BorderLevel level,
}) {
  return showDialog<BorderImportConfig>(
    context: context,
    builder: (_) => _BorderImportDialog(initial: initial, level: level),
  );
}

class _BorderImportDialog extends StatefulWidget {
  const _BorderImportDialog({required this.initial, required this.level});

  final LatLngBounds initial;
  final BorderLevel level;

  @override
  State<_BorderImportDialog> createState() => _BorderImportDialogState();
}

class _BorderImportDialogState extends State<_BorderImportDialog> {
  late final TextEditingController _south;
  late final TextEditingController _west;
  late final TextEditingController _north;
  late final TextEditingController _east;

  @override
  void initState() {
    super.initState();
    String f(double v) => v.toStringAsFixed(5);
    _south = TextEditingController(text: f(widget.initial.south));
    _west = TextEditingController(text: f(widget.initial.west));
    _north = TextEditingController(text: f(widget.initial.north));
    _east = TextEditingController(text: f(widget.initial.east));
    for (final c in [_south, _west, _north, _east]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_south, _west, _north, _east]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) => parseDecimal(c.text.trim());

  BorderBboxVerdict get _verdict => checkBorderBbox(
      _v(_south), _v(_west), _v(_north), _v(_east),
      level: widget.level);

  bool get _canImport =>
      _verdict == BorderBboxVerdict.ok || _verdict == BorderBboxVerdict.warn;

  void _submit() {
    if (!_canImport) return;
    Navigator.of(context).pop(BorderImportConfig(
      south: _v(_south)!,
      west: _v(_west)!,
      north: _v(_north)!,
      east: _v(_east)!,
    ));
  }

  Widget _coord(TextEditingController c, String label, bool isLat) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          errorText: isLat ? validateLat(c.text) : validateLng(c.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = widget.level;
    return AlertDialog(
      title: const Text('Import borders'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Area', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(children: [
                _coord(_south, 'South', true),
                const SizedBox(width: 8),
                _coord(_north, 'North', true),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _coord(_west, 'West', false),
                const SizedBox(width: 8),
                _coord(_east, 'East', false),
              ]),
              const SizedBox(height: 8),
              _sizeLine(theme),
              const SizedBox(height: 16),
              Text('Level', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public),
                title: Text(level.label),
                subtitle: Text(level.blurb),
              ),
              const SizedBox(height: 8),
              Text(
                'Every boundary the box touches is downloaded and kept whole, '
                'so an area can reach well past the box you drew. The box '
                'decides what gets fetched, not what you end up with.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _costLine(theme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canImport ? _submit : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  TextStyle? _errStyle(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
        fontWeight: FontWeight.w500,
      );

  TextStyle? _warnStyle(ThemeData theme) =>
      theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade800);

  /// The box's own state: unusable numbers, or its size.
  Widget _sizeLine(ThemeData theme) {
    final s = _v(_south), w = _v(_west), n = _v(_north), e = _v(_east);
    if (s == null ||
        w == null ||
        n == null ||
        e == null ||
        ![s, w, n, e].every((v) => v.isFinite)) {
      return Text('Enter four numbers to define the area.',
          style: _errStyle(theme));
    }
    if (s >= n || w >= e) {
      return Text('South must be below north, and west below east.',
          style: _errStyle(theme));
    }
    final width = geoDistance.as(LengthUnit.Meter, LatLng(s, w), LatLng(s, e));
    final height = geoDistance.as(LengthUnit.Meter, LatLng(s, w), LatLng(n, w));
    return Text('${formatMeters(width)} × ${formatMeters(height)}',
        style: theme.textTheme.bodySmall);
  }

  /// One honest line about what this box costs at this level — always naming
  /// the limit, so "too large" says what it is too large *for*.
  Widget _costLine(ThemeData theme) {
    final level = widget.level;
    switch (_verdict) {
      case BorderBboxVerdict.tooLarge:
        return Text(
          'This area is too large for ${level.label.toLowerCase()} — at most '
          '${formatMeters(level.maxDiagonalMeters)} across. Pick a smaller '
          'box, or a finer level on a new layer.',
          style: _errStyle(theme),
        );
      case BorderBboxVerdict.warn:
        return Text(
          'A big box for ${level.label.toLowerCase()} — this may take a '
          'minute, or come back busy. A smaller area is quicker.',
          style: _warnStyle(theme),
        );
      case BorderBboxVerdict.ok:
        return Text('Importing ${level.label.toLowerCase()}.',
            style: theme.textTheme.bodySmall);
      case BorderBboxVerdict.malformed:
      case BorderBboxVerdict.misordered:
        return const SizedBox.shrink();
    }
  }
}
