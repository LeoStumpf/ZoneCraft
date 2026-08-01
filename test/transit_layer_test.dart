import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/transit.dart';
import 'package:zonecraft/ui/transit_layer.dart';
import 'package:zonecraft/ui/transit_modes_sheet.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  int bit(String key) => transitModeByKey(key)!.bit;

  /// One import: a rail+bus interchange, a subway-only stop, a bus-only stop,
  /// and one with no type at all.
  Future<({String layerId, String setId, List<TransitStop> stops})>
      seed() async {
    final layerId = await repo.createLayer(
        name: 'T', colorArgb: 0xFF123456, type: 'transit');
    final setId = await repo.createPendingTransitSet(
      layerId: layerId,
      south: 48.0,
      west: 11.3,
      north: 48.3,
      east: 11.8,
      modeMask: transitAllModesMask,
      visibleModeMask: transitAllModesMask,
    );
    await repo.fillTransitSet(setId, [
      (
        osmId: 1,
        lat: 48.14,
        lng: 11.46,
        name: 'Pasing Bahnhof',
        modeMask: bit('bus') | bit('train') | bit('tram'),
        nodeCount: 31,
        routeRef: null,
      ),
      (
        osmId: 2,
        lat: 48.13,
        lng: 11.57,
        name: 'Marienplatz',
        modeMask: bit('subway'),
        nodeCount: 4,
        routeRef: null,
      ),
      (
        osmId: 3,
        lat: 48.11,
        lng: 11.52,
        name: 'Bushaltestelle',
        modeMask: bit('bus'),
        nodeCount: 2,
        routeRef: null,
      ),
      (
        osmId: 4,
        lat: 48.12,
        lng: 11.53,
        name: 'Unklar',
        modeMask: 0,
        nodeCount: 1,
        routeRef: null,
      ),
    ]);
    return (
      layerId: layerId,
      setId: setId,
      stops: await repo.watchAllTransitStops().first,
    );
  }

  Future<TransitTally> tallyOf(String layerId) async => transitTally(
        layerId: layerId,
        sets: await repo.watchAllTransitSets().first,
        allStations: await repo.watchAllTransitStops().first,
      );

  test('a station shows while ANY of its types is enabled', () async {
    final s = await seed();
    Map<String, int> mask(int m) => {s.setId: m};

    expect(visibleTransitStations(s.stops, mask(transitAllModesMask)),
        hasLength(4));

    // Rail only: the interchange survives (a train stops there), the bus-only
    // stop goes. This is the whole point of the union rule.
    final rail = visibleTransitStations(s.stops, mask(transitRailMask));
    expect(rail.map((x) => x.name),
        containsAll(['Pasing Bahnhof', 'Marienplatz']));
    expect(rail.map((x) => x.name), isNot(contains('Bushaltestelle')));

    // Bus off, everything else on.
    final noBus = visibleTransitStations(
        s.stops, mask(transitAllModesMask & ~bit('bus')));
    expect(noBus.map((x) => x.name), contains('Pasing Bahnhof'));
    expect(noBus.map((x) => x.name), isNot(contains('Bushaltestelle')));
  });

  test('a typeless station is never orphaned, but hides with everything',
      () async {
    final s = await seed();
    // It has no modes, so no single mode "owns" it — it rides along.
    expect(
      visibleTransitStations(s.stops, {s.setId: bit('subway')})
          .map((x) => x.name),
      containsAll(['Marienplatz', 'Unklar']),
    );
    // Hide all really hides all.
    expect(visibleTransitStations(s.stops, {s.setId: 0}), isEmpty);
  });

  test('stations of another layer are not drawn', () async {
    final s = await seed();
    expect(visibleTransitStations(s.stops, const {}), isEmpty);
  });

  test('the sheet count agrees with what the map draws', () async {
    final s = await seed();
    for (final m in [
      transitAllModesMask,
      transitRailMask,
      bit('bus'),
      0,
    ]) {
      expect(
        visibleTransitStationCount(s.stops, m),
        visibleTransitStations(s.stops, {s.setId: m}).length,
        reason: 'mask $m',
      );
    }
  });

  test('the tally offers a tick box only for types that are actually here',
      () async {
    final s = await seed();
    final t = await tallyOf(s.layerId);

    // Bus, tram, subway and train occur; ferry and monorail do not, so no tick
    // box for them — an empty category is a puzzle, not a filter.
    expect(t.present.map((m) => m.key), ['bus', 'tram', 'subway', 'train']);
    expect(t.counts, {'bus': 2, 'tram': 1, 'subway': 1, 'train': 1});
    expect(t.untyped, 1);
    expect(t.total, 4);
    expect(t.shown, 4);
    expect(t.setIds, {s.setId});

    // Every type carries a plain-language line, so "Light rail" is not left to
    // be guessed at.
    for (final m in transitModes) {
      expect(m.blurb, isNotEmpty, reason: m.key);
    }
  });

  test('the tally follows what the tick boxes wrote', () async {
    final s = await seed();
    await repo.setTransitVisibleModes({s.setId}, transitRailMask);
    final t = await tallyOf(s.layerId);

    expect(t.visible, transitRailMask);
    // Pasing (train), Marienplatz (subway) and the typeless one; the bus-only
    // stop drops out.
    expect(t.shown, 3);
    expect(t.total, 4);
  });

  test('the tally unions imports that disagree', () async {
    final s = await seed();
    final other = await repo.createPendingTransitSet(
      layerId: s.layerId,
      south: 48.0,
      west: 11.3,
      north: 48.1,
      east: 11.4,
      modeMask: transitAllModesMask,
      visibleModeMask: bit('bus'),
    );
    await repo.setTransitVisibleModes({s.setId}, bit('subway'));

    final t = await tallyOf(s.layerId);
    expect(t.visible, bit('bus') | bit('subway'));
    expect(t.setIds, {s.setId, other});
  });

  test('the station icon follows the most specific type serving it', () {
    // A stop served by both reads as a station, not a bus stop.
    expect(transitIconFor(bit('subway') | bit('bus')),
        transitIconFor(bit('subway')));
    expect(transitIconFor(bit('bus')), isNot(transitIconFor(bit('subway'))));
    expect(transitIconFor(0), isNotNull); // never blows up on an unset mask
  });
}
