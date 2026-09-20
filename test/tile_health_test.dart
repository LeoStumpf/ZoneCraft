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

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/tile_health.dart';

/// Pins the two judgements that keep this from being noise.
///
/// **Offline is not a failure.** The map is offline-first; a tile that never
/// arrives is the normal state the cache exists for, and a banner about it
/// would fire on every subway ride. Only a server that answered and said *no*
/// is worth interrupting for.
///
/// **One refusal is not news.** Tiles go out in bursts, so a single 429 among
/// twenty is ordinary. Three consecutive ones is a pattern.
void main() {
  group('classification', () {
    test('a spent allowance and a rate limit read as quota', () {
      expect(tileFailureFor(402), TileFailureKind.quota);
      expect(tileFailureFor(429), TileFailureKind.quota);
    });

    test('a refused key and a blocked client read as rejected', () {
      expect(tileFailureFor(401), TileFailureKind.rejected);
      expect(tileFailureFor(403), TileFailureKind.rejected);
    });

    test('5xx is the server, not us', () {
      expect(tileFailureFor(500), TileFailureKind.serverError);
      expect(tileFailureFor(503), TileFailureKind.serverError);
    });

    test('404 is an ordinary answer for a tile that does not exist', () {
      // High zoom past a provider's coverage returns this all day. Treating it
      // as a failure would put a banner on a working map.
      expect(tileFailureFor(404), isNull);
      expect(tileFailureFor(200), isNull);
    });
  });

  group('TileHealth', () {
    test('says nothing when tiles are fine', () {
      final h = TileHealth();
      h.report(statusCode: 200);
      expect(h.failure, isNull);
    });

    test('says nothing about being offline', () {
      final h = TileHealth();
      for (var i = 0; i < 10; i++) {
        h.report();
      }
      expect(h.failure, isNull, reason: 'no answer is not a refusal');
    });

    test('needs three refusals before it speaks', () {
      final h = TileHealth();
      h.report(statusCode: 429);
      expect(h.failure, isNull);
      h.report(statusCode: 429);
      expect(h.failure, isNull);
      h.report(statusCode: 429);
      expect(h.failure, TileFailureKind.quota);
    });

    test('notifies exactly once when it crosses the threshold', () {
      final h = TileHealth();
      var notifications = 0;
      h.addListener(() => notifications++);
      for (var i = 0; i < 6; i++) {
        h.report(statusCode: 429);
      }
      expect(notifications, 1, reason: 'every later tile must not re-notify');
    });

    test('a working tile clears it — that is the whole answer', () {
      final h = TileHealth();
      for (var i = 0; i < 3; i++) {
        h.report(statusCode: 429);
      }
      expect(h.failure, TileFailureKind.quota);
      h.report(statusCode: 200);
      expect(h.failure, isNull);
      expect(h.rawFailure, isNull);
    });

    test('an interleaved success resets the streak', () {
      final h = TileHealth();
      h.report(statusCode: 429);
      h.report(statusCode: 429);
      h.report(statusCode: 200);
      h.report(statusCode: 429);
      expect(h.failure, isNull, reason: 'two more are needed, not one');
    });

    test('dismissing hides it without pretending tiles work', () {
      final h = TileHealth();
      for (var i = 0; i < 3; i++) {
        h.report(statusCode: 429);
      }
      h.dismiss();
      expect(h.failure, isNull);
      expect(
        h.rawFailure,
        TileFailureKind.quota,
        reason: 'the refusal is still in force',
      );
      // More of the same must not nag.
      for (var i = 0; i < 5; i++) {
        h.report(statusCode: 429);
      }
      expect(h.failure, isNull);
    });

    test('a different refusal re-raises a dismissed banner', () {
      // "Slow down" and "your key is refused" are different news, and the
      // second one does not fix itself.
      final h = TileHealth();
      for (var i = 0; i < 3; i++) {
        h.report(statusCode: 429);
      }
      h.dismiss();
      for (var i = 0; i < 3; i++) {
        h.report(statusCode: 403);
      }
      expect(h.failure, TileFailureKind.rejected);
    });

    test('failing again after recovering speaks up again', () {
      final h = TileHealth();
      for (var i = 0; i < 3; i++) {
        h.report(statusCode: 429);
      }
      h.dismiss();
      h.report(statusCode: 200);
      for (var i = 0; i < 3; i++) {
        h.report(statusCode: 429);
      }
      expect(h.failure, TileFailureKind.quota);
    });
  });

  group('what it says', () {
    test('every kind has a headline and a one-line summary', () {
      for (final kind in TileFailureKind.values) {
        expect(tileFailureTitle(kind), isNotEmpty, reason: kind.name);
        expect(tileFailureSummary(kind), isNotEmpty, reason: kind.name);
      }
    });

    test('the explanation always says the user\'s work is safe', () {
      // The visible symptom is the map disappearing, which reads as data loss.
      // That fear gets answered before anything else, in every case.
      for (final kind in TileFailureKind.values) {
        final text = tileFailureExplanation(
          kind,
          host: 'tiles.example.org',
          isCommunityOsm: false,
        );
        expect(
          text.toLowerCase(),
          contains('on this device'),
          reason: kind.name,
        );
      }
    });

    test('it names the server when that server is not OpenStreetMap', () {
      final text = tileFailureExplanation(
        TileFailureKind.quota,
        host: 'maps.geoapify.com',
        isCommunityOsm: false,
      );
      expect(text, contains('maps.geoapify.com'));
      expect(text, contains('allowance'));
    });

    test('a community-OSM refusal is described honestly, not as a bug', () {
      // Their servers are donated and their policy allows blocking without
      // notice. Saying "something went wrong" would be a lie.
      final text = tileFailureExplanation(
        TileFailureKind.rejected,
        host: 'tile.openstreetmap.org',
        isCommunityOsm: true,
      );
      expect(text, contains('donations'));
      expect(text, contains('does not fix itself'));
    });

    test('only the fixable kinds offer a way out', () {
      expect(tileFailureIsPersistent(TileFailureKind.quota), isTrue);
      expect(tileFailureIsPersistent(TileFailureKind.rejected), isTrue);
      expect(tileFailureIsPersistent(TileFailureKind.serverError), isFalse);
    });
  });
}
