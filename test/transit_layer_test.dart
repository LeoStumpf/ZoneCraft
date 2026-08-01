import 'package:drift/native.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/ui/transit_layer.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  /// Imports one subway route (own colour) and one tram route (no colour),
  /// sharing a stop, and returns the stored rows.
  Future<
      ({
        List<TransitRoute> routes,
        List<TransitRoutePart> parts,
        List<TransitStop> stops,
        List<TransitRouteStop> join,
      })> seed() async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    await repo.importTransitSet(
      layerId: layerId,
      south: 48.0,
      west: 11.0,
      north: 48.3,
      east: 11.4,
      modeMask: 0xFF,
      routes: [
        (
          osmId: 1,
          modeKey: 'subway',
          ref: 'U6',
          name: null,
          operatorName: null,
          colourHex: '#0065AE',
          colorArgb: 0xFF0065AE,
          parts: [
            [const LatLng(48.10, 11.10), const LatLng(48.11, 11.11)],
            [const LatLng(48.28, 11.38), const LatLng(48.29, 11.39)],
          ],
          stopIndices: [0, 1],
        ),
        (
          osmId: 2,
          modeKey: 'tram',
          ref: '19',
          name: null,
          operatorName: null,
          colourHex: null,
          colorArgb: null,
          parts: [
            [const LatLng(48.12, 11.12), const LatLng(48.13, 11.13)],
          ],
          stopIndices: [0],
        ),
      ],
      stops: [
        (osmId: 100, lat: 48.10, lng: 11.10, name: 'Shared'),
        (osmId: 101, lat: 48.28, lng: 11.38, name: 'U6 only'),
      ],
    );
    return (
      routes: await repo.watchAllTransitRoutes().first,
      parts: await repo.watchAllTransitRouteParts().first,
      stops: await repo.watchAllTransitStops().first,
      join: await repo.watchAllTransitRouteStops().first,
    );
  }

  test('a route draws in its OSM colour, falling back to its mode', () async {
    final s = await seed();
    final u6 = s.routes.firstWhere((r) => r.ref == 'U6');
    final tram = s.routes.firstWhere((r) => r.ref == '19');
    expect(routeColorArgb(u6), 0xFF0065AE);
    expect(routeColorArgb(tram), transitModeByKey('tram')!.colorArgb);
    expect(routeStrokeWidth(u6), transitModeByKey('subway')!.strokeWidth);
  });

  test('parts are culled by their stored bbox, without decoding', () async {
    final s = await seed();
    final u6 = s.routes.firstWhere((r) => r.ref == 'U6');
    final parts = s.parts.where((p) => p.routeId == u6.id).toList();
    expect(parts, hasLength(2));
    // A view over the first part only.
    final view = LatLngBounds(const LatLng(48.05, 11.05), const LatLng(48.15, 11.15));
    final visible = parts.where((p) => partVisible(p, view)).toList();
    expect(visible, hasLength(1));
    expect(decodeLatLngs(visible.single.points).first.latitude,
        closeTo(48.10, 1e-9));
    // A view containing neither.
    final far = LatLngBounds(const LatLng(10.0, 10.0), const LatLng(11.0, 11.0));
    expect(parts.where((p) => partVisible(p, far)), isEmpty);
  });

  test('a stop shows while ANY route serving it is visible', () async {
    final s = await seed();
    final u6 = s.routes.firstWhere((r) => r.ref == 'U6');
    final tram = s.routes.firstWhere((r) => r.ref == '19');
    final shared = s.stops.firstWhere((x) => x.osmId == 100).id;
    final u6Only = s.stops.firstWhere((x) => x.osmId == 101).id;

    expect(visibleTransitStopIds(s.routes, s.join), {shared, u6Only});

    // Hide U6: its exclusive stop goes, the shared one stays (the tram calls).
    await repo.setTransitRouteVisibility([u6.id], false);
    var routes = await repo.watchAllTransitRoutes().first;
    expect(visibleTransitStopIds(routes, s.join), {shared});

    // Hide the tram too: nothing serves the shared stop any more.
    await repo.setTransitRouteVisibility([tram.id], false);
    routes = await repo.watchAllTransitRoutes().first;
    expect(visibleTransitStopIds(routes, s.join), isEmpty);
  });

  test('the geometry cache decodes a part once', () async {
    final s = await seed();
    final part = s.parts.first;
    final a = transitGeometryCache.points(part);
    final b = transitGeometryCache.points(part);
    expect(identical(a, b), isTrue);
    expect(a, hasLength(2));
    transitGeometryCache.forget([part.id]);
    expect(identical(transitGeometryCache.points(part), a), isFalse);
  });

  test('the stop icon follows the most specific mode serving it', () {
    final subway = transitModeByKey('subway')!.bit;
    final bus = transitModeByKey('bus')!.bit;
    // A stop served by both reads as a station, not a bus stop.
    expect(transitIconFor(subway | bus), transitIconFor(subway));
    expect(transitIconFor(bus), isNot(transitIconFor(subway)));
    expect(transitIconFor(0), isNotNull); // never blows up on an unset mask
  });
}
