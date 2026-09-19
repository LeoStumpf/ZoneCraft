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

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/tiles.dart';
import 'package:zonecraft/ui/region_geometry.dart';

/// The view bound that unbounded regions are clipped to must stay a box the
/// world can actually show. Growing a zoom-2 viewport by 75 % used to give
/// lat −192…+207 and lng −176…+200; folded onto the sphere that is a small quad
/// on the far side of the globe, and the subspace clipped to it vanished (or
/// drew as a strip), then stayed that way because the out-of-range bound
/// "contained" every later view.
void main() {
  group('ViewBound', () {
    test('ofCorners takes min/max, also for longitudes past ±180', () {
      final b = ViewBound.ofCorners(const [
        LatLng(10, 170),
        LatLng(10, 190),
        LatLng(-5, 190),
        LatLng(-5, 170),
      ]);
      expect(b.minLat, -5);
      expect(b.maxLat, 10);
      expect(b.minLng, 170);
      expect(b.maxLng, 190);
    });

    test('inflated never leaves the drawable world', () {
      // A phone at zoom 2: taller than the world, 138° wide.
      const view = ViewBound(-72, -57, 87.3, 81);
      final b = view.inflated(0.75);
      expect(b.minLat, -mercatorMaxLat);
      expect(b.maxLat, mercatorMaxLat);
      expect(b.maxLng - b.minLng, lessThan(360));
      expect(b.maxLng - b.minLng, greaterThan(340)); // 2.5 × 138
      expect(b.center.longitude, closeTo(12, 1e-9));
      expect(b.contains(view.clampedToWorld()), isTrue);

      // A wide screen at zoom 2: wider than the world. Capped to one world,
      // still centred where the view was.
      const wide = ViewBound(-80, -190, 85, 210);
      final w = wide.inflated(0.75);
      expect(w.maxLng - w.minLng, closeTo(360, 0.02));
      expect(w.center.longitude, closeTo(10, 1e-9));
      expect(w.contains(wide.clampedToWorld()), isTrue);
    });

    test('a street-zoom bound is untouched by the clamp', () {
      const view = ViewBound(48.10, 11.50, 48.12, 11.53);
      final b = view.inflated(0.75);
      expect(b.minLat, closeTo(48.085, 1e-9));
      expect(b.maxLat, closeTo(48.135, 1e-9));
      expect(b.minLng, closeTo(11.4775, 1e-9));
      expect(b.maxLng, closeTo(11.5525, 1e-9));
      expect(b.quad, hasLength(4));
    });

    test('contains works across the antimeridian frame jump', () {
      // Built while the camera centre was −175 (a bound of −215…−135); the
      // camera then wrapped to +175 and the view reads 165…185.
      const bound = ViewBound(-40, -215, 40, -135);
      const view = ViewBound(-10, 165, 10, 185);
      expect(bound.contains(view), isTrue);
      expect(bound.shiftToContain(view), 360);
      expect(bound.shiftToContain(const ViewBound(-10, -185, 10, -165)), 0);
      expect(bound.shiftToContain(const ViewBound(-10, 100, 10, 120)), isNull);
      expect(bound.shiftedLng(360).minLng, 145);
    });
  });

  group('regionGeometryCache.boundRegion', () {
    test(
      're-frames a cached ring when the camera wraps, and does not rebuild',
      () {
        final cache = RegionGeometryCache();
        var builds = 0;
        Rings build(ViewBound b) {
          builds++;
          return (
            outer: [
              [LatLng(0, b.minLng), LatLng(0, b.maxLng), LatLng(1, b.maxLng)],
            ],
            core: const [],
          );
        }

        const west = ViewBound(-10, -185, 10, -165); // camera at −175
        final r1 = cache.boundRegion('s', 'sig', west, build);
        expect(builds, 1);
        expect(r1.outer.single.first.longitude, lessThan(-180));

        const east = ViewBound(-10, 175, 10, 195); // same view, camera at +185
        final r2 = cache.boundRegion('s', 'sig', east, build);
        expect(builds, 1, reason: 'one world over is the same geometry');
        expect(
          r2.outer.single.first.longitude,
          closeTo(r1.outer.single.first.longitude + 360, 1e-9),
        );

        // Zoomed out past the bound: a rebuild, once, then cached at world size
        // for every view that is still world-ish.
        const world = ViewBound(-80, -200, 88, 200);
        cache.boundRegion('s', 'sig', world, build);
        expect(builds, 2);
        cache.boundRegion('s', 'sig', world, build);
        cache.boundRegion(
          's',
          'sig',
          const ViewBound(-60, -100, 60, -40),
          build,
        );
        cache.boundRegion(
          's',
          'sig',
          const ViewBound(-85, -170, 85, 170),
          build,
        );
        expect(builds, 2, reason: 'the world bound covers every later view');
        // ...but not for a close-up: its rings are sampled for a world view,
        // so zooming in more than two levels rebuilds at the finer scale.
        cache.boundRegion('s', 'sig', const ViewBound(-2, 10, 2, 13), build);
        expect(builds, 3);
        // Nor for a view across the bound's own far seam (180° from its
        // centre): that one rebuilds into a world bound centred on itself.
        cache.boundRegion('s', 'sig', world, build);
        expect(builds, 4);
        cache.boundRegion(
          's',
          'sig',
          const ViewBound(-80, -20, 88, 380),
          build,
        );
        expect(builds, 5);
      },
    );
  });
}
