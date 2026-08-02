import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/data/borders.dart';
import 'package:zonecraft/geo/border_areas.dart';

void main() {
  BorderWay way(int id, List<List<double>> pts, {String role = 'outer'}) =>
      BorderWay(
        id: id,
        role: role,
        points: [for (final p in pts) LatLng(p[0], p[1])],
      );

  /// The unit square as three ways, given in order and forwards.
  List<BorderWay> squareWays() => [
        way(1, [
          [0, 0],
          [0, 1]
        ]),
        way(2, [
          [0, 1],
          [1, 1]
        ]),
        way(3, [
          [1, 1],
          [1, 0],
          [0, 0]
        ]),
      ];

  Set<String> vertices(List<LatLng> ring) =>
      {for (final p in ring) '${p.latitude},${p.longitude}'};

  group('assembleRings', () {
    test('stitches ways into one closed ring', () {
      final rings = assembleRings(squareWays());
      expect(rings, hasLength(1));
      // Implicitly closed: no duplicated first vertex.
      expect(rings.single, hasLength(4));
      expect(vertices(rings.single), {'0.0,0.0', '0.0,1.0', '1.0,1.0', '1.0,0.0'});
    });

    test('member order and direction are not trusted', () {
      // Shuffled, and two of the three reversed — exactly what the API returns.
      final ways = squareWays();
      final scrambled = [
        BorderWay(
            id: ways[2].id,
            role: 'outer',
            points: ways[2].points.reversed.toList()),
        ways[0],
        BorderWay(
            id: ways[1].id,
            role: 'outer',
            points: ways[1].points.reversed.toList()),
      ];
      final rings = assembleRings(scrambled);
      expect(rings, hasLength(1));
      expect(rings.single, hasLength(4));
    });

    test('an already-closed single way needs no stitching', () {
      final rings = assembleRings([
        way(1, [
          [0, 0],
          [0, 1],
          [1, 1],
          [1, 0],
          [0, 0]
        ])
      ]);
      expect(rings.single, hasLength(4));
    });

    test('outer and inner members become separate rings', () {
      final rings = assembleRings([
        ...squareWays(),
        way(9, [
          [0.2, 0.2],
          [0.2, 0.8],
          [0.8, 0.8],
          [0.8, 0.2],
          [0.2, 0.2]
        ], role: 'inner'),
      ]);
      expect(rings, hasLength(2));
      // Outers first; the hole carries no role flag because even-odd fill
      // makes a ring inside another a hole on its own.
      expect(rings.first, hasLength(4));
      expect(rings.last, hasLength(4));
    });

    test('an inner way never chains onto an outer one sharing an endpoint', () {
      // The outer chain ends at (1,1) and an inner way starts there. Chaining
      // across roles would swallow the hole into the outline as one ring.
      final rings = assembleRings([
        way(1, [
          [0, 0],
          [0, 1]
        ]),
        way(2, [
          [0, 1],
          [1, 1]
        ]),
        way(10, [
          [1, 1],
          [0.5, 0.5]
        ], role: 'inner'),
        way(11, [
          [0.5, 0.5],
          [0.6, 0.4],
          [1, 1]
        ], role: 'inner'),
      ]);
      expect(rings, hasLength(2));
      expect(rings.first, hasLength(3), reason: 'the outline stands alone');
      expect(rings.last, hasLength(3), reason: 'and the hole is its own ring');
    });

    test('a run that will not close is closed rather than dropped', () {
      // Three sides of a square: the fourth is missing from the data.
      final rings = assembleRings([
        way(1, [
          [0, 0],
          [0, 1]
        ]),
        way(2, [
          [0, 1],
          [1, 1]
        ]),
        way(3, [
          [1, 1],
          [1, 0]
        ]),
      ]);
      expect(rings, hasLength(1),
          reason: 'an area must never silently disappear');
      expect(rings.single, hasLength(4));
    });

    test('a two-point remnant is dropped — there is no area in it', () {
      expect(
        assembleRings([
          way(1, [
            [0, 0],
            [0, 1]
          ])
        ]),
        isEmpty,
      );
    });

    test('empty input, and ways too short to be a segment', () {
      expect(assembleRings(const []), isEmpty);
      expect(
        assembleRings([
          way(1, [
            [0, 0]
          ])
        ]),
        isEmpty,
      );
    });
  });

  group('clipRingsToBox', () {
    const box = LatLngBox(south: 0, west: 0, north: 1, east: 1);

    List<List<LatLng>> ring(List<List<double>> pts) => [
          [for (final p in pts) LatLng(p[0], p[1])]
        ];

    test('a ring already inside is unchanged', () {
      final r = ring([
        [0.2, 0.2],
        [0.2, 0.8],
        [0.8, 0.8]
      ]);
      expect(clipRingsToBox(r, box).single, hasLength(3));
    });

    test('a straddling ring is cut at the box edge', () {
      final out = clipRingsToBox(
        ring([
          [0.5, 0.5],
          [0.5, 2.0],
          [0.9, 2.0],
          [0.9, 0.5]
        ]),
        box,
      ).single;
      // Nothing survives east of the box.
      for (final p in out) {
        expect(p.longitude, lessThanOrEqualTo(1.0 + 1e-9));
        expect(p.longitude, greaterThanOrEqualTo(-1e-9));
      }
      // And the cut vertices land exactly on the edge, which is what lets the
      // painter recognise them as a cut rather than a border.
      expect(out.any((p) => onBoxEdge(p, box, 1e-9)), isTrue);
    });

    test('a disjoint ring is dropped, not clamped into the box', () {
      expect(
        clipRingsToBox(
          ring([
            [5, 5],
            [5, 6],
            [6, 6]
          ]),
          box,
        ),
        isEmpty,
      );
    });

    test('a hole inside the box survives alongside its outer ring', () {
      final rings = [
        [
          const LatLng(0, 0),
          const LatLng(0, 1),
          const LatLng(1, 1),
          const LatLng(1, 0),
        ],
        [
          const LatLng(0.3, 0.3),
          const LatLng(0.3, 0.7),
          const LatLng(0.7, 0.7),
          const LatLng(0.7, 0.3),
        ],
      ];
      final out = clipRingsToBox(rings, box);
      expect(out, hasLength(2), reason: 'even-odd parity must survive the clip');
      expect(out.last, hasLength(4));
    });
  });

  group('assignAreaColors', () {
    AreaAdjacencyInput a(int id, List<int> ways) =>
        AreaAdjacencyInput(osmId: id, wayIds: ways);

    test('areas sharing a way never share a colour', () {
      // A ring of five, each bordering the next — an odd cycle, so it genuinely
      // needs three colours.
      final areas = [
        a(1, [10, 11]),
        a(2, [11, 12]),
        a(3, [12, 13]),
        a(4, [13, 14]),
        a(5, [14, 10]),
      ];
      final colors = assignAreaColors(areas);
      expect(colors.keys.toSet(), {1, 2, 3, 4, 5});
      for (final pair in [(1, 2), (2, 3), (3, 4), (4, 5), (5, 1)]) {
        expect(colors[pair.$1], isNot(colors[pair.$2]),
            reason: '${pair.$1} and ${pair.$2} share a border');
      }
      for (final c in colors.values) {
        expect(c, inInclusiveRange(0, kBorderColorCount - 1));
      }
    });

    test('cross-set adjacency is caught, because way ids are global', () {
      // Two "imports" that were never fetched together still resolve.
      final colors = assignAreaColors([
        a(1, [10]),
        a(2, [10]),
      ]);
      expect(colors[1], isNot(colors[2]));
    });

    test('an area present in two imports comes out with one colour', () {
      final colors = assignAreaColors([
        a(1, [10, 11]),
        a(1, [10]), // same area, partially re-imported
        a(2, [11]),
      ]);
      expect(colors, hasLength(2));
      expect(colors[1], isNot(colors[2]));
    });

    test('an isolated area is still coloured', () {
      expect(assignAreaColors([a(1, [10])])[1], isNotNull);
      expect(assignAreaColors(const []), isEmpty);
    });

    test('deterministic for a given input, whatever order it arrives in', () {
      final areas = [
        a(1, [10, 11]),
        a(2, [11, 12]),
        a(3, [12, 10]),
        a(4, [99]),
      ];
      final first = assignAreaColors(areas);
      final again = assignAreaColors(areas.reversed.toList());
      expect(again, first);
    });

    test('more neighbours than colours degrades instead of failing', () {
      // One hub bordering eight others, all mutually adjacent through it.
      final areas = [
        a(0, [for (var i = 1; i <= 8; i++) i]),
        for (var i = 1; i <= 8; i++) a(i, [i]),
      ];
      final colors = assignAreaColors(areas);
      expect(colors, hasLength(9));
      for (var i = 1; i <= 8; i++) {
        expect(colors[i], isNot(colors[0]),
            reason: 'the hub must differ from every spoke');
      }
    });
  });

  group('labelAnchor', () {
    test('the centroid, when it lands inside', () {
      final p = labelAnchor([
        [
          const LatLng(0, 0),
          const LatLng(0, 2),
          const LatLng(2, 2),
          const LatLng(2, 0),
        ]
      ]);
      expect(p.latitude, closeTo(1, 1e-9));
      expect(p.longitude, closeTo(1, 1e-9));
    });

    test('a C shape puts the anchor inside itself, not in its bay', () {
      // A "C" opening east: the centroid falls in the empty middle.
      final ring = [
        const LatLng(0, 0),
        const LatLng(0, 3),
        const LatLng(1, 3),
        const LatLng(1, 1),
        const LatLng(2, 1),
        const LatLng(2, 3),
        const LatLng(3, 3),
        const LatLng(3, 0),
      ];
      final p = labelAnchor([ring]);
      expect(_contains(ring, p), isTrue,
          reason: 'a name outside its own outline reads as the neighbour\'s');
    });

    test('the largest ring wins, so an exclave never takes the name', () {
      final p = labelAnchor([
        [
          const LatLng(0, 0),
          const LatLng(0, 0.1),
          const LatLng(0.1, 0.1),
          const LatLng(0.1, 0),
        ],
        [
          const LatLng(10, 10),
          const LatLng(10, 12),
          const LatLng(12, 12),
          const LatLng(12, 10),
        ],
      ]);
      expect(p.latitude, closeTo(11, 1e-9));
    });

    test('no usable ring gives a defined answer rather than throwing', () {
      expect(labelAnchor(const []), const LatLng(0, 0));
    });
  });

  group('encodeRings / decodeRings', () {
    test('round-trips multi-ring geometry', () {
      final rings = [
        [const LatLng(48.0, 11.0), const LatLng(48.1, 11.2), const LatLng(48.2, 11.0)],
        [const LatLng(48.05, 11.05), const LatLng(48.06, 11.06), const LatLng(48.07, 11.05)],
      ];
      final back = decodeRings(encodeRings(rings));
      expect(back, hasLength(2));
      expect(back.first.first.latitude, closeTo(48.0, 1e-9));
      expect(back.last.last.longitude, closeTo(11.05, 1e-9));
    });

    test('garbage in, empty out — a corrupt row must not take the map down', () {
      expect(decodeRings('nope'), isEmpty);
      expect(decodeRings('{}'), isEmpty);
      expect(decodeRings('[1,2,3]'), isEmpty);
      expect(decodeRings('[[[1],[2,3],[4,5]]]'), isEmpty,
          reason: 'a ring left with two points is not an area');
      expect(decodeRings('[[["a","b"],[1,2],[3,4],[5,6]]]').single, hasLength(3));
    });

    test('drops degenerate rings rather than storing them', () {
      expect(
        decodeRings(encodeRings([
          [const LatLng(1, 1), const LatLng(2, 2)]
        ])),
        isEmpty,
      );
    });
  });

  group('onBoxEdge', () {
    const box = LatLngBox(south: 0, west: 0, north: 1, east: 1);

    test('recognises a cut vertex on any of the four edges', () {
      for (final p in [
        const LatLng(0, 0.5),
        const LatLng(1, 0.5),
        const LatLng(0.5, 0),
        const LatLng(0.5, 1),
      ]) {
        expect(onBoxEdge(p, box, 1e-7), isTrue);
      }
    });

    test('an interior vertex is a real border', () {
      expect(onBoxEdge(const LatLng(0.5, 0.5), box, 1e-7), isFalse);
    });
  });

  group('buildBorderAreas', () {
    test('assembles, clips and thins in one pass', () {
      final rel = BorderRelationData(
        osmId: 42,
        name: 'Half in',
        ways: [
          BorderWay(id: 1, role: 'outer', points: const [
            LatLng(0.2, 0.2),
            LatLng(0.2, 2.0),
          ]),
          BorderWay(id: 2, role: 'outer', points: const [
            LatLng(0.2, 2.0),
            LatLng(0.8, 2.0),
            LatLng(0.8, 0.2),
            LatLng(0.2, 0.2),
          ]),
        ],
      );
      final built = buildBorderAreas(BorderBuildRequest(
        relations: [rel],
        box: const LatLngBox(south: 0, west: 0, north: 1, east: 1),
      ));
      expect(built, hasLength(1));
      final a = built.single;
      expect(a.osmId, 42);
      expect(a.name, 'Half in');
      expect(a.wayIds, [1, 2]);
      // Only the part inside the box is stored.
      expect(a.east, lessThanOrEqualTo(1.0 + 1e-9));
      expect(a.pointCount, greaterThanOrEqualTo(3));
      expect(decodeRings(a.rings), hasLength(1));
      expect(totalPointCount(built), a.pointCount);
    });

    test('an area entirely outside the box is not part of this import', () {
      final built = buildBorderAreas(BorderBuildRequest(
        relations: [
          BorderRelationData(osmId: 1, name: 'Elsewhere', ways: [
            BorderWay(id: 1, role: 'outer', points: const [
              LatLng(50, 50),
              LatLng(50, 51),
              LatLng(51, 51),
              LatLng(50, 50),
            ]),
          ]),
        ],
        box: const LatLngBox(south: 0, west: 0, north: 1, east: 1),
      ));
      expect(built, isEmpty);
    });

    test('simplification thins a dense boundary without losing the shape', () {
      // 400 points along one edge, all within a metre of the straight line.
      final dense = <LatLng>[
        for (var i = 0; i < 400; i++) LatLng(0.2, 0.2 + i * 0.0015),
        const LatLng(0.8, 0.8),
      ];
      final built = buildBorderAreas(BorderBuildRequest(
        relations: [
          BorderRelationData(osmId: 1, name: null, ways: [
            BorderWay(id: 1, role: 'outer', points: dense),
          ]),
        ],
        box: const LatLngBox(south: 0, west: 0, north: 1, east: 1),
      ));
      expect(built.single.pointCount, lessThan(dense.length));
      expect(built.single.pointCount, greaterThanOrEqualTo(3));
    });
  });
}

/// Even-odd point-in-ring, for asserting a label landed inside its own area.
bool _contains(List<LatLng> ring, LatLng p) {
  var inside = false;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    if ((a.latitude > p.latitude) != (b.latitude > p.latitude)) {
      final t = (p.latitude - a.latitude) / (b.latitude - a.latitude);
      if (p.longitude < a.longitude + t * (b.longitude - a.longitude)) {
        inside = !inside;
      }
    }
  }
  return inside;
}
