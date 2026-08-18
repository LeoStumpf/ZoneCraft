import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/ui/draw_stroke.dart';

MapCamera _camera({double zoom = 14, double rotation = 0}) => MapCamera(
  crs: const Epsg3857(),
  center: const LatLng(48.137, 11.575),
  zoom: zoom,
  rotation: rotation,
  nonRotatedSize: const Size(360, 800),
);

/// A straight stroke of [n] points from [a] to [b], as a finger would emit it.
List<Offset> _drag(Offset a, Offset b, {int n = 60}) => [
  for (var i = 0; i < n; i++) Offset.lerp(a, b, i / (n - 1))!,
];

void main() {
  group('strokeToPoints', () {
    test('a straight drag collapses to its two endpoints', () {
      final pts = strokeToPoints(
        _drag(const Offset(60, 200), const Offset(300, 600)),
        _camera(),
        closed: false,
      );
      expect(pts, isNotNull);
      expect(pts!.length, 2, reason: 'RDP keeps only the endpoints of a line');
    });

    test('keeps the shape of a bend', () {
      final stroke = [
        ..._drag(const Offset(60, 200), const Offset(300, 200)),
        ..._drag(const Offset(300, 200), const Offset(300, 600)),
      ];
      final pts = strokeToPoints(stroke, _camera(), closed: false)!;
      expect(pts.length, 3); // start, corner, end
    });

    test('a tap or a twitch is not a drawing', () {
      expect(
        strokeToPoints(const [Offset(100, 100)], _camera(), closed: false),
        isNull,
      );
      expect(
        strokeToPoints(
          _drag(const Offset(100, 100), const Offset(104, 103)),
          _camera(),
          closed: false,
        ),
        isNull,
        reason: 'a 5 px span is a finger twitch, not a stroke',
      );
    });

    test('an area needs three points and is stored without a closing dup', () {
      final triangle = [
        ..._drag(const Offset(80, 200), const Offset(280, 200)),
        ..._drag(const Offset(280, 200), const Offset(180, 400)),
        ..._drag(const Offset(180, 400), const Offset(80, 200)),
      ];
      final pts = strokeToPoints(triangle, _camera(), closed: true)!;
      expect(pts.length, 3);
      expect(pts.first, isNot(pts.last));

      // A straight drag can't be an area: closing it leaves a degenerate sliver.
      expect(
        strokeToPoints(
          _drag(const Offset(60, 200), const Offset(300, 600)),
          _camera(),
          closed: true,
        ),
        isNull,
      );
    });

    test('thinning is zoom-relative: the same wiggle survives at any zoom', () {
      // A saw-tooth whose teeth are 12 px tall — visible to the user at every
      // zoom, so it must survive at every zoom. A fixed metre tolerance would
      // keep it only when zoomed in.
      final saw = <Offset>[];
      for (var x = 60; x <= 300; x += 20) {
        saw.add(Offset(x.toDouble(), 300));
        saw.add(Offset(x + 10.0, 312));
      }
      for (final zoom in [6.0, 12.0, 18.0]) {
        final pts = strokeToPoints(saw, _camera(zoom: zoom), closed: false)!;
        expect(
          pts.length,
          greaterThan(10),
          reason: 'the teeth must survive at zoom $zoom',
        );
      }
    });

    test('screen points map through the camera, rotation included', () {
      // The stroke is in the map widget's own box, which is the space
      // `screenOffsetToLatLng` works in — so a rotated map draws where the
      // finger is, not 90° away from it.
      const a = Offset(60, 200);
      const b = Offset(300, 600);
      for (final rotation in [0.0, 90.0, 217.0]) {
        final camera = _camera(rotation: rotation);
        final pts = strokeToPoints(_drag(a, b), camera, closed: false)!;
        for (final (i, screen) in [a, b].indexed) {
          expect(
            (camera.latLngToScreenOffset(pts[i]) - screen).distance,
            lessThan(1),
            reason: 'endpoint $i at rotation $rotation°',
          );
        }
      }
    });
  });
}
