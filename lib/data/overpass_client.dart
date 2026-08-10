import 'dart:async';
import 'dart:convert' show Utf8Decoder;

import 'package:http/http.dart' as http;

import 'request_pacer.dart';

/// The shared Overpass transport: endpoint failover, transient-vs-fatal status
/// handling, a streamed size cap, and progress reporting — one implementation
/// for every import that talks to the public API (`transit.dart`,
/// `borders.dart`).
///
/// This was lifted out of the transit client, because the reliability problem is
/// the *instance*, not the query. Measured over one afternoon, asking all three
/// for Munich's 20 city districts (a 0.4 MB answer):
///
/// | instance | behaviour |
/// |---|---|
/// | overpass-api.de | 2–3 s, but ~1 in 3 rejected in 8 s with `Dispatcher_Client::request_read_and_idx::timeout` |
/// | overpass.kumi.systems | always answered, in **67–160 s** |
/// | overpass.private.coffee | never answered at all (200 s, no bytes) |
///
/// That shapes the retry policy, because those two failures want opposite
/// treatment:
///
/// * A **fast rejection** (429/5xx) is the dispatcher saying "I'm queueing, not
///   that your query is wrong" — the same instance usually answers on the next
///   try, and asking again costs the 8 s it just spent. So it is retried in
///   place ([_attemptsPerEndpoint]) after a short pause.
/// * A **timeout or socket error** says this instance is slow or dead. Retrying
///   it just spends the whole budget twice, so we move on immediately.
///
/// Without that split, a single 504 on the fast instance sent every import to a
/// 160 s instance and then to a dead one — five minutes of silent spinner
/// ending in failure, which is exactly what it looked like from outside.

/// How the request is going, for a progress display. Overpass gives no
/// server-side progress, so this is what can honestly be shown: which instance
/// is being asked, how many we've been through, and how many bytes have landed.
enum OverpassStage {
  /// Request sent, nothing back yet. This is the phase that can sit still for a
  /// minute on a slow instance, so callers should pair it with an elapsed clock.
  contacting,

  /// Bytes are arriving.
  downloading,

  /// Fully downloaded, being decoded.
  processing,
}

class OverpassProgress {
  const OverpassProgress({
    required this.stage,
    required this.endpoint,
    required this.endpointIndex,
    required this.endpointCount,
    required this.attempt,
    required this.timeout,
    this.bytes = 0,
    this.totalBytes,
  });

  final OverpassStage stage;
  final String endpoint;

  /// 1-based position in the failover order, and how many there are.
  final int endpointIndex;
  final int endpointCount;

  /// 1-based try against *this* endpoint.
  final int attempt;

  /// How long this attempt will be given before it is abandoned — so a display
  /// can say when the waiting ends rather than leaving it open-ended.
  final Duration timeout;

  /// Bytes received so far, and the total if the server sent a Content-Length
  /// (it often doesn't — Overpass usually streams chunked).
  final int bytes;
  final int? totalBytes;

  /// Host alone, which is what a person recognises.
  String get host => Uri.tryParse(endpoint)?.host ?? endpoint;
}

typedef OverpassProgressCallback = void Function(OverpassProgress progress);

/// The outcome of an Overpass request: the value, or a **user-facing** reason it
/// failed.
///
/// A bare `null` can't distinguish "you're offline" from "the instance is
/// shedding load", and the public instances answer perfectly good queries with
/// 504 often enough that blaming the connection would usually be a lie.
class OverpassOutcome<T> {
  const OverpassOutcome.ok(T this.value, {this.endpoint})
      : message = null,
        cancelled = false;
  const OverpassOutcome.failed(String this.message)
      : value = null,
        endpoint = null,
        cancelled = false;

  /// The user pressed Cancel. Deliberately **not** a failure: nothing is worth
  /// reporting as an error, and nothing must be written — a cancelled transit
  /// import that recorded itself as failed would leave a retry row for
  /// something that never went wrong.
  const OverpassOutcome.cancelled()
      : value = null,
        message = null,
        endpoint = null,
        cancelled = true;

  final T? value;

  /// Null on both success *and* cancellation, so read [cancelled] before
  /// reaching for this.
  final String? message;

  /// Which endpoint served the request, so the caller can prefer it next time.
  final String? endpoint;

  /// Abandoned on request rather than finished or failed.
  final bool cancelled;

  bool get ok => message == null && !cancelled;
}

