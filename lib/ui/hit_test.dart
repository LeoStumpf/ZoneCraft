import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../state/providers.dart';
import 'object_summary.dart';
import 'region_geometry.dart';

/// Screen-space geometry primitives shared by tap hit-testing and the
/// nearest-segment vertex insert. Pure functions, no camera state — the camera
/// is only needed to project lat/lng to offsets, which callers do first.

/// Haversine distance calculator. Vincenty (latlong2's default) returns NaN for
/// the near-antipodal pairs a zoomed-out viewport produces, so every distance
/// used for hit-testing goes through this one.
const Distance geoDistance = Distance(calculator: Haversine());

/// Shortest distance from [p] to the segment a–b, in the same units as the
/// offsets (pixels, for projected geometry).
double distToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lenSq == 0) return (p - a).distance;
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Even-odd point-in-polygon over a projected ring.
bool pointInPolygon(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i], pj = poly[j];
    if (((pi.dy > p.dy) != (pj.dy > p.dy)) &&
        (p.dx < (pj.dx - pi.dx) * (p.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx)) {
      inside = !inside;
    }
  }
  return inside;
}

/// Default tap slop: within this many pixels of an object's drawn boundary
/// counts as "you pointed at *that* object".
const double kEdgeTolerancePx = 24;

/// Longest list a hit chooser shows, so an overlapping pile stays readable.
const int kMaxHitCandidates = 6;

/// One object a tap/long-press could plausibly have meant.
///
/// [edgeDistPx] — screen distance to the object's drawn boundary; [inside] —
/// whether the point falls in its filled region; [sizeProxyMeters] — how big
/// the object is, used to prefer the most specific one when several contain the
/// point (`infinity` for the unbounded types, so they always lose).
class HitCandidate {
  const HitCandidate({
    required this.ref,
    required this.inside,
    required this.edgeDistPx,
    required this.sizeProxyMeters,
  });

  final ObjectRef ref;
  final bool inside;
  final double edgeDistPx;
  final double sizeProxyMeters;
}

/// Orders candidates by what the user most likely meant, best first.
///
/// 1. Anything within [tolerancePx] of its boundary, nearest boundary first —
///    pointing at an outline is an unambiguous "that one".
/// 2. Otherwise anything containing the point, smallest first — this
///    generalises the old "smallest circle wins", and is what stops a
///    continent-sized half-plane from swallowing every tap.
///
/// Pure, so the arbitration is unit-testable without a camera.
List<HitCandidate> rankCandidates(
  List<HitCandidate> raw, {
  double tolerancePx = kEdgeTolerancePx,
  int max = kMaxHitCandidates,
}) {
  final onEdge = <HitCandidate>[];
  final within = <HitCandidate>[];
  for (final c in raw) {
    if (c.edgeDistPx <= tolerancePx) {
      onEdge.add(c);
    } else if (c.inside) {
      within.add(c);
    }
  }
  onEdge.sort((a, b) => a.edgeDistPx.compareTo(b.edgeDistPx));
  within.sort((a, b) => a.sizeProxyMeters.compareTo(b.sizeProxyMeters));
  final ranked = [...onEdge, ...within];
  return ranked.length <= max ? ranked : ranked.sublist(0, max);
}

