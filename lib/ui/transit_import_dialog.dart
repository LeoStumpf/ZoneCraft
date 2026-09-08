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

import '../data/transit.dart';
import '../geo/coords.dart';
import 'hit_test.dart' show geoDistance;
import 'object_summary.dart' show formatMeters;

/// The area to import, and which station types to fetch for it.
///
/// The types are a choice about the **query**, not about display: what isn't
/// imported isn't stored, and showing it later would mean importing again. The
/// dialog pre-ticks [recommendedImportModes] for the box, so the common path is
/// still "confirm and go".
class TransitImportConfig {
  const TransitImportConfig({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.modeMask,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  /// Which modes to fetch (packed [TransitMode.bit]s).
  final int modeMask;

  double get diagonalMeters => bboxDiagonalMeters(south, west, north, east);
}

/// Bbox validation, pulled out of the widget so it is testable without a
/// widget test.
String? validateLat(String? v) {
  final n = parseDecimal((v ?? '').trim());
  if (n == null || !n.isFinite) return 'Number';
  if (n < -90 || n > 90) return '−90…90';
  return null;
}

String? validateLng(String? v) {
  final n = parseDecimal((v ?? '').trim());
  if (n == null || !n.isFinite) return 'Number';
  if (n < -180 || n > 180) return '−180…180';
  return null;
}

/// The diagonal of a box, in metres.
double bboxDiagonalMeters(
  double south,
  double west,
  double north,
  double east,
) {
  return geoDistance.as(
    LengthUnit.Meter,
    LatLng(south, west),
    LatLng(north, east),
  );
}

/// Whether a box is orderable, and small enough for the types being imported.
enum BboxVerdict {
  ok,
  warn,

  /// Too large **for the ticked types** — untick the dense ones, or shrink it.
  tooLarge,

  /// Unparseable numbers.
  malformed,

  /// Parseable, but south ≥ north or west ≥ east.
  misordered,

  /// Nothing ticked: there is no import to make.
  noModes,
}

/// The verdict for a box **given what is ticked**: a 500 km box is fine for
/// trains and impossible for buses, so the size alone cannot decide.
BboxVerdict checkBbox(
  double? south,
  double? west,
  double? north,
  double? east, {
  int modeMask = -1,
}) {
  if (south == null || west == null || north == null || east == null) {
    return BboxVerdict.malformed;
  }
  if (![south, west, north, east].every((v) => v.isFinite)) {
    return BboxVerdict.malformed;
  }
  if (south >= north || west >= east) return BboxVerdict.misordered;
  final d = bboxDiagonalMeters(south, west, north, east);
  if (!d.isFinite) return BboxVerdict.malformed;
  if (modeMask & transitAllModesMask == 0) return BboxVerdict.noModes;
  if (transitModesOverLimit(modeMask, d).isNotEmpty) {
    return BboxVerdict.tooLarge;
  }
  if (transitModesOverWarning(modeMask, d).isNotEmpty) return BboxVerdict.warn;
  return BboxVerdict.ok;
}

/// Asks which area to import stations for.
///
/// A **bottom sheet over the live map**, not a dialog: the four S/W/N/E fields
/// describe a box on the ground, and until this sheet existed the rubber band
/// drawn during the two corner taps vanished the instant the dialog opened —
/// so editing those numbers, or arriving from the "import what you can see"
/// path that never drew a band at all, was blind. [onPreview] reports the box
/// on every edit, null while it is unusable.
///
/// Calls [onDone] exactly once — with the config, or null when cancelled.
class TransitImportSheet extends StatefulWidget {
  const TransitImportSheet({
    super.key,
    required this.initial,
    required this.onPreview,
    required this.onDone,
  });

  final LatLngBounds initial;
  final ValueChanged<LatLngBounds?> onPreview;
  final ValueChanged<TransitImportConfig?> onDone;

  @override
  State<TransitImportSheet> createState() => _TransitImportSheetState();
}

class _TransitImportSheetState extends State<TransitImportSheet> {
  late final TextEditingController _south;
  late final TextEditingController _west;
  late final TextEditingController _north;
  late final TextEditingController _east;

  late int _modes;

  /// Whether the ticks are the user's. Until they are, they track the box —
  /// dragging a wide area drops bus back out on its own — but the moment
  /// someone ticks anything, their choice stops being second-guessed.
  bool _chosen = false;

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
    _modes = recommendedImportModes(_diagonal);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onPreview(_boxOrNull()));
  }

  /// The box as typed, or null while it is not a usable one. Deliberately the
  /// same "usable" [checkBbox] means by `malformed`/`misordered`, so the map
  /// stops showing a box exactly when the sheet stops accepting one.
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

  void _boxChanged() {
    setState(() {
      if (!_chosen) _modes = recommendedImportModes(_diagonal);
    });
    widget.onPreview(_boxOrNull());
  }

  double? _v(TextEditingController c) => parseDecimal(c.text.trim());

