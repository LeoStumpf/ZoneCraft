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

import 'package:flutter/foundation.dart';

/// Why the map stopped loading new tiles — and the words to say about it.
///
/// The map is offline-first, so a tile that does not arrive normally means
/// nothing worth saying: cached areas keep drawing and everything the user made
/// is on the device. But there is one case that *does* need explaining, and it
/// is the one that looks most like a broken app: the tile server answered, and
/// what it said was **no**. A daily quota runs out, a key is rejected, an
/// operator blocks the app. The map then half-loads grey squares forever with
/// no clue why, at an hour the user cannot predict and for a reason they cannot
/// guess.
///
/// So this exists to turn one hard stop into one sentence.

/// What the server said, in the only four flavours worth different words.
enum TileFailureKind {
  /// 402 / 429: the plan's allowance is spent, or requests are coming too fast.
  /// Recoverable by waiting — usually until the provider's day rolls over.
  quota,

  /// 401 / 403: the key was refused, or this client is blocked. Waiting does
  /// not fix it; a person has to.
  rejected,

  /// 5xx: the server is having a bad day. Nothing to do but try later.
  serverError,

  /// No answer at all. Deliberately *not* surfaced — see [TileHealth.report].
  offline,
}

/// Classifies an HTTP status into the kind of thing the user should be told.
/// Null means "nothing worth a banner" — chiefly 404, which is an ordinary
/// answer for a tile that does not exist at this zoom.
TileFailureKind? tileFailureFor(int statusCode) => switch (statusCode) {
  402 || 429 => TileFailureKind.quota,
  401 || 403 => TileFailureKind.rejected,
  >= 500 && < 600 => TileFailureKind.serverError,
  _ => null,
};

/// Watches tile fetches and decides when something is worth telling the user.
///
/// Two rules keep it from crying wolf. **A single failure says nothing** — one
/// 429 in a burst of twenty tiles is ordinary — so [_threshold] consecutive
/// ones are required. And **any success clears everything**, because the map
/// working again is the whole answer; there is no state to nurse afterwards.
class TileHealth extends ChangeNotifier {
  /// Consecutive refusals before the banner appears. Three, because tiles are
  /// requested in bursts: fewer would fire on a single unlucky tile, more would
  /// wait through most of a screenful of grey.
  static const int _threshold = 3;

  TileFailureKind? _kind;
  int _streak = 0;
  bool _dismissed = false;

  /// What to tell the user, or null when there is nothing to say: tiles are
  /// fine, the streak is too short to mean anything yet, or this one was
  /// dismissed.
  ///
  /// The streak check belongs here and not only at the notify: a listener that
  /// rebuilds for its own reasons reads this getter, and without it the banner
  /// appeared on the *first* refusal — which is exactly the single unlucky tile
  /// [_threshold] exists to ignore.
  TileFailureKind? get failure =>
      _dismissed || _streak < _threshold ? null : _kind;

  /// The refusal currently in force, dismissed or not. For tests and for
  /// deciding whether a *new* kind should re-raise a dismissed banner.
  @visibleForTesting
  TileFailureKind? get rawFailure => _kind;

  /// A tile came back. [statusCode] null means the request never completed
  /// (offline, timeout, socket reset).
  ///
  /// Not being online is not a failure this reports: it is the normal state the
  /// whole cache exists for, the user already knows, and a banner about it would
  /// fire on every subway ride.
  void report({int? statusCode}) {
    if (statusCode == null) return;
    if (statusCode == 200) {
      _clear();
      return;
    }
    final kind = tileFailureFor(statusCode);
    if (kind == null) return;

    // A different refusal is new news, so it re-raises even after a dismissal.
    if (kind != _kind) {
      _kind = kind;
      _streak = 1;
      _dismissed = false;
    } else {
      _streak++;
    }
    if (_streak == _threshold) notifyListeners();
  }

  /// Hides the current banner until tiles fail differently, or fail again after
  /// working. The message is an explanation, not an alarm — once read, it has
  /// done its job.
  void dismiss() {
    if (_kind == null || _dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  void _clear() {
    if (_kind == null && !_dismissed) return;
    final wasVisible = failure != null;
    _kind = null;
    _streak = 0;
    _dismissed = false;
    if (wasVisible) notifyListeners();
  }
}

/// The headline: what the user is actually seeing, in their terms.
String tileFailureTitle(TileFailureKind kind) => switch (kind) {
  TileFailureKind.quota => 'The map has stopped loading new areas',
  TileFailureKind.rejected => 'The map server is refusing this app',
  TileFailureKind.serverError => 'The map server is having trouble',
  TileFailureKind.offline => 'No connection',
};

/// One line under the headline. Short enough for a banner.
String tileFailureSummary(TileFailureKind kind) => switch (kind) {
  TileFailureKind.quota =>
    "Today's allowance is used up. Everything you made is safe.",
  TileFailureKind.rejected =>
    'Tiles are being refused. Everything you made is safe.',
  TileFailureKind.serverError =>
    'The tile server is failing. Everything you made is safe.',
  TileFailureKind.offline => 'Cached areas still work.',
};

/// The full explanation, for the dialog behind the banner's "Why?".
///
/// [host] is the tile server actually in use and [isCommunityOsm] says whether
/// that is OpenStreetMap's own donated one, because the honest account differs:
/// a paid-or-free-tier provider has a quota that resets, while OSM's servers
/// have people who decided this app was asking too much of them.
String tileFailureExplanation(
  TileFailureKind kind, {
  required String host,
  required bool isCommunityOsm,
}) {
  const safe =
      'Nothing you have made is affected. Every zone, import, '
      'measurement and layer lives on this device, not on that server, and '
      'map areas you have already looked at are cached and still draw.';

  return switch (kind) {
    TileFailureKind.quota =>
      isCommunityOsm
          ? 'The base map comes from OpenStreetMap’s own servers, which are '
                'run on donations, and they are asking this app to slow down.\n\n'
                '$safe\n\n'
                'It usually clears by itself. If it does not, the app is asking '
                'for more than its share and the author would want to know.'
          : 'The base map comes from $host on a plan with a daily allowance, and '
                'today’s is spent. It resets on the provider’s schedule, '
                'normally within a day.\n\n'
                '$safe\n\n'
                'This is a limit of the app, not of anything you did — the '
                'allowance is shared by everyone using ZoneCraft.',
    TileFailureKind.rejected =>
      isCommunityOsm
          ? 'OpenStreetMap’s servers have refused this app’s requests. '
                'They run on donations and may block a client that costs them more '
                'than it should — without warning, which is their published '
                'policy and a fair one.\n\n'
                '$safe\n\n'
                'This one does not fix itself. Please tell the author, who can '
                'sort it out with them.'
          : 'The key ZoneCraft uses for $host has been refused — expired, '
                'revoked, or over its limit for good.\n\n'
                '$safe\n\n'
                'This one does not fix itself. Please tell the author.',
    TileFailureKind.serverError =>
      '$host is returning errors. That is at their end, not yours.\n\n$safe\n\n'
          'Try again in a while.',
    TileFailureKind.offline => 'No tile server could be reached. $safe',
  };
}

/// Whether the user can do anything but wait — decides if the dialog offers the
/// "point it at your own server" route rather than just an explanation.
bool tileFailureIsPersistent(TileFailureKind kind) =>
    kind == TileFailureKind.rejected || kind == TileFailureKind.quota;
