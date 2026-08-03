import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/height_generator.dart';
import 'package:zonecraft/data/repository.dart';

/// A stalled connection is not the same failure as an offline one, and only the
/// offline one was ever survivable.
///
/// Airplane mode fails a socket immediately, so it never exercised this path.
/// A captive portal, a mobile handoff or a wedged CDN edge instead accepts the
/// connection and then says nothing — and `package:http` has no default
/// timeout, so the future simply never completed. The elevation probe's
/// `_probing` flag stayed true and its spinner ran until the app was killed.
///
/// These tests pin that every terrain fetch is bounded. They must stay fast, so
/// they assert the *shape* (it returns, with a failure value) rather than
/// waiting out the real 15 s budget.
void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  /// A client whose requests never complete — the stall this guards against.
  http.Client stalled() =>
      MockClient((_) => Completer<http.Response>().future);

  test('queryElevation gives up on a stalled connection instead of hanging',
      () async {
    final result = await queryElevation(
      repo: repo,
      client: stalled(),
      lat: 48.137,
      lng: 11.575,
    ).timeout(
      kTerrainTileTimeout + const Duration(seconds: 5),
      onTimeout: () => throw StateError(
          'queryElevation outlived its own timeout — the .timeout() on the '
          'tile fetch is gone'),
    );
    // Null is "no elevation available", which the probe renders as "n/a".
    expect(result, isNull);
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('generateHeightRegion fails with a message, not a hang', () async {
    final layerId = await repo.createLayer(
        name: 'H', colorArgb: 0xFF0000FF, type: 'height');
    final regionId = await repo.createHeightRegion(
      layerId: layerId,
      centerLat: 48.137,
      centerLng: 11.575,
      radiusMeters: 1000,
    );
    final region = (await repo.watchAllHeightRegions().first)
        .firstWhere((r) => r.id == regionId);

    // Every tile stalls, so none arrive and the run must surface that rather
    // than sitting behind its modal (which has no cancel) for ever.
    //
    // A 1 km radius is only a couple of tiles, so what this actually walks is
    // the per-tile timeout twice over, not `kHeightGenBudget` — the budget only
    // bites on a region big enough for the per-tile timeouts to sum past it,
    // which is too slow to assert here. Both are bounds on the same runaway;
    // this pins the one a test can afford.
    await expectLater(
      generateHeightRegion(
        repo: repo,
        client: stalled(),
        region: region,
      ).timeout(
        kHeightGenBudget + const Duration(seconds: 10),
        onTimeout: () => throw StateError(
            'generateHeightRegion never returned — a terrain fetch is '
            'unbounded again'),
      ),
      throwsA(isA<HeightGenException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
