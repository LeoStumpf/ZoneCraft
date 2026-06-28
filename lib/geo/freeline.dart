import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Lat/lng geometry for a "freehand line": a user-drawn polyline that **cuts** an
/// inclusion circle into two sides. The line is treated as a cut, not a boundary
/// to one fixed side: a point is "this side or the other", and crossing the line
/// flips the side. With that even-odd rule, loops and switchbacks need no special
/// handling — they are simply "the other side" again — so a meandering river
/// never scatters the fill or closes with a stray chord.
///
/// Each returned *run* is one continuous piece of the line clipped to the disk
/// neighbourhood and closed by a far arc; filled **even-odd** it gives one side
/// of that piece. The painter intersects each run with the disk and **XORs** the
/// runs together (a river that enters/leaves the disk more than once just flips
/// the side at each crossing) — the right-hand side by default; the layer's
/// invert fills the complement (`disk − right`).
///
/// To match the engine's `band = outer − core` model the [outer] runs are the
/// nominal cut grown onto the uncoloured side by `bandMeters` and the [core]
/// runs the nominal cut, both offset by `offsetMeters` first (a positive offset
/// pushes the cut into the filled side). `bandInward` swaps which gets the band.
class FreeLineRegion {
  const FreeLineRegion(this.outer, this.core)
      : missesDisk = false,
        centreOnRight = false;

  /// Even-odd cut rings (one per continuous run) for the band's outer edge.
  /// Empty when fewer than two finite points are given or the line misses the
  /// disk entirely (the painter then fills all/none by the centre's side).
  final List<List<LatLng>> outer;

  /// Even-odd cut rings for the band's inner edge.
  final List<List<LatLng>> core;

  /// True when the line does not reach the disk at all and [outer]/[core] are
  /// empty; [centreOnRight] then says whether the whole disk is the filled side.
  final bool missesDisk;

  /// Whether the disk centre is on the right (filled) side when [missesDisk].
  final bool centreOnRight;

  const FreeLineRegion.miss(this.centreOnRight)
      : outer = const [],
        core = const [],
        missesDisk = true;
}

/// A 2-D vector in a local tangent plane (metres east/north of the circle
/// centre). Internal to the freeline cut maths.
class _V {
  const _V(this.x, this.y);
  final double x, y;
  _V operator +(_V o) => _V(x + o.x, y + o.y);
  _V operator -(_V o) => _V(x - o.x, y - o.y);
  _V scale(double s) => _V(x * s, y * s);
  double get len => sqrt(x * x + y * y);
  _V get unit {
    final l = len;
    return l == 0 ? const _V(0, 0) : _V(x / l, y / l);
  }
}

/// Builds the right-hand cut runs for the polyline [points], to be filled
/// even-odd and bounded to the inclusion circle ([center], [radiusMeters]). The
/// work is done in a local tangent plane around [center] (accurate at city
/// scale), then converted back to lat/lng.
FreeLineRegion freeLineDiskRegion({
  required List<LatLng> points,
  required LatLng center,
  required double radiusMeters,
  required double offsetMeters,
  required double bandMeters,
  bool bandInward = false,
}) {
  final pts = <LatLng>[
    for (final p in points)
      if (p.latitude.isFinite && p.longitude.isFinite) p,
  ];
  if (pts.length < 2 || !radiusMeters.isFinite || radiusMeters <= 0) {
    return const FreeLineRegion(<List<LatLng>>[], <List<LatLng>>[]);
  }

  // Local equirectangular plane around the circle centre.
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * cos(center.latitude * pi / 180);
  _V toPlane(LatLng p) => _V(
        (p.longitude - center.longitude) * mPerDegLng,
        (p.latitude - center.latitude) * mPerDegLat,
      );
  LatLng toLatLng(_V v) => LatLng(
        center.latitude + v.y / mPerDegLat,
        center.longitude + v.x / mPerDegLng,
      );

  final r = radiusMeters;
  final p = [for (final q in pts) toPlane(q)];

  // Per-segment right normals (right of travel = dir rotated −90°), averaged at
  // each vertex so the offset miters cleanly.
  final segN = <_V>[
    for (var i = 0; i < p.length - 1; i++)
      () {
        final d = (p[i + 1] - p[i]).unit;
        return _V(d.y, -d.x);
      }(),
  ];
  final vNorm = <_V>[
    for (var i = 0; i < p.length; i++)
      () {
        final a = i > 0 ? segN[i - 1] : null;
        final b = i < segN.length ? segN[i] : null;
        if (a == null) return b!;
        if (b == null) return a;
        final s = a + b;
        return s.len < 1e-9 ? a : s.unit;
      }(),
  ];

  List<_V> offsetLine(double shift) =>
      [for (var i = 0; i < p.length; i++) p[i] + vNorm[i].scale(shift)];

  // An imported feature is often stitched from disjoint OSM ways joined by long
  // straight connectors (tens of km). Those connectors are not part of the real
  // line and must not act as cuts, so the line is broken wherever a segment is a
  // gross outlier (> 8× the median, with a floor). Clean hand-drawn lines have
  // uniform spacing, so they are never broken.
  final segLens = <double>[
    for (var i = 0; i < p.length - 1; i++) (p[i + 1] - p[i]).len,
  ]..sort();
  final median = segLens.isEmpty ? 0.0 : segLens[segLens.length ~/ 2];
  // 8× the median catches the gross connector outliers in a stitched import
  // while leaving a normally-spaced line (hand-drawn, or sparse-but-uniform)
  // untouched. The floor keeps a very dense line from breaking on minor jitter.
  final jumpLen = max(8 * median, 1500.0);

  // Does any real piece of the line reach the disk?
  final nominal = offsetLine(offsetMeters);
  if (_cutRuns(nominal, r, jumpLen).isEmpty) {
    // The line misses the disk: the whole disk is one side.
    return FreeLineRegion.miss(_pointRight(const _V(0, 0), nominal));
  }

  final outerShift = bandInward ? offsetMeters : offsetMeters - bandMeters;
  final coreShift = bandInward ? offsetMeters + bandMeters : offsetMeters;

  List<List<LatLng>> build(double shift) {
    final runs = _cutRuns(offsetLine(shift), r, jumpLen);
    final out = <List<LatLng>>[];
    for (final run in runs) {
      final ring = _cutRing(run, r);
      if (ring.length >= 3) out.add([for (final v in ring) toLatLng(v)]);
    }
    return out;
  }

  return FreeLineRegion(build(outerShift), build(coreShift));
}

