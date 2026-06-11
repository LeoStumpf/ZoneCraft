import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/geo/plane.dart';

void main() {
  const distance = Distance(calculator: Haversine());

  // Ray-cast point-in-polygon on lat/lng (x=lng, y=lat). Fine for the small,
  // dateline/pole-free rings here.
  bool inside(List<LatLng> poly, LatLng q) {
    var hit = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      final intersect = (yi > q.latitude) != (yj > q.latitude) &&
          q.longitude < (xj - xi) * (q.latitude - yi) / (yj - yi) + xi;
      if (intersect) hit = !hit;
    }
    return hit;
  }

  /// Asserts that, with no band, [outer] membership matches the geodesic
  /// "closer to near than far" classification across a sample grid (skipping
  /// points within [tolM] metres of the equidistant divide, where the polygon's
  /// segment discretisation blurs the edge).
  void expectClassifiesGeodesically({
    required LatLng a,
    required LatLng b,
    required bool nearA,
    required List<LatLng> corners,
    required double latLo,
    required double latHi,
    required double lngLo,
    required double lngHi,
    double tolM = 3000,
  }) {
    final region = planeRegion(
      a: a,
      b: b,
      nearA: nearA,
      bandMeters: 0,
      viewportCorners: corners,
    );
    expect(region.outer.length, greaterThanOrEqualTo(3));
    final near = nearA ? a : b;
    final far = nearA ? b : a;
    var checked = 0;
    for (var gi = 1; gi < 10; gi++) {
      for (var gj = 1; gj < 10; gj++) {
        final p = LatLng(
          latLo + (latHi - latLo) * gi / 10,
          lngLo + (lngHi - lngLo) * gj / 10,
        );
        final dn = distance(p, near);
        final df = distance(p, far);
        if ((dn - df).abs() < tolM) continue; // too near the divide
        expect(inside(region.outer, p), dn < df,
            reason: 'at $p  dNear=$dn dFar=$df');
        checked++;
      }
    }
    expect(checked, greaterThan(10)); // the grid actually exercised both sides
  }

  group('planeRegion', () {
    test('fills the half nearer the near point (equatorial)', () {
      final corners = <LatLng>[
        const LatLng(0.2, -0.2),
        const LatLng(0.2, 0.2),
        const LatLng(-0.2, 0.2),
        const LatLng(-0.2, -0.2),
      ];
      expectClassifiesGeodesically(
        a: const LatLng(0, -0.1),
        b: const LatLng(0, 0.1),
        nearA: true,
        corners: corners,
        latLo: -0.18,
        latHi: 0.18,
        lngLo: -0.18,
        lngHi: 0.18,
      );
    });

    test('is geodesically correct at high latitude / wide extent', () {
      // Near 70°N over a multi-degree extent, a straight pixel bisector would
      // visibly drift; the geodesic divide still classifies by great-circle
      // distance.
      final corners = <LatLng>[
        const LatLng(74, -10),
        const LatLng(74, 10),
        const LatLng(66, 10),
        const LatLng(66, -10),
      ];
      expectClassifiesGeodesically(
        a: const LatLng(70, -6),
        b: const LatLng(70, 6),
        nearA: false, // fill the far point's side, exercising nearA=false
        corners: corners,
        latLo: 67,
        latHi: 73,
        lngLo: -8,
        lngHi: 8,
        tolM: 8000,
      );
    });

    test('degenerate (coincident points) yields empty rings', () {
      final corners = <LatLng>[
        const LatLng(1, -1),
        const LatLng(1, 1),
        const LatLng(-1, 1),
        const LatLng(-1, -1),
      ];
      final r = planeRegion(
        a: const LatLng(0, 0),
        b: const LatLng(0, 0),
        nearA: true,
        bandMeters: 0,
        viewportCorners: corners,
      );
      expect(r.outer, isEmpty);
      expect(r.core, isEmpty);
    });

    test('band widens outer relative to core around the divide', () {
      final corners = <LatLng>[
        const LatLng(0.2, -0.2),
        const LatLng(0.2, 0.2),
        const LatLng(-0.2, 0.2),
        const LatLng(-0.2, -0.2),
      ];
      final r = planeRegion(
        a: const LatLng(0, -0.1),
        b: const LatLng(0, 0.1),
        nearA: true,
        bandMeters: 2000, // 2 km half-band
        viewportCorners: corners,
      );
      // A point just past the geometric divide (on the far side) is swept into
      // the enlarged outer but not the shrunk core.
      const justFar = LatLng(0, 0.005); // ~556 m onto the far side
      expect(inside(r.outer, justFar), isTrue);
      expect(inside(r.core, justFar), isFalse);
    });
  });
}
