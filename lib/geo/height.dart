import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import 'simplify.dart';

/// Elevation-contour geometry for the height layer: decode Terrarium terrain
/// tiles, sample an elevation grid over a bounded circle, trace the threshold
/// iso-contour with marching squares, and clip the result to the circle.
///
/// Pure Dart with no Flutter/drift deps so [buildHeightRings] can run inside a
/// `compute()` isolate. The caller fetches the terrain tiles (cache-first) and
/// passes their raw PNG bytes in; this file does the CPU-heavy decode + contour.

/// Terrarium PNG terrain tiles (public, no API key). Elevation per pixel is
/// `(R*256 + G + B/256) - 32768` metres.
String terrariumTileUrl(int z, int x, int y) =>
    'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/$z/$x/$y.png';

/// The slippy tile column/row covering [lng]/[lat] at zoom [z] (for a
/// single-point elevation lookup).
int terrariumTileX(double lng, int z) =>
    _lngToTileX(lng, z).floor().clamp(0, (1 << z) - 1);
int terrariumTileY(double lat, int z) =>
    _latToTileY(lat, z).floor().clamp(0, (1 << z) - 1);

/// Elevation (metres) at [lat]/[lng], decoded from the single Terrarium tile
/// PNG [bytes] (tile [tileX]/[tileY] at zoom [z]) that covers it; null if the
/// bytes don't decode. Used by the map's "measure elevation" probe.
double? elevationFromTilePng(
    Uint8List bytes, int z, int tileX, int tileY, double lat, double lng) {
  final im = img.decodePng(bytes);
  if (im == null) return null;
  final px = ((_lngToTileX(lng, z) - tileX) * 256).floor().clamp(0, im.width - 1);
  final py = ((_latToTileY(lat, z) - tileY) * 256).floor().clamp(0, im.height - 1);
  final p = im.getPixel(px, py);
  return p.r * 256 + p.g + p.b / 256 - 32768;
}

/// Hard caps keeping a single generation bounded (also enforced by the caller).
const double heightMaxRadiusMeters = 25000;
const int heightMaxTiles = 80;
const int _maxGrid = 512;
const int _minGrid = 16;

/// Plain, isolate-transferable request for [buildHeightRings]. Tiles are passed
/// as parallel lists (coords + raw PNG bytes) plus the circle + threshold.
class HeightGenRequest {
  const HeightGenRequest({
    required this.tileX,
    required this.tileY,
    required this.tileBytes,
    required this.sampleZoom,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.thresholdMeters,
    required this.aboveThreshold,
  });

  final List<int> tileX;
  final List<int> tileY;
  final List<Uint8List> tileBytes;
  final int sampleZoom;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final double thresholdMeters;
  final bool aboveThreshold;
}

/// The slippy bounding box of a circle, as integer tile coords at [z]. Returned
/// to the caller so it can enumerate/fetch the covering terrain tiles before
/// spawning the isolate.
class TileBox {
  const TileBox(this.minX, this.minY, this.maxX, this.maxY);
  final int minX, minY, maxX, maxY;
  int get count => (maxX - minX + 1) * (maxY - minY + 1);
}

/// Tiles covering the [radiusMeters] circle around ([centerLat], [centerLng]).
TileBox heightTileBox(
  double centerLat,
  double centerLng,
  double radiusMeters,
  int z,
) {
  final b = _circleBounds(centerLat, centerLng, radiusMeters);
  final n = 1 << z;
  int clampT(int v) => v.clamp(0, n - 1);
  return TileBox(
    clampT(_lngToTileX(b.west, z).floor()),
    clampT(_latToTileY(b.north, z).floor()),
    clampT(_lngToTileX(b.east, z).floor()),
    clampT(_latToTileY(b.south, z).floor()),
  );
}

