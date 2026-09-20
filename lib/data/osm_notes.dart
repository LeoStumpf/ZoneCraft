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

/// Delivering one note to the OpenStreetMap API — the only outbound *write*
/// the app makes, and the only place anything a user typed leaves the device.
///
/// Notes are the sanctioned path. OSM's developer guidance says plainly that
/// *"it is OK for third party sites or apps that use OpenStreetMap data to
/// include notes functionality through the API"*, and `POST /api/0.6/notes`
/// accepts an unauthenticated request, which is why this needs no account and
/// no token.
///
/// Three rules shape the code rather than just the UI:
///
/// - **No retry, and no failover.** Every other client in this app retries a
///   transient status and walks a list of endpoints; a write must not. A POST
///   that timed out may well have been applied, and the visible cost of
///   guessing wrong is a duplicate note somebody has to close by hand. There
///   is also only one OpenStreetMap — an endpoint list would mean sending
///   somebody's contribution to a server that is not it.
/// - **Never throws.** Like `overpassPost`, every failure comes back as an
///   outcome carrying a sentence, because the caller's job is to keep the
///   user's text on screen rather than to handle an exception.
/// - **One explicit timeout.** `package:http` has none of its own.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_info.dart';
import 'request_pacer.dart';

/// Where notes are sent.
///
/// A build-time define, not a [ServiceOverride]: the three switchable services
/// are ones someone else pays to run and can ask to be left alone, whereas the
/// OpenStreetMap database is not a thing you swap — a typed-in URL here would
/// mean somebody's contribution quietly going to a stranger's server. The
/// define exists so development and on-device verification can point at
/// `https://master.apis.dev.openstreetmap.org`, the public sandbox, and never
/// at the live database.
const String kOsmApiBase = String.fromEnvironment(
  'OSM_API_URL',
  defaultValue: 'https://api.openstreetmap.org',
);

/// Whether this build is pointed at the real database. The report sheet says
/// so when it is not, since a note that lands in the sandbox helps nobody and
/// looks identical from in here.
bool get osmApiIsLive => kOsmApiBase == 'https://api.openstreetmap.org';

/// Host shown on the "Servers and limits" page.
String get osmApiHost => Uri.tryParse(kOsmApiBase)?.host ?? kOsmApiBase;

const Duration kOsmNoteTimeout = Duration(seconds: 30);

Uri osmNoteCreateUri() => Uri.parse('$kOsmApiBase/api/0.6/notes.json');

/// Where a note can be read in a browser.
///
/// The API host and the web host are the same thing on the sandbox but not on
/// the real service — `api.openstreetmap.org` answers the API, `www.` serves
/// the site — so this maps one to the other rather than assuming. Without it
/// a report filed from a sandbox build links to a note number that does not
/// exist on the live site, which is a 404 in exactly the situation the define
/// exists to make safe.
String osmNoteUrl(int noteId) => osmApiIsLive
    ? 'https://www.openstreetmap.org/note/$noteId'
    : '$kOsmApiBase/note/$noteId';

/// What happened to one note.
///
/// [noteId] is set exactly when [ok] is true. [retryable] separates "this may
/// work later" (offline, busy, rate-limited) from "this will never work as
/// written" (rejected, refused), so the outbox can offer a retry only where
/// one makes sense.
class OsmNoteOutcome {
  const OsmNoteOutcome.ok(this.noteId) : message = null, retryable = false;

  const OsmNoteOutcome.failed(this.message, {this.retryable = false})
    : noteId = null;

  final int? noteId;
  final String? message;
  final bool retryable;

  bool get ok => message == null;
}

