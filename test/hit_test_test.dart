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

import 'dart:ui' show Size;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/data/database.dart' as db;
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/ui/hit_test.dart';
import 'package:zonecraft/ui/object_summary.dart';
import 'package:zonecraft/data/poi_sets.dart';

HitCandidate candidate(
  String id, {
  bool inside = false,
  double edgeDistPx = 1000,
  double sizeProxyMeters = double.infinity,
  ObjectKind kind = ObjectKind.circle,
  int z = 0,
}) {
  return HitCandidate(
    ref: ObjectRef(kind: kind, id: id, layerId: 'L'),
    inside: inside,
    edgeDistPx: edgeDistPx,
    sizeProxyMeters: sizeProxyMeters,
    z: z,
  );
}

List<String> idsOf(List<HitCandidate> hits) =>
    [for (final h in hits) h.ref.id];

void main() {
  group('distToSegment', () {
    test('measures perpendicular distance inside the segment', () {
      expect(
        distToSegment(const Offset(5, 3), Offset.zero, const Offset(10, 0)),
        closeTo(3, 1e-9),
      );
    });

    test('clamps to the endpoints beyond the segment', () {
      expect(
        distToSegment(const Offset(-4, 3), Offset.zero, const Offset(10, 0)),
        closeTo(5, 1e-9),
      );
    });

    test('handles a degenerate (zero-length) segment', () {
      expect(
        distToSegment(const Offset(3, 4), Offset.zero, Offset.zero),
        closeTo(5, 1e-9),
      );
    });
  });

  group('pointInPolygon', () {
    final square = const [
      Offset(0, 0),
      Offset(10, 0),
      Offset(10, 10),
      Offset(0, 10),
    ];

    test('is true inside and false outside', () {
      expect(pointInPolygon(const Offset(5, 5), square), isTrue);
      expect(pointInPolygon(const Offset(15, 5), square), isFalse);
    });
  });

  group('rankCandidates', () {
    // v26 gave elements a draw order, so the genuinely ambiguous case — two
    // coincident shapes of the same size — can finally be arbitrated in favour
    // of the one the user can actually see.
    test('a tie is broken in favour of the element in front', () {
      final ranked = rankCandidates([
        candidate('back', inside: true, edgeDistPx: 900, sizeProxyMeters: 500, z: 0),
        candidate('front', inside: true, edgeDistPx: 900, sizeProxyMeters: 500, z: 3),
      ]);
      expect(idsOf(ranked).first, 'front');
    });

    test('a tie on the edge bucket is broken the same way', () {
      final ranked = rankCandidates([
        candidate('back', edgeDistPx: 3, z: 0),
        candidate('front', edgeDistPx: 3, z: 9),
      ]);
      expect(idsOf(ranked).first, 'front');
    });

    // The one thing z must never do. Promoted above `sizeProxyMeters` it would
    // let a big element in front swallow taps meant for a small one behind it,
    // which is exactly the failure the size rule exists to prevent.
    test('being in front never beats being the smaller target', () {
      final ranked = rankCandidates([
        candidate('big-front', inside: true, edgeDistPx: 900, sizeProxyMeters: 5e5, z: 99),
        candidate('small-back', inside: true, edgeDistPx: 900, sizeProxyMeters: 200, z: 0),
      ]);
      expect(idsOf(ranked).first, 'small-back');
    });

    test('boundary proximity wins over containment', () {
      // A tap 4 px from a small circle's rim, also deep inside a huge region.
      final ranked = rankCandidates([
        candidate('huge', inside: true, edgeDistPx: 900, sizeProxyMeters: 5e5),
        candidate('small', inside: true, edgeDistPx: 4, sizeProxyMeters: 200),
      ]);
      expect(idsOf(ranked), ['small', 'huge']);
    });

    test('nearest boundary first among several edges', () {
      final ranked = rankCandidates([
        candidate('far', edgeDistPx: 20),
        candidate('near', edgeDistPx: 3),
        candidate('mid', edgeDistPx: 11),
      ]);
      expect(idsOf(ranked), ['near', 'mid', 'far']);
    });

    test('away from every edge, the smallest container wins', () {
      final ranked = rankCandidates([
        candidate('plane',
            inside: true,
            edgeDistPx: 5000,
            sizeProxyMeters: double.infinity,
            kind: ObjectKind.subspace),
        candidate('big', inside: true, edgeDistPx: 400, sizeProxyMeters: 9000),
        candidate('tight', inside: true, edgeDistPx: 300, sizeProxyMeters: 80),
      ]);
      // An unbounded half-plane never beats a bounded region it contains.
      expect(idsOf(ranked), ['tight', 'big', 'plane']);
    });

    test('drops objects that are neither near an edge nor containing', () {
      final ranked = rankCandidates([
        candidate('miss', edgeDistPx: 300),
        candidate('hit', inside: true, edgeDistPx: 300, sizeProxyMeters: 10),
      ]);
      expect(idsOf(ranked), ['hit']);
    });

    test('caps the list so an overlapping pile stays readable', () {
      final ranked = rankCandidates([
        for (var i = 0; i < 20; i++)
          candidate('c$i', edgeDistPx: i.toDouble()),
      ]);
      expect(ranked, hasLength(kMaxHitCandidates));
      expect(idsOf(ranked).first, 'c0');
    });

    test('an empty input ranks to nothing', () {
      expect(rankCandidates(const []), isEmpty);
    });
  });

  // --- the imported types (schema v23: they became selectable) ---------------
  //
  // Until their editors landed these three had no `case` here at all, so a tap
  // on a POI, a station or a border area produced nothing and Edit mode was a
  // button that visibly did nothing.

  const center = LatLng(48.10, 11.50);
  final camera = MapCamera(
    crs: const Epsg3857(),
    center: center,
    zoom: 14,
    rotation: 0,
    nonRotatedSize: const Size(360, 800),
  );

  Layer layerOf(String type) => Layer(
        id: 'L',
        name: type,
        colorArgb: 0xFF000000,
        isVisible: true,
        sortOrder: 0,
        type: type,
        isInverted: false,
        opacity: 1,
        borderFillAreas: false,
        borderShowNames: false,
        createdAt: DateTime(2026),
      );

  group('collectCandidates on a poi layer', () {
    final set = PoiSet(
      id: 'S',
      layerId: 'L',
      categoryKey: 'cafe',
      centerLat: center.latitude,
      centerLng: center.longitude,
      radiusMeters: 800,
      createdAt: DateTime(2026),
      colorShade: 0,
      source: kPoiSourceRadius,
      zOrder: 0,
      modeMask: 0,
      visibleModeMask: -1,
    );
    PoiPoint poi(String id, LatLng at) => PoiPoint(
          id: id,
          poiSetId: 'S',
          lat: at.latitude,
          lng: at.longitude,
          sortOrder: 0,
          createdAt: DateTime(2026),
          modeMask: 0,
        );

    test('a tap on a marker offers that POI, not its set', () {
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('poi'),
        poiSets: [set],
        poiPoints: [poi('p1', center)],
      );
      expect(hits, hasLength(1));
      expect(hits.single.ref.kind, ObjectKind.poiPoint);
      expect(hits.single.ref.id, 'p1');
      expect(hits.single.edgeDistPx, closeTo(0, 0.5));
    });

    test('a marker has no interior, so distant ground never ranks it', () {
      final hits = collectCandidates(
        camera: camera,
        tap: const LatLng(48.2, 11.7),
        layer: layerOf('poi'),
        poiSets: [set],
        poiPoints: [poi('p1', center)],
      );
      // Collected, but far and not "inside" — which is what rankCandidates
      // drops. A POI that ranked from a screen away would make every tap on
      // empty ground select something.
      expect(hits.single.inside, isFalse);
      expect(rankCandidates(hits), isEmpty);
    });

    test('POIs from another layer are not offered', () {
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('poi'),
        poiSets: [set.copyWith(layerId: 'OTHER')],
        poiPoints: [poi('p1', center)],
      );
      expect(hits, isEmpty);
    });
  });

  group('collectCandidates on a poi layer with a station import', () {
    PoiSet setWith(int visible) => PoiSet(
          id: 'S',
          layerId: 'L',
          categoryKey: kTransitStationCategoryKey,
          centerLat: 48.1,
          centerLng: 11.5,
          radiusMeters: 1,
          source: kPoiSourceBox,
          south: 48.0,
          west: 11.4,
          north: 48.2,
          east: 11.6,
          modeMask: 3,
          visibleModeMask: visible,
          createdAt: DateTime(2026),
          colorShade: 0,
          zOrder: 0,
        );
    final stop = PoiPoint(
      id: 's1',
      poiSetId: 'S',
      osmType: 'node',
      osmId: 42,
      lat: center.latitude,
      lng: center.longitude,
      sortOrder: 0,
      modeMask: 1,
      createdAt: DateTime(2026),
    );

    test('a tap on a station offers it', () {
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('poi'),
        poiSets: [setWith(3)],
        poiPoints: [stop],
      );
      expect(hits, hasLength(1));
      expect(hits.single.ref.kind, ObjectKind.poiPoint);
      expect(hits.single.ref.id, 's1');
    });

    test('a station the type filter hides is not tappable', () {
      // Picking a marker that isn't drawn is indistinguishable from the app
      // choosing at random.
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('poi'),
        poiSets: [setWith(2)], // bit 1 (this stop's mode) not shown
        poiPoints: [stop],
      );
      expect(hits, isEmpty);
    });

    test('a station whose modes OSM never said stays tappable', () {
      // modeMask 0 means "the data doesn't say", and the painter draws those —
      // so hiding them from taps would strand them.
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('poi'),
        poiSets: [setWith(2)],
        poiPoints: [stop.copyWith(modeMask: 0)],
      );
      expect(hits, hasLength(1));
    });

    test('unticking every type makes even a typeless station untappable', () {
      // The case the two copies of this rule used to disagree on: "does the
      // station share a bit with the filter?" is true-by-exception for
      // modeMask 0, so a mode-less station survived a filter of 0 here while
      // the painter (which special-cases the empty filter first) drew nothing.
      // The result was an invisible marker answering a tap on blank ground.
      for (final mask in [0, 1, 2]) {
        expect(
          collectCandidates(
            camera: camera,
            tap: center,
            layer: layerOf('poi'),
            poiSets: [setWith(0)],
            poiPoints: [stop.copyWith(modeMask: mask)],
          ),
          isEmpty,
          reason: 'station modeMask $mask with nothing shown',
        );
      }
    });

    test('the filter never touches a radius or hand-made set', () {
      // A mode-less point in an ordinary set must always draw and tap: the
      // filter is a property of station imports, and a cafe has no modes.
      for (final source in [kPoiSourceRadius, kPoiSourceManual]) {
        final hits = collectCandidates(
          camera: camera,
          tap: center,
          layer: layerOf('poi'),
          poiSets: [setWith(0).copyWith(source: source)],
          poiPoints: [stop.copyWith(modeMask: 0)],
        );
        expect(hits, hasLength(1), reason: source);
      }
    });

    test('the hit test and the painter agree on every filter', () {
      // One predicate, two readers — this is the assertion that keeps them
      // from drifting again rather than just fixing today's disagreement.
      for (final stationMask in [0, 1, 2, 3]) {
        for (final visible in [0, 1, 2, 3]) {
          final st = stop.copyWith(modeMask: stationMask);
          final set = setWith(visible);
          final drawn = poiPointVisible(st, set);
          final tappable = collectCandidates(
            camera: camera,
            tap: center,
            layer: layerOf('poi'),
            poiSets: [set],
            poiPoints: [st],
          );
          expect(
            tappable.isNotEmpty,
            drawn,
            reason: 'station $stationMask, visible $visible',
          );
        }
      }
    });
  });

  group('collectCandidates on a combined layer', () {
    final circle = db.Circle(
      id: 'c1',
      layerId: 'L',
      centerLat: center.latitude,
      centerLng: center.longitude,
      radiusMeters: 400,
      createdAt: DateTime(2026),
      colorShade: 0,
      zOrder: 0,
    );
    final sub = db.Subspace(
      id: 'p1',
      layerId: 'L',
      createdAt: DateTime(2026),
      colorShade: 0,
      zOrder: 0,
    );
    final subPoints = [
      db.SubspacePoint(
        id: 'a',
        subspaceId: 'p1',
        lat: center.latitude,
        lng: center.longitude,
        sortOrder: 0,
        isMain: true,
        createdAt: DateTime(2026),
      ),
      db.SubspacePoint(
        id: 'b',
        subspaceId: 'p1',
        lat: center.latitude + 0.5,
        lng: center.longitude + 0.5,
        sortOrder: 1,
        isMain: false,
        createdAt: DateTime(2026),
      ),
    ];

    test('it offers every type the layer holds, from one tap', () {
      // The painter draws all of them, so all of them have to be tappable —
      // the same predicate on both sides. A switch on `layer.type` returned
      // nothing at all here, which looks exactly like "empty ground".
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf(kMixedType),
        circles: [circle],
        subspaces: [sub],
        subspacePoints: subPoints,
      );
      expect(
        hits.map((h) => h.ref.kind).toSet(),
        {ObjectKind.circle, ObjectKind.subspace},
      );
    });

    test('a single-type layer still sees only its own', () {
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('circles'),
        circles: [circle],
        subspaces: [sub],
        subspacePoints: subPoints,
      );
      expect(hits.map((h) => h.ref.kind).toSet(), {ObjectKind.circle});
    });

    test('it never offers borders, which a combined layer cannot hold', () {
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf(kMixedType),
        borderShapes: [
          BorderShapeRef(
            id: 'a1',
            rings: const [
              [
                LatLng(48.0, 11.4),
                LatLng(48.0, 11.6),
                LatLng(48.2, 11.6),
                LatLng(48.2, 11.4),
              ]
            ],
            south: 48.0,
            west: 11.4,
            north: 48.2,
            east: 11.6,
          ),
        ],
      );
      expect(hits, isEmpty);
    });
  });
}