/// Extracts the cut runs of [line] within the disk of radius [r]. The line is
/// first broken at jump segments (> [jumpLen]) into contiguous real pieces, so
/// stitching connectors never cut. Each piece is then clipped to the disk; a
/// resulting run is kept only if it genuinely **traverses** the disk — both ends
/// are boundary crossings — or a dangling end is a *true* line endpoint (then
/// extended to span the disk). Stray fragments that merely sit inside the disk
/// (a leftover bit of a stitched import) are dropped, so they don't carve slivers.
List<List<_V>> _cutRuns(List<_V> line, double r, double jumpLen) {
  // 1. Break at jump segments into contiguous pieces.
  final pieces = <List<_V>>[];
  var piece = <_V>[line.first];
  for (var i = 0; i < line.length - 1; i++) {
    if ((line[i + 1] - line[i]).len > jumpLen) {
      pieces.add(piece);
      piece = <_V>[line[i + 1]];
    } else {
      piece.add(line[i + 1]);
    }
  }
  pieces.add(piece);

  final ext = r * 3 + 1000;
  final out = <List<_V>>[];

  for (var pi = 0; pi < pieces.length; pi++) {
    final pc = pieces[pi];
    if (pc.length < 2) continue;
    final trueStart = pi == 0; // a dangling run start is a real line end here
    final trueEnd = pi == pieces.length - 1;
    bool ins(_V v) => v.len <= r;

    var cur = <_V>[];
    var startCross = false; // current run opened at a boundary crossing
    void flush(bool endCross) {
      out.addAll(_finishRun(cur, startCross, endCross, trueStart, trueEnd, ext));
      cur = <_V>[];
    }

    for (var i = 0; i < pc.length - 1; i++) {
      final a = pc[i], b = pc[i + 1];
      final aIn = ins(a), bIn = ins(b);
      if (aIn && bIn) {
        if (cur.isEmpty) {
          cur.add(a);
          startCross = false; // opened at a piece vertex (dangling)
        }
        cur.add(b);
      } else if (aIn && !bIn) {
        if (cur.isEmpty) {
          cur.add(a);
          startCross = false;
        }
        final x = _circleCross(a, b, r);
        if (x != null) cur.add(x);
        flush(true);
      } else if (!aIn && bIn) {
        final x = _circleCross(a, b, r);
        cur = <_V>[if (x != null) x else a];
        startCross = x != null;
        cur.add(b);
      } else {
        // Both outside but the segment may pass through (two crossings) — a
        // clean traversing cut.
        final hits = _segCircle(a, b, r);
        if (hits.length >= 2) {
          hits.sort((p, q) => p.t.compareTo(q.t));
          out.add(<_V>[hits.first.p, hits.last.p]);
        }
      }
    }
    flush(false); // piece ended; any open run dangles at the piece end
  }
  return out;
}

/// Validates and finishes one clipped run. Drops it unless each end is a disk
/// crossing or a true line endpoint; extends dangling true-endpoint ends past
/// the disk so the cut spans it.
List<List<_V>> _finishRun(List<_V> cur, bool startCross, bool endCross,
    bool trueStart, bool trueEnd, double ext) {
  if (cur.length < 2) return const [];
  if (!(startCross || trueStart)) return const []; // stray fragment start
  if (!(endCross || trueEnd)) return const []; // stray fragment end
  final run = <_V>[...cur];
  if (!startCross) {
    run.insert(0, run.first + (run.first - run[1]).unit.scale(ext));
  }
  if (!endCross) {
    run.add(run.last + (run.last - run[run.length - 2]).unit.scale(ext));
  }
  return [run];
}