/// Turns a response into an outcome. Pure, so every status this app can meet
/// is a table test rather than something only a real server can produce.
///
/// The messages are written to be read by somebody whose report just did not
/// go, standing outside: they say what to do next, and they never blame the
/// user for a limit they could not have known about.
OsmNoteOutcome classifyOsmNoteResponse(int statusCode, String body) {
  if (statusCode == 200 || statusCode == 201) {
    final id = parseOsmNoteId(body);
    if (id == null) {
      // The note was almost certainly created — OSM answered 200 — so this
      // must not read as a failure the user should retry into a duplicate.
      return const OsmNoteOutcome.failed(
        'OpenStreetMap accepted the report but sent back something we could '
        'not read, so the note number is unknown. Check openstreetmap.org '
        'before sending it again.',
      );
    }
    return OsmNoteOutcome.ok(id);
  }
  switch (statusCode) {
    case 400:
      return const OsmNoteOutcome.failed(
        'OpenStreetMap rejected the report. The text may be empty or too '
        'long, or the position outside the map.',
      );
    case 401:
    case 403:
      return const OsmNoteOutcome.failed(
        'OpenStreetMap refused the report. Anonymous reports may be closed '
        'for now — you can save this one and send it from openstreetmap.org '
        'with your own account.',
      );
    case 404:
      return const OsmNoteOutcome.failed(
        'That position is outside the area OpenStreetMap accepts notes for.',
      );
    case 409:
      // Moderation Zones, added to the API in May 2026.
      return const OsmNoteOutcome.failed(
        'OpenStreetMap does not accept notes in this area. Save the report '
        'and it can still be exported.',
      );
    case 429:
      return const OsmNoteOutcome.failed(
        'OpenStreetMap is limiting anonymous reports at the moment. Save this '
        'one for later, or export it and send it with your own account.',
        retryable: true,
      );
  }
  if (statusCode >= 500 && statusCode < 600) {
    return const OsmNoteOutcome.failed(
      'OpenStreetMap is having trouble right now. The report is saved — try '
      'sending it again in a while.',
      retryable: true,
    );
  }
  return OsmNoteOutcome.failed(
    'OpenStreetMap refused the report (HTTP $statusCode).',
  );
}

/// The note number out of a create response.
///
/// The `.json` endpoint answers with a GeoJSON feature whose `properties.id`
/// is the note number; older deployments answer XML. Both are read, because a
/// self-hosted or sandbox instance may be a version behind and losing the
/// number would leave the user unable to find their own note.
int? parseOsmNoteId(String body) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final props = decoded['properties'];
        if (props is Map) {
          final id = props['id'];
          if (id is num) return id.toInt();
        }
        final id = decoded['id'];
        if (id is num) return id.toInt();
      }
      // A malformed body is simply an unreadable answer, not a crash.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
    return null;
  }
  final match = RegExp(r'<id>\s*(\d+)\s*</id>').firstMatch(body);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// Sends one note. See the library doc for why this neither retries nor fails
/// over.
///
/// [client] is for tests; when it is null this owns and closes its own.
Future<OsmNoteOutcome> submitOsmNote({
  required double lat,
  required double lng,
  required String text,
  http.Client? client,
}) async {
  if (text.trim().isEmpty) {
    return const OsmNoteOutcome.failed('A report needs something to say.');
  }
  final owned = client == null;
  final c = client ?? http.Client();
  try {
    final resp = await osmApiPacer.run(
      () => c
          .post(
            osmNoteCreateUri(),
            headers: const {
              'User-Agent': zoneCraftUserAgent,
              'Content-Type': 'application/json',
            },
            // Longitude is `lon` here, not `lng`.
            body: jsonEncode({'lat': lat, 'lon': lng, 'text': text}),
          )
          .timeout(kOsmNoteTimeout),
    );
    return classifyOsmNoteResponse(resp.statusCode, resp.body);
    // Offline, DNS, TLS, timeout — indistinguishable from here, and all mean
    // the same thing to the person holding the phone.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return const OsmNoteOutcome.failed(
      'Could not reach OpenStreetMap. The report is saved — try again when '
      'you have a connection.',
      retryable: true,
    );
  } finally {
    if (owned) c.close();
  }
}