  /// NaN while the box is unusable — every threshold comparison then reads
  /// false, so nothing is warned about until there is a box to warn about.
  double get _diagonal {
    final s = _v(_south), w = _v(_west), n = _v(_north), e = _v(_east);
    if (s == null || w == null || n == null || e == null) return double.nan;
    if (s >= n || w >= e) return double.nan;
    return bboxDiagonalMeters(s, w, n, e);
  }

  int get _recommended => recommendedImportModes(_diagonal);

  BboxVerdict get _verdict =>
      checkBbox(_v(_south), _v(_west), _v(_north), _v(_east), modeMask: _modes);

  bool get _canImport =>
      _verdict == BboxVerdict.ok || _verdict == BboxVerdict.warn;

  void _setModes(int mask) => setState(() {
    _chosen = true;
    _modes = mask;
  });

  void _submit() {
    if (!_canImport) return;
    widget.onDone(
      TransitImportConfig(
        south: _v(_south)!,
        west: _v(_west)!,
        north: _v(_north)!,
        east: _v(_east)!,
        modeMask: _modes,
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
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // Half the viewport at most: the rest is where the box being
          // described is drawn.
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
                    child: Text('Import transit stations',
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'What to import',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (_chosen && _modes != _recommended)
                    TextButton(
                      onPressed: () => setState(() {
                        _chosen = false;
                        _modes = _recommended;
                      }),
                      child: const Text('Recommended'),
                    ),
                ],
              ),
              Text(
                'Only the ticked types are fetched, and only what is fetched is '
                'stored. Fewer types means a much smaller query — over a whole '
                'state, bus stops are 25× the data of train stops and never '
                'arrive.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _setModes(transitAllModesMask),
                    child: const Text('All'),
                  ),
                  TextButton(
                    onPressed: () => _setModes(transitRailMask),
                    child: const Text('Rail only'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _setModes(transitModeByKey('train')?.bit ?? 0),
                    child: const Text('Train only'),
                  ),
                ],
              ),
              for (final m in transitModes) _modeTile(theme, m),
              _modesLine(theme),
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

  /// The box's own state: unusable numbers, or its size. What that size *costs*
  /// depends on the ticks, so it is said under them instead ([_modesLine]).
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

  /// One tick box per type, each carrying what this box size means for it —
  /// the limit is per type, so the reason belongs next to the type.
  Widget _modeTile(ThemeData theme, TransitMode m) {
    final on = _modes & m.bit != 0;
    final d = _diagonal;
    final over = d > m.maxDiagonalMeters;
    final warn = !over && d > m.warnDiagonalMeters;

    final String note;
    TextStyle? noteStyle;
    if (over) {
      note =
          'Too many stops over an area this size — '
          'max ${formatMeters(m.maxDiagonalMeters)} across';
      noteStyle = _errStyle(theme);
    } else if (warn) {
      note = 'A lot of stops over an area this size — this may be slow';
      noteStyle = _warnStyle(theme);
    } else {
      note = m.blurb;
      noteStyle = theme.textTheme.bodySmall;
    }

    return CheckboxListTile(
      value: on,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (v) => _setModes(transitMaskWith(_modes, m, on: v ?? false)),
      title: Row(
        children: [
          Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
              color: Color(m.colorArgb),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(m.label)),
          // Only worth marking when the suggestion is a *choice* — labelling
          // every row "suggested" says nothing.
          if (_recommended != transitAllModesMask && _recommended & m.bit != 0)
            Text('suggested', style: theme.textTheme.labelSmall),
        ],
      ),
      subtitle: Text(note, style: noteStyle),
    );
  }

  /// The verdict for the ticks as a whole — always actionable, never a silent
  /// refusal, and always naming the type responsible.
  Widget _modesLine(ThemeData theme) {
    String names(List<TransitMode> ms) => ms.map((m) => m.label).join(', ');
    switch (_verdict) {
      case BboxVerdict.noModes:
        return Text(
          'Tick at least one type to import.',
          style: _errStyle(theme),
        );
      case BboxVerdict.tooLarge:
        final over = transitModesOverLimit(_modes, _diagonal);
        return Text(
          'This area is too large for ${names(over)}. Untick '
          '${over.length == 1 ? 'it' : 'them'} to import the rest, or pick a '
          'smaller area.',
          style: _errStyle(theme),
        );
      case BboxVerdict.warn:
        final over = transitModesOverWarning(_modes, _diagonal);
        // "Untick it" is only advice when something else is ticked to keep;
        // otherwise the only lever left is the box.
        final onlyThese = transitMaskOf(over) == _modes;
        return Text(
          '${names(over)} over an area this size is a big query — it may take '
          'a minute, or come back busy. '
          '${onlyThese ? 'A smaller area is quicker.' : 'Unticking helps.'}',
          style: _warnStyle(theme),
        );
      case BboxVerdict.ok:
        return Text(
          'Importing ${transitModeLabels(_modes)}.',
          style: theme.textTheme.bodySmall,
        );
      case BboxVerdict.malformed:
      case BboxVerdict.misordered:
        return const SizedBox.shrink();
    }
  }
}
