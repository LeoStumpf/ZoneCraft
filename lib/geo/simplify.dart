import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'spherical.dart';

/// Ramer–Douglas–Peucker vertex simplification with a **true great-circle metre**
/// tolerance, used to thin heavy imported tracks/borders and generated height
/// contours before they are stored. Perpendicular distance is measured against
/// the great circle through the segment endpoints (via [ecef]/[Vec3]), so a
/// tolerance of N metres means "no retained point moves the shape more than N m
/// on the ground". Pure Dart (no Flutter/drift) so it runs inside the height
/// `compute()` isolate and is directly unit-testable.

/// Default tolerance for imported freehand tracks/borders (metres).
const double kImportSimplifyMeters = 10.0;

/// Default tolerance for generated height-contour rings (metres).
const double kHeightSimplifyMeters = 15.0;

/// Great-circle (surface) distance between [a] and [b] in metres.
double _pointMeters(LatLng a, LatLng b) {
  final d = ecef(a).dot(ecef(b)).clamp(-1.0, 1.0);
  return acos(d) * earthRadius;
}

/// Perpendicular distance (metres) of [p] from the great circle through [a],[b].
/// Falls back to the point distance when [a]≈[b] (degenerate segment).
double _crossTrackMeters(LatLng p, LatLng a, LatLng b) {
  final n = ecef(a).cross(ecef(b));
  if (n.length < 1e-12) return _pointMeters(p, a); // a,b coincide
  final s = ecef(p).dot(n.normalized()).abs().clamp(0.0, 1.0);
  return asin(s) * earthRadius;
}

/// Classic recursive RDP on an **open** polyline: keeps both endpoints and drops
/// interior points within [tolM] of the endpoint chord.
List<LatLng> _rdp(List<LatLng> pts, double tolM) {
  if (pts.length < 3) return pts;
  final a = pts.first;
  final b = pts.last;
  var dmax = 0.0;
  var idx = 0;
  for (var i = 1; i < pts.length - 1; i++) {
    final d = _crossTrackMeters(pts[i], a, b);
    if (d > dmax) {
      dmax = d;
      idx = i;
    }
  }
  if (dmax > tolM) {
    final left = _rdp(pts.sublist(0, idx + 1), tolM);
    final right = _rdp(pts.sublist(idx), tolM);
    // left ends and right begins at pts[idx]; drop the shared duplicate.
    return [...left.sublist(0, left.length - 1), ...right];
  }
  return [a, b];
}

/// Simplifies an **open** polyline (e.g. a freehand line / GPX trace). Endpoints
/// are preserved; returns the input unchanged when it is already at or below
/// [minPoints] or the tolerance is not positive.
List<LatLng> simplifyLine(List<LatLng> pts, double tolM, {int minPoints = 2}) {
  if (!tolM.isFinite || tolM <= 0 || pts.length <= minPoints) return pts;
  final out = _rdp(pts, tolM);
  return out.length >= minPoints ? out : pts;
}

/// Simplifies a **closed** ring (freehand area / height contour). Tolerates an
/// optional duplicated closing vertex, keeps the ring closed (implicit — the
/// result carries no duplicated last vertex), and never collapses it below
/// [minPoints] (returns the distinct input ring instead).
List<LatLng> simplifyRing(List<LatLng> pts, double tolM, {int minPoints = 3}) {
  if (!tolM.isFinite || tolM <= 0) return pts;
  // Work on the distinct vertices (drop a trailing duplicate of the first).
  var ring = pts;
  if (ring.length >= 2 &&
      ring.first.latitude == ring.last.latitude &&
      ring.first.longitude == ring.last.longitude) {
    ring = ring.sublist(0, ring.length - 1);
  }
  if (ring.length <= minPoints) return ring;
  // Split the ring at vertex 0 and the vertex farthest from it into two open
  // polylines, RDP each, then rejoin. Anchoring on two extreme points avoids the
  // degenerate collapse of running RDP straight on a first==last ring.
  final a0 = ring.first;
  var far = 1;
  var dmax = -1.0;
  for (var i = 1; i < ring.length; i++) {
    final d = _pointMeters(ring[i], a0);
    if (d > dmax) {
      dmax = d;
      far = i;
    }
  }
  final s1 = _rdp(ring.sublist(0, far + 1), tolM); // a0 .. far
  final s2 = _rdp([...ring.sublist(far), a0], tolM); // far .. a0 (closing)
  // Drop each half's trailing vertex (the shared `far`, and the closing a0) to
  // leave an implicit-closed ring with no duplicates.
  final result = [
    ...s1.sublist(0, s1.length - 1),
    ...s2.sublist(0, s2.length - 1),
  ];
  return result.length >= minPoints ? result : ring;
}
