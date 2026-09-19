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

import 'dart:math';
import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/geo/spherical.dart';
import 'package:zonecraft/ui/area_geometry.dart';
import 'package:zonecraft/ui/region_layer.dart';

/// A two-point subspace (the closer-of-two half-plane) painted at every zoom
/// must fill exactly the ground that *is* closer to its main point.
///
/// Zoomed out to the world it used to vanish around zoom 5, draw as a strip
/// along the bottom edge at zoom 2 and jump about when panned — the clip quad
/// (the viewport grown 75 %) had folded over the pole, and the poisoned rings
/// were then cached for every later zoom. This drives the real painter against
/// a recording canvas and checks the solid fill against geodesic distances on
/// a grid of screen points.
void main() {
  const main = LatLng(48.0, 11.7);
  const other = LatLng(48.2, 11.9);
  const distance = Distance(calculator: Haversine());
  const size = Size(400, 850); // a phone

  // Ground distance from [p] to the divide — the great circle equidistant
  // from main and other, `{P : P·m = 0}` with m along main − other.
  final m = (ecef(main) - ecef(other)).normalized();
  double toDivideMeters(LatLng p) => asin(ecef(p).dot(m).abs()) * earthRadius;

  final layer = Layer(
    id: 'ls',
    name: 'Sub',
    type: kSubspace,
    colorArgb: 0xFFFF0000,
    opacity: 0.45,
    isVisible: true,
    isInverted: false,
    sortOrder: 0,
    borderFillAreas: false,
    borderShowNames: false,
    createdAt: DateTime(2026, 9, 1),
  );
  final subspace = Subspace(
    id: 's1',
    layerId: 'ls',
    createdAt: DateTime(2026, 9, 1),
    colorShade: 0,
    zOrder: 0,
  );
  SubspacePoint point(String id, LatLng p, {required bool isMain}) =>
      SubspacePoint(
        id: id,
        subspaceId: 's1',
        lat: p.latitude,
        lng: p.longitude,
        sortOrder: isMain ? 0 : 1,
        isMain: isMain,
        createdAt: DateTime(2026, 9, 1),
      );

  MapCamera camera(LatLng center, double zoom) => MapCamera(
    crs: const Epsg3857(),
    center: center,
    zoom: zoom,
    rotation: 0,
    nonRotatedSize: size,
  );

  /// `screenOffsetToLatLng` with the longitude left unclamped (flutter_map
  /// clamps it to ±180, which would put every point past the antimeridian
  /// *on* it).
  LatLng unproject(MapCamera cam, Offset p) {
    final ll = cam.screenOffsetToLatLng(p);
    final worldPx = cam.getWorldWidthAtZoom();
    final lng = cam.center.longitude + (p.dx - size.width / 2) / worldPx * 360;
    return LatLng(ll.latitude, lng);
  }

  /// The solid fill the fill pass draws, or null if it drew none.
  Path? solidFill(MapCamera cam, {bool inverted = false}) {
    final widget = RegionLayer(
      layer: inverted ? layer.copyWith(isInverted: true) : layer,
      subspaces: [subspace],
      subspacePoints: {
        's1': [
          point('m', main, isMain: true),
          point('o', other, isMain: false),
        ],
      },
      uncertaintyMeters: 0,
      phase: RegionPhase.fill,
      opacity: 0.45,
    );
    final rec = _Recorder();
    widget.painterFor(cam, const <ResolvedArea>[]).paint(rec, size);
    return rec.fills.singleOrNull;
  }

  /// Every grid point at least [marginPx] inside the viewport whose ground is
  /// clearly on one side of the divide must be filled iff it is closer to
  /// main (or the other way round when inverted).
  void expectMatchesGround(
    MapCamera cam, {
    bool inverted = false,
    double nearDivideMeters = 150000,
  }) {
    final fill = solidFill(cam, inverted: inverted);
    expect(fill, isNotNull, reason: 'zoom ${cam.zoom}: nothing was filled');
    var checked = 0;
    for (var x = 10.0; x < size.width; x += 15) {
      for (var y = 10.0; y < size.height; y += 15) {
        final p = Offset(x, y);
        final ll = unproject(cam, p);
        if (ll.latitude.abs() > 84) continue; // off the Mercator world
        if (toDivideMeters(ll) < nearDivideMeters) continue;
        final dm = distance.as(LengthUnit.Meter, main, ll);
        final dOther = distance.as(LengthUnit.Meter, other, ll);
        final closerToMain = dm < dOther;
        expect(
          fill!.contains(p),
          inverted ? !closerToMain : closerToMain,
          reason:
              'zoom ${cam.zoom} centre ${cam.center}: screen $p = $ll '
              '(dMain ${dm.round()} m, dOther ${dOther.round()} m)',
        );
        checked++;
      }
    }
    expect(checked, greaterThan(500));
  }

  test('street zoom: the half-plane is where it always was', () {
    expectMatchesGround(
      camera(const LatLng(48.1, 11.8), 14),
      nearDivideMeters: 60,
    );
  });

  test('every zoom out to the whole world fills the right ground', () {
    for (final zoom in [10.0, 7.0, 5.0, 4.0, 3.0, 2.0]) {
      expectMatchesGround(
        camera(const LatLng(48.1, 11.7), zoom),
        nearDivideMeters: zoom > 6 ? 2000 : 150000,
      );
    }
  });

  test('the inverted layer fills the complement at world zoom', () {
    expectMatchesGround(camera(const LatLng(20, 11.7), 2), inverted: true);
  });

  test('a view across the antimeridian is one clean region', () {
    expectMatchesGround(camera(const LatLng(-20, 179), 2));
    expectMatchesGround(camera(const LatLng(-20, -179), 3));
  });

  test('zooming in again after the world view is not poisoned by it', () {
    // The geometry cache is app-wide; a world-sized bound built at zoom 2
    // "contains" every later view, so the rings it holds must be right.
    expectMatchesGround(camera(const LatLng(48.1, 11.7), 2));
    expectMatchesGround(
      camera(const LatLng(48.1, 11.8), 14),
      nearDivideMeters: 60,
    );
    expectMatchesGround(camera(const LatLng(48.1, 11.7), 2));
  });
}

class _Recorder implements Canvas {
  final fills = <Path>[];

  @override
  void drawPath(Path path, Paint paint) {
    if (paint.style == PaintingStyle.fill) fills.add(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
