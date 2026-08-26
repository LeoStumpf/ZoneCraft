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
/// ring order — the spherical clip quad for the unbounded (plane/subspace/
/// freeline) regions. Null when a corner unprojects to a non-finite coordinate
/// (extreme zoom-out / near-pole), which callers treat as "don't draw".
List<LatLng>? viewportCorners(MapCamera camera, {double inflatePx = 8}) {
  final r = cameraViewport(camera).inflate(inflatePx);
  final offs = <Offset>[r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  final out = <LatLng>[];
  for (final o in offs) {
    final ll = camera.screenOffsetToLatLng(o);
    if (!ll.latitude.isFinite || !ll.longitude.isFinite) return null;
    out.add(ll);
  }
  return out;
}
