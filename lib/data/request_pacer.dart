import 'dart:async';
import 'dart:collection';

/// Keeps the app inside the request rates the public OSM services ask for.
///
/// Every service ZoneCraft talks to is donated infrastructure with a published
/// limit, and the app had no mechanism for honouring any of them — it simply
/// sent requests when the user acted. That was survivable only because the
/// actions are all deliberate (tap Search, tap Import); nothing stopped a
/// double-tap or an impatient retry from exceeding the rate.
///
/// [RequestPacer] serialises calls through a single queue and holds each one
/// until [minInterval] has passed since the previous one *started*. Rate is
/// measured start-to-start, because that is what a server counts.
///
/// This is a **pacer, not a debouncer**. A debouncer drops calls that arrive
/// during the quiet window, which is right for something fired by keystrokes
/// or a moving map — nothing here is. These calls are all explicit user
/// actions, and dropping one silently would look like a button that does
/// nothing. So they queue and run late instead.
class RequestPacer {
  RequestPacer({required this.minInterval});

  /// Minimum start-to-start gap between requests.
  final Duration minInterval;

  /// The tail of the queue. Always a *resolved-or-resolving* future — errors
  /// from the action are routed to the caller's completer, never into this
  /// chain, or one failed request would wedge every later one.
  Future<void> _tail = Future<void>.value();

  DateTime? _lastStart;

  /// Runs [action] when its turn comes and the interval has elapsed.
  ///
  /// Returns whatever [action] returns; throws whatever it throws, at the
  /// caller, not into the queue.
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      final last = _lastStart;
      if (last != null) {
        final wait = minInterval - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastStart = DateTime.now();
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }
}

/// Nominatim's published ceiling is "an absolute maximum of 1 request per
/// second". A little over a second, because the limit is enforced at the far
/// end against clock skew and our own timing jitter.
final RequestPacer nominatimPacer =
    RequestPacer(minInterval: const Duration(milliseconds: 1100));

/// Overpass publishes no requests-per-second number — it rate-limits by slots
/// and answers 429/504 when you are over, which `overpass_client.dart` already
/// treats as transient. A one-second floor costs a user-initiated import
/// nothing and keeps an impatient double-tap from counting twice.
final RequestPacer overpassPacer =
    RequestPacer(minInterval: const Duration(seconds: 1));

/// A small most-recently-used cache of results, keyed by query string.
///
/// Nominatim's policy is unusually direct about this — "Results must be cached
/// on your side" — and adds that "clients sending repeatedly the same query may
/// be classified as faulty and blocked". Searching the same thing twice is
/// completely ordinary behaviour (type "Isar", look, cancel, reopen, type
/// "Isar"), so without this the app was generating exactly the traffic pattern
/// that gets clients blocked.
///
/// In memory only, and deliberately so: a geocoding result is a snapshot of a
/// live database, and persisting it across launches would serve stale geometry
/// for an import the user expects to be current. The point is to absorb repeat
/// queries within a session, not to build an offline geocoder.
class QueryCache<T> {
  QueryCache({this.maxEntries = 32});

  /// How many distinct queries to remember. Small: this is for the repeat you
  /// just made, not a corpus.
  final int maxEntries;

  final LinkedHashMap<String, T> _entries = LinkedHashMap<String, T>();

  /// Normalises so trivial variants share an entry — the server would return
  /// the same thing for them anyway.
  static String normalise(String query) =>
      query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// The cached value for [query], or null. A hit is promoted to most-recent.
  T? get(String query) {
    final key = normalise(query);
    final hit = _entries.remove(key);
    if (hit != null) _entries[key] = hit; // re-insert = most recent
    return hit;
  }

  void put(String query, T value) {
    final key = normalise(query);
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first); // oldest
    }
  }

  void clear() => _entries.clear();

  int get length => _entries.length;
}
