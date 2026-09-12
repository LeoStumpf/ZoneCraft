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

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/database.dart';
import '../data/height_generator.dart';
import '../data/layer_types.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'element_color_dialog.dart';
import 'import_actions.dart' show convertRingsToFreehandFlow;

/// Docked bottom-sheet editor for a height region: an elevation threshold
/// applied inside a bounded circle. Lets the user set the centre (typed or
/// place-by-tap), radius, threshold, above/below direction and sample
/// resolution, then **Generate** the fill from terrain tiles. Generation runs
/// off the UI thread and stores polygons that render offline thereafter.
class HeightEditorSheet extends ConsumerStatefulWidget {
  const HeightEditorSheet({
    super.key,
    required this.region,
    required this.polygonCount,
    required this.layers,
  });

  final HeightRegion region;

  /// Number of generated fill polygons for this region (0 = none yet).
  final int polygonCount;
  final List<Layer> layers;

  @override
  ConsumerState<HeightEditorSheet> createState() => _HeightEditorSheetState();
}

class _HeightEditorSheetState extends ConsumerState<HeightEditorSheet> {
  static const _userAgent =
      'ZoneCraft/1.0 (https://github.com/LeoStumpf/ZoneCraft)';

  late final TextEditingController _center;
  late final TextEditingController _radius;
  late final TextEditingController _threshold;
  late final TextEditingController _label;
  final _centerFocus = FocusNode();

