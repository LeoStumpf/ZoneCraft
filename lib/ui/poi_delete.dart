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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/osm_report.dart';
import '../data/poi_sets.dart';
import '../state/providers.dart';
import 'osm_report_sheet.dart';

/// What the delete question was answered with.
enum PoiDeleteChoice { cancel, delete, deleteAndPublish }

/// **The one way a single POI is deleted**, from the editor or the Elements
/// list: ask first, and — for something OpenStreetMap has — offer to tell it
/// the place is gone in the same breath.
///
/// The two belong together because they are one thought. You delete your copy
/// of an imported bench because it is not there any more; that is exactly the
/// moment the fix is worth passing on, and asking later would be asking about
/// something the user can no longer see. A hand-placed point was never on OSM,
/// so it is only asked about.
///
/// The note is composed **before** the delete, since it quotes the point, and
/// the delete happens whatever the sheet ends with: the choice made was
/// "delete", and publishing was the extra. Undo brings the point back.
///
/// Returns true when the point was deleted.
Future<bool> deletePoiPointFlow(
  BuildContext context,
  WidgetRef ref,
  String pointId,
) async {
  final point = (ref.read(poiPointsProvider).asData?.value ?? const [])
      .where((p) => p.id == pointId)
      .firstOrNull;
  if (point == null) return false;
  final sets = ref.read(poiSetsProvider).asData?.value ?? const <PoiSet>[];
  final subject = osmSubjectFor(point, sets);
  final choice = await showDialog<PoiDeleteChoice>(
    context: context,
    builder: (ctx) => _DeleteDialog(point: point, subject: subject),
  );
  if (choice == null || choice == PoiDeleteChoice.cancel) return false;
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  String? outcome;
  if (choice == PoiDeleteChoice.deleteAndPublish) {
    final result = await showOsmReportSheet(
      context,
      subject,
      kind: OsmReportKind.gone,
    );
    outcome = switch (result.outcome) {
      OsmReportOutcomeKind.cancelled => null,
      OsmReportOutcomeKind.saved => 'kept in your OpenStreetMap list',
      OsmReportOutcomeKind.sent => 'OpenStreetMap told — thank you',
    };
  }
  await ref.read(repositoryProvider).deletePoiPoint(pointId);
  if (ref.read(selectedPoiPointProvider) == pointId) {
    ref.read(selectedPoiPointProvider.notifier).select(null);
  }
  messenger
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(outcome == null ? 'Deleted' : 'Deleted, and $outcome'),
      ),
    );
  return true;
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.point, required this.subject});

  final PoiPoint point;
  final OsmReportSubject subject;

  @override
  Widget build(BuildContext context) {
    final name = point.name?.trim();
    final what = (name == null || name.isEmpty) ? 'this place' : '“$name”';
    final canTell = subject.canReportGone;
    return AlertDialog(
      title: Text('Delete $what?'),
      content: Text(
        canTell
            ? 'This removes your copy only — OpenStreetMap still has it. '
                  'If it is really gone on the ground, you can tell '
                  'OpenStreetMap too.'
            : 'Undo will bring it back.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, PoiDeleteChoice.cancel),
          child: const Text('Cancel'),
        ),
        if (canTell)
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(context, PoiDeleteChoice.deleteAndPublish),
            child: const Text('Delete & tell OSM…'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, PoiDeleteChoice.delete),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
