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
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/osm_report.dart';
import '../data/repository.dart';
import '../geo/coords.dart' show formatLatLng, parseLatLng;
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'osm_report_sheet.dart';
import 'poi_delete.dart';
import '../data/service_credits.dart';
import 'service_credit_line.dart';

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
/// next question is whether anyone else gets the fix. **Publish** is that
/// question, answered with an OpenStreetMap note — offered only for a change
/// of the user's own, and asked again as **Save & publish** at the moment a
/// name or position is saved, and as **Delete & tell OSM** on a delete.
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
  Repository get _repo => ref.read(repositoryProvider);

  /// Starts moving on the map — a draggable pin, a line back to where the
  /// point is, and the map's own Cancel / Save / Save & publish banner. A
  /// second press puts the pin away again.
  void _toggleMove() {
    final moves = ref.read(poiMoveProvider.notifier);
    if (ref.read(poiMoveProvider)?.pointId == widget.id) {
      moves.cancel();
      return;
    }
    moves.start(widget.id, LatLng(widget.lat, widget.lng));
  }

  /// This point as a note would describe it — optionally as it will be once
  /// a change being saved right now has landed, so "Save & publish" can
  /// compose from the new values without waiting for the row to come back.
  ///
  /// For an import the original is what OSM returned: the stored `orig*`
  /// once the point is a fork, else its current values, which is exactly what
  /// the repository will record as `orig*` on this first edit.
  OsmReportSubject _subject({String? name, double? lat, double? lng}) {
    final changing = name != null || lat != null || lng != null;
    final forked = widget.editedAt != null;
    final hand = widget.movable;
    return OsmReportSubject(
      lat: lat ?? widget.lat,
      lng: lng ?? widget.lng,
      name: name == null ? widget.name : (name.isEmpty ? null : name),
      origLat: hand ? null : (forked ? widget.origLat : widget.lat),
      origLng: hand ? null : (forked ? widget.origLng : widget.lng),
      origName: hand ? null : (forked ? widget.origName : widget.name),
      edited: !hand && (forked || changing),
      categoryLabel: widget.subtitle,
      tagKey: widget.tagKey,
      tagValue: widget.tagValue,
      osmType: widget.osmType,
      osmId: widget.osmId,
      poiPointId: widget.id,
    );
  }

  Future<void> _publish(OsmReportSubject subject) async {
    // Put a pending move away first: the sheet covers the map, and a pin left
    // on it would be a second, unsaved position for the same point.
    ref.read(poiMoveProvider.notifier).cancel();
    if (!subject.canPublish) {
      _toast('Nothing to publish — it matches OpenStreetMap');
      return;
    }
    final result = await showOsmReportSheet(context, subject);
    if (!mounted) return;
    switch (result.outcome) {
      case OsmReportOutcomeKind.cancelled:
        return;
      case OsmReportOutcomeKind.saved:
        _toast('Kept in your OpenStreetMap list');
      case OsmReportOutcomeKind.sent:
        _toast('Sent to OpenStreetMap — thank you');
    }
  }

  Future<void> _editName() async {
    final answer = await showDialog<_Edited>(
      context: context,
      builder: (_) => _EditValueDialog(
        title: 'Name',
        initial: widget.name ?? '',
        hint: 'Leave empty to clear',
        capitalization: TextCapitalization.words,
        validate: (_) => null,
      ),
    );
    if (answer == null || !mounted) return;
    final name = answer.value.trim();
    await _repo.updatePoiPoint(
      widget.id,
      name: Value<String?>(name.isEmpty ? null : name),
    );
    if (answer.publish && mounted) await _publish(_subject(name: name));
  }

  Future<void> _editPosition() async {
    final answer = await showDialog<_Edited>(
      context: context,
      builder: (_) => _EditValueDialog(
        title: 'Position',
        initial: formatLatLng(widget.lat, widget.lng),
        hint: 'lat, lng',
        keyboard: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        validate: (t) => parseLatLng(t) == null
            ? 'Not a position — try 48.137, 11.575'
            : null,
      ),
    );
    if (answer == null || !mounted) return;
    final p = parseLatLng(answer.value)!;
    await _repo.movePoiPoint(id: widget.id, lat: p.latitude, lng: p.longitude);
    if (answer.publish && mounted) {
      await _publish(_subject(lat: p.latitude, lng: p.longitude));
    }
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
    ref.read(poiMoveProvider.notifier).cancel();
    ref.read(selectedPoiPointProvider.notifier).select(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edited = widget.editedAt != null;
    final subject = _subject();
    // The newest report about this point, if any: what the Publish button's
    // neighbour says, so a place already sent does not look unpublished.
    final report = (ref.watch(osmReportsProvider).asData?.value ?? const [])
        .where((r) => r.poiPointId == widget.id)
        .firstOrNull;
    final name = widget.name?.trim();
    final moving = ref.watch(poiMoveProvider)?.pointId == widget.id;
    return EditorSheet(
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 20),
            const SizedBox(width: 8),
            Text(widget.title, style: theme.textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: 'Delete…',
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error,
              onPressed: () =>
                  unawaited(deletePoiPointFlow(context, ref, widget.id)),
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: _close,
            ),
          ],
        ),
        // Facts first, each with the button that changes it. A live text field
        // wrote on every keystroke — eleven undo steps for one name, and no
        // moment at which "save this, and publish it" could be asked.
        _Fact(
          label: 'Name',
          value: (name == null || name.isEmpty) ? 'No name' : name,
          dim: name == null || name.isEmpty,
          actions: [
            TextButton.icon(
              onPressed: () => unawaited(_editName()),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ],
        ),
        _Fact(
          label: 'Position',
          value: formatLatLng(widget.lat, widget.lng),
          actions: [
            TextButton.icon(
              onPressed: () => unawaited(_editPosition()),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            // Toggled, not a one-shot: while the pin is out, this is how it
            // goes away again besides the banner's Cancel.
            if (moving)
              FilledButton.tonalIcon(
                onPressed: _toggleMove,
                icon: const Icon(Icons.open_with, size: 18),
                label: const Text('Moving…'),
              )
            else
              TextButton.icon(
                onPressed: _toggleMove,
                icon: const Icon(Icons.open_with, size: 18),
                label: const Text('Move'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [widget.subtitle, if (widget.movable) 'placed by hand'].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (edited) ...[
          const SizedBox(height: 4),
          Text(
            'Corrected by you. OpenStreetMap still has '
            '${_upstreamDescription()}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
        if (report != null &&
            (subject.canPublish || report.sentAt != null)) ...[
          const SizedBox(height: 4),
          Text(
            report.sentAt != null
                ? 'Sent to OpenStreetMap'
                      '${report.noteId != null ? ' as note ${report.noteId}' : ''}.'
                : 'In your OpenStreetMap list, not sent yet.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (subject.canPublish) ...[
          const SizedBox(height: 8),
          const ServiceCreditLine(kGiveBackShort),
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
            // Only for a change of the user's own: something they placed, or
            // a correction. An untouched import *is* what OSM has.
            if (subject.canPublish)
              FilledButton.tonalIcon(
                onPressed: () => unawaited(_publish(subject)),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(
                  report?.sentAt != null
                      ? 'Publish again…'
                      : widget.movable
                      ? 'Publish to OpenStreetMap…'
                      : 'Publish this change…',
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
    final moved =
        widget.origLat != null &&
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

/// One labelled value with the buttons that change it.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    required this.actions,
    this.dim = false,
  });

  final String label;
  final String value;
  final List<Widget> actions;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A Wrap, not a Row: at a large system font the buttons drop below the
    // value instead of being clipped by the sheet (see `editor_sheet.dart`).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: scaledPx(context, 160)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: dim ? theme.colorScheme.onSurfaceVariant : null,
                    fontStyle: dim ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A changed value, and whether to publish it too.
typedef _Edited = ({String value, bool publish});

/// Edit one value, then **Save** or **Save & publish…** — the second only
/// saves first and then opens the publish sheet, so nothing leaves the device
/// without that sheet's own Send.
class _EditValueDialog extends StatefulWidget {
  const _EditValueDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.validate,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
  });

  final String title;
  final String initial;
  final String hint;
  final String? Function(String) validate;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;

  @override
  State<_EditValueDialog> createState() => _EditValueDialogState();
}

class _EditValueDialogState extends State<_EditValueDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done({required bool publish}) {
    if (widget.validate(_text.text) != null) return;
    Navigator.pop<_Edited>(context, (value: _text.text, publish: publish));
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.validate(_text.text);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: widget.keyboard,
        textCapitalization: widget.capitalization,
        decoration: InputDecoration(hintText: widget.hint, errorText: error),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _done(publish: false),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: error == null ? () => _done(publish: true) : null,
          child: const Text('Save & publish…'),
        ),
        FilledButton(
          onPressed: error == null ? () => _done(publish: false) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