  bool _busy = false;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    final r = widget.region;
    _center = TextEditingController(
      text: formatLatLng(r.centerLat, r.centerLng),
    );
    _radius = TextEditingController(text: r.radiusMeters.round().toString());
    _threshold = TextEditingController(
      text: r.thresholdMeters.round().toString(),
    );
    _label = TextEditingController(text: r.label ?? '');
  }

  @override
  void didUpdateWidget(HeightEditorSheet old) {
    super.didUpdateWidget(old);
    // Keep the centre field in sync when a map-tap relocates it.
    if (!_centerFocus.hasFocus) {
      final t = formatLatLng(widget.region.centerLat, widget.region.centerLng);
      if (_center.text != t) _center.text = t;
    }
  }

  @override
  void dispose() {
    _center.dispose();
    _radius.dispose();
    _threshold.dispose();
    _label.dispose();
    _centerFocus.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final client = http.Client();
    try {
      final result = await generateHeightRegion(
        repo: _repo,
        client: client,
        region: widget.region,
        headers: const {'User-Agent': _userAgent},
      );
      _snack(
        result.polygonCount == 0
            ? 'No terrain ${widget.region.aboveThreshold ? 'above' : 'below'} '
                  '${widget.region.thresholdMeters.round()} m in this area'
            : 'Generated ${result.polygonCount} '
                  'area${result.polygonCount == 1 ? '' : 's'}'
                  '${result.missingTiles > 0 ? ' (${result.missingTiles} tiles missing)' : ''}',
      );
    } on HeightGenException catch (e) {
      _snack(e.message);
    // The failure we can explain is typed and handled above. This is the backstop
    // that puts everything else in front of the user instead of dropping it into
    // an unhandled async error.
    // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _snack('Generation failed: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _armCenter() {
    ref.read(heightPlacementProvider.notifier).arm(on: true);
    _snack('Tap the map to place the area centre');
  }

  /// The owning layer's colour, which the element's shade is derived from.
  /// Null when the layer is not in the list this sheet was handed (it was
  /// deleted under us) — the swatch then hides itself rather than throwing
  /// inside a build.
  Color? get _layerColor {
    for (final l in widget.layers) {
      if (l.id == widget.region.layerId) return Color(l.colorArgb);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final armed = ref.watch(heightPlacementProvider);
    final r = widget.region;
    final id = r.id;
    final heightLayers = widget.layers.where((l) => layerHolds(l, kHeight)).toList();
    final generated = r.generatedAt != null;

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.terrain, size: 18),
            const SizedBox(width: 8),
            Text(
              'Edit height area',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 12),
            // The layer picker takes the slack and ellipsises: a layer named
            // after an imported border ("Ludwigsvorstadt-Isarvorstadt") is
            // far longer than this row is wide.
            EditorLayerPicker(
              layers: heightLayers,
              selectedId: r.layerId,
              onChanged: (v) => _repo.updateHeightRegion(r.id, layerId: v),
            ),
            ElementColorButton(
              kind: ColoredElement.heightRegion,
              id: widget.region.id,
              title: widget.region.label?.trim().isNotEmpty == true
                  ? widget.region.label!.trim()
                  : 'Height area',
              colorArgb: widget.region.colorArgb,
              colorShade: widget.region.colorShade,
              layerColor: _layerColor,
            ),
            IconButton(
              tooltip: 'Delete area',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () async {
                await _repo.deleteHeightRegion(id);
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
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _center,
                focusNode: _centerFocus,
                decoration: const InputDecoration(
                  labelText: 'Centre (lat, lng)',
                  hintText: '47.421, 10.985',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (s) {
                  final ll = parseLatLng(s);
                  if (ll != null) {
                    unawaited(_repo.updateHeightRegion(
                        id,
                        centerLat: ll.latitude,
                        centerLng: ll.longitude,
                      ));
                  }
                },
              ),
            ),
            IconButton(
              tooltip: 'Place centre by tapping the map',
              icon: Icon(armed ? Icons.touch_app : Icons.touch_app_outlined),
              color: armed ? Theme.of(context).colorScheme.primary : null,
              onPressed: _armCenter,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Wrap rather than Row: two number fields with labels do not both fit
        // at a large system font.
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: scaledPx(context, 120),
              child: TextField(
                controller: _radius,
                decoration: const InputDecoration(
                  labelText: 'Radius (m)',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (s) {
                  final n = parseDecimal(s);
                  if (n != null && n.isFinite && n > 0) {
                    unawaited(_repo.updateHeightRegion(id, radiusMeters: n));
                  }
                },
              ),
            ),
            SizedBox(
              width: scaledPx(context, 130),
              child: TextField(
                controller: _threshold,
                decoration: const InputDecoration(
                  labelText: 'Elevation (m)',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (s) {
                  final n = parseDecimal(s);
                  if (n != null && n.isFinite) {
                    unawaited(_repo.updateHeightRegion(id, thresholdMeters: n));
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Above')),
                ButtonSegment(value: false, label: Text('Below')),
              ],
              selected: {r.aboveThreshold},
              onSelectionChanged: (s) =>
                  _repo.updateHeightRegion(id, aboveThreshold: s.first),
            ),
            const Spacer(),
            DropdownButton<int>(
              value: r.sampleZoom,
              items: const [
                DropdownMenuItem(value: 12, child: Text('Coarse')),
                DropdownMenuItem(value: 13, child: Text('Medium')),
                DropdownMenuItem(value: 14, child: Text('Fine')),
              ],
              onChanged: (v) {
                if (v != null) {
                  unawaited(_repo.updateHeightRegion(id, sampleZoom: v));
                }
              },
            ),
          ],
        ),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            isDense: true,
          ),
          onChanged: (s) {
            final t = s.trim();
            unawaited(
              _repo.updateHeightRegion(id, label: Value(t.isEmpty ? null : t))
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.terrain),
              label: Text(
                _busy ? 'Generating…' : (generated ? 'Regenerate' : 'Generate'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _busy
                    ? 'Fetching terrain & computing…'
                    : generated
                    ? '${widget.polygonCount} '
                          'area${widget.polygonCount == 1 ? '' : 's'} '
                          'generated'
                    : 'Not generated yet',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (generated && widget.polygonCount > 0) ...[
          const SizedBox(height: 8),
          // The way out of a generated fill and into geometry you own — the
          // same conversion a border area offers. Outer contours only: a
          // freehand area has no holes, so a "below" region comes across as
          // its outer disk (the flow's doc says why).
          OutlinedButton.icon(
            onPressed: _busy ? null : _convertToFreehand,
            icon: const Icon(Icons.hexagon_outlined, size: 18),
            label: const Text('Convert to freehand area…'),
          ),
        ],
      ],
    );
  }

  Future<void> _convertToFreehand() async {
    final rings = await _repo.heightRegionRings(widget.region.id);
    if (!mounted) return;
    await convertRingsToFreehandFlow(
      context,
      _repo,
      ref.read(layersProvider).asData?.value ?? const [],
      name: widget.region.label?.trim().isNotEmpty == true
          ? widget.region.label!.trim()
          : 'Height area',
      rings: rings,
    );
  }

  void _close() {
    ref.read(heightPlacementProvider.notifier).arm(on: false);
    ref.read(selectedHeightRegionProvider.notifier).select(null);
  }
}
