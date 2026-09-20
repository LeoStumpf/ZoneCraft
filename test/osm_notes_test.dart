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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zonecraft/app_info.dart';
import 'package:zonecraft/data/osm_notes.dart';

/// The one place this app writes to somebody else's database.
///
/// Two things are pinned here beyond the happy path. The **request** must
/// identify the app — the API usage policy's only hard requirement, and the
/// string operators block by. And every failure must come back as a sentence
/// rather than an exception, because the caller's job when a send fails is to
/// keep the user's text on screen, which it cannot do while unwinding.
void main() {
  group('the request', () {
    test('says who it is, and posts lat/lon/text as JSON', () async {
      http.Request? sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response('{"properties":{"id":42}}', 200);
      });

      await submitOsmNote(
          lat: 48.1374, lng: 11.5755, text: 'A bench.', client: client);

      final request = sent!;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/0.6/notes.json');
      expect(request.headers['User-Agent'], zoneCraftUserAgent);
      expect(request.headers['User-Agent'], contains(kAppVersion),
          reason: 'the policy asks for the application *and version*');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      // `lon`, not `lng` — the API's spelling, and a silent 400 otherwise.
      expect(body, {'lat': 48.1374, 'lon': 11.5755, 'text': 'A bench.'});
    });

    test('goes to the configured API, which is the sandbox in a test build',
        () {
      expect(osmNoteCreateUri().toString(), startsWith(kOsmApiBase));
      expect(osmApiHost, Uri.parse(kOsmApiBase).host);
      expect(osmApiIsLive, kOsmApiBase == 'https://api.openstreetmap.org');
    });

    test('an empty report is refused here, not at the far end', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      final outcome =
          await submitOsmNote(lat: 48.1, lng: 11.5, text: '   ', client: client);
      expect(outcome.ok, isFalse);
      expect(called, isFalse, reason: 'nothing is sent');
    });
  });

  group('what comes back', () {
    test('a created note yields its number', () {
      final outcome =
          classifyOsmNoteResponse(200, '{"properties":{"id":4812345}}');
      expect(outcome.ok, isTrue);
      expect(outcome.noteId, 4812345);
    });

    test('an XML answer is read too', () {
      // A sandbox or self-hosted instance may be a version behind, and losing
      // the number leaves the user unable to find their own note.
      expect(parseOsmNoteId('<osm><note><id>77</id></note></osm>'), 77);
      expect(parseOsmNoteId('{"id":78}'), 78);
      expect(parseOsmNoteId('not json at all'), isNull);
      expect(parseOsmNoteId('{oops'), isNull);
    });

    test('an accepted note we cannot read does not invite a retry', () {
      // OSM answered 200, so the note almost certainly exists. Telling the
      // user to try again would make them file a duplicate somebody has to
      // close by hand.
      final outcome = classifyOsmNoteResponse(200, 'surprise');
      expect(outcome.ok, isFalse);
      expect(outcome.retryable, isFalse);
      expect(outcome.message, contains('accepted'));
    });

    test('every refusal is explained, and only the temporary ones retry', () {
      const permanent = [400, 401, 403, 404, 409, 418];
      for (final status in permanent) {
        final outcome = classifyOsmNoteResponse(status, '');
        expect(outcome.ok, isFalse, reason: 'HTTP $status');
        expect(outcome.message, isNotEmpty, reason: 'HTTP $status');
        expect(outcome.retryable, isFalse,
            reason: 'HTTP $status will not start working on its own');
      }
      for (final status in [429, 500, 502, 503]) {
        final outcome = classifyOsmNoteResponse(status, '');
        expect(outcome.retryable, isTrue, reason: 'HTTP $status');
      }
    });

    test('a refusal never leaves the user without a way forward', () {
      // Whatever went wrong, the report itself is not lost: the messages say
      // so, because the sheet keeps the text and the outbox keeps the row.
      for (final status in [403, 409, 429, 500]) {
        final message = classifyOsmNoteResponse(status, '').message!;
        expect(message, matches(RegExp('saved|save|export|account|try')),
            reason: 'HTTP $status should say what to do next');
      }
    });

    test('a moderation zone is named as the area refusing, not as a fault', () {
      // Added to the API in May 2026. A user who wandered into one has done
      // nothing wrong and should not be told they have.
      final outcome = classifyOsmNoteResponse(409, '');
      expect(outcome.message, contains('does not accept notes in this area'));
    });
  });

  group('failures below HTTP', () {
    test('being offline is an outcome, never an exception', () async {
      final client = MockClient(
          (_) async => throw const SocketException('no route to host'));
      final outcome = await submitOsmNote(
          lat: 48.1, lng: 11.5, text: 'A bench.', client: client);
      expect(outcome.ok, isFalse);
      expect(outcome.retryable, isTrue);
      expect(outcome.message, contains('Could not reach OpenStreetMap'));
    });

    test('a timeout is the same, and does not hang', () async {
      final client = MockClient((_) async {
        throw TimeoutException('too slow');
      });
      final outcome = await submitOsmNote(
          lat: 48.1, lng: 11.5, text: 'A bench.', client: client);
      expect(outcome.ok, isFalse);
      expect(outcome.retryable, isTrue);
    });

    test('there is exactly one attempt, and one server', () async {
      // Every other client here retries and fails over; a write must not. A
      // POST that timed out may well have been applied, and there is only one
      // OpenStreetMap to send it to.
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('', 503);
      });
      await submitOsmNote(
          lat: 48.1, lng: 11.5, text: 'A bench.', client: client);
      expect(attempts, 1);
    });
  });
}
