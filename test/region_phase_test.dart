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
import 'package:latlong2/latlong.dart' hide Circle, Path;

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/ui/area_geometry.dart';
import 'package:zonecraft/ui/region_layer.dart';

/// The uncertainty band is painted in its own pass, below every solid fill on
/// the map.
///
/// A band says "the region *might* reach here". Once elements could be
/// reordered, a front element's band started landing on a back element's solid
/// fill — the uncertain shape drawn over the certain one. The fix is a draw
/// *order*: all bands, then all fills. Nothing in the widget tree can state
/// that, so this drives the painter against a recording canvas.
///
/// The other half of the invariant is that the two passes stay **disjoint**.
/// They composite separately (they are separate widgets), so a band left under
/// a fill would blend with it into a third colour — the exact thing the
/// flat-union model exists to avoid. Hence the clears.
void main() {
  final camera = MapCamera(
    crs: const Epsg3857(),
    center: const LatLng(48.14, 11.57),
    zoom: 13,
    rotation: 0,
    nonRotatedSize: const Size(400, 600),
  );

  const layerOpacity = 0.45; // k = 1: solid 0.45, band 0.20, outline 1.0
  const solidAlpha = 0.45;
  const bandAlpha = 0.20;

  final layer = Layer(
    id: 'l1',
    name: 'l1',
    type: kCircles,
    colorArgb: 0xFF2196F3,
    opacity: layerOpacity,
    isVisible: true,
    isInverted: false,
    sortOrder: 0,
    borderFillAreas: false,
    borderShowNames: false,
    createdAt: DateTime(2026, 9, 1),
  );

  Circle circle(String id, double lng, int argb) => Circle(
    id: id,
    layerId: 'l1',
    centerLat: 48.14,
    centerLng: lng,
    radiusMeters: 800,
    createdAt: DateTime(2026, 9, 1),
    colorArgb: argb,
    colorShade: 0,
    zOrder: 0,
  );

  // Two overlapping circles in different colours: two colour runs, back first.
  final back = circle('back', 11.565, 0xFF00FF00);
  final front = circle('front', 11.575, 0xFF0000FF);

  List<_Op> paint(RegionPhase phase, {double uncertainty = 500}) {
    final widget = RegionLayer(
      layer: layer,
      circles: [back, front],
      uncertaintyMeters: uncertainty,
      phase: phase,
      opacity: layerOpacity,
    );
    final rec = _Recorder();
    widget
        .painterFor(camera, const <ResolvedArea>[])
        .paint(rec, const Size(400, 600));
    return rec.ops;
  }

  test('the band pass draws bands only, the fill pass fills only', () {
    final bands = paint(RegionPhase.band);
    final fills = paint(RegionPhase.fill);

    // Both passes have something to say about both runs.
    expect(bands.where((o) => o.isFill(bandAlpha)), hasLength(2));
    expect(fills.where((o) => o.isFill(solidAlpha)), hasLength(2));

    // ...and neither strays into the other's job. This is the whole point: a
    // band can no longer be drawn in the same breath as a fill, so it can no
    // longer land on top of one.
    expect(bands.where((o) => o.isFill(solidAlpha)), isEmpty);
    expect(fills.where((o) => o.isFill(bandAlpha)), isEmpty);
  });

  test('every band is drawn before any of the fill area is cleared', () {
    // The clears take the fill pass's area back out of the band pass. They have
    // to come last: clearing per run as we go would let the *front* run's band
    // paint over the *back* run's already-cleared fill area, and that band
    // would then sit under that fill once the two passes composite.
    final ops = paint(RegionPhase.band);
    final lastBand = ops.lastIndexWhere((o) => o.isFill(bandAlpha));
    final firstClear = ops.indexWhere((o) => o.blend == BlendMode.clear);
    expect(
      firstClear,
      greaterThan(-1),
      reason: 'the fill area must be cleared',
    );
    expect(lastBand, lessThan(firstClear));
    // One clear per run, so a front band cannot survive over a back solid.
    expect(ops.where((o) => o.blend == BlendMode.clear), hasLength(2));
  });

  test('the band pass always takes an offscreen layer, because it clears', () {
    // A clear on the bare canvas would take the map tiles with it.
    final ops = paint(RegionPhase.band);
    final layerOpen = ops.indexWhere((o) => o.kind == 'saveLayer');
    expect(layerOpen, greaterThan(-1));
    expect(layerOpen, lessThan(ops.indexWhere((o) => o.kind == 'drawPath')));
    expect(ops.last.kind, 'restore');
  });

  test('both passes visit the colour runs in the same order', () {
    // Bands keep the relative stacking the fills have, or sending an element
    // back would shuffle the bands the other way.
    List<int> colours(List<_Op> ops, double alpha) => [
      for (final o in ops)
        if (o.isFill(alpha)) o.rgb,
    ];
    expect(colours(paint(RegionPhase.band), bandAlpha), [0x00FF00, 0x0000FF]);
    expect(colours(paint(RegionPhase.fill), solidAlpha), [0x00FF00, 0x0000FF]);
  });

  test('with no uncertainty the band pass draws nothing at all', () {
    // At 0 m the map screen drops the pass entirely (see bandPassLayers); the
    // painter must agree, so a stray band widget cannot clear a hole in itself.
    final ops = paint(RegionPhase.band, uncertainty: 0);
    expect(ops.where((o) => o.kind == 'drawPath'), isEmpty);
  });

  test('the fill pass still paints its outline', () {
    // The nominal boundary is not a band and does not move: it stays with the
    // fill, above every band on the map.
    final ops = paint(RegionPhase.fill);
    expect(ops.where((o) => o.isStroke), hasLength(2));
  });
}

/// One recorded canvas call: what it was, and the paint it used.
class _Op {
  _Op(
    this.kind, {
    this.alpha = 0,
    this.rgb = 0,
    this.blend,
    this.isStroke = false,
  });

  final String kind;
  final double alpha;
  final int rgb;
  final BlendMode? blend;
  final bool isStroke;

  bool isFill(double a) =>
      kind == 'drawPath' &&
      !isStroke &&
      blend != BlendMode.clear &&
      (alpha - a).abs() < 0.005;

  @override
  String toString() => '$kind(a=$alpha, rgb=${rgb.toRadixString(16)}, $blend)';
}

/// A [Canvas] that records instead of rasterising. `noSuchMethod` swallows the
/// rest of the (large) interface — only the calls the region painter makes are
/// worth capturing.
class _Recorder implements Canvas {
  final ops = <_Op>[];

  _Op _of(String kind, Paint paint) => _Op(
    kind,
    alpha: paint.color.a,
    rgb: paint.color.toARGB32() & 0xFFFFFF,
    blend: paint.blendMode,
    isStroke: paint.style == PaintingStyle.stroke,
  );

  @override
  void drawPath(Path path, Paint paint) => ops.add(_of('drawPath', paint));

  @override
  void drawRect(Rect rect, Paint paint) => ops.add(_of('drawRect', paint));

  @override
  void saveLayer(Rect? bounds, Paint paint) => ops.add(_of('saveLayer', paint));

  @override
  void save() => ops.add(_Op('save'));

  @override
  void restore() => ops.add(_Op('restore'));

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) => ops.add(_Op('clipRect'));

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) =>
      ops.add(_Op('clipPath'));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
