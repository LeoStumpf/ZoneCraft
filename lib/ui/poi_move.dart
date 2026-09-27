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
import 'package:latlong2/latlong.dart';

import '../data/osm_report.dart' show compassName, describeOffset;
import '../geo/measure.dart' show distanceMeters;
import '../state/providers.dart';
import 'theme.dart' show MapChrome;

/// The banner a point move raises: how far the pin is from where the point is
/// stored, and Cancel / Save — plus Save & publish when [canPublish] (a point
/// that came from OpenStreetMap, whose correction is worth passing on).
///
/// A `Wrap`, not a `Row`: three buttons and a sentence do not fit one line on
/// a Pixel 4a at a large font, and a banner clips silently.
class PointMoveBanner extends StatelessWidget {
  const PointMoveBanner({
    super.key,
    required this.move,
    required this.onCancel,
    required this.onSave,
    required this.onSaveAndPublish,
    this.canPublish = true,
  });

  final PointMove move;
  final bool canPublish;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onSaveAndPublish;

  @override
  Widget build(BuildContext context) {
    return MapChrome(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_with, size: 16),
                  const SizedBox(width: 6),
                  Flexible(child: Text(pointMoveBannerText(move))),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                  if (canPublish)
                    TextButton(
                      onPressed: move.moved ? onSaveAndPublish : null,
                      child: const Text('Save & publish…'),
                    ),
                  FilledButton(
                    onPressed: move.moved ? onSave : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the move banner says: an instruction until the pin has moved, then
/// the distance and direction from where the point is stored.
String pointMoveBannerText(PointMove move) {
  if (!move.moved) return 'Drag the pin, or tap where it really is';
  final meters = distanceMeters(move.from, move.to);
  final bearing = const Distance().bearing(move.from, move.to);
  return 'Moved ${describeOffset(meters)} ${compassName(bearing)}';
}

/// The editors' **Move** button for one point: starts the map's move mode on
/// it — the pin, the dashed line, the ring round the point, the banner — and,
/// pressed again while that point is moving, puts the pin away.
///
/// Lit while its point is the one moving, so a list of eight identical rows
/// says which of them the ringed dot on the map is.
class PointMoveButton extends ConsumerWidget {
  const PointMoveButton({
    super.key,
    required this.pointId,
    required this.lat,
    required this.lng,
    required this.target,
    this.tooltip = 'Move on the map',
  });

  final String pointId;
  final double lat;
  final double lng;
  final PointMoveTarget target;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moving = ref.watch(pointMoveProvider)?.pointId == pointId;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: moving ? 'Stop moving' : tooltip,
      isSelected: moving,
      style: moving
          ? IconButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
            )
          : null,
      icon: const Icon(Icons.open_with),
      onPressed: () {
        final moves = ref.read(pointMoveProvider.notifier);
        if (moving) {
          moves.cancel();
          return;
        }
        moves.start(pointId, LatLng(lat, lng), target: target);
      },
    );
  }
}