/// Lets a caller abandon an in-flight [overpassPost].
///
/// A token rather than closing the client, because every import shares the map
/// screen's long-lived `http.Client` with tile loading and place search —
/// closing it would take those down too.
///
/// The contract is that **every point where the request waits observes this**:
/// the pacer queue, the endpoint/attempt loops, the retry pause, the connect
/// and the body stream. Miss one and Cancel appears ignored for as long as that
/// wait lasts, which on a busy instance is a minute — the exact complaint the
/// button exists to answer.
class OverpassCancel {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called, and never otherwise — only ever await
  /// it as one arm of a race.
  Future<void> get future => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Thrown internally once [OverpassCancel.cancel] fires; converted to
/// [OverpassOutcome.cancelled] before it reaches a caller.
class _CancelledException implements Exception {
  const _CancelledException();
}

/// Completes after [delay], or early if cancelled.
Future<void> _delayOrCancel(Duration delay, OverpassCancel? cancel) {
  final delayed = Future<void>.delayed(delay);
  if (cancel == null) return delayed;
  return Future.any<void>([delayed, cancel.future]);
}

/// Overpass instances, tried in order. Whichever one is busy is the variable, so
/// failing over is worth more than retrying — but see the header: a *fast*
/// rejection is retried in place first.
const List<String> overpassEndpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];

const String overpassUserAgent =
    'ZoneCraft/1.0 (https://github.com/LeoStumpf/ZoneCraft)';

/// Statuses the public instances use for "I am overloaded", not "your query is
/// wrong". These are retried in place, then failed over; anything else is a
/// query error and is reported as-is.
const Set<int> _transientStatus = {429, 500, 502, 503, 504};

/// Tries per endpoint when it rejects *quickly*. Two, because the measured
/// rejection rate on the fast instance is about one in three: a second ask
/// takes that to roughly one in nine, for the eight seconds the first one cost.
const int _attemptsPerEndpoint = 2;

/// Pause before asking the same instance again, so a retry isn't just the same
/// request landing in the same full queue.
const Duration _retryDelay = Duration(seconds: 2);

/// How quickly an instance must answer to be worth *starting from* next time.
///
/// The remembered endpoint exists to skip one that is down, not to crown
/// whichever happened to answer last. Without this bound a single failover
/// pinned every later import to the slow instance — one 8 s rejection on the
/// fast one, and from then on every import took 60–160 s, permanently, which is
/// most of what "it takes forever" meant. An instance that took longer than
/// this worked, but it is not a good default: next time we start at the top of
/// the list again and give the fast one another chance, which costs at most a
/// few seconds because a busy instance rejects fast.
const Duration kOverpassPreferenceMaxElapsed = Duration(seconds: 20);

/// POSTs [query] to each endpoint in turn until one answers.
///
/// [parse] returns null when the body is unintelligible, which is reported
/// distinctly from "parsed fine, found nothing". [oversizeMessage] is what a
/// body past [maxBytes] says — the advice differs per import (fewer transit
/// types vs. a smaller box), so the caller owns the wording.
///
/// [onProgress] fires as the request moves between stages and as bytes arrive.
/// [cancel] abandons the whole exchange — see [OverpassCancel].
///
/// Never throws.
Future<OverpassOutcome<T>> overpassPost<T>(
  String query, {
  required http.Client? client,
  required Duration timeout,
  required T? Function(String body) parse,
  int? maxBytes,
  String? oversizeMessage,
  String? preferEndpoint,
  OverpassProgressCallback? onProgress,
  OverpassCancel? cancel,
}) async {
  final owned = client == null;
  final c = client ?? http.Client();
  // Try the last endpoint that worked first, then the rest in order.
  final endpoints = <String>[
    if (preferEndpoint != null && overpassEndpoints.contains(preferEndpoint))
      preferEndpoint,
    for (final e in overpassEndpoints)
      if (e != preferEndpoint) e,
  ];
  var lastTransient = 'Overpass is busy — try again in a moment.';
  try {
    for (var i = 0; i < endpoints.length; i++) {
      final endpoint = endpoints[i];
      for (var attempt = 1; attempt <= _attemptsPerEndpoint; attempt++) {
        // Checked per attempt, not just once: failing over to a third instance
        // after the user gave up is exactly the wait Cancel exists to end.
        if (cancel != null && cancel.isCancelled) {
          return const OverpassOutcome.cancelled();
        }
        OverpassProgress progress(OverpassStage stage,
                {int bytes = 0, int? totalBytes}) =>
            OverpassProgress(
              stage: stage,
              endpoint: endpoint,
              endpointIndex: i + 1,
              endpointCount: endpoints.length,
              attempt: attempt,
              timeout: timeout,
              bytes: bytes,
              totalBytes: totalBytes,
            );

        onProgress?.call(progress(OverpassStage.contacting));

        final _Response resp;
        try {
          // Paced, so a double-tapped import (or a failover landing straight on
          // the next instance) can't put two requests on the wire back to back.
          // Costs a user-initiated import nothing; the wait is already seconds.
          resp = await overpassPacer.run(
            () {
              // Cancelling while queued behind another request must not put a
              // dead request on the wire a second later.
              if (cancel != null && cancel.isCancelled) {
                throw const _CancelledException();
              }
              return _send(
                c,
                endpoint,
                query,
                timeout: timeout,
                maxBytes: maxBytes,
                cancel: cancel,
                onBytes: (bytes, total) => onProgress
                    ?.call(progress(OverpassStage.downloading,
                        bytes: bytes, totalBytes: total)),
              );
            },
          );
        } on _CancelledException {
          return const OverpassOutcome.cancelled();
        } on _OversizeException {
          // Caught mid-stream, so an answer far too big to use is abandoned
          // rather than downloaded in full and then refused.
          return OverpassOutcome.failed(oversizeMessage ??
              'That area returns too much data — pick a smaller box.');
        } catch (_) {
          // A timeout or socket error says nothing about the *query*, so try
          // the next instance rather than blaming the user's connection — and
          // don't retry this one, which is slow or down, not merely busy.
          lastTransient = 'Could not reach Overpass — check your connection, '
              'or try again in a moment.';
          break;
        }

        if (resp.statusCode == 200) {
          onProgress?.call(progress(OverpassStage.processing,
              bytes: resp.body.length));
          final parsed = parse(resp.body);
          if (parsed == null) {
            return const OverpassOutcome.failed(
                'Overpass sent a response we could not read. Try again.');
          }
          return OverpassOutcome.ok(parsed, endpoint: endpoint);
        }
        if (_transientStatus.contains(resp.statusCode)) {
          lastTransient = 'Overpass is busy — try again in a moment.';
          // A quick rejection is the dispatcher queueing, not a verdict on the
          // query: ask the same instance again before giving up on it.
          if (attempt < _attemptsPerEndpoint) {
            await _delayOrCancel(_retryDelay, cancel);
            continue;
          }
          break;
        }
        return OverpassOutcome.failed(
            'Overpass refused the request (HTTP ${resp.statusCode}).');
      }
    }
    return OverpassOutcome.failed(lastTransient);
  } finally {
    if (owned) c.close();
  }
}

