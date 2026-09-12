// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../data/layer_types.dart';
import '../data/poi_sets.dart' show poiPointVisible;
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
    this.z = 0,
    this.layerZ = 0,
  });

  final ObjectRef ref;
  final bool inside;
  final double edgeDistPx;
  final double sizeProxyMeters;

  /// The element's place in its layer's stack — higher is drawn in front.
  ///
  /// A **tie-break only**; see [rankCandidates] for why it must never outrank
  /// size. Defaults to 0 so a candidate built without one simply ties.
  final int z;

  /// The owning *layer's* place in the map stack — higher is drawn in front.
  ///
  /// The outer tie-break, above [z]: a tap that several layers answer equally
  /// well resolves to the one on top, which is the one whose fill you see.
  /// Defaults to 0, so a single-layer collection ranks exactly as before.
  final int layerZ;

  HitCandidate copyWith({int? layerZ}) => HitCandidate(
    ref: ref,
    inside: inside,
    edgeDistPx: edgeDistPx,
    sizeProxyMeters: sizeProxyMeters,
    z: z,
    layerZ: layerZ ?? this.layerZ,
  );
}

/// Orders candidates by what the user most likely meant, best first.
///
/// 1. Anything within [tolerancePx] of its boundary, nearest boundary first —
///    pointing at an outline is an unambiguous "that one".
/// 2. Otherwise anything containing the point, smallest first — this
///    generalises the old "smallest circle wins", and is what stops a
///    continent-sized half-plane from swallowing every tap.
///
/// Ties inside each of those two buckets are broken by stack order, front
/// first, so two coincident circles of the same radius resolve to the one you
/// can actually see. It is deliberately **only** a tie-break: promoted above
/// `sizeProxyMeters` it would let a large element in front swallow taps meant
/// for a small one behind it, which is exactly the failure the size rule exists
/// to prevent. The kind ordinal sits between the two because `z` is scoped per
/// table — a circle's z and a subspace's z are not comparable — and without it the
/// comparator would not be a total order on a mixed layer.
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
  int byStack(HitCandidate a, HitCandidate b) {
    // Layer first: `z` is scoped per table *within* a layer, so across
    // layers only the layer order is comparable.
    final l = b.layerZ.compareTo(a.layerZ);
    if (l != 0) return l;
    final k = a.ref.kind.index.compareTo(b.ref.kind.index);
    return k != 0 ? k : b.z.compareTo(a.z);
  }

  onEdge.sort((a, b) {
    final d = a.edgeDistPx.compareTo(b.edgeDistPx);
    return d != 0 ? d : byStack(a, b);
  });
  within.sort((a, b) {
    final d = a.sizeProxyMeters.compareTo(b.sizeProxyMeters);
    return d != 0 ? d : byStack(a, b);
  });
  final ranked = [...onEdge, ...within];
  return ranked.length <= max ? ranked : ranked.sublist(0, max);
}