/// The closed even-odd cut ring for one [run] that already spans the disk of
/// radius [r] (its ends are on or beyond the rim), closed by a far arc on the
/// side that puts the run's right-hand side inside. Filled even-odd then
/// intersected with the disk it yields the run's right-hand region; loops in the
/// run flip the side, as intended.
List<_V> _cutRing(List<_V> run, double r) {
  final ep = run;
  final big = r * 6 + 4000;
  final angEnd = atan2(ep.last.y, ep.last.x);
  final angStart = atan2(ep.first.y, ep.first.x);

  List<_V> closed(bool ccw) => <_V>[
        ...ep,
        _V(big * cos(angEnd), big * sin(angEnd)),
        ..._arc(angEnd, angStart, big, ccw),
        _V(big * cos(angStart), big * sin(angStart)),
      ];

  // Pick the closure side so the run's right-hand side is the even-odd interior.
  final probe = _rightProbe(ep, r);
  return closed(_contains(closed(true), probe));
}

/// A probe just to the right of the run's segment nearest the origin, stepped in
/// by a small fraction of [r] — used to choose the closure side.
_V _rightProbe(List<_V> ep, double r) {
  var best = double.infinity, bi = 0;
  for (var i = 0; i < ep.length - 1; i++) {
    final m = _V((ep[i].x + ep[i + 1].x) / 2, (ep[i].y + ep[i + 1].y) / 2);
    if (m.len < best) {
      best = m.len;
      bi = i;
    }
  }
  final a = ep[bi], b = ep[bi + 1];
  final dir = (b - a).unit;
  final right = _V(dir.y, -dir.x);
  final mid = _V((a.x + b.x) / 2, (a.y + b.y) / 2);
  return mid + right.scale(min(r * 0.05, 50));
}

/// The boundary crossing of segment [a]→[b] with the origin circle of radius
/// [r] (one endpoint inside, one outside ⇒ a single crossing).
_V? _circleCross(_V a, _V b, double r) {
  final hits = _segCircle(a, b, r);
  return hits.isEmpty ? null : hits.first.p;
}

/// Intersections of segment [a]→[b] with the origin-centred circle of radius
/// [r], as `(t, point)` with t in [0,1].
List<({double t, _V p})> _segCircle(_V a, _V b, double r) {
  final d = b - a;
  final qa = d.x * d.x + d.y * d.y;
  if (qa == 0) return const [];
  final qb = 2 * (a.x * d.x + a.y * d.y);
  final qc = a.x * a.x + a.y * a.y - r * r;
  final disc = qb * qb - 4 * qa * qc;
  if (disc < 0) return const [];
  final sq = sqrt(disc);
  final out = <({double t, _V p})>[];
  for (final t in [(-qb - sq) / (2 * qa), (-qb + sq) / (2 * qa)]) {
    if (t >= 0 && t <= 1) out.add((t: t, p: a + d.scale(t)));
  }
  return out;
}

/// Arc points on the origin circle of radius [r] from angle [from] to [to]
/// (radians), excluding the endpoints, sweeping CCW or CW. ~2° steps.
List<_V> _arc(double from, double to, double r, bool ccw) {
  var delta = to - from;
  if (ccw) {
    while (delta <= 0) {
      delta += 2 * pi;
    }
  } else {
    while (delta >= 0) {
      delta -= 2 * pi;
    }
  }
  final steps = max(2, (delta.abs() / (2 * pi) * 180).ceil());
  return <_V>[
    for (var k = 1; k < steps; k++)
      () {
        final ang = from + delta * k / steps;
        return _V(r * cos(ang), r * sin(ang));
      }(),
  ];
}

/// Whether [q] is to the right of polyline [op], judged by its nearest segment.
bool _pointRight(_V q, List<_V> op) {
  var best = double.infinity;
  var right = false;
  for (var i = 0; i < op.length - 1; i++) {
    final a = op[i], b = op[i + 1];
    final d = b - a;
    final len2 = d.x * d.x + d.y * d.y;
    final t = len2 > 0
        ? (((q.x - a.x) * d.x + (q.y - a.y) * d.y) / len2).clamp(0.0, 1.0)
        : 0.0;
    final px = a.x + t * d.x, py = a.y + t * d.y;
    final dist2 = (q.x - px) * (q.x - px) + (q.y - py) * (q.y - py);
    if (dist2 < best) {
      best = dist2;
      right = (q.x - a.x) * d.y - (q.y - a.y) * d.x > 0;
    }
  }
  return right;
}

/// Even-odd point-in-polygon for the plane ring [poly].
bool _contains(List<_V> poly, _V q) {
  var hit = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i].x, yi = poly[i].y;
    final xj = poly[j].x, yj = poly[j].y;
    final intersect = (yi > q.y) != (yj > q.y) &&
        q.x < (xj - xi) * (q.y - yi) / (yj - yi) + xi;
    if (intersect) hit = !hit;
  }
  return hit;
}
