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
        const Offset(180, 799), // bottom centre — the pixel that used to fall out
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