/// Every object of [layer] that [tap] could have meant, unranked.
///
/// [areaContours] optionally supplies a freehand area's *resolved* boundary
/// (the offset outline the painter actually draws); without it the raw drawn
/// ring is used, which differs only when the area carries an offset.
/// [layerZ] stamps every candidate with the layer's stack position, for a
/// caller that collects over several layers and ranks them together.
List<HitCandidate> collectCandidates({
  required MapCamera camera,
  required LatLng tap,
  required Layer layer,
  int layerZ = 0,
  List<Circle> circles = const [],
  List<Subspace> subspaces = const [],
  List<SubspacePoint> subspacePoints = const [],
  List<FreeLine> freeLines = const [],
  List<FreeLinePoint> freeLinePoints = const [],
  List<FreeArea> freeAreas = const [],
  List<FreeAreaPoint> freeAreaPoints = const [],
  List<HeightRegion> heightRegions = const [],
  List<PoiSet> poiSets = const [],
  List<PoiPoint> poiPoints = const [],
  List<BorderShapeRef> borderShapes = const [],
  List<List<LatLng>> Function(FreeArea area)? areaContours,
}) {
  final out = <HitCandidate>[];
  final tapPx = camera.latLngToScreenOffset(tap);

  ObjectRef refOf(ObjectKind kind, String id) =>
      ObjectRef(kind: kind, id: id, layerId: layer.id);

  // Same predicate the painter uses, driven the same way: a mixed layer
  // offers every type it holds, a single-type layer exactly its own. When
  // "what is drawn" and "what can be tapped" were decided separately the two
  // drifted apart — see `poiPointVisible`.
  for (final type in layerContentTypes(layer)) {
    switch (type) {
      case 'circles':
        for (final c in circles.where((c) => c.layerId == layer.id)) {
          if (!c.radiusMeters.isFinite || c.radiusMeters <= 0) continue;
          if (!c.centerLat.isFinite || !c.centerLng.isFinite) continue;
          final d = geoDistance.as(
            LengthUnit.Meter,
            LatLng(c.centerLat, c.centerLng),
            tap,
          );
          if (!d.isFinite) continue;
          out.add(
            HitCandidate(
              ref: refOf(ObjectKind.circle, c.id),
              inside: d <= c.radiusMeters,
              edgeDistPx: metersToPixels(
                camera,
                tap,
                (d - c.radiusMeters).abs(),
              ),
              sizeProxyMeters: c.radiusMeters,
              z: c.zOrder,
            ),
          );
        }
      case 'height':
        for (final r in heightRegions.where((r) => r.layerId == layer.id)) {
          if (!r.radiusMeters.isFinite || r.radiusMeters <= 0) continue;
          if (!r.centerLat.isFinite || !r.centerLng.isFinite) continue;
          final d = geoDistance.as(
            LengthUnit.Meter,
            LatLng(r.centerLat, r.centerLng),
            tap,
          );
          if (!d.isFinite) continue;
          out.add(
            HitCandidate(
              ref: refOf(ObjectKind.heightRegion, r.id),
              inside: d <= r.radiusMeters,
              edgeDistPx: metersToPixels(
                camera,
                tap,
                (d - r.radiusMeters).abs(),
              ),
              sizeProxyMeters: r.radiusMeters,
              z: r.zOrder,
            ),
          );
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
            final d = geoDistance.as(
              LengthUnit.Meter,
              LatLng(p.lat, p.lng),
              tap,
            );
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
              final d = geoDistance.as(
                LengthUnit.Meter,
                LatLng(main.lat, main.lng),
                LatLng(p.lat, p.lng),
              );
              if (d.isFinite && d < nearestOther) nearestOther = d;
            }
          }
          out.add(
            HitCandidate(
              ref: refOf(ObjectKind.subspace, s.id),
              inside: dMain <= dOtherMin,
              // The cell border is equidistant, so it sits half the gap away.
              edgeDistPx: metersToPixels(
                camera,
                tap,
                (dMain - dOtherMin).abs() / 2,
              ),
              sizeProxyMeters: nearestOther,
              z: s.zOrder,
            ),
          );
        }
      case 'freeline':
        for (final l in freeLines.where((l) => l.layerId == layer.id)) {
          final pts =
              (freeLinePoints
                      .where(
                        (p) => p.freeLineId == l.id && _finite(p.lat, p.lng),
                      )
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
          out.add(
            HitCandidate(
              ref: refOf(ObjectKind.freeLine, l.id),
              // The drawn line is the object; its half-disk fill is not a hit area
              // (that would make half the view select the line).
              inside: false,
              edgeDistPx: best,
              sizeProxyMeters: inc.radiusMeters,
              z: l.zOrder,
            ),
          );
        }
      case 'freearea':
        for (final a in freeAreas.where((a) => a.layerId == layer.id)) {
          final raw =
              (freeAreaPoints
                      .where(
                        (p) => p.freeAreaId == a.id && _finite(p.lat, p.lng),
                      )
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
          out.add(
            HitCandidate(
              ref: refOf(ObjectKind.freeArea, a.id),
              inside: inside,
              edgeDistPx: best,
              sizeProxyMeters: ViewBound.ofCorners(raw).diagonalMeters,
              z: a.zOrder,
            ),
          );
        }
      case 'poi':
        // The marker, not the set: a POI layer's set is a search circle you can't
        // see, so a tap on the map can only sensibly mean the dot under it.
        final mine = {
          for (final st in poiSets)
            if (st.layerId == layer.id) st.id: st,
        };
        for (final p in poiPoints) {
          final set = mine[p.poiSetId];
          if (set == null) continue;
          if (!_finite(p.lat, p.lng)) continue;
          // A station the type filter is hiding is not on screen, so it must not
          // be tappable — picking an invisible marker is indistinguishable from
          // the app picking at random. Same predicate the painter culls with, so
          // the two cannot drift: notably, unticking *every* type hides even the
          // mode-less stations, which an "is any bit shared?" test would leave
          // answering taps over blank ground.
          if (!poiPointVisible(p, set)) continue;
          final d = (camera.latLngToScreenOffset(LatLng(p.lat, p.lng)) - tapPx)
              .distance;
          if (!d.isFinite) continue;
          out.add(
            HitCandidate(
              ref: refOf(ObjectKind.poiPoint, p.id),
              // A marker has no interior — only its own disc counts, which is what
              // stops a tap on empty ground from picking the nearest POI a screen
              // away.
              inside: false,
              edgeDistPx: d,
              sizeProxyMeters: 0,
            ),
          );
        }
      case 'borders':
        for (final shape in borderShapes) {
          // Cull on the stored bounds *before* projecting anything.
          //
          // An administrative outline is not a handful of vertices: one state
          // boundary is 119 238 points, and a municipality layer is ~97 areas.
          // Projecting every vertex of every area on every tap is seconds of
          // frozen UI, and it buys nothing — a ring lies inside its own bounding
          // box, so a tap further than the tap slop from the projected box can
          // neither be inside the area nor near its outline, and [rankCandidates]
          // would drop it anyway. This makes the cull exact, not approximate.
          final box = _projectedBounds(camera, shape);
          if (box == null || !box.inflate(kEdgeTolerancePx).contains(tapPx)) {
            continue;
          }
          var inside = false;
          var best = double.infinity;
          for (final ring in shape.rings) {
            if (ring.length < 3) continue;
            final px = [for (final p in ring) camera.latLngToScreenOffset(p)];
            // Even-odd across rings, matching the painter: a tap in a hole is
            // outside the area, exactly as it looks.
            if (pointInPolygon(tapPx, px)) inside = !inside;
            for (var i = 0; i < px.length; i++) {
              final d = distToSegment(tapPx, px[i], px[(i + 1) % px.length]);
              if (d < best) best = d;
            }
          }
          if (!best.isFinite) continue;
          out.add(
            HitCandidate(
              ref: refOf(ObjectKind.borderArea, shape.id),
              inside: inside,
              edgeDistPx: best,
              // The stored bounds, not the ring: an administrative area is
              // hundreds of points and this only has to order "which of the two
              // areas under the tap is the smaller one".
              sizeProxyMeters: geoDistance.as(
                LengthUnit.Meter,
                LatLng(shape.south, shape.west),
                LatLng(shape.north, shape.east),
              ),
            ),
          );
        }
    }
  }
  if (layerZ == 0) return out;
  return [for (final c in out) c.copyWith(layerZ: layerZ)];
}

