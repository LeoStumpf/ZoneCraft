import 'dart:ui' show Size;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/hit_test.dart';
import 'package:zonecraft/ui/object_summary.dart';
import 'package:zonecraft/ui/transit_layer.dart' show visibleTransitStations;

HitCandidate candidate(
  String id, {
  bool inside = false,
  double edgeDistPx = 1000,
  double sizeProxyMeters = double.infinity,
  ObjectKind kind = ObjectKind.circle,
}) {
  return HitCandidate(
    ref: ObjectRef(kind: kind, id: id, layerId: 'L'),
    inside: inside,
    edgeDistPx: edgeDistPx,
    sizeProxyMeters: sizeProxyMeters,
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
            kind: ObjectKind.plane),
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
    );
    PoiPoint poi(String id, LatLng at) => PoiPoint(
          id: id,
          poiSetId: 'S',
          lat: at.latitude,
          lng: at.longitude,
          sortOrder: 0,
          createdAt: DateTime(2026),
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

  group('collectCandidates on a transit layer', () {
    TransitSet setWith(int visible) => TransitSet(
          id: 'S',
          layerId: 'L',
          south: 48.0,
          west: 11.4,
          north: 48.2,
          east: 11.6,
          modeMask: 3,
          visibleModeMask: visible,
          stationCount: 1,
          nodeCount: 1,
          createdAt: DateTime(2026),
          colorShade: 0,
        );
    final stop = TransitStop(
      id: 's1',
      setId: 'S',
      osmId: 42,
      lat: center.latitude,
      lng: center.longitude,
      modeMask: 1,
      nodeCount: 1,
      createdAt: DateTime(2026),
    );

    test('a tap on a station offers it', () {
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('transit'),
        transitSets: [setWith(3)],
        transitStops: [stop],
      );
      expect(hits, hasLength(1));
      expect(hits.single.ref.kind, ObjectKind.transitStop);
      expect(hits.single.ref.id, 's1');
    });

    test('a station the type filter hides is not tappable', () {
      // Picking a marker that isn't drawn is indistinguishable from the app
      // choosing at random.
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('transit'),
        transitSets: [setWith(2)], // bit 1 (this stop's mode) not shown
        transitStops: [stop],
      );
      expect(hits, isEmpty);
    });

    test('a station whose modes OSM never said stays tappable', () {
      // modeMask 0 means "the data doesn't say", and the painter draws those —
      // so hiding them from taps would strand them.
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('transit'),
        transitSets: [setWith(2)],
        transitStops: [stop.copyWith(modeMask: 0)],
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
            layer: layerOf('transit'),
            transitSets: [setWith(0)],
            transitStops: [stop.copyWith(modeMask: mask)],
          ),
          isEmpty,
          reason: 'station modeMask $mask with nothing shown',
        );
      }
    });

    test('the hit test and the painter agree on every filter', () {
      // One predicate, two readers — this is the assertion that keeps them
      // from drifting again rather than just fixing today's disagreement.
      for (final stationMask in [0, 1, 2, 3]) {
        for (final visible in [0, 1, 2, 3]) {
          final st = stop.copyWith(modeMask: stationMask);
          final drawn = visibleTransitStations([st], {'S': visible});
          final tappable = collectCandidates(
            camera: camera,
            tap: center,
            layer: layerOf('transit'),
            transitSets: [setWith(visible)],
            transitStops: [st],
          );
          expect(
            tappable.isNotEmpty,
            drawn.isNotEmpty,
            reason: 'station $stationMask, visible $visible',
          );
        }
      }
    });
  });

  group('collectCandidates on a borders layer', () {
    // A square around the camera centre, with a hole in the middle of it.
    const outer = [
      LatLng(48.05, 11.45),
      LatLng(48.05, 11.55),
      LatLng(48.15, 11.55),
      LatLng(48.15, 11.45),
    ];
    const hole = [
      LatLng(48.09, 11.49),
      LatLng(48.09, 11.51),
      LatLng(48.11, 11.51),
      LatLng(48.11, 11.49),
    ];
    BorderShapeRef shape(List<List<LatLng>> rings) => BorderShapeRef(
          id: 'a1',
          rings: rings,
          south: 48.05,
          west: 11.45,
          north: 48.15,
          east: 11.55,
        );

    test('a tap inside the area selects it', () {
      final hits = collectCandidates(
        camera: camera,
        tap: const LatLng(48.06, 11.46),
        layer: layerOf('borders'),
        borderShapes: [shape(const [outer])],
      );
      expect(hits, hasLength(1));
      expect(hits.single.ref.kind, ObjectKind.borderArea);
      expect(hits.single.inside, isTrue);
    });

    test('a tap in a hole is outside, exactly as it looks', () {
      final hits = collectCandidates(
        camera: camera,
        tap: center, // the middle of the hole
        layer: layerOf('borders'),
        borderShapes: [shape(const [outer, hole])],
      );
      expect(hits.single.inside, isFalse);
    });

    test('a tap just outside still offers the area by its edge', () {
      // Inside the tap slop of the western edge (11.45) but outside the ring.
      final hits = collectCandidates(
        camera: camera,
        tap: const LatLng(48.10, 11.4497),
        layer: layerOf('borders'),
        borderShapes: [shape(const [outer])],
      );
      expect(hits.single.inside, isFalse);
      expect(hits.single.edgeDistPx, lessThan(kEdgeTolerancePx));
      expect(rankCandidates(hits).single.ref.id, 'a1');
    });

    test('an area nowhere near the tap is never even projected', () {
      // The cull is on the *stored bounds*, so a far tap costs four
      // projections rather than one per vertex — a state boundary is 119 238
      // of them, and a layer holds dozens of areas. It is exact, not an
      // approximation: a ring lies inside its own box, so nothing dropped here
      // could have survived [rankCandidates] anyway.
      final hits = collectCandidates(
        camera: camera,
        tap: const LatLng(48.30, 11.90),
        layer: layerOf('borders'),
        borderShapes: [shape(const [outer])],
      );
      expect(hits, isEmpty);
    });

    test('the smallest area containing the tap wins', () {
      // Two nested districts: tapping well inside both has to mean the one you
      // can actually point at, which is what [sizeProxyMeters] orders.
      const inner = [
        LatLng(48.08, 11.48),
        LatLng(48.08, 11.52),
        LatLng(48.12, 11.52),
        LatLng(48.12, 11.48),
      ];
      final hits = collectCandidates(
        camera: camera,
        tap: center,
        layer: layerOf('borders'),
        borderShapes: [
          shape(const [outer]),
          BorderShapeRef(
            id: 'a2',
            rings: const [inner],
            south: 48.08,
            west: 11.48,
            north: 48.12,
            east: 11.52,
          ),
        ],
      );
      expect(hits.map((h) => h.ref.id), containsAll(['a1', 'a2']));
      expect(rankCandidates(hits).first.ref.id, 'a2');
    });
  });
}
