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
import 'package:latlong2/latlong.dart';

import '../data/osm_report.dart' show compassName, describeOffset;
import '../geo/measure.dart' show distanceMeters;
import '../state/providers.dart';
import 'theme.dart' show MapChrome;

/// The banner a POI move raises: how far the pin is from where the point is
/// stored, and Cancel / Save / Save & publish.
///
/// A `Wrap`, not a `Row`: three buttons and a sentence do not fit one line on
/// a Pixel 4a at a large font, and a banner clips silently.
class PoiMoveBanner extends StatelessWidget {
  const PoiMoveBanner({
    super.key,
    required this.move,
    required this.onCancel,
    required this.onSave,
    required this.onSaveAndPublish,
  });

  final PoiMove move;
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
                  Flexible(child: Text(poiMoveBannerText(move))),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
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
String poiMoveBannerText(PoiMove move) {
  if (!move.moved) return 'Drag the pin, or tap where it really is';
  final meters = distanceMeters(move.from, move.to);
  final bearing = const Distance().bearing(move.from, move.to);
  return 'Moved ${describeOffset(meters)} ${compassName(bearing)}';
}
