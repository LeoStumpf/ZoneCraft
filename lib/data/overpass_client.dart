import 'package:http/http.dart' as http;

/// The shared Overpass transport: endpoint failover, transient-vs-fatal status
/// handling, and a size cap — one implementation for every import that talks to
/// the public API (`transit.dart`, `borders.dart`).
///
/// This was lifted out of the transit client verbatim, because the reliability
/// problem is the *instance*, not the query: in testing the main instance
/// refused in 8 s an area that kumi served, and later the roles reversed. Any
/// second caller re-deriving that logic would re-derive it wrong.

/// The outcome of an Overpass request: the value, or a **user-facing** reason it
/// failed.
///
/// A bare `null` can't distinguish "you're offline" from "the instance is
/// shedding load", and the public instances answer perfectly good queries with
/// 504 often enough that blaming the connection would usually be a lie.
class OverpassOutcome<T> {
  const OverpassOutcome.ok(T this.value, {this.endpoint}) : message = null;
  const OverpassOutcome.failed(String this.message)
      : value = null,
        endpoint = null;

  final T? value;
  final String? message;

  /// Which endpoint served the request, so the caller can prefer it next time.
  final String? endpoint;

  bool get ok => message == null;
}

/// Overpass instances, tried in order. Whichever one is busy is the variable, so
/// failing over is worth more than retrying.
const List<String> overpassEndpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];

const String overpassUserAgent =
    'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)';

/// Statuses the public instances use for "I am overloaded", not "your query is
/// wrong". These — and timeouts, and socket errors — fail **over** to the next
/// endpoint; anything else is a query error and is reported as-is.
const Set<int> _transientStatus = {429, 500, 502, 503, 504};

/// POSTs [query] to each endpoint in turn until one answers.
///
/// [parse] returns null when the body is unintelligible, which is reported
/// distinctly from "parsed fine, found nothing". [oversizeMessage] is what a
/// body past [maxBytes] says — the advice differs per import (fewer transit
/// types vs. a smaller box), so the caller owns the wording.
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
    for (final endpoint in endpoints) {
      final http.Response resp;
      try {
        resp = await c
            .post(
              Uri.parse(endpoint),
              headers: const {'User-Agent': overpassUserAgent},
              body: {'data': query},
            )
            .timeout(timeout);
      } catch (_) {
        // A timeout or socket error says nothing about the *query*, so try the
        // next instance rather than blaming the user's connection.
        lastTransient = 'Could not reach Overpass — check your connection, '
            'or try again in a moment.';
        continue;
      }
      if (resp.statusCode == 200) {
        if (maxBytes != null && resp.bodyBytes.length > maxBytes) {
          return OverpassOutcome.failed(oversizeMessage ??
              'That area returns too much data — pick a smaller box.');
        }
        final parsed = parse(resp.body);
        if (parsed == null) {
          return const OverpassOutcome.failed(
              'Overpass sent a response we could not read. Try again.');
        }
        return OverpassOutcome.ok(parsed, endpoint: endpoint);
      }
      if (_transientStatus.contains(resp.statusCode)) {
        lastTransient = 'Overpass is busy — try again in a moment.';
        continue;
      }
      return OverpassOutcome.failed(
          'Overpass refused the request (HTTP ${resp.statusCode}).');
    }
    return OverpassOutcome.failed(lastTransient);
  } finally {
    if (owned) c.close();
  }
}
