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
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/data/serialization.dart'
    show layerTypeForExportKind, legacyLayerType;

void main() {
  Layer layer(String type) => Layer(
    id: 'l',
    name: 'L',
    colorArgb: 1,
    isVisible: true,
    sortOrder: 0,
    type: type,
    isInverted: false,
    opacity: 1,
    borderFillAreas: false,
    borderShowNames: false,
    createdAt: DateTime(2026),
  );

  /// The seven object types, i.e. everything except `mixed`.
  final objectTypes = kAllLayerTypes.toList();

  test('the catalogue is complete and has no duplicates', () {
    expect(kAllLayerTypes.toSet().length, kAllLayerTypes.length);
    expect(objectTypes, hasLength(7));
    // Every mixed content type is a real object type, and borders is not one.
    for (final t in kMixedContentTypes) {
      expect(objectTypes, contains(t));
    }
    expect(kMixedContentTypes, isNot(contains(kBorders)));
    expect(kMixedContentTypes, hasLength(6));
  });

  group('layerHolds', () {
    test('a single-type layer holds exactly its own type', () {
      // Exhaustive over every (layer type × object type) pair, so an eighth
      // type added to the schema fails here rather than somewhere subtle.
      for (final lt in objectTypes) {
        for (final ot in objectTypes) {
          expect(
            layerHolds(layer(lt), ot),
            ot == lt,
            reason: 'a "$lt" layer and a "$ot" object',
          );
        }
      }
    });

    test('nothing holds an unknown type', () {
      for (final lt in kAllLayerTypes) {
        expect(layerHolds(layer(lt), 'no-such-type'), isFalse);
      }
    });
  });

  group('layerContentTypes', () {
    test('a single-type layer yields exactly itself', () {
      for (final lt in objectTypes) {
        expect(layerContentTypes(layer(lt)), [lt]);
      }
    });

    test('the retired mixed set keeps the draw order the split needs', () {
      // Legacy, and load-bearing: the v30 migration and the v3 file reader
      // both stack the layers they split out in this order, so an upgraded map
      // looks like the one it replaced. Markers last — they are labels and
      // have to stay legible over the fills.
      expect(kMixedContentTypes.first, kCircles);
      expect(kMixedContentTypes.last, kPoi);
      expect(kMixedContentTypes, isNot(contains(kBorders)));
    });

    test('it agrees with layerHolds, for every type', () {
      for (final lt in kAllLayerTypes) {
        final held = layerContentTypes(layer(lt));
        for (final ot in objectTypes) {
          expect(
            held.contains(ot),
            layerHolds(layer(lt), ot),
            reason: '"$lt" vs "$ot"',
          );
        }
      }
    });
  });

  group('kInvertibleTypes', () {
    test('is exactly the region types whose painter honours invert', () {
      // `height` draws a region but ignores `inverted` (its band follows the
      // elevation contour), and markers and separate areas have no single
      // outside — so offering "Fill outside" for any of them would be a
      // toggle that writes the database and changes nothing.
      expect(kInvertibleTypes, [kCircles, kSubspace, kFreeLine, kFreeArea]);
      for (final t in [kHeight, kPoi, kBorders]) {
        expect(kInvertibleTypes, isNot(contains(t)), reason: t);
      }
    });
  });

  group('layerTypeForExportKind', () {
    test('every object type is reachable from some export kind', () {
      // The two vocabularies differ ('circle' vs 'circles'), so a gap here
      // means a file's objects silently fail the merge check.
      final reachable = {
        for (final k in const [
          'circle',
          'subspace',
          'freeline',
          'freearea',
          'height',
          'poi',
          'borderarea',
        ])
          layerTypeForExportKind(k),
      };
      expect(reachable, containsAll(objectTypes));
      expect(reachable, isNot(contains(null)));
    });

    test(
      'the retired v1/v2 kinds and layer types translate, track is dropped',
      () {
        // A file written before v27 still has to open. The kinds are mapped by
        // `_featureToObject`; this is the layer-type half of the same promise.
        expect(
          layerTypeForExportKind('plane'),
          isNull,
          reason: 'the reader translates it before this is consulted',
        );
        expect(legacyLayerType('planes'), kSubspace);
        expect(legacyLayerType('transit'), kPoi);
        expect(legacyLayerType('track'), isNull);
        for (final t in kAllLayerTypes) {
          expect(
            legacyLayerType(t),
            t,
            reason: 'today\'s types are themselves',
          );
        }
      },
    );

    test('an unknown kind maps to null rather than guessing', () {
      expect(layerTypeForExportKind('somethingelse'), isNull);
    });
  });
}
