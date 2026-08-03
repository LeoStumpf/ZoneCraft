import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/request_pacer.dart';

/// The pacer is the only thing standing between an impatient user and the
/// request rates the donated OSM services publish, so its two properties are
/// worth pinning: requests **run in order**, and they are **spaced**.
void main() {
  group('RequestPacer', () {
    test('spaces consecutive requests by at least the interval', () async {
      final pacer = RequestPacer(minInterval: const Duration(milliseconds: 120));
      final starts = <DateTime>[];
      Future<int> stamp(int i) async {
        starts.add(DateTime.now());
        return i;
      }

      await Future.wait([pacer.run(() => stamp(1)), pacer.run(() => stamp(2))]);

      expect(starts, hasLength(2));
      final gap = starts[1].difference(starts[0]);
      // Timer resolution is coarse, so allow a small shortfall rather than
      // making this test flaky on a loaded machine.
      expect(gap.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('the first request is not delayed', () async {
      final pacer = RequestPacer(minInterval: const Duration(seconds: 5));
      final sw = Stopwatch()..start();
      await pacer.run(() async => 'go');
      sw.stop();
      // Nothing to wait behind — a pacer must not add latency to an idle app.
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('runs in the order submitted', () async {
      final pacer = RequestPacer(minInterval: const Duration(milliseconds: 5));
      final order = <int>[];
      await Future.wait([
        for (var i = 0; i < 5; i++)
          pacer.run(() async {
            order.add(i);
            return i;
          }),
      ]);
      expect(order, [0, 1, 2, 3, 4]);
    });

    test('a failing request throws to its caller, not into the queue',
        () async {
      final pacer = RequestPacer(minInterval: const Duration(milliseconds: 5));

      // The whole point: one failure used to be able to wedge the shared chain,
      // which would have silently stopped every later import in the session.
      await expectLater(
        pacer.run<void>(() async => throw StateError('boom')),
        throwsStateError,
      );

      expect(await pacer.run(() async => 'still works'), 'still works');
    });

    test('the shipped pacers respect the published limits', () {
      // Nominatim: "an absolute maximum of 1 request per second".
      expect(nominatimPacer.minInterval.inMilliseconds,
          greaterThanOrEqualTo(1000));
      expect(overpassPacer.minInterval, greaterThan(Duration.zero));
    });
  });

  group('QueryCache', () {
    test('returns what was stored, and misses on anything else', () {
      final cache = QueryCache<String>();
      cache.put('Isar', 'river');
      expect(cache.get('Isar'), 'river');
      expect(cache.get('Danube'), isNull);
    });

    test('normalises case and whitespace, since the server would too', () {
      final cache = QueryCache<String>();
      cache.put('  Munich   City  ', 'x');
      expect(cache.get('munich city'), 'x');
      expect(cache.get('MUNICH CITY'), 'x');
    });

    test('evicts the least recently used once full', () {
      final cache = QueryCache<int>(maxEntries: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      cache.get('a'); // 'a' is now the most recent, so 'b' is the oldest
      cache.put('d', 4);

      expect(cache.length, 3);
      expect(cache.get('b'), isNull, reason: 'oldest should have gone');
      expect(cache.get('a'), 1);
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('re-putting a key refreshes rather than duplicating', () {
      final cache = QueryCache<int>(maxEntries: 2);
      cache.put('a', 1);
      cache.put('a', 2);
      expect(cache.length, 1);
      expect(cache.get('a'), 2);
    });
  });
}
