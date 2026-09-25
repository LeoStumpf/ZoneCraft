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

/// Publishing one change you made — a place you added, moved or renamed —
/// and deciding what happens to it: send it now, or keep it in your list.
///
/// Three things here are load-bearing rather than decorative:
///
/// - **The draft is editable, and Send is off until it says something.**
///   OSM's guidance is that notes are human-to-human communication and that
///   apps must "create no automated notes"; a prefilled field somebody reads
///   and changes is a human writing, a prefilled field wired straight to a
///   Send button is not.
/// - **The standing warning is shown every time**, never counted down by
///   `UiHints`. OSM asks apps to make users aware that this is for map data
///   and not for feedback about the app, and a warning that goes quiet after
///   three showings stops doing that for exactly the people who have got
///   comfortable enough to be careless.
/// - **Save for later is a first-class button, not a fallback.** It is the
///   whole second half of the feature: a mapper with an account can keep the
///   reports, export them and file them properly under their own name.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/osm_notes.dart';
import '../data/osm_report.dart';
import '../data/repository.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';

/// What the sheet decided, so the caller can say so.
enum OsmReportOutcomeKind { cancelled, saved, sent }

class OsmReportResult {
  const OsmReportResult(this.outcome, {this.kind});

  final OsmReportOutcomeKind outcome;
  final OsmReportKind? kind;
}

/// Opens the report form over [subject]. Returns what was decided.
///
/// [kind] overrides the one the subject's own change implies — the delete
/// flow passes [OsmReportKind.gone], which no edit implies.
///
/// A modal route rather than the map's `bottomSheet` slot: unlike an editor,
/// this is not something you leave open while you look at the map, and the
/// slot is already shared by four other things.
Future<OsmReportResult> showOsmReportSheet(
  BuildContext context,
  OsmReportSubject subject, {
  OsmReportKind? kind,
}) async {
  final result = await showModalBottomSheet<OsmReportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OsmReportSheet(subject: subject, kind: kind),
  );
  return result ?? const OsmReportResult(OsmReportOutcomeKind.cancelled);
}

class _OsmReportSheet extends ConsumerStatefulWidget {
  const _OsmReportSheet({required this.subject, this.kind});

  final OsmReportSubject subject;
  final OsmReportKind? kind;

  @override
  ConsumerState<_OsmReportSheet> createState() => _OsmReportSheetState();
}

class _OsmReportSheetState extends ConsumerState<_OsmReportSheet> {
  late OsmReportKind _kind;
  late final TextEditingController _text;

  /// True once the human has touched the draft. Used only to decide whether
  /// changing the *kind* may rewrite the field — never to gate Send, because
  /// a draft somebody read and agreed with is as deliberate as one they
  /// retyped, and refusing it would just teach people to add a full stop.
  bool _touched = false;

  bool _sending = false;
  String? _error;

  /// Notes actually delivered in the last day, or null while it is being
  /// counted. See [kOsmReportsSoftCapPerDay].
  int? _sentToday;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _kind = widget.kind ?? widget.subject.defaultKind;
    _text = TextEditingController(
      text: composeOsmReportText(_kind, widget.subject),
    );
    unawaited(_countRecent());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _countRecent() async {
    final n = await _repo.osmReportsSentSince(const Duration(days: 1));
    if (mounted) setState(() => _sentToday = n);
  }

  void _pickKind(OsmReportKind kind) {
    setState(() {
      _kind = kind;
      // An untouched draft follows the chips; one somebody has written in is
      // theirs, and silently replacing it would be the worst moment to do so.
      if (!_touched) {
        _text.text = composeOsmReportText(kind, widget.subject);
      }
    });
  }

  Future<String> _store() {
    final anchor = osmReportAnchor(_kind, widget.subject);
    return _repo.createOsmReport(
      lat: anchor.latitude,
      lng: anchor.longitude,
      kind: _kind.name,
      body: _text.text.trim(),
      osmType: widget.subject.osmType,
      osmId: widget.subject.osmId,
      poiPointId: widget.subject.poiPointId,
    );
  }

