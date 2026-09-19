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
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/ui/camera_viewport.dart';
import 'package:zonecraft/ui/region_geometry.dart';

/// A phone-shaped viewport, the one from the bug report (720×1600 device px at
/// dpr 2).
const _widget = Size(360, 800);

MapCamera _camera(double rotation) => MapCamera(
  crs: const Epsg3857(),
  center: const LatLng(48.104, 11.516),
  zoom: 12,
  rotation: rotation,
  nonRotatedSize: _widget,
);

void main() {
  group('cameraViewport', () {
    test('is the widget box at every rotation', () {
      for (final rotation in [0.0, 45.0, 90.0, 180.0, 270.0, -30.0]) {
        expect(
          cameraViewport(_camera(rotation)),
          Offset.zero & _widget,
          reason: 'rotation $rotation°',
        );
      }
    });

    test('camera.size is NOT the widget box once rotated', () {
      // The trap this helper exists to avoid: `MapCamera.size` is the
      // rotation-expanded bounding box, so a clip built from it cuts the
      // overlay along a straight line (at 90° nothing paints below y≈360).
      final rotated = _camera(90);
      expect(rotated.nonRotatedSize, _widget);
      expect(rotated.size.width, closeTo(800, 0.001));
      expect(rotated.size.height, closeTo(360, 0.001));
      expect(_camera(0).size, _widget);
    });
  });

  group('viewportCorners', () {
    test('round-trip back to the inflated widget rect, rotated or not', () {
      for (final rotation in [0.0, 90.0, 135.0]) {
        final camera = _camera(rotation);
        final corners = viewportCorners(camera);
        expect(corners, isNotNull, reason: 'rotation $rotation°');
        final r = (Offset.zero & _widget).inflate(8);
        final expected = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
        for (var i = 0; i < 4; i++) {
          final back = camera.latLngToScreenOffset(corners![i]);
          expect(
            (back - expected[i]).distance,
            lessThan(1),
            reason: 'corner $i at rotation $rotation°',
          );
        }
      }
    });

    test('the quad covers the whole screen when the map is rotated', () {
      // The regression from the video: at ~90° the clip quad was built from
      // `camera.size`, so the bottom of the screen fell outside it and the
      // subspace fill stopped in a straight line partway down.
      final camera = _camera(90);
      final bound = ViewBound.ofCorners(viewportCorners(camera)!);
      for (final probe in [
        const Offset(
          180,
          799,
        ), // bottom centre — the pixel that used to fall out
        const Offset(0, 799),
        const Offset(359, 799),
        const Offset(180, 0),
      ]) {
        expect(
          bound.containsPoint(camera.screenOffsetToLatLng(probe)),
          isTrue,
          reason: 'screen point $probe must be inside the clip quad',
        );
      }
    });

    test('longitudes are continuous across the antimeridian', () {
      // flutter_map clamps an unprojected longitude to ±180, which would make
      // a view straddling 180° read as 170 and −170 — a 340° box.
      final camera = MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(0, 179),
        zoom: 4,
        rotation: 0,
        nonRotatedSize: _widget,
      );
      final corners = viewportCorners(camera)!;
      final lngs = corners.map((c) => c.longitude).toList();
      expect(lngs[0], lessThan(179));
      expect(lngs[1], greaterThan(180)); // the NE corner is in the next world
      expect(lngs[1] - lngs[0], closeTo(376 * 360 / (256 * 16), 1e-6));
      // ...and agrees with flutter_map wherever no clamp applies.
      final inner = MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(48.1, 11.5),
        zoom: 4,
        rotation: 30,
        nonRotatedSize: _widget,
      );
      for (final c in viewportCorners(inner)!) {
        final back = inner.latLngToScreenOffset(c);
        final r = cameraViewport(inner).inflate(8);
        expect(
          [
            r.topLeft,
            r.topRight,
            r.bottomRight,
            r.bottomLeft,
          ].any((o) => (o - back).distance < 1e-6),
          isTrue,
          reason: '$c must project back onto a corner',
        );
      }
    });

    test('a view wider than the world keeps its true extent', () {
      final camera = MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(0, 0),
        zoom: 2,
        rotation: 0,
        nonRotatedSize: const Size(1400, 800), // world is 1024 px here
      );
      final corners = viewportCorners(camera)!;
      expect(
        corners[1].longitude - corners[0].longitude,
        closeTo(1416 * 360 / 1024, 1e-6),
      );
    });

    test('null when a corner unprojects to a non-finite coordinate', () {
      final camera = MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(48.104, 11.516),
        zoom: 12,
        rotation: 0,
        nonRotatedSize: Size(double.infinity, double.infinity),
      );
      expect(viewportCorners(camera), isNull);
    });
  });
}
