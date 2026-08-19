import 'dart:ui' show Offset, Rect;

import 'hit_test.dart' show distToSegment;
import 'screen_cluster.dart' show clusterOffsets;

/// The screen-space arithmetic behind reshaping an imported border outline:
/// which vertices get a drag handle, and where a new one belongs.
///
/// Pure functions over **already-projected** rings, so the camera stays at the
/// call site and both decisions are unit-testable. They are separate from
/// `hit_test.dart` because that file answers "what did the tap mean?", while
/// this one answers "what can the finger reach?" — the same projection, a
/// different question.

/// One vertex of an outline, addressed by which ring it is on and where.
typedef RingVertex = ({int ring, int index});

/// Which of [rings]' vertices should be drawn as drag handles.
///
/// Two passes, in this order:
///
/// 1. **Cull** to [bounds] (the viewport, usually inflated a little so a handle
///    just off the edge is still grabbable after a nudge). Only what is on
///    screen can be dragged.
/// 2. **Thin** to one handle per [spacingPx] of screen space. An administrative
///    boundary carries a vertex every few metres — Alleshausen is 105 of them
///    across 6 km — so at any zoom showing the whole area the dots merge into a
///    solid band with nothing to aim at. Each surviving handle is a **real**
///    vertex (the cluster's seed, never its mean), so a drag moves the boundary
///    itself rather than an interpolation, and the rest reappear as you zoom in.
///
/// Culling first matters: clustering points you cannot see would let an
/// off-screen vertex suppress one you are trying to grab.
///
/// `tooMany` is true when even the thinned set exceeds [max] — a whole state on
/// screen at once. The handles are then empty, because at that density every
/// drag target covers its neighbours, and the honest answer is to zoom in,
/// which the culling then rewards.
({List<RingVertex> handles, bool tooMany}) reshapeHandles(
  List<List<Offset>> rings, {
  required Rect bounds,
  required double spacingPx,
  required int max,
}) {
  final offsets = <Offset>[];
  final at = <RingVertex>[];
  for (var r = 0; r < rings.length; r++) {
    for (var i = 0; i < rings[r].length; i++) {
      final o = rings[r][i];
      if (!o.dx.isFinite || !o.dy.isFinite) continue;
      if (!bounds.contains(o)) continue;
      offsets.add(o);
      at.add((ring: r, index: i));
    }
  }
  if (offsets.isEmpty) return (handles: const <RingVertex>[], tooMany: false);
  final kept = [
    for (final c in clusterOffsets(offsets, spacingPx)) at[c.indices.first],
  ];
  if (kept.length > max) {
    return (handles: const <RingVertex>[], tooMany: true);
  }
  return (handles: kept, tooMany: false);
}

/// Where a new vertex belongs so that a tap at [tap] lands **on** the outline:
/// the ring and insertion index of the segment nearest the tap.
///
/// The returned index is the position to `insert` at, so the new point splits
/// the segment it was aimed at rather than landing at the end of an arbitrary
/// ring. The closing segment (last → first) yields `ring.length`, which appends
/// — the same thing, since the ring wraps.
///
/// Null when no ring has a fillable three points, i.e. there is no outline to
/// insert into.
RingVertex? nearestInsertion(List<List<Offset>> rings, Offset tap) {
  var bestRing = -1, bestIndex = 0;
  var best = double.infinity;
  for (var r = 0; r < rings.length; r++) {
    final ring = rings[r];
    if (ring.length < 3) continue;
    for (var i = 0; i < ring.length; i++) {
      final d = distToSegment(tap, ring[i], ring[(i + 1) % ring.length]);
      if (d < best) {
        best = d;
        bestRing = r;
        bestIndex = i + 1;
      }
    }
  }
  return bestRing < 0 ? null : (ring: bestRing, index: bestIndex);
}
