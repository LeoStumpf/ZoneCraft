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
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/error_log.dart';
import '../data/layer_types.dart';
import '../data/osm_report.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'edit_value_dialog.dart';
import 'element_color_dialog.dart';
import 'osm_report_sheet.dart' show publishCorrection;
import 'poi_move.dart' show PointMoveButton;
import 'confirm_delete.dart';

/// Docked bottom-sheet editor for a circle. Unlike a dialog, this sits below the
/// map (which stays interactive) and applies every change live to the database,
/// so the map updates as you edit. Close just deselects; delete removes the
/// circle.
class CircleEditorSheet extends ConsumerStatefulWidget {
  const CircleEditorSheet({
    super.key,
    required this.circle,
    required this.layers,
  });

  final Circle circle;
  final List<Layer> layers;

  @override
  ConsumerState<CircleEditorSheet> createState() => _CircleEditorSheetState();
}

class _CircleEditorSheetState extends ConsumerState<CircleEditorSheet> {
  // Radius slider works on a log scale so both small and huge radii are usable.
  static const _minRadius = 10.0;
  static const _maxRadius = 1000000.0;

  late final TextEditingController _label;

  /// The circle as it was when this editor opened — what **Reset** puts back.
  late ({double lat, double lng, double radius, String? label}) _snapshot;
  // The radius is editable both ways: the log slider for a quick sweep, the
  // field for an exact value ("500 m" is unhittable on a 10 m–1000 km slider).
  late final TextEditingController _radiusField;
  final FocusNode _radiusFocus = FocusNode();
  late double _radius;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    final c = widget.circle;
    _snapshot = _snap(c);
    _label = TextEditingController(text: c.label ?? '');
    _radius = c.radiusMeters;
    _radiusField = TextEditingController(text: _radiusFieldText(_radius));
  }

  @override
  void didUpdateWidget(CircleEditorSheet old) {
    super.didUpdateWidget(old);
    // A different circle in the same slot is a new sitting.
    if (old.circle.id != widget.circle.id) {
      _snapshot = _snap(widget.circle);
      _label.text = widget.circle.label ?? '';
    }
    if (widget.circle.radiusMeters != _radius) {
      _radius = widget.circle.radiusMeters;
      _syncRadiusField();
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _radiusField.dispose();
    _radiusFocus.dispose();
    super.dispose();
  }

  static ({double lat, double lng, double radius, String? label}) _snap(
    Circle c,
  ) => (
    lat: c.centerLat,
    lng: c.centerLng,
    radius: c.radiusMeters,
    label: c.label,
  );

  bool get _changed => _snap(widget.circle) != _snapshot;

  /// Puts the circle back the way it was when the editor opened, as one undo
  /// step.
  Future<void> _reset() async {
    ref.read(pointMoveProvider.notifier).cancel();
    final s = _snapshot;
    await _repo.undo.group('Reset circle', () async {
      await _repo.updateCircle(
        widget.circle.id,
        centerLat: s.lat,
        centerLng: s.lng,
        radiusMeters: s.radius,
        label: Value(s.label),
      );
    });
    if (!mounted) return;
    _label.text = s.label ?? '';
  }

  Future<void> _editCentre() async {
    final answer = await showPositionDialog(
      context,
      lat: widget.circle.centerLat,
      lng: widget.circle.centerLng,
      title: 'Centre',
      canPublish: widget.circle.osmId != null,
    );
    if (answer == null || !mounted) return;
    ref.read(pointMoveProvider.notifier).cancel();
    await _repo.updateCircle(
      widget.circle.id,
      centerLat: answer.at.latitude,
      centerLng: answer.at.longitude,
    );
    await _repo.undo.sealStep(label: 'Move circle');
    if (!answer.publish || !mounted) return;
    final subject = _subject(lat: answer.at.latitude, lng: answer.at.longitude);
    if (subject != null) await publishCorrection(context, subject);
  }

  /// What a note about this circle's place would say — as it is, or with a
  /// centre being saved right now. Null unless a POI import seeded it.
  OsmReportSubject? _subject({double? lat, double? lng}) {
    final c = widget.circle;
    return seededPointSubject(
      osmType: c.osmType,
      osmId: c.osmId,
      origLat: c.origLat,
      origLng: c.origLng,
      origName: c.origName,
      lat: lat ?? c.centerLat,
      lng: lng ?? c.centerLng,
      label: c.label,
    );
  }

  void _close() {
    ref.read(pointMoveProvider.notifier).cancel();
    ref.read(selectedCircleProvider.notifier).select(null);
  }

  /// Applies a radius from the slider: rounded to whole metres so the value
  /// the field shows is exactly the value that is stored.
  void _setRadiusFromSlider(double meters) {
    _setRadius(meters.roundToDouble());
    // Forced: the field usually keeps focus (the keyboard stays up) while the
    // slider is dragged, and leaving it on the old number would have the two
    // controls disagree about the radius.
    _syncRadiusField(force: true);
  }

  void _setRadius(double meters) {
    setState(() => _radius = meters);
    logAsyncFailure(
      _repo.updateCircle(widget.circle.id, radiusMeters: meters),
      'Saving the radius',
    );
  }

  /// Mirrors the current radius into the field, unless the user is typing in
  /// it — rewriting it under the caret would fight the keyboard.
  void _syncRadiusField({bool force = false}) {
    if (_radiusFocus.hasFocus && !force) return;
    final t = _radiusFieldText(_radius);
    if (_radiusField.text == t) return;
    _radiusField.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  static String _radiusFieldText(double m) =>
      m == m.roundToDouble() ? m.round().toString() : m.toStringAsFixed(1);

  String _radiusLabel(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1)} km'
      : '${m.round()} m';

  /// The layers this circle can be moved to. Filtered, like every other
  /// editor's picker: an unfiltered list offered `poi` and `borders` layers
  /// too, and moving a circle onto one stored it where nothing paints circles.
  List<Layer> get _circleLayers =>
      widget.layers.where((l) => layerHolds(l, kCircles)).toList();

  /// The owning layer's colour, which the element's shade is derived from.
  /// Null when the layer is not in the list this sheet was handed (it was
  /// deleted under us) — the swatch then hides itself rather than throwing
  /// inside a build.
  Color? get _layerColor {
    for (final l in widget.layers) {
      if (l.id == widget.circle.layerId) return Color(l.colorArgb);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subject();
    final sliderValue =
        (math.log(_radius.clamp(_minRadius, _maxRadius)) / math.ln10).clamp(
          math.log(_minRadius) / math.ln10,
          math.log(_maxRadius) / math.ln10,
        );

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.circle_outlined, size: 18),
            const SizedBox(width: 8),
            Text('Edit circle', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            ElementColorButton(
              kind: ColoredElement.circle,
              id: widget.circle.id,
              title: widget.circle.label?.trim().isNotEmpty == true
                  ? widget.circle.label!.trim()
                  : 'Circle',
              colorArgb: widget.circle.colorArgb,
              colorShade: widget.circle.colorShade,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              onPressed: () async {
                if (!await confirmDelete(
                  context,
                  title: 'Delete this circle?',
                )) {
                  return;
                }
                await _repo.deleteCircle(widget.circle.id);
                _close();
              },
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: _close,
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: scaledPx(context, 132),
              child: TextField(
                controller: _radiusField,
                focusNode: _radiusFocus,
                decoration: InputDecoration(
                  labelText: 'Radius (m)',
                  helperText: _radius >= 1000 ? _radiusLabel(_radius) : null,
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (s) {
                  final n = parseDecimal(s);
                  if (n != null && n.isFinite && n > 0) _setRadius(n);
                },
              ),
            ),
            const SizedBox(width: 8),
            // The layer picker takes the slack and ellipsises: a layer named
            // after an imported border ("Ludwigsvorstadt-Isarvorstadt") is
            // far longer than this row is wide.
            // Not wrapped in a Flexible: EditorLayerPicker *is* one, and a
            // Flexible must sit directly inside the Flex.
            EditorLayerPicker(
              layers: _circleLayers,
              selectedId: widget.circle.layerId,
              onChanged: (v) =>
                  _repo.updateCircle(widget.circle.id, layerId: v),
            ),
          ],
        ),
        Slider(
          min: math.log(_minRadius) / math.ln10,
          max: math.log(_maxRadius) / math.ln10,
          value: sliderValue.toDouble(),
          onChanged: (v) => _setRadiusFromSlider(math.pow(10, v).toDouble()),
        ),
        // The centre is a fact with the two ways to change it: typed, or
        // dragged on the map with the move pin. A live field wrote a new
        // centre on every keystroke of a half-typed coordinate.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: scaledPx(context, 150)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Centre', style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    formatLatLng(
                      widget.circle.centerLat,
                      widget.circle.centerLng,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit the centre\'s coordinates',
              icon: const Icon(Icons.edit_location_alt_outlined),
              onPressed: () => unawaited(_editCentre()),
            ),
            PointMoveButton(
              pointId: widget.circle.id,
              lat: widget.circle.centerLat,
              lng: widget.circle.centerLng,
              target: PointMoveTarget.circle,
              tooltip: 'Move the centre on the map',
            ),
            TextButton.icon(
              onPressed: _changed ? () => unawaited(_reset()) : null,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
            // A circle seeded from an OSM place that you have since moved
            // (or renamed): the correction is worth passing on.
            if (subject?.canPublish ?? false)
              TextButton.icon(
                onPressed: () =>
                    unawaited(publishCorrection(context, subject!)),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Report to OSM…'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            isDense: true,
          ),
          onChanged: (s) {
            final t = s.trim();
            logAsyncFailure(
              _repo.updateCircle(
                widget.circle.id,
                label: Value(t.isEmpty ? null : t),
              ),
              'Saving the name',
            );
          },
        ),
      ],
    );
  }
}