/// The bare geometry of one border area that hit-testing needs.
///
/// Deliberately **not** the painter's `BorderShape`: this file is pure and
/// unit-testable, and must not depend on a widget library. The map screen
/// already holds decoded shapes (`borderShapesProvider` decodes once per
/// emission, never per frame) and adapts them at the call site.
class BorderShapeRef {
  const BorderShapeRef({
    required this.id,
    required this.rings,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final String id;
  final List<List<LatLng>> rings;
  final double south, west, north, east;
}

/// The screen-space box that certainly contains [shape], from its four stored
/// corners alone — four projections instead of one per vertex.
///
/// Mercator is monotone in both axes and the camera's rotation is rigid, so the
/// lat/lng box maps to a (possibly rotated) rectangle whose corners are the
/// projections of these four; the bounding box of those four therefore contains
/// every point of the rings. Null when a corner doesn't project finitely.
Rect? _projectedBounds(MapCamera camera, BorderShapeRef shape) {
  if (!_finite(shape.south, shape.north) || !_finite(shape.west, shape.east)) {
    return null;
  }
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final ll in [
    LatLng(shape.south, shape.west),
    LatLng(shape.south, shape.east),
    LatLng(shape.north, shape.east),
    LatLng(shape.north, shape.west),
  ]) {
    final o = camera.latLngToScreenOffset(ll);
    if (!o.dx.isFinite || !o.dy.isFinite) return null;
    if (o.dx < minX) minX = o.dx;
    if (o.dx > maxX) maxX = o.dx;
    if (o.dy < minY) minY = o.dy;
    if (o.dy > maxY) maxY = o.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
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