/// Raised mid-download once [maxBytes] is passed.
class _OversizeException implements Exception {
  const _OversizeException();
}

class _Response {
  const _Response(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

/// Sends the query and collects the response **as a stream**, so bytes can be
/// counted for progress and the size cap can abort early.
///
/// [timeout] is an overall deadline for the whole exchange, not a per-chunk one:
/// a large answer legitimately takes a while to arrive, but the total is what
/// the caller budgeted for.
Future<_Response> _send(
  http.Client client,
  String endpoint,
  String query, {
  required Duration timeout,
  int? maxBytes,
  required void Function(int bytes, int? total) onBytes,
  OverpassCancel? cancel,
}) async {
  final deadline = DateTime.now().add(timeout);
  Duration remaining() {
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  final request = http.Request('POST', Uri.parse(endpoint))
    ..headers['User-Agent'] = overpassUserAgent
    ..bodyFields = {'data': query};

  final sending = client.send(request).timeout(remaining());
  final http.StreamedResponse streamed;
  if (cancel == null) {
    streamed = await sending;
  } else {
    try {
      // This is the wait that dominates a slow import — the instance sits on
      // the request before sending a single byte — so it has to lose the race
      // to Cancel, not merely be checked around.
      streamed = await Future.any<http.StreamedResponse>([
        sending,
        cancel.future
            .then<http.StreamedResponse>((_) => throw const _CancelledException()),
      ]);
    } on _CancelledException {
      // The socket is still in flight and nothing will read it. Drain it in the
      // background so the connection is released now instead of being held to
      // the deadline.
      unawaited(sending
          .then((r) => r.stream.drain<void>())
          .catchError((Object _) {}));
      rethrow;
    }
  }
  final total = streamed.contentLength;

  final chunks = <List<int>>[];
  var received = 0;
  final done = Completer<void>();
  late final StreamSubscription<List<int>> sub;
  sub = streamed.stream.listen(
    (chunk) {
      chunks.add(chunk);
      received += chunk.length;
      if (maxBytes != null && received > maxBytes) {
        sub.cancel();
        if (!done.isCompleted) done.completeError(const _OversizeException());
        return;
      }
      onBytes(received, total);
    },
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
    onError: (Object e, StackTrace s) {
      if (!done.isCompleted) done.completeError(e, s);
    },
    cancelOnError: true,
  );

  // A large body legitimately takes a while; Cancel has to interrupt that too,
  // not only the connect.
  final StreamSubscription<void>? cancelSub =
      cancel?.future.asStream().listen((_) {
    sub.cancel();
    if (!done.isCompleted) done.completeError(const _CancelledException());
  });

  try {
    await done.future.timeout(remaining());
  } catch (_) {
    await sub.cancel();
    rethrow;
  } finally {
    await cancelSub?.cancel();
  }

  final bytes = <int>[for (final chunk in chunks) ...chunk];
  return _Response(streamed.statusCode, _decodeUtf8(bytes));
}

/// Overpass always answers UTF-8; a malformed byte becomes U+FFFD rather than
/// taking the whole import down.
String _decodeUtf8(List<int> bytes) =>
    const Utf8Decoder(allowMalformed: true).convert(bytes);
