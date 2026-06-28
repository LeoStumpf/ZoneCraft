import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Lat/lng geometry for a "freehand line": a user-drawn polyline that splits an
/// **inclusion circle** into two clean halves. The region returned fills the
/// half on the polyline's **right** (the right normal of its direction of
/// travel); the layer's invert fills the other half via the engine's
/// `disk − outer` complement.
///
/// The split is exact for any wiggly line (a meandering river included): the
/// half's boundary is `[the line's path across the disk] + [the circle arc on
/// that side]`, not a swept cap — so a curvy line never scatters the fill. The
/// line's open ends are extended straight so they reach past the circle, and the
/// line is offset on the ground by `offsetMeters` before splitting.
///
/// To match the engine's `band = outer − core` model one ring is the nominal
/// boundary (shifted by `offsetMeters`) and the other offsets it by `bandMeters`
/// to put the band on the **uncoloured** side: normally (`bandInward` false)
/// [outer] grows past the line (`offsetMeters − bandMeters`) and [core] is the
/// nominal filled side; when the layer is inverted (`bandInward` true) [outer]
/// is the nominal filled side and [core] is shrunk inward (`offsetMeters +
/// bandMeters`). A positive offset pushes the boundary into the filled side.
class FreeLineRegion {
  const FreeLineRegion(this.outer, this.core);

  /// The filled half on the band's outer edge, as a lat/lng ring. Empty when
  /// fewer than two finite points are given or the geometry is degenerate.
  final List<LatLng> outer;

  /// The filled half on the band's inner edge.
  final List<LatLng> core;
}

/// A 2-D vector in a local tangent plane (metres east/north of the circle
/// centre). Internal to the freeline split maths.
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

/// Builds the right-hand half-disk rings for the polyline [points], bounded to
/// the inclusion circle ([center], [radiusMeters]). [offsetMeters] is the signed
/// boundary offset and [bandMeters] the uncertainty half-band, both on the
/// ground. The work is done in a local tangent plane around [center] (accurate
/// at city scale), then converted back to lat/lng.
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
    return const FreeLineRegion(<LatLng>[], <LatLng>[]);
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

  // Extend the open ends straight so the line reaches well past the circle and
  // always splits it edge-to-edge.
  final ext = r * 3 + 1000;
  final e0 = p.first + (p.first - p[1]).unit.scale(ext);
  final eN = p.last + (p.last - p[p.length - 2]).unit.scale(ext);
  final ep = <_V>[e0, ...p, eN];

  // Per-segment right normals (right of travel = dir rotated −90°), averaged at
  // each vertex so the offset miters cleanly.
  final segN = <_V>[
    for (var i = 0; i < ep.length - 1; i++)
      () {
        final d = (ep[i + 1] - ep[i]).unit;
        return _V(d.y, -d.x);
      }(),
  ];
  final vNorm = <_V>[
    for (var i = 0; i < ep.length; i++)
      () {
        final a = i > 0 ? segN[i - 1] : null;
        final b = i < segN.length ? segN[i] : null;
        if (a == null) return b!;
        if (b == null) return a;
        final s = (a + b);
        return s.len < 1e-9 ? a : s.unit; // opposite normals: keep one
      }(),
  ];

  // Nominal boundary on the coloured side; the band ring offset to the
  // uncoloured side (past the line by default, into the fill when inverted).
  final outerShift = bandInward ? offsetMeters : offsetMeters - bandMeters;
  final coreShift = bandInward ? offsetMeters + bandMeters : offsetMeters;

  List<LatLng> split(double shift) {
    final op = <_V>[
      for (var i = 0; i < ep.length; i++) ep[i] + vNorm[i].scale(shift),
    ];
    final ring = _rightHalfDisk(op, r);
    return [for (final v in ring) toLatLng(v)];
  }

  return FreeLineRegion(split(outerShift), split(coreShift));
}

/// The right-hand region of polyline [op] within the circle of radius [r]
/// centred at the origin, as a closed plane ring. Splits the disk along the line
/// (boundary = the line's in-disk path + the circle arc on the right), so any
/// curvy line yields a clean half. Returns the whole circle / nothing when the
/// line doesn't cross the disk (the centre decides which).
List<_V> _rightHalfDisk(List<_V> op, double r) {
  // Intersections of the polyline with the circle, ordered along the line.
  final hits = <({double param, _V p})>[];
  for (var i = 0; i < op.length - 1; i++) {
    for (final h in _segCircle(op[i], op[i + 1], r)) {
      hits.add((param: i + h.t, p: h.p));
    }
  }
  if (hits.length < 2) {
    // No clean crossing: the whole disk is on one side. Fill it (or not) by
    // testing the centre against the line.
    return _pointRight(const _V(0, 0), op) ? _circle(r) : const <_V>[];
  }
  hits.sort((a, b) => a.param.compareTo(b.param));
  final a = hits.first, b = hits.last;

  // The line's path across the disk, from the first crossing to the last.
  final inside = <_V>[a.p];
  for (var i = 0; i < op.length; i++) {
    if (i > a.param && i < b.param) inside.add(op[i]);
  }
  inside.add(b.p);

  // Close along the circle arc from B back to A — one direction gives the right
  // half, the other the left. Pick by a probe just to the right of the path.
  final angA = atan2(a.p.y, a.p.x);
  final angB = atan2(b.p.y, b.p.x);
  final cand1 = <_V>[...inside, ..._arc(angB, angA, r, ccw: true)];
  final cand2 = <_V>[...inside, ..._arc(angB, angA, r, ccw: false)];
  final probe = _rightProbe(inside, r);
  return _contains(cand1, probe) ? cand1 : cand2;
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
List<_V> _arc(double from, double to, double r, {required bool ccw}) {
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

/// A probe point just to the right of [inside]'s middle segment, stepped in by a
/// small fraction of [r] — used to tell the right half-disk from the left.
_V _rightProbe(List<_V> inside, double r) {
  final mi = max(1, inside.length ~/ 2);
  final a = inside[mi - 1], b = inside[mi];
  final dir = (b - a).unit;
  final right = _V(dir.y, -dir.x);
  final mid = _V((a.x + b.x) / 2, (a.y + b.y) / 2);
  return mid + right.scale(min(r * 0.05, 50));
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
      // Right of travel: (q − a) projected onto the right normal (dy, −dx) > 0.
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

/// A full circle ring of radius [r] centred at the origin (~2° resolution).
List<_V> _circle(double r) => <_V>[
      for (var k = 0; k < 180; k++)
        () {
          final ang = 2 * pi * k / 180;
          return _V(r * cos(ang), r * sin(ang));
        }(),
    ];
