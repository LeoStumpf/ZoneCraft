import 'dart:ui';

/// One cluster of screen-space points: the member indices into the input list
/// plus the members' mean position.
class ScreenCluster {
  const ScreenCluster({required this.indices, required this.center});

  final List<int> indices;
  final Offset center;
}

/// Groups [points] (screen-space) so that no two rendered markers overlap:
/// greedy seed clustering — walk the points in order, start a cluster at each
/// point not yet absorbed, and absorb every other point within [radius] px of
/// that seed. A uniform grid of [radius]-sized cells accelerates the
/// neighbourhood search (only the 3×3 cells around a seed can hold members),
/// so the pass is ~O(n) for spread-out points.
///
/// Deterministic for a given input order, and stable under camera translation
/// (all points shift equally, so seeds and memberships are preserved). Zooming
/// changes the pixel distances, so clusters split/merge naturally with zoom.
List<ScreenCluster> clusterOffsets(List<Offset> points, double radius) {
  if (points.isEmpty) return const [];
  final cell = radius;
  final grid = <(int, int), List<int>>{};
  (int, int) keyOf(Offset p) => ((p.dx / cell).floor(), (p.dy / cell).floor());
  for (var i = 0; i < points.length; i++) {
    grid.putIfAbsent(keyOf(points[i]), () => []).add(i);
  }

  final assigned = List<bool>.filled(points.length, false);
  final out = <ScreenCluster>[];
  final r2 = radius * radius;
  for (var i = 0; i < points.length; i++) {
    if (assigned[i]) continue;
    assigned[i] = true;
    final seed = points[i];
    final members = <int>[i];
    final (cx, cy) = keyOf(seed);
    for (var gx = cx - 1; gx <= cx + 1; gx++) {
      for (var gy = cy - 1; gy <= cy + 1; gy++) {
        final bucket = grid[(gx, gy)];
        if (bucket == null) continue;
        for (final j in bucket) {
          if (assigned[j]) continue;
          final d = points[j] - seed;
          if (d.dx * d.dx + d.dy * d.dy <= r2) {
            assigned[j] = true;
            members.add(j);
          }
        }
      }
    }
    var sx = 0.0, sy = 0.0;
    for (final m in members) {
      sx += points[m].dx;
      sy += points[m].dy;
    }
    out.add(ScreenCluster(
      indices: members,
      center: Offset(sx / members.length, sy / members.length),
    ));
  }
  return out;
}