/// Every object of [layer] that [tap] could have meant, unranked.
///
/// [areaContours] optionally supplies a freehand area's *resolved* boundary
/// (the offset outline the painter actually draws); without it the raw drawn
/// ring is used, which differs only when the area carries an offset.
List<HitCandidate> collectCandidates({
  required MapCamera camera,
  required LatLng tap,
  required Layer layer,
  List<Circle> circles = const [],
  List<Plane> planes = const [],
  List<Subspace> subspaces = const [],
  List<SubspacePoint> subspacePoints = const [],
  List<FreeLine> freeLines = const [],
  List<FreeLinePoint> freeLinePoints = const [],
  List<FreeArea> freeAreas = const [],
  List<FreeAreaPoint> freeAreaPoints = const [],
  List<HeightRegion> heightRegions = const [],
  List<List<LatLng>> Function(FreeArea area)? areaContours,
}) {
  final out = <HitCandidate>[];
  final tapPx = camera.latLngToScreenOffset(tap);

  ObjectRef refOf(ObjectKind kind, String id) =>
      ObjectRef(kind: kind, id: id, layerId: layer.id);

  switch (layer.type) {
    case 'circles':
      for (final c in circles.where((c) => c.layerId == layer.id)) {
        if (!c.radiusMeters.isFinite || c.radiusMeters <= 0) continue;
        if (!c.centerLat.isFinite || !c.centerLng.isFinite) continue;
        final d = geoDistance.as(
            LengthUnit.Meter, LatLng(c.centerLat, c.centerLng), tap);
        if (!d.isFinite) continue;
        out.add(HitCandidate(
          ref: refOf(ObjectKind.circle, c.id),
          inside: d <= c.radiusMeters,
          edgeDistPx: metersToPixels(camera, tap, (d - c.radiusMeters).abs()),
          sizeProxyMeters: c.radiusMeters,
        ));
      }
    case 'height':
      for (final r in heightRegions.where((r) => r.layerId == layer.id)) {
        if (!r.radiusMeters.isFinite || r.radiusMeters <= 0) continue;
        if (!r.centerLat.isFinite || !r.centerLng.isFinite) continue;
        final d = geoDistance.as(
            LengthUnit.Meter, LatLng(r.centerLat, r.centerLng), tap);
        if (!d.isFinite) continue;
        out.add(HitCandidate(
          ref: refOf(ObjectKind.heightRegion, r.id),
          inside: d <= r.radiusMeters,
          edgeDistPx: metersToPixels(camera, tap, (d - r.radiusMeters).abs()),
          sizeProxyMeters: r.radiusMeters,
        ));
      }
    case 'planes':
      for (final p in planes.where((p) => p.layerId == layer.id)) {
        if (!_finite(p.aLat, p.aLng) || !_finite(p.bLat, p.bLng)) continue;
        final near = p.nearA ? LatLng(p.aLat, p.aLng) : LatLng(p.bLat, p.bLng);
        final far = p.nearA ? LatLng(p.bLat, p.bLng) : LatLng(p.aLat, p.aLng);
        final dn = geoDistance.as(LengthUnit.Meter, near, tap);
        final df = geoDistance.as(LengthUnit.Meter, far, tap);
        if (!dn.isFinite || !df.isFinite) continue;
        out.add(HitCandidate(
          ref: refOf(ObjectKind.plane, p.id),
          inside: dn <= df,
          // Distance to the bisector is half the difference of the two.
          edgeDistPx: metersToPixels(camera, tap, (dn - df).abs() / 2),
          // A half-plane is unbounded, so it never wins on specificity.
          sizeProxyMeters: double.infinity,
        ));
      }
    case 'subspace':
      for (final s in subspaces.where((s) => s.layerId == layer.id)) {
        final pts = subspacePoints
            .where((p) => p.subspaceId == s.id && _finite(p.lat, p.lng))
            .toList();
        if (pts.length < 2) continue;
        double? dMain;
        var dOtherMin = double.infinity;
        var nearestOther = double.infinity;
        for (final p in pts) {
          final d =
              geoDistance.as(LengthUnit.Meter, LatLng(p.lat, p.lng), tap);
          if (!d.isFinite) continue;
          if (p.isMain) {
            dMain = dMain == null ? d : math.min(dMain, d);
          } else if (d < dOtherMin) {
            dOtherMin = d;
          }
        }
        if (dMain == null || !dOtherMin.isFinite) continue;
        // How close the neighbours crowd the main point — a rough cell size.
        final main = pts.where((p) => p.isMain).firstOrNull;
        if (main != null) {
          for (final p in pts) {
            if (p.id == main.id) continue;
            final d = geoDistance.as(LengthUnit.Meter,
                LatLng(main.lat, main.lng), LatLng(p.lat, p.lng));
            if (d.isFinite && d < nearestOther) nearestOther = d;
          }
        }
        out.add(HitCandidate(
          ref: refOf(ObjectKind.subspace, s.id),
          inside: dMain <= dOtherMin,
          // The cell border is equidistant, so it sits half the gap away.
          edgeDistPx:
              metersToPixels(camera, tap, (dMain - dOtherMin).abs() / 2),
          sizeProxyMeters: nearestOther,
        ));
      }
    case 'freeline':
      for (final l in freeLines.where((l) => l.layerId == layer.id)) {
        final pts = (freeLinePoints
                .where((p) => p.freeLineId == l.id && _finite(p.lat, p.lng))
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
            .map((p) => LatLng(p.lat, p.lng))
            .toList();
        if (pts.length < 2) continue;
        var best = double.infinity;
        for (var i = 0; i < pts.length - 1; i++) {
          final d = distToSegment(
            tapPx,
            camera.latLngToScreenOffset(pts[i]),
            camera.latLngToScreenOffset(pts[i + 1]),
          );
          if (d < best) best = d;
        }
        if (!best.isFinite) continue;
        final inc = effectiveInclusion(
          lat: l.inclusionLat,
          lng: l.inclusionLng,
          radiusMeters: l.inclusionRadiusMeters,
          points: pts,
        );
        out.add(HitCandidate(
          ref: refOf(ObjectKind.freeLine, l.id),
          // The drawn line is the object; its half-disk fill is not a hit area
          // (that would make half the view select the line).
          inside: false,
          edgeDistPx: best,
          sizeProxyMeters: inc.radiusMeters,
        ));
      }
    case 'freearea':
      for (final a in freeAreas.where((a) => a.layerId == layer.id)) {
        final raw = (freeAreaPoints
                .where((p) => p.freeAreaId == a.id && _finite(p.lat, p.lng))
                .toList()
              ..sort((x, y) => x.sortOrder.compareTo(y.sortOrder)))
            .map((p) => LatLng(p.lat, p.lng))
            .toList();
        if (raw.length < 3) continue;
        final contours = areaContours?.call(a) ?? [raw];
        var inside = false;
        var best = double.infinity;
        for (final ring in contours) {
          if (ring.length < 3) continue;
          final px = [for (final p in ring) camera.latLngToScreenOffset(p)];
          // Even-odd across contours, so an offset's holes read as outside.
          if (pointInPolygon(tapPx, px)) inside = !inside;
          for (var i = 0; i < px.length; i++) {
            final d = distToSegment(tapPx, px[i], px[(i + 1) % px.length]);
            if (d < best) best = d;
          }
        }
        if (!best.isFinite) continue;
        out.add(HitCandidate(
          ref: refOf(ObjectKind.freeArea, a.id),
          inside: inside,
          edgeDistPx: best,
          sizeProxyMeters: ViewBound.ofCorners(raw).diagonalMeters,
        ));
      }
  }
  return out;
}

bool _finite(double a, double b) => a.isFinite && b.isFinite;

/// How many screen pixels [meters] on the ground spans near [at], by projecting
/// a point that far north. Mirrors the painter's private `_metersToPixels` so a
/// metre-space distance can be compared against a pixel tap tolerance.
///
/// Returns 0 for a degenerate camera rather than a non-finite value.
double metersToPixels(MapCamera camera, LatLng at, double meters) {
  if (!meters.isFinite || meters <= 0) return 0;
  final north = geoDistance.offset(at, meters, 0);
  final a = camera.latLngToScreenOffset(at);
  final b = camera.latLngToScreenOffset(north);
  final px = (a - b).distance;
  return px.isFinite ? px : 0;
}
