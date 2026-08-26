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

import 'package:latlong2/latlong.dart';

/// Haversine (spherical) is used deliberately: it is numerically stable and,
/// unlike the default Vincenty solver, never returns NaN or fails to converge
/// for large radii / wide viewports. Accuracy (~0.3%) is far more than enough
/// for drawing circles on a map.
const Distance _distance = Distance(calculator: Haversine());

/// Returns the vertices of a geodesic circle: [points] coordinates that are each
/// [radiusMeters] (along the Earth's surface) from [center].
///
/// Drawing these as a polygon yields a circle that is correct on the globe — at
/// high latitudes it appears as an ellipse in Web Mercator, which is the whole
/// point. The ring is open (first point is not repeated); flutter_map closes
/// polygons automatically.
///
/// Returns an empty list for invalid input (non-finite centre or radius, or a
/// non-positive radius) so callers can simply skip drawing rather than crash.
List<LatLng> geodesicCircle(
  LatLng center,
  double radiusMeters, {
  int points = 90,
}) {
  assert(points >= 3, 'A circle needs at least 3 points');
  if (!center.latitude.isFinite ||
      !center.longitude.isFinite ||
      !radiusMeters.isFinite ||
      radiusMeters <= 0) {
    return const <LatLng>[];
  }
  final ring = <LatLng>[];
  for (var i = 0; i < points; i++) {
    // Haversine.offset requires the bearing in -180..180 (not 0..360).
    var bearing = 360.0 * i / points;
    if (bearing > 180.0) bearing -= 360.0;
    final p = _distance.offset(center, radiusMeters, bearing);
    if (!p.latitude.isFinite || !p.longitude.isFinite) {
      return const <LatLng>[]; // bail out rather than draw a partial ring
    }
    ring.add(p);
  }
  return ring;
}
