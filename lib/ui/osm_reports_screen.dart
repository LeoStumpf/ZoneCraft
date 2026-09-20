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

/// Every correction you have written, sent or not — the outbox.
///
/// **Nothing on this screen sends itself.** There is no timer, no flush when
/// the network returns, no send-on-launch; a note leaves on a press and only
/// on a press. That is OSM's "create no automated notes" rule written into the
/// structure rather than into a comment on a button, and it is why an unsent
/// report is a to-do item rather than a queue entry.
///
/// The reason the screen exists at all is the second route out. A mapper with
/// an account may quite reasonably not want to file anonymous notes: they can
/// keep their reports here, **export the lot as GeoJSON**, open it in JOSM or
/// QGIS as a to-do layer and work through it under their own name. Which is
/// also why a sent report stays listed with a link to its note — a
/// contribution you cannot find again is one you cannot follow up.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/osm_notes.dart';
import '../data/osm_report.dart';
import '../data/repository.dart';
import '../state/providers.dart';
import 'external_link.dart';
import 'import_actions.dart';

class OsmReportsScreen extends ConsumerStatefulWidget {
  const OsmReportsScreen({super.key});

  @override
  ConsumerState<OsmReportsScreen> createState() => _OsmReportsScreenState();
}

class _OsmReportsScreenState extends ConsumerState<OsmReportsScreen> {
  /// Probed once for the whole screen, as every other screen with links does:
  /// `canLaunchUrl` throws with no platform implementation, and a link that
  /// silently does nothing is worse than plain text.
  bool _canOpenLinks = false;

  /// The report currently being sent, so only its row shows a spinner.
  String? _sending;

  Repository get _repo => ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
  }

  Future<void> _probe() async {
    final ok = await canLaunchExternalUrl(
      Uri.parse('https://www.openstreetmap.org'),
    );
    if (mounted) setState(() => _canOpenLinks = ok);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send(OsmReport report) async {
    // The hard cap applies here too, or the outbox would be the way around
    // the limit the sheet enforces.
    final today = await _repo.osmReportsSentSince(const Duration(days: 1));
    if (today >= kOsmReportsHardCapPerDay) {
      _toast(
        'That is as many reports as OpenStreetMap accepts anonymously '
        'in a day. Try tomorrow, or export them.',
      );
      return;
    }
    setState(() => _sending = report.id);
    final outcome = await submitOsmNote(
      lat: report.lat,
      lng: report.lng,
      text: report.body,
    );
    if (outcome.ok) {
      await _repo.markOsmReportSent(report.id, outcome.noteId!);
      _toast('Sent — note ${outcome.noteId}');
    } else {
      await _repo.markOsmReportFailed(report.id, outcome.message!);
      _toast(outcome.message!);
    }
    if (mounted) setState(() => _sending = null);
  }

  Future<void> _edit(OsmReport report) async {
    final controller = TextEditingController(text: report.body);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit report'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || saved.isEmpty) return;
    await _repo.updateOsmReport(report.id, body: saved);
  }

  Future<void> _delete(OsmReport report) async {
    await _repo.deleteOsmReport(report.id);
    _toast(
      report.sentAt == null
          ? 'Report discarded'
          : 'Removed from this list — the note stays on OpenStreetMap',
    );
  }

  Future<void> _export(List<OsmReport> reports) async {
    final destination = await askExportDestination(
      context,
      title: 'Export reports',
      message:
          'A GeoJSON point per report, with its text and the element it '
          'is about — a to-do layer for JOSM or QGIS.',
    );
    if (destination == null || !mounted) return;
    await deliverFile(
      context,
      content: osmReportsGeoJson(reports),
      fileName: 'zonecraft-reports-${exportStamp()}.geojson',
      mimeType: 'application/geo+json',
      destination: destination,
      subject: 'ZoneCraft — OpenStreetMap reports',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reports = ref.watch(osmReportsProvider).asData?.value ?? const [];
    final unsent = reports.where((r) => r.sentAt == null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenStreetMap outbox'),
        actions: [
          IconButton(
            tooltip: 'Export all reports',
            icon: const Icon(Icons.ios_share),
            onPressed: reports.isEmpty
                ? null
                : () => unawaited(_export(reports)),
          ),
        ],
      ),
      body: reports.isEmpty
          ? _empty(theme)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  unsent == 0
                      ? 'Everything here has been sent. Tap a note number to '
                            'see what mappers have made of it.'
                      : '$unsent waiting to be sent. Nothing leaves this '
                            'device until you press Send.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                for (final r in reports) ...[
                  _ReportCard(
                    report: r,
                    canOpenLinks: _canOpenLinks,
                    sending: _sending == r.id,
                    onSend: () => unawaited(_send(r)),
                    onEdit: () => unawaited(_edit(r)),
                    onDelete: () => unawaited(_delete(r)),
                    onCopy: () async {
                      await Clipboard.setData(ClipboardData(text: r.body));
                      _toast('Report copied');
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _empty(ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing to report yet',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap an imported POI on the map and correct it — the editor '
            'then offers to pass the correction on. Reports you keep here '
            'can be exported as a file for someone to file under their '
            'own OpenStreetMap account.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.canOpenLinks,
    required this.sending,
    required this.onSend,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
  });

  final OsmReport report;
  final bool canOpenLinks;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = OsmReportKind.byName(report.kind);
    final sent = report.sentAt != null;
    final noteUrl = report.noteId == null ? null : osmNoteUrl(report.noteId!);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sent ? Icons.check_circle_outline : Icons.inbox_outlined,
                  size: 18,
                  color: sent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kind?.label ?? report.kind,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  _day(report.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(report.body, style: theme.textTheme.bodySmall),
            if (report.lastError != null && !sent) ...[
              const SizedBox(height: 8),
              Text(
                report.lastError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 4),
            if (sending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => unawaited(onCopy()),
                    icon: const Icon(Icons.copy_all_outlined, size: 16),
                    label: const Text('Copy'),
                  ),
                  if (sent && noteUrl != null)
                    TextButton.icon(
                      // Without a browser the number is still printed above;
                      // a dead button would be worse than none.
                      onPressed: canOpenLinks
                          ? () => unawaited(
                              openExternalUrl(
                                Uri.parse(noteUrl),
                                context: context,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text('Note ${report.noteId}'),
                    ),
                  if (!sent) ...[
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onSend,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: Text(
                        report.lastError == null ? 'Send' : 'Try again',
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: sent ? 'Remove from this list' : 'Discard',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: theme.colorScheme.error,
                    onPressed: onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _day(DateTime when) {
    final local = when.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
