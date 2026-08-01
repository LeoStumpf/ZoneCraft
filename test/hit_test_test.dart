import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/state/providers.dart';
import 'package:zonecraft/ui/hit_test.dart';
import 'package:zonecraft/ui/object_summary.dart';

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
}
