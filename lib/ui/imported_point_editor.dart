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

import '../data/osm_report.dart';
import '../data/repository.dart';
import '../geo/coords.dart' show formatLatLng, parseLatLng;
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'osm_report_sheet.dart';

/// Docked editor for **one stored point** — a POI or a station; since v27
/// both are `PoiPoints` rows, and only the icon and subtitle differ.
///
/// This is the level *below* an element: a point belongs to a set, and it is
/// the set that appears in the Elements list.
/// The point is reachable only by tapping it on the map, which is where you
/// noticed it was wrong.
///
/// **An imported point can be corrected, and saying so is what makes that
/// honest.** It used to be rename-and-delete only: a position was the fetched
/// fact the layer exists to record, and moving one silently turned a record of
/// where things are into a drawing of where you think they are. What changed
/// is not the risk but the bookkeeping — `PoiPoints.editedAt` records the
/// fork and keeps what OSM returned, so the row, the editor and every export
/// say plainly that this is your correction rather than upstream's data. The
/// same contract a reshaped border area lives under.
///
/// Which is also where the feature this editor exists for begins: you are
/// standing next to the bench, you have just fixed your copy, and the obvious
/// next question is whether anyone else gets the fix. **Share this
/// correction** is that question, answered with an OpenStreetMap note.
///
/// A POI in a **hand-made** category has no upstream to fork from, so none of
/// the bookkeeping applies to it — but it has the same offer, the other way
/// round: it is something OSM does not have yet.
class ImportedPointEditorSheet extends ConsumerStatefulWidget {
  const ImportedPointEditorSheet({
    super.key,
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.movable = false,
    this.editedAt,
    this.origLat,
    this.origLng,
    this.origName,
    this.osmType,
    this.osmId,
    this.tagKey,
    this.tagValue,
  });

  /// The `PoiPoints` row id.
  final String id;

  final String? name;
  final double lat;
  final double lng;

  final IconData icon;

  /// Sheet heading ("Edit POI" / "Edit station").
  final String title;

  /// One line of context under the name — the category, or which modes serve
  /// the station.
  final String subtitle;

  /// Whether this point is hand-placed rather than imported. Both kinds can
  /// now be moved; this decides what the sheet *says* about the move, and
  /// which report the share button offers.
  final bool movable;

  /// When this point was corrected by hand — null for an untouched import and
  /// for every hand-placed point.
  final DateTime? editedAt;

  /// What the import returned, for a corrected point.
  final double? origLat;
  final double? origLng;
  final String? origName;

  /// The upstream element, when there is one.
  final String? osmType;
  final int? osmId;

  /// The OSM tag this point's category stands for, when the category has one.
  /// A hand-made category built from a bare icon does not, and guessing would
  /// be worse than saying nothing.
  final String? tagKey;
  final String? tagValue;

  @override
  ConsumerState<ImportedPointEditorSheet> createState() =>
      _ImportedPointEditorSheetState();
}

