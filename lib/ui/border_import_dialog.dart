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
///
/// A **bottom sheet over the live map** for the same reason as
/// [TransitImportSheet]: the box is a thing on the ground, and it is worth
/// seeing here more than anywhere — the copy below has to warn in words that
/// an imported area can reach well past the box, which is far easier to
/// believe with the box drawn. [onPreview] reports it on every edit, null
/// while it is unusable.
///
/// Calls [onDone] exactly once — with the config, or null when cancelled.
class BorderImportSheet extends StatefulWidget {
  const BorderImportSheet({
    super.key,
    required this.initial,
    required this.level,
    required this.onPreview,
    required this.onDone,
  });

  final LatLngBounds initial;
  final BorderLevel level;
  final ValueChanged<LatLngBounds?> onPreview;
  final ValueChanged<BorderImportConfig?> onDone;

  @override
  State<BorderImportSheet> createState() => _BorderImportSheetState();
}

class _BorderImportSheetState extends State<BorderImportSheet> {
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
      c.addListener(_boxChanged);
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onPreview(_boxOrNull()));
  }

  void _boxChanged() {
    setState(() {});
    widget.onPreview(_boxOrNull());
  }

  /// The box as typed, or null while it is not a usable one — the same
  /// "usable" [checkBorderBbox] means, so the map stops drawing a box exactly
  /// when the sheet stops accepting one.
  LatLngBounds? _boxOrNull() {
    final s = _v(_south), w = _v(_west), n = _v(_north), e = _v(_east);
    if (s == null || w == null || n == null || e == null) return null;
    if (![s, w, n, e].every((v) => v.isFinite)) return null;
    if (s >= n || w >= e) return null;
    return LatLngBounds(LatLng(s, w), LatLng(n, e));
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
    _v(_south),
    _v(_west),
    _v(_north),
    _v(_east),
    level: widget.level,
  );

  bool get _canImport =>
      _verdict == BorderBboxVerdict.ok || _verdict == BorderBboxVerdict.warn;

  void _submit() {
    if (!_canImport) return;
    widget.onDone(
      BorderImportConfig(
        south: _v(_south)!,
        west: _v(_west)!,
        north: _v(_north)!,
        east: _v(_east)!,
      ),
    );
  }

  Widget _coord(TextEditingController c, String label, bool isLat) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
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
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Import borders',
                        style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.onDone(null),
                  ),
                ],
              ),
              Text('Area', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(
                children: [
                  _coord(_south, 'South', true),
                  const SizedBox(width: 8),
                  _coord(_north, 'North', true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _coord(_west, 'West', false),
                  const SizedBox(width: 8),
                  _coord(_east, 'East', false),
                ],
              ),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => widget.onDone(null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canImport ? _submit : null,
                    child: const Text('Import'),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
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
      return Text(
        'Enter four numbers to define the area.',
        style: _errStyle(theme),
      );
    }
    if (s >= n || w >= e) {
      return Text(
        'South must be below north, and west below east.',
        style: _errStyle(theme),
      );
    }
    final width = geoDistance.as(LengthUnit.Meter, LatLng(s, w), LatLng(s, e));
    final height = geoDistance.as(LengthUnit.Meter, LatLng(s, w), LatLng(n, w));
    return Text(
      '${formatMeters(width)} × ${formatMeters(height)}',
      style: theme.textTheme.bodySmall,
    );
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
        return Text(
          'Importing ${level.label.toLowerCase()}.',
          style: theme.textTheme.bodySmall,
        );
      case BorderBboxVerdict.malformed:
      case BorderBboxVerdict.misordered:
        return const SizedBox.shrink();
    }
  }
}
