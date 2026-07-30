import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/ui/screen_cluster.dart';

void main() {
  test('far-apart points stay singletons', () {
    final pts = [
      const Offset(0, 0),
      const Offset(200, 0),
      const Offset(0, 200),
    ];
    final clusters = clusterOffsets(pts, 48);
    expect(clusters.length, 3);
    expect(clusters.every((c) => c.indices.length == 1), isTrue);
  });

  test('points within the radius collapse into one cluster', () {
    final pts = [
      const Offset(100, 100),
      const Offset(110, 105),
      const Offset(95, 130),
      const Offset(500, 500),
    ];
    final clusters = clusterOffsets(pts, 48);
    expect(clusters.length, 2);
    final big = clusters.firstWhere((c) => c.indices.length == 3);
    expect(big.indices.toSet(), {0, 1, 2});
    // Centre is the members' mean.
    expect(big.center.dx, closeTo((100 + 110 + 95) / 3, 1e-9));
    expect(big.center.dy, closeTo((100 + 105 + 130) / 3, 1e-9));
  });

  test('membership is by distance to the seed, not the grid cell', () {
    // Two points 40 px apart straddling a grid-cell boundary must merge.
    final pts = [const Offset(47, 0), const Offset(87, 0)];
    final clusters = clusterOffsets(pts, 48);
    expect(clusters.length, 1);
    expect(clusters.single.indices, [0, 1]);
  });

  test('every point lands in exactly one cluster', () {
    final pts = [
      for (var i = 0; i < 200; i++)
        Offset((i * 37) % 500.0, (i * 91) % 700.0),
    ];
    final clusters = clusterOffsets(pts, 40);
    final all = [for (final c in clusters) ...c.indices]..sort();
    expect(all, [for (var i = 0; i < 200; i++) i]);
  });

  test('empty input yields no clusters', () {
    expect(clusterOffsets(const [], 48), isEmpty);
  });
}