class _ImportedPointEditorSheetState
    extends ConsumerState<ImportedPointEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _pos;
  final FocusNode _posFocus = FocusNode();

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name ?? '');
    _pos = TextEditingController(
      text: formatLatLng(widget.lat, widget.lng),
    );
  }

  @override
  void didUpdateWidget(ImportedPointEditorSheet old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _name.text = widget.name ?? '';
    // Keep the field in step when the point is moved by tapping the map, but
    // never rewrite it under the caret.
    if (!_posFocus.hasFocus) {
      final t = formatLatLng(widget.lat, widget.lng);
      if (_pos.text != t) _pos.text = t;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _pos.dispose();
    _posFocus.dispose();
    super.dispose();
  }

  void _armPlacement() {
    ref.read(poiPointPlacementProvider.notifier).arm(on: true);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.movable
                ? 'Tap the map to move this POI'
                : 'Tap the map where it really is',
          ),
        ),
      );
  }

  /// Everything the report needs to know about this point, gathered in one
  /// place so the sheet has no idea it came from a POI row.
  OsmReportSubject get _subject => OsmReportSubject(
        lat: widget.lat,
        lng: widget.lng,
        name: widget.name,
        origLat: widget.origLat,
        origLng: widget.origLng,
        origName: widget.origName,
        edited: widget.editedAt != null,
        categoryLabel: widget.subtitle,
        tagKey: widget.tagKey,
        tagValue: widget.tagValue,
        osmType: widget.osmType,
        osmId: widget.osmId,
        poiPointId: widget.id,
      );

  Future<void> _report() async {
    // Disarm first: the sheet covers the map, and a tap landing behind it
    // would move the point the user is in the middle of describing.
    ref.read(poiPointPlacementProvider.notifier).arm(on: false);
    final result = await showOsmReportSheet(context, _subject);
    if (!mounted) return;
    switch (result.outcome) {
      case OsmReportOutcomeKind.cancelled:
        return;
      case OsmReportOutcomeKind.saved:
        _toast('Saved to your OpenStreetMap outbox');
      case OsmReportOutcomeKind.sent:
        _toast('Sent to OpenStreetMap — thank you');
    }
    // "It is not there any more" usually ends with the local copy going too.
    // After the report, never before: the report quotes the point.
    if (result.alsoRemove) await _delete();
  }

  Future<void> _revert() async {
    await _repo.revertPoiPoint(widget.id);
    if (!mounted) return;
    _toast('Put back to what OpenStreetMap has');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    ref.read(poiPointPlacementProvider.notifier).arm(on: false);
    ref.read(selectedPoiPointProvider.notifier).select(null);
  }

  Future<void> _rename(String text) {
    final label = Value<String?>(text.trim().isEmpty ? null : text.trim());
    return _repo.updatePoiPoint(widget.id, name: label);
  }

  Future<void> _delete() async {
    await _repo.deletePoiPoint(widget.id);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edited = widget.editedAt != null;
    return EditorSheet(
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 20),
            const SizedBox(width: 8),
            Text(widget.title, style: theme.textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: widget.movable
                  ? 'Delete this POI'
                  : 'Remove from this import',
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              onPressed: _delete,
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: _close,
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Leave empty to clear',
            isDense: true,
          ),
          onChanged: _rename,
        ),
        const SizedBox(height: 8),
        // Both kinds get a position field now. What differs is what a change
        // to it *means*: on a hand-placed point it is simply where you put it,
        // on an imported one it forks the row from upstream — which is why the
        // note below spells that out rather than leaving it to be discovered.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pos,
                focusNode: _posFocus,
                decoration: const InputDecoration(
                  labelText: 'Position (lat, lng)',
                  isDense: true,
                ),
                onChanged: (t) {
                  final p = parseLatLng(t);
                  if (p == null) return; // half-typed; ignore until valid
                  unawaited(_repo.movePoiPoint(
                      id: widget.id,
                      lat: p.latitude,
                      lng: p.longitude,
                    ));
                },
              ),
            ),
            IconButton(
              tooltip: widget.movable
                  ? 'Tap the map to move it'
                  : 'Tap the map where it really is',
              icon: Icon(
                Icons.touch_app_outlined,
                color: ref.watch(poiPointPlacementProvider)
                    ? theme.colorScheme.primary
                    : null,
              ),
              onPressed: _armPlacement,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The coordinate used to be printed here because there was nowhere
        // else for it. There is a field for it now, so this line says only
        // what the field cannot.
        Text(
          [
            widget.subtitle,
            if (widget.movable) 'placed by hand',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (edited) ...[
          const SizedBox(height: 8),
          Text(
            'Corrected by you. OpenStreetMap still has '
            '${_upstreamDescription()}.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.tertiary),
          ),
        ] else if (!widget.movable) ...[
          const SizedBox(height: 8),
          Text(
            'Imported from OpenStreetMap. Changing it here changes your copy '
            'only — and the app will say so from then on.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (edited)
              OutlinedButton.icon(
                onPressed: () => unawaited(_revert()),
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Revert'),
              ),
            FilledButton.tonalIcon(
              onPressed: () => unawaited(_report()),
              icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
              label: Text(
                edited
                    ? 'Share this correction'
                    : widget.movable
                        ? 'Add it to OpenStreetMap'
                        : 'Tell OpenStreetMap',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// What OSM holds, in the fewest words that still say which part you
  /// changed — the position, the name, or both.
  String _upstreamDescription() {
    final moved = widget.origLat != null &&
        widget.origLng != null &&
        (widget.origLat != widget.lat || widget.origLng != widget.lng);
    final renamed = widget.origName != widget.name;
    if (moved && renamed) {
      return '“${widget.origName ?? 'no name'}” at '
          '${formatLatLng(widget.origLat!, widget.origLng!)}';
    }
    if (moved) return 'it at ${formatLatLng(widget.origLat!, widget.origLng!)}';
    if (renamed) return 'it as “${widget.origName ?? 'unnamed'}”';
    return 'something different';
  }
}
