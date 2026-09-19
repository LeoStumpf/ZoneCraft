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

import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// The map's screen-space viewport: the map widget's own, non-rotated box.
///
/// **Never use [MapCamera.size] for screen-space work.** `MapCamera` carries two
/// sizes and they differ as soon as the map is rotated:
///
/// - [MapCamera.nonRotatedSize] is the widget's box, and it is the space
///   [MapCamera.latLngToScreenOffset] / [MapCamera.screenOffsetToLatLng] work
///   in — they apply the rotation themselves.
/// - [MapCamera.size] is the *rotation-expanded bounding box* of that widget
///   (`W·|cos θ| + H·|sin θ|` per axis), meant for layers that paint in canvas
///   space through flutter_map's `MobileLayerTransformer`.
///
/// Everything in this app projects with `latLngToScreenOffset`, so every clip
/// and cull rect must be this one. Clipping against [MapCamera.size] instead
/// chops overlays along a straight line whenever the map is rotated: at 90° on
/// a 360×800 viewport the canvas becomes 800×360, top-left anchored, so nothing
/// paints below y≈360. It is invisible at 0°/180° and worst near 90°/270°,
/// which is why it reached users as "half my layer disappears after pinching"
/// (pinch-zoom also rotates).
Rect cameraViewport(MapCamera camera) => Offset.zero & camera.nonRotatedSize;

/// The four corners of [cameraViewport], inflated by [inflatePx], as lat/lng in
/// ring order — the spherical clip box for the unbounded (subspace) regions.
///
/// Longitudes are **continuous around the camera centre, not clamped to
/// ±180**. flutter_map's `screenOffsetToLatLng` clamps the unprojected
/// longitude to ±180 (`Epsg3857` replicates the world sideways, so a screen
/// point past the antimeridian is a real place in the next world copy), which
/// would turn a view straddling 180° into corners of 170 and −170 — a 340° box
/// instead of a 20° one — and would silently cut a view wider than the world
/// down to exactly one world. Web Mercator's x axis is linear in longitude
/// (`x = (lng / 360 + 0.5) · worldWidth`), so the longitude is read straight
/// off the same rotated pixel point the unproject uses; the latitude comes from
/// the unproject as before. Corners of a view centred at lng 179 come out as
/// e.g. 170…188, and a view wider than the world keeps its true extent.
///
/// Null when a corner is non-finite (an infinite viewport size), which callers
/// treat as "don't draw".
List<LatLng>? viewportCorners(MapCamera camera, {double inflatePx = 8}) {
  final r = cameraViewport(camera).inflate(inflatePx);
  final offs = <Offset>[r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  final worldWidth = camera.getWorldWidthAtZoom();
  final mapCenter = camera.projectAtZoom(camera.center);
  final halfSize = camera.nonRotatedSize.center(Offset.zero);
  final out = <LatLng>[];
  for (final o in offs) {
    final ll = camera.screenOffsetToLatLng(o);
    var lng = ll.longitude;
    if (worldWidth > 0) {
      // The same pixel point `screenOffsetToLatLng` unprojects, before the
      // CRS clamps its longitude.
      var point = mapCenter - (halfSize - o);
      if (camera.rotation != 0.0) point = camera.rotatePoint(mapCenter, point);
      lng = (point.dx / worldWidth - 0.5) * 360;
    }
    if (!ll.latitude.isFinite || !lng.isFinite) return null;
    out.add(LatLng(ll.latitude, lng));
  }
  return out;
}
