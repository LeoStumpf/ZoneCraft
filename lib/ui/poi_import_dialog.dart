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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/overpass.dart';
import '../geo/coords.dart';
import 'editor_sheet.dart' show scaledPx;

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

/// The smallest and largest search radius the dialog offers, in metres.
///
/// The ceiling is Overpass's practical limit for this query, not a UI choice —
/// it is the same 25 km the validator has always enforced, now also the end of
/// the slider so the refusal is visible before the request rather than after
/// it.
const double kMinPoiSearchRadius = 100;
const double kMaxPoiSearchRadius = 25000;

/// Asks for a POI category + search radius (and, when [needsCircleRadius], a
/// per-circle radius). [allCategories] offers the full catalogue (POI layers
/// show unnamed street furniture just fine); by default only the seedable
/// named-place categories are listed.
///
/// Lives in a **bottom sheet over the live map**, not a dialog, because the
/// number being typed here is a distance on the ground: [onPreview] reports
/// every change so the caller can draw the ring that is about to be searched.
/// A radius used to be a bare text field defaulting to 1000 with nothing on
/// screen to compare it against, and "too much data — pick a smaller radius"
/// arrived only after the request came back.
///
/// Calls [onDone] exactly once — with the config, or null when cancelled.
class PoiImportSheet extends StatefulWidget {
  const PoiImportSheet({
    super.key,
    required this.needsCircleRadius,
    required this.allCategories,
    required this.onPreview,
    required this.onDone,
  });

  final bool needsCircleRadius;
  final bool allCategories;

  /// The search radius in metres as it currently stands, or null while the
  /// field holds something unusable. Called on every edit.
  final ValueChanged<double?> onPreview;

  final ValueChanged<PoiImportConfig?> onDone;

  @override
  State<PoiImportSheet> createState() => _PoiImportSheetState();
}

class _PoiImportSheetState extends State<PoiImportSheet> {
  final _formKey = GlobalKey<FormState>();
  late List<PoiCategory> _choices;
  late PoiCategory _category;

  @override
  void initState() {
    super.initState();
    _choices = widget.allCategories ? poiCategories : seedablePoiCategories;
    _category = _choices.first;
    // Draw the default straight away: the sheet opening is itself an answer to
    // "how far is 1000 m from here".
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onPreview(_radiusOrNull()));
  }

  /// The search radius as typed, or null if it is not a usable number.
  ///
  /// Goes through [parseDecimal], never `double.parse`: in a comma-decimal
  /// locale "1,5" is what the keyboard produces, and the old code validated
  /// with one and parsed with the other — so a valid entry could throw on
  /// submit.
  double? _radiusOrNull() {
    final n = parseDecimal(_searchRadius.text.trim());
    if (n == null || !n.isFinite || n <= 0 || n > kMaxPoiSearchRadius) {
      return null;
    }
    return n;
  }

  void _onRadiusTyped(String _) {
    setState(() {});
    widget.onPreview(_radiusOrNull());
  }

  /// The slider is logarithmic: the interesting range spans two and a half
  /// decades, and a linear one would spend nine tenths of its travel between
  /// 3 km and 25 km while the 100 m–1 km end — where most imports live — sat
  /// in the first few pixels.
  static double _toSlider(double m) =>
      (math.log(m.clamp(kMinPoiSearchRadius, kMaxPoiSearchRadius)) -
              math.log(kMinPoiSearchRadius)) /
          (math.log(kMaxPoiSearchRadius) - math.log(kMinPoiSearchRadius));

  static double _fromSlider(double t) {
    final v = math.exp(math.log(kMinPoiSearchRadius) +
        t * (math.log(kMaxPoiSearchRadius) - math.log(kMinPoiSearchRadius)));
    // Round to something a person would have typed, so the field does not
    // fill with 1473.9182.
    if (v < 1000) return (v / 10).round() * 10;
    return (v / 100).round() * 100;
  }

  final _searchRadius = TextEditingController(text: '1000');
  final _circleRadius = TextEditingController(text: '100');

  @override
  void dispose() {
    _searchRadius.dispose();
    _circleRadius.dispose();
    super.dispose();
  }

  String? _validateMeters(String? v, {required double max}) {
    final n = parseDecimal((v ?? '').trim());
    if (n == null || !n.isFinite || n <= 0) return 'Enter metres > 0';
    if (n > max) return 'Max ${max.round()} m';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final search = parseDecimal(_searchRadius.text.trim());
    final circle = parseDecimal(_circleRadius.text.trim());
    // The validator already accepted both through `parseDecimal`; re-reading
    // them the same way is what keeps that promise true.
    if (search == null || (widget.needsCircleRadius && circle == null)) return;
    widget.onDone(
      PoiImportConfig(
        category: _category,
        searchRadiusMeters: search,
        circleRadiusMeters: widget.needsCircleRadius ? circle : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = _radiusOrNull();
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // Half the viewport at most: the other half is the point — it is
          // where the ring being described is drawn.
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
                          'Import nearby POIs',
                          style: Theme.of(context).textTheme.titleMedium,
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
                    onChanged: (c) => setState(() => _category = c ?? _category),
                  ),
                  const SizedBox(height: 8),
                  // Field and slider drive the same value from both ends: type
                  // an exact number, or drag until the ring on the map looks
                  // right. Neither is authoritative — the text is.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: scaledPx(context, 140),
                        child: TextFormField(
                          controller: _searchRadius,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Search radius (m)',
                            isDense: true,
                          ),
                          onChanged: _onRadiusTyped,
                          validator: (v) =>
                              _validateMeters(v, max: kMaxPoiSearchRadius),
                        ),
                      ),
                      Text(
                        radius == null
                            ? 'Drag or type a radius'
                            : 'The ring on the map is what will be searched',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Slider(
                    value: _toSlider(radius ?? kMinPoiSearchRadius),
                    onChanged: (t) {
                      _searchRadius.text = _fromSlider(t).round().toString();
                      _onRadiusTyped(_searchRadius.text);
                    },
                  ),
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
                        onPressed: radius == null ? null : _submit,
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
}