/// Builds the fill-polygon rings for a height region. Runs in an isolate; the
/// result is a list of rings, each a flat `[lat0, lng0, lat1, lng1, …]` list
/// (so it transfers cheaply). Rings are meant to be rendered with an even-odd
/// fill (which yields correct holes); the caller stores them as polygons.
List<List<double>> buildHeightRings(HeightGenRequest req) {
  // 1. Decode tiles, keyed by "x/y".
  final tiles = <String, img.Image>{};
  for (var i = 0; i < req.tileBytes.length; i++) {
    final im = img.decodePng(req.tileBytes[i]);
    if (im != null) tiles['${req.tileX[i]}/${req.tileY[i]}'] = im;
  }

  final z = req.sampleZoom;
  final b = _circleBounds(req.centerLat, req.centerLng, req.radiusMeters);

  // 2. Grid resolution ≈ tile-pixel ground size over the bbox, capped.
  final pxAcross =
      ((_lngToTileX(b.east, z) - _lngToTileX(b.west, z)) * 256).abs();
  final pxDown =
      ((_latToTileY(b.south, z) - _latToTileY(b.north, z)) * 256).abs();
  final gridW = pxAcross.round().clamp(_minGrid, _maxGrid);
  final gridH = pxDown.round().clamp(_minGrid, _maxGrid);

  double lngAt(double i) => b.west + (b.east - b.west) * i / (gridW - 1);
  double latAt(double j) => b.north - (b.north - b.south) * j / (gridH - 1);

  double elevAt(double lat, double lng) {
    final tx = _lngToTileX(lng, z);
    final ty = _latToTileY(lat, z);
    final tileX = tx.floor();
    final tileY = ty.floor();
    final im = tiles['$tileX/$tileY'];
    if (im == null) return 0; // missing tile (ocean / 404) -> sea level
    final px = ((tx - tileX) * 256).floor().clamp(0, im.width - 1);
    final py = ((ty - tileY) * 256).floor().clamp(0, im.height - 1);
    final p = im.getPixel(px, py);
    return p.r * 256 + p.g + p.b / 256 - 32768;
  }

  // 3. Augmented scalar field (real grid + 1-cell border). The border value is
  //    forced to the *opposite* side of the threshold so every region of
  //    interest closes into a loop; which side even-odd fill then keeps is set
  //    by this padding (pad "below" -> fill above; pad "above" -> fill below).
  final iso = req.thresholdMeters;
  final pad = req.aboveThreshold ? iso - 1e9 : iso + 1e9;
  final w2 = gridW + 2;
  final h2 = gridH + 2;
  final field = List<double>.filled(w2 * h2, pad);
  for (var j = 0; j < gridH; j++) {
    final lat = latAt(j.toDouble());
    for (var i = 0; i < gridW; i++) {
      field[(j + 1) * w2 + (i + 1)] = elevAt(lat, lngAt(i.toDouble()));
    }
  }
  double f(int ai, int aj) => field[aj * w2 + ai];

  // 4. Marching squares -> segments in augmented (col,row) space.
  final segs = <_Seg>[];
  _Pt interp(double iso, double va, double vb, _Pt a, _Pt b) {
    final d = vb - va;
    final t = d.abs() < 1e-12 ? 0.5 : (iso - va) / d;
    return _Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  for (var aj = 0; aj < h2 - 1; aj++) {
    for (var ai = 0; ai < w2 - 1; ai++) {
      final tl = f(ai, aj);
      final tr = f(ai + 1, aj);
      final br = f(ai + 1, aj + 1);
      final bl = f(ai, aj + 1);
      var c = 0;
      if (tl >= iso) c |= 8;
      if (tr >= iso) c |= 4;
      if (br >= iso) c |= 2;
      if (bl >= iso) c |= 1;
      if (c == 0 || c == 15) continue;

      // Edge crossing points (only computed when used).
      _Pt top() => interp(iso, tl, tr, _Pt(ai.toDouble(), aj.toDouble()),
          _Pt(ai + 1.0, aj.toDouble()));
      _Pt right() => interp(iso, tr, br, _Pt(ai + 1.0, aj.toDouble()),
          _Pt(ai + 1.0, aj + 1.0));
      _Pt bottom() => interp(iso, bl, br, _Pt(ai.toDouble(), aj + 1.0),
          _Pt(ai + 1.0, aj + 1.0));
      _Pt left() => interp(iso, tl, bl, _Pt(ai.toDouble(), aj.toDouble()),
          _Pt(ai.toDouble(), aj + 1.0));

      void add(_Pt a, _Pt b) => segs.add(_Seg(a, b));
      final centerInside = (tl + tr + br + bl) / 4 >= iso;
      switch (c) {
        case 1:
          add(left(), bottom());
        case 2:
          add(bottom(), right());
        case 3:
          add(left(), right());
        case 4:
          add(top(), right());
        case 5:
          if (centerInside) {
            add(left(), top());
            add(bottom(), right());
          } else {
            add(left(), bottom());
            add(top(), right());
          }
        case 6:
          add(top(), bottom());
        case 7:
          add(left(), top());
        case 8:
          add(left(), top());
        case 9:
          add(top(), bottom());
        case 10:
          if (centerInside) {
            add(left(), bottom());
            add(top(), right());
          } else {
            add(left(), top());
            add(bottom(), right());
          }
        case 11:
          add(top(), right());
        case 12:
          add(left(), right());
        case 13:
          add(bottom(), right());
        case 14:
          add(left(), bottom());
      }
    }
  }

  // 5. Stitch segments into closed loops, map back to lat/lng, clip to circle.
  final clipPoly = _geoCircle(req.centerLat, req.centerLng, req.radiusMeters);
  final center = LatLng(req.centerLat, req.centerLng);
  final out = <List<double>>[];
  for (final loop in _stitch(segs)) {
    final ring = <LatLng>[
      // augmented (col,row) -> real grid coords (subtract the 1-cell border).
      for (final p in loop) LatLng(latAt(p.y - 1), lngAt(p.x - 1)),
    ];
    final clipped = _clipToConvex(ring, clipPoly, center);
    // Thin the marching-squares stair-steps (many collinear points) before
    // storing; runs in this isolate so the cost stays off the UI thread.
    final simplified =
        simplifyRing(clipped, kHeightSimplifyMeters, minPoints: 4);
    if (simplified.length < 3) continue;
    out.add([for (final p in simplified) ...[p.latitude, p.longitude]]);
  }
  return out;
}

// --- marching-squares helpers ----------------------------------------------

class _Pt {
  const _Pt(this.x, this.y);
  final double x, y;
  String get key => '${(x * 4096).round()}:${(y * 4096).round()}';
}

class _Seg {
  _Seg(this.a, this.b);
  final _Pt a, b;
}

List<List<_Pt>> _stitch(List<_Seg> segs) {
  final byKey = <String, List<int>>{};
  for (var i = 0; i < segs.length; i++) {
    byKey.putIfAbsent(segs[i].a.key, () => []).add(i);
    byKey.putIfAbsent(segs[i].b.key, () => []).add(i);
  }
  final used = List<bool>.filled(segs.length, false);
  final loops = <List<_Pt>>[];
  for (var s = 0; s < segs.length; s++) {
    if (used[s]) continue;
    final loop = <_Pt>[segs[s].a];
    var curIdx = s;
    var curKey = segs[s].a.key;
    while (true) {
      used[curIdx] = true;
      final seg = segs[curIdx];
      final atA = seg.a.key == curKey;
      final next = atA ? seg.b : seg.a;
      loop.add(next);
      curKey = next.key;
      int? pick;
      for (final ci in byKey[curKey] ?? const <int>[]) {
        if (!used[ci]) {
          pick = ci;
          break;
        }
      }
      if (pick == null) break;
      curIdx = pick;
    }
    if (loop.length >= 4) loops.add(loop);
  }
  return loops;
}

// --- geo helpers ------------------------------------------------------------

class _Bounds {
  const _Bounds(this.north, this.south, this.west, this.east);
  final double north, south, west, east;
}

_Bounds _circleBounds(double lat, double lng, double radiusMeters) {
  final dLat = radiusMeters / 111320.0;
  final cosLat = math.cos(lat * math.pi / 180).abs();
  final dLng = radiusMeters / (111320.0 * (cosLat < 1e-6 ? 1e-6 : cosLat));
  return _Bounds(lat + dLat, lat - dLat, lng - dLng, lng + dLng);
}

const Distance _dist = Distance(calculator: Haversine());

List<LatLng> _geoCircle(double lat, double lng, double radiusMeters,
    {int points = 64}) {
  final center = LatLng(lat, lng);
  final ring = <LatLng>[];
  for (var i = 0; i < points; i++) {
    var bearing = 360.0 * i / points;
    if (bearing > 180.0) bearing -= 360.0;
    ring.add(_dist.offset(center, radiusMeters, bearing));
  }
  return ring;
}

double _lngToTileX(double lng, int z) => (lng + 180.0) / 360.0 * (1 << z);

double _latToTileY(double lat, int z) {
  final clamped = lat.clamp(-85.05112878, 85.05112878);
  final r = clamped * math.pi / 180.0;
  return (1.0 - math.log(math.tan(r) + 1.0 / math.cos(r)) / math.pi) /
      2.0 *
      (1 << z);
}

/// Clips [subject] against the convex polygon [clip] (Sutherland–Hodgman),
/// using [inside] (the circle centre) to pick each edge's inside half-plane so
/// the result is independent of [clip]'s winding. Coordinates are treated as
/// planar (lng = x, lat = y), fine at the small scales involved.
List<LatLng> _clipToConvex(
    List<LatLng> subject, List<LatLng> clip, LatLng inside) {
  var output = subject;
  for (var i = 0; i < clip.length; i++) {
    if (output.isEmpty) break;
    final a = clip[i];
    final b = clip[(i + 1) % clip.length];
    final ref = _cross(a, b, inside);
    final input = output;
    output = <LatLng>[];
    for (var j = 0; j < input.length; j++) {
      final cur = input[j];
      final prev = input[(j - 1 + input.length) % input.length];
      final curIn = _cross(a, b, cur) * ref >= 0;
      final prevIn = _cross(a, b, prev) * ref >= 0;
      if (curIn) {
        if (!prevIn) output.add(_intersect(prev, cur, a, b));
        output.add(cur);
      } else if (prevIn) {
        output.add(_intersect(prev, cur, a, b));
      }
    }
  }
  return output;
}

double _cross(LatLng a, LatLng b, LatLng p) =>
    (b.longitude - a.longitude) * (p.latitude - a.latitude) -
    (b.latitude - a.latitude) * (p.longitude - a.longitude);

LatLng _intersect(LatLng p1, LatLng p2, LatLng a, LatLng b) {
  final x1 = p1.longitude, y1 = p1.latitude;
  final x2 = p2.longitude, y2 = p2.latitude;
  final x3 = a.longitude, y3 = a.latitude;
  final x4 = b.longitude, y4 = b.latitude;
  final den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
  if (den.abs() < 1e-15) return p2;
  final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den;
  return LatLng(y1 + t * (y2 - y1), x1 + t * (x2 - x1));
}
