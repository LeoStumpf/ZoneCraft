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

import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/ui/border_layer.dart';
import 'package:zonecraft/ui/object_summary.dart';
import 'package:zonecraft/ui/poi_groups.dart';
import 'package:zonecraft/ui/transit_modes_sheet.dart';

/// Families keyed on a layer id must not outlive the layer.
///
/// Riverpod 3 did **not** flip the autoDispose default — verified in the
/// installed source, where `Provider` and `Provider.family` both declare
/// `isAutoDispose = false`. When the last listener goes the element *pauses*,
/// so nothing keeps recomputing, but it keeps its last value for the life of
/// the container.
///
/// For three of these that is a small map of summaries. For
/// [borderShapesProvider] it is every ring of every area in the layer, already
/// decoded from JSON — which this repo's own comments size at 119 238 points
/// for a state-sized import. Delete that layer and the rings stay resident for
/// the rest of the session, because a paused provider never recomputes to the
/// empty list that would replace them.
void main() {
  test('every layer-keyed family disposes with its layer', () {
    final families = {
      'borderShapesProvider': borderShapesProvider,
      'layerSummariesProvider': layerSummariesProvider,
      'poiTypeGroupsProvider': poiTypeGroupsProvider,
      'transitTallyProvider': transitTallyProvider,
    };

    for (final entry in families.entries) {
      expect(
        entry.value('any-layer-id').isAutoDispose,
        isTrue,
        reason: '${entry.key} keeps its last value once the layer is gone',
      );
    }
  });
}
