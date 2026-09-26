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

import '../data/overpass.dart';
import '../geo/coords.dart';
import 'bbox_fields.dart';
import 'object_summary.dart' show formatMeters;
import 'theme.dart';
import 'transit_import_dialog.dart' show bboxDiagonalMeters;

/// The user's choices from the POI import sheet.
class PoiImportConfig {
  const PoiImportConfig({
    required this.category,
    required this.box,
    this.circleRadiusMeters,
  });

  /// Which POI category to fetch.
  final PoiCategory category;

  /// The area to fetch it in.
  final LatLngBounds box;

  /// For circle layers: the radius of each created circle. Null otherwise.
  final double? circleRadiusMeters;
}

/// The widest box a POI import accepts, corner to corner, and where it starts
/// warning. 50 km is the span the old 25 km search radius covered, so nothing
/// that used to be importable stopped being so when the circle became a box.
const double kMaxPoiBoxDiagonal = 50000;
const double kWarnPoiBoxDiagonal = 25000;

/// Whether a box is usable for a POI import, and small enough.
enum PoiBboxVerdict { ok, warn, tooLarge, malformed, misordered }

/// The verdict for a POI import over this box — the same shape as the station
/// and border checks, so the three sheets refuse the same way.
PoiBboxVerdict checkPoiBbox(
  double? south,
  double? west,
  double? north,
  double? east,
) {
  if (south == null || west == null || north == null || east == null) {
    return PoiBboxVerdict.malformed;
  }
  if (![south, west, north, east].every((v) => v.isFinite)) {
    return PoiBboxVerdict.malformed;
  }
  if (south >= north || west >= east) return PoiBboxVerdict.misordered;
  final d = bboxDiagonalMeters(south, west, north, east);
  if (!d.isFinite) return PoiBboxVerdict.malformed;
  if (d > kMaxPoiBoxDiagonal) return PoiBboxVerdict.tooLarge;
  if (d > kWarnPoiBoxDiagonal) return PoiBboxVerdict.warn;
  return PoiBboxVerdict.ok;
}

/// Asks for a POI category over a box (and, when [needsCircleRadius], a
/// per-circle radius). [allCategories] offers the full catalogue (POI layers
/// show unnamed street furniture just fine); by default only the seedable
/// named-place categories are listed.
///
/// A **box**, like the station and border imports, because all three answer
/// the same question — "which part of the map?" — and asking it three ways
/// was the thing people found odd. It used to be a radius around the map
/// centre; the query was a box underneath all along, trimmed to a circle on
/// the phone.
///
/// Lives in a **bottom sheet over the live map**: [onPreview] reports the box
/// on every edit (null while unusable) so the caller can draw it.
///
/// Calls [onDone] exactly once — with the config, or null when cancelled.
class PoiImportSheet extends StatefulWidget {
  const PoiImportSheet({
    super.key,
    required this.initial,
    required this.needsCircleRadius,
    required this.allCategories,
    required this.onPreview,
    required this.onDone,
  });

  final LatLngBounds initial;
  final bool needsCircleRadius;
  final bool allCategories;
  final ValueChanged<LatLngBounds?> onPreview;
  final ValueChanged<PoiImportConfig?> onDone;

  @override
  State<PoiImportSheet> createState() => _PoiImportSheetState();
}

class _PoiImportSheetState extends State<PoiImportSheet> {
  final _formKey = GlobalKey<FormState>();
  late List<PoiCategory> _choices;
  late PoiCategory _category;
  late final BboxControllers _box = BboxControllers(widget.initial);
  final _circleRadius = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _choices = widget.allCategories ? poiCategories : seedablePoiCategories;
    _category = _choices.first;
    _box.addListener(_boxChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onPreview(_box.box),
    );
  }

  @override
  void dispose() {
    _box.dispose();
    _circleRadius.dispose();
    super.dispose();
  }

  void _boxChanged() {
    setState(() {});
    widget.onPreview(_box.box);
  }

  PoiBboxVerdict get _verdict => checkPoiBbox(_box.s, _box.w, _box.n, _box.e);

  bool get _canImport =>
      _verdict == PoiBboxVerdict.ok || _verdict == PoiBboxVerdict.warn;

  String? _validateMeters(String? v, {required double max}) {
    final n = parseDecimal((v ?? '').trim());
    if (n == null || !n.isFinite || n <= 0) return 'Enter metres > 0';
    if (n > max) return 'Max ${max.round()} m';
    return null;
  }

  void _submit() {
    final box = _box.box;
    if (!_canImport || box == null) return;
    if (!_formKey.currentState!.validate()) return;
    // The validator accepted it through `parseDecimal`; re-reading it the same
    // way is what keeps that promise true in a comma-decimal locale.
    final circle = parseDecimal(_circleRadius.text.trim());
    if (widget.needsCircleRadius && circle == null) return;
    widget.onDone(
      PoiImportConfig(
        category: _category,
        box: box,
        circleRadiusMeters: widget.needsCircleRadius ? circle : null,
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
          // Half the viewport at most: the other half is the point — it is
          // where the box being described is drawn.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Import POIs',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel',
                        icon: const Icon(Icons.close),
                        onPressed: () => widget.onDone(null),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<PoiCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in _choices)
                        DropdownMenuItem(value: c, child: Text(c.label)),
                    ],
                    onChanged: (c) =>
                        setState(() => _category = c ?? _category),
                  ),
                  const SizedBox(height: 12),
                  BboxFields(box: _box),
                  const SizedBox(height: 4),
                  _costLine(theme),
                  if (widget.needsCircleRadius) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _circleRadius,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Circle radius (m)',
                        helperText: 'Radius of each created circle',
                        isDense: true,
                      ),
                      validator: (v) => _validateMeters(v, max: 100000),
                    ),
                  ],
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
      ),
    );
  }

  /// What this box costs — always naming the limit, so "too large" says what
  /// it is too large *for*.
  Widget _costLine(ThemeData theme) {
    switch (_verdict) {
      case PoiBboxVerdict.tooLarge:
        return Text(
          'This area is too large — at most '
          '${formatMeters(kMaxPoiBoxDiagonal)} across. Pick a smaller one.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        );
      case PoiBboxVerdict.warn:
        return Text(
          'A big area — this may take a minute, and a busy category stops at '
          '$overpassResultCap places. A smaller area is quicker.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: warningColor(context),
          ),
        );
      case PoiBboxVerdict.ok:
        return Text(
          'The box on the map is what will be searched.',
          style: theme.textTheme.bodySmall,
        );
      case PoiBboxVerdict.malformed:
      case PoiBboxVerdict.misordered:
        return const SizedBox.shrink();
    }
  }
}
