import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zonecraft/data/overpass_client.dart';
import 'package:zonecraft/data/repository.dart' show ImportTally;
import 'package:zonecraft/ui/import_progress.dart';

/// A MockClient that answers `send` (which is what the streaming path uses).
http.Client mock(
  Future<http.Response> Function(http.BaseRequest request) handler,
) {
  return MockClient.streaming((request, _) async {
    final resp = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(resp.body)),
      resp.statusCode,
      contentLength: resp.bodyBytes.length,
      request: request,
    );
  });
}

void main() {
  const ok = '{"elements":[]}';

  Future<OverpassOutcome<String>> post(
    http.Client c, {
    String? prefer,
    int? maxBytes,
    Duration timeout = const Duration(seconds: 30),
    OverpassProgressCallback? onProgress,
    OverpassCancel? cancel,
  }) =>
      overpassPost<String>(
        'query',
        client: c,
        timeout: timeout,
        maxBytes: maxBytes,
        preferEndpoint: prefer,
        onProgress: onProgress,
        cancel: cancel,
        parse: (body) => body.contains('elements') ? body : null,
      );

  group('retry policy', () {
    // The measured failure modes want opposite treatment: a fast 5xx is the
    // dispatcher queueing (ask again), a timeout means slow or dead (move on).

    test('a fast rejection is retried on the SAME instance first', () async {
      final tried = <String>[];
      var calls = 0;
      final out = await post(mock((req) async {
        tried.add(req.url.toString());
        calls++;
        return calls == 1
            ? http.Response('busy', 504)
            : http.Response(ok, 200);
      }));
      expect(out.ok, isTrue);
      expect(tried, hasLength(2));
      expect(tried[0], tried[1],
          reason: 'the second try must be the same instance, not a failover');
      expect(out.endpoint, overpassEndpoints.first);
    });

    test('after its retries a rejecting instance is abandoned', () async {
      final tried = <String>[];
      final out = await post(mock((req) async {
        tried.add(req.url.toString());
        // The first endpoint always rejects; the second answers.
        return req.url.toString() == overpassEndpoints.first
            ? http.Response('busy', 503)
            : http.Response(ok, 200);
      }));
      expect(out.ok, isTrue);
      expect(out.endpoint, overpassEndpoints[1]);
      expect(tried.where((t) => t == overpassEndpoints.first), hasLength(2),
          reason: 'exactly the per-endpoint budget, then move on');
    });

    test('a timeout does NOT retry the same instance — it is slow, not busy',
        () async {
      final tried = <String>[];
      final out = await post(
        mock((req) async {
          tried.add(req.url.toString());
          if (req.url.toString() == overpassEndpoints.first) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          return http.Response(ok, 200);
        }),
        timeout: const Duration(milliseconds: 80),
      );
      expect(out.ok, isTrue);
      expect(out.endpoint, overpassEndpoints[1]);
      expect(tried.where((t) => t == overpassEndpoints.first), hasLength(1),
          reason: 'retrying a slow instance just spends the budget twice');
    });

    test('a query error is reported as-is and never retried', () async {
      var calls = 0;
      final out = await post(mock((_) async {
        calls++;
        return http.Response('bad query', 400);
      }));
      expect(out.ok, isFalse);
      expect(out.message, contains('400'));
      expect(calls, 1);
    });

    test('every instance rejecting reports busy, never blames the connection',
        () async {
      var calls = 0;
      final out = await post(mock((_) async {
        calls++;
        return http.Response('busy', 504);
      }));
      expect(out.ok, isFalse);
      expect(out.message, contains('busy'));
      expect(calls, overpassEndpoints.length * 2,
          reason: 'each of the three gets its two tries');
    });

    test('the preferred endpoint is tried first', () async {
      final tried = <String>[];
      final out = await post(
        mock((req) async {
          tried.add(req.url.toString());
          return http.Response(ok, 200);
        }),
        prefer: overpassEndpoints[2],
      );
      expect(tried.first, overpassEndpoints[2]);
      expect(out.endpoint, overpassEndpoints[2]);
    });
  });

  group('streaming', () {
    test('an oversized body is abandoned mid-stream, not downloaded whole',
        () async {
      var delivered = 0;
      final client = MockClient.streaming((request, _) async {
        // 10 chunks of 1 KB; the cap should stop this well before the end.
        return http.StreamedResponse(
          Stream.fromIterable([
            for (var i = 0; i < 10; i++) utf8.encode('x' * 1024),
          ]).map((c) {
            delivered += c.length;
            return c;
          }),
          200,
          request: request,
        );
      });
      final out = await post(client, maxBytes: 2048);
      expect(out.ok, isFalse);
      expect(out.message, contains('too much data'));
      expect(delivered, lessThan(10 * 1024),
          reason: 'the point is to stop paying for bytes we will refuse');
    });

    test('progress reports the stages, with bytes as they arrive', () async {
      final seen = <OverpassProgress>[];
      final out = await post(
        mock((_) async => http.Response(ok, 200)),
        onProgress: seen.add,
      );
      expect(out.ok, isTrue);
      expect(seen.map((p) => p.stage), contains(OverpassStage.contacting));
      expect(seen.map((p) => p.stage), contains(OverpassStage.downloading));
      expect(seen.map((p) => p.stage), contains(OverpassStage.processing));
      expect(seen.last.bytes, greaterThan(0));
    });

    test('progress names which instance, and which try', () async {
      final seen = <OverpassProgress>[];
      var calls = 0;
      await post(
        mock((_) async {
          calls++;
          return calls == 1
              ? http.Response('busy', 504)
              : http.Response(ok, 200);
        }),
        onProgress: seen.add,
      );
      final contacts =
          seen.where((p) => p.stage == OverpassStage.contacting).toList();
      expect(contacts, hasLength(2));
      expect(contacts[0].attempt, 1);
      expect(contacts[1].attempt, 2);
      expect(contacts[1].endpointIndex, 1, reason: 'same instance, second try');
      expect(contacts[0].host, 'overpass-api.de');
    });

    test('an unreadable 200 is distinguished from an empty answer', () async {
      final out = await post(mock((_) async => http.Response('nope', 200)));
      expect(out.ok, isFalse);
      expect(out.message, contains('could not read'));
    });
  });

  group('cancellation', () {
    // The button exists because a public instance can sit on a request for a
    // minute. So what matters is not that cancelling *eventually* works, but
    // that it works at each point the request waits — miss one and Cancel is
    // indistinguishable from a dead button for as long as that wait lasts.

    test('a cancelled request is not a failed one', () async {
      final cancel = OverpassCancel()..cancel();
      var calls = 0;
      final out = await post(
        mock((_) async {
          calls++;
          return http.Response(ok, 200);
        }),
        cancel: cancel,
      );
      expect(out.cancelled, isTrue);
      expect(out.ok, isFalse);
      expect(out.message, isNull,
          reason: 'callers must read `cancelled` before `message!`');
      expect(calls, 0, reason: 'cancelled before the wire, so nothing was sent');
    });

    test('cancelling while an instance is silent gives up immediately',
        () async {
      final cancel = OverpassCancel();
      // Cancelling has to be tested *on the wire*, not while queued behind the
      // shared pacer — which is a different (also covered) code path.
      final onTheWire = Completer<void>();
      var calls = 0;
      final future = post(
        mock((_) async {
          calls++;
          if (!onTheWire.isCompleted) onTheWire.complete();
          // Longer than the test could tolerate: only the cancel can end this.
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response(ok, 200);
        }),
        cancel: cancel,
      );
      await onTheWire.future;
      final elapsed = Stopwatch()..start();
      cancel.cancel();
      final out = await future.timeout(const Duration(seconds: 5));
      elapsed.stop();
      expect(out.cancelled, isTrue);
      expect(calls, 1, reason: 'it must not fail over to the next instance');
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 1)),
          reason: 'waiting out the 30 s silence is exactly what Cancel is for');
    });

    test('cancelling mid-download stops reading the body', () async {
      final cancel = OverpassCancel();
      final chunks = StreamController<List<int>>();
      var delivered = 0;
      final client = MockClient.streaming((request, _) async {
        return http.StreamedResponse(chunks.stream, 200, request: request);
      });
      final future = post(client, cancel: cancel, onProgress: (p) {
        if (p.stage == OverpassStage.downloading) {
          delivered = p.bytes;
          cancel.cancel();
        }
      });
      chunks.add(utf8.encode('x' * 1024));
      final out = await future.timeout(const Duration(seconds: 5));
      expect(out.cancelled, isTrue);
      expect(delivered, 1024, reason: 'it got that far, then stopped');
      await chunks.close();
    });

    test('cancelling during the retry pause does not wait it out', () async {
      final cancel = OverpassCancel();
      final rejected = Completer<void>();
      var calls = 0;
      final future = post(
        mock((_) async {
          calls++;
          if (!rejected.isCompleted) rejected.complete();
          // A fast rejection, which normally means "retry this same instance
          // after _retryDelay".
          return http.Response('busy', 504);
        }),
        cancel: cancel,
      );
      await rejected.future;
      final elapsed = Stopwatch()..start();
      cancel.cancel();
      final out = await future.timeout(const Duration(seconds: 5));
      elapsed.stop();
      expect(out.cancelled, isTrue);
      expect(calls, 1, reason: 'the queued retry must not go out');
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)),
          reason: 'the 2 s retry pause has to be interruptible');
    });

    test('without a token the transport behaves exactly as before', () async {
      final out = await post(mock((_) async => http.Response(ok, 200)));
      expect(out.ok, isTrue);
      expect(out.cancelled, isFalse);
    });
  });

  group('describeOverpassProgress', () {
    OverpassProgress p(
      OverpassStage stage, {
      int index = 1,
      int attempt = 1,
      int bytes = 0,
      int? total,
    }) =>
        OverpassProgress(
          stage: stage,
          endpoint: 'https://overpass-api.de/api/interpreter',
          endpointIndex: index,
          endpointCount: 3,
          attempt: attempt,
          timeout: const Duration(seconds: 150),
          bytes: bytes,
          totalBytes: total,
        );

    test('the happy path names the host without failover noise', () {
      final s = describeOverpassProgress(p(OverpassStage.contacting));
      expect(s, contains('overpass-api.de'));
      expect(s, isNot(contains('instance')));
      // The two things a stuck-looking wait has to answer.
      expect(s, contains('nothing yet'));
      expect(s, contains('gives up after 2m'));
    });

    test('having moved on, it says how far down the list we are', () {
      expect(
        describeOverpassProgress(p(OverpassStage.contacting, index: 2)),
        contains('instance 2 of 3'),
      );
    });

    test('a retry is named, so a stall is distinguishable from a loop', () {
      expect(
        describeOverpassProgress(p(OverpassStage.contacting, attempt: 2)),
        contains('try 2'),
      );
    });

    test('downloading shows a total only when the server sent one', () {
      expect(
        describeOverpassProgress(
            p(OverpassStage.downloading, bytes: 2 * 1024 * 1024)),
        'Downloading from overpass-api.de — 2.0 MB',
      );
      expect(
        describeOverpassProgress(p(OverpassStage.downloading,
            bytes: 1024 * 1024, total: 4 * 1024 * 1024)),
        contains('1.0 MB of 4.0 MB'),
      );
    });

    test('formatBytes steps through the units', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
    });
  });

  group('describeImportTally', () {
    test('a clean import just states the count', () {
      expect(
        describeImportTally(const ImportTally(added: 12, skipped: 0), 'areas'),
        'Imported 12 areas.',
      );
    });

    test('skipped duplicates are never left silent', () {
      // "Imported 12" after asking for 49 reads as a broken import, which is
      // the confusion dedup exists to remove.
      expect(
        describeImportTally(const ImportTally(added: 12, skipped: 37), 'areas'),
        contains('12 areas'),
      );
      expect(
        describeImportTally(const ImportTally(added: 12, skipped: 37), 'areas'),
        contains('37 already here'),
      );
    });

    test('an all-duplicate import says so — the map does not change', () {
      expect(
        describeImportTally(const ImportTally(added: 0, skipped: 8), 'stations'),
        'Nothing new — all 8 stations were already imported.',
      );
    });
  });
}