  Future<void> _save() async {
    await _store();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(OsmReportResult(OsmReportOutcomeKind.saved, kind: _kind));
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    // Stored *before* the attempt, not after: if the app dies mid-request the
    // report is still in the outbox, and a row with no note number is exactly
    // what the retry row is for.
    final id = await _store();
    final anchor = osmReportAnchor(_kind, widget.subject);
    final outcome = await submitOsmNote(
      lat: anchor.latitude,
      lng: anchor.longitude,
      text: _text.text.trim(),
    );
    if (outcome.ok) {
      await _repo.markOsmReportSent(id, outcome.noteId!);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(OsmReportResult(OsmReportOutcomeKind.sent, kind: _kind));
      return;
    }
    await _repo.markOsmReportFailed(id, outcome.message!);
    if (!mounted) return;
    // The sheet stays open with the text intact. The row is already saved, so
    // the failure costs nothing but the attempt.
    setState(() {
      _sending = false;
      _error = outcome.message;
    });
    unawaited(_countRecent());
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Report copied')));
  }

  /// Why Send cannot be pressed, or null when it can.
  String? get _sendBlocked {
    if (_text.text.trim().isEmpty) return 'A report needs something to say.';
    if (_text.text.trim().length > kOsmReportMaxChars) {
      return 'That is longer than a mapper will read. Trim it a little.';
    }
    final sent = _sentToday;
    if (sent != null && sent >= kOsmReportsHardCapPerDay) {
      return 'You have sent $sent reports today, which is as many as '
          'OpenStreetMap accepts anonymously. Save this one — it can still be '
          'exported, or sent tomorrow.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A forced kind is the whole choice; otherwise at most one is offered.
    final kinds = widget.kind != null
        ? [widget.kind!]
        : widget.subject.availableKinds;
    final blocked = _sendBlocked;
    final sent = _sentToday ?? 0;
    final length = _text.text.trim().length;

    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.volunteer_activism_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Publish to OpenStreetMap',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        if (kinds.length > 1) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final kind in kinds)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: _sending ? null : (_) => _pickKind(kind),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 8,
          enabled: !_sending,
          onChanged: (_) => setState(() => _touched = true),
          decoration: InputDecoration(
            labelText: 'What should a mapper know?',
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            counterText: '$length / $kOsmReportMaxChars',
            errorText: length > kOsmReportMaxChars
                ? 'Too long for a note.'
                : null,
          ),
        ),
        const SizedBox(height: 8),
        // Every time, never counted down. See the library doc.
        Text(
          'This goes to OpenStreetMap’s volunteer mappers. It is public and '
          'permanent, and it is for map data only — not for feedback about '
          'ZoneCraft. Please don’t include personal information.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!osmApiIsLive) ...[
          const SizedBox(height: 8),
          Text(
            'This build sends to $osmApiHost, not to OpenStreetMap itself.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
        if (sent >= kOsmReportsSoftCapPerDay && blocked == null) ...[
          const SizedBox(height: 8),
          Text(
            'You have sent $sent reports today. OpenStreetMap limits anonymous '
            'reports — beyond a handful a day, saving them and exporting the '
            'file is the kinder route.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            '$_error\n\nIt is saved in your outbox either way.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (blocked != null && _text.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            blocked,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_sending)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy'),
              ),
              OutlinedButton.icon(
                onPressed: _text.text.trim().isEmpty
                    ? null
                    : () => unawaited(_save()),
                icon: const Icon(Icons.inbox_outlined, size: 18),
                label: const Text('Keep in my list'),
              ),
              FilledButton.icon(
                onPressed: blocked != null ? null : () => unawaited(_send()),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Send now'),
              ),
            ],
          ),
      ],
    );
  }
}
