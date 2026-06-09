import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

/// Returns the vertices of a geodesic circle: [points] coordinates that are each
/// exactly [radiusMeters] (along the Earth's surface) from [center].
///
/// Drawing these as a polygon yields a circle that is correct on the globe — at
/// high latitudes it appears as an ellipse in Web Mercator, which is the whole
/// point. The ring is open (first point is not repeated); flutter_map closes
/// polygons automatically.
List<LatLng> geodesicCircle(
  LatLng center,
  double radiusMeters, {
  int points = 90,
}) {
  assert(points >= 3, 'A circle needs at least 3 points');
  assert(radiusMeters > 0, 'Radius must be positive');
  return List<LatLng>.generate(points, (i) {
    final bearing = 360.0 * i / points;
    return _distance.offset(center, radiusMeters, bearing);
  });
}
