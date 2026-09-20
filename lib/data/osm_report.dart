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

/// What a correction *says*, and where it is pinned — the whole composition
/// layer, pure, with no Flutter and no I/O so every sentence it can produce is
/// checkable in a table test.
///
/// The app composes a draft; a human then reads and edits it before anything
/// is sent. That order is deliberate and load-bearing. OpenStreetMap's own
/// guidance for third-party apps is that notes are *"human-to-human
/// communication"* and that apps must *"create no automated notes"*, while
/// also requiring that a report carry *"sufficient information and detail for
/// an experienced mapper to be able to fix the issue"*. A blank box fails the
/// second rule and a send button that skips the human fails the first, so the
/// draft exists to be argued with rather than submitted.
library;

import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../app_info.dart';
import 'database.dart' show OsmReport;
// For [osmNoteUrl] only — the note's web address depends on which server it
// was filed with, which is the one thing about a report this file cannot work
// out on its own.
import 'osm_notes.dart' show osmNoteUrl;

/// What kind of thing is being reported.
///
/// Stored by `name`, never by index — a future kind must not renumber rows
/// already written.
enum OsmReportKind {
  /// The element exists but is in the wrong place, and the user has moved
  /// their copy to where it really is. Only offered once that move has
  /// happened: its sentence quotes the correction.
  movedHere(label: 'It is in the wrong place', needsCorrection: true),

  /// The name (or the lack of one) is wrong, and the user has fixed theirs.
  wrongName(label: 'The name is wrong', needsCorrection: true),

  /// It is not there any more.
  gone(label: 'It is not there any more'),

  /// A hand-placed POI that OpenStreetMap does not have.
  missing(label: 'This is missing from OpenStreetMap'),

  /// Anything else, including a report about ground with no element on it.
  other(label: 'Something else');

  const OsmReportKind({required this.label, this.needsCorrection = false});

  /// The chip's text, and the outbox row's heading.
  final String label;

  /// Whether this kind can only be stated by a point that has been corrected
  /// locally — its sentence quotes what changed, so without the change there
  /// is nothing to say.
  final bool needsCorrection;

  static OsmReportKind? byName(String name) {
    for (final k in OsmReportKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// The subject of a report, gathered from wherever the sheet was opened.
///
/// A plain value type rather than a POI row, because one of the four entry
/// points is a long-press on empty ground, which has no row at all.
class OsmReportSubject {
  const OsmReportSubject({
    required this.lat,
    required this.lng,
    this.name,
    this.origLat,
    this.origLng,
    this.origName,
    this.edited = false,
    this.categoryLabel,
    this.tagKey,
    this.tagValue,
    this.osmType,
    this.osmId,
    this.poiPointId,
  });

  /// Ground with nothing mapped on it — a long-press anywhere.
  const OsmReportSubject.place(this.lat, this.lng)
    : name = null,
      origLat = null,
      origLng = null,
      origName = null,
      edited = false,
      categoryLabel = null,
      tagKey = null,
      tagValue = null,
      osmType = null,
      osmId = null,
      poiPointId = null;

  /// Where the user's copy is *now* — the corrected position when it has been
  /// moved.
  final double lat;
  final double lng;
  final String? name;

  /// What the import returned, when this point has been corrected locally.
  final double? origLat;
  final double? origLng;
  final String? origName;
  final bool edited;

  /// Human-readable category ("Benches"), for the draft's first line.
  final String? categoryLabel;

  /// The OSM tag this category stands for, when there is one. A hand-made
  /// category built from a bare icon has none, and guessing is worse than
  /// silence — a mapper can tag an unlabelled bench, but has to undo a wrong
  /// suggestion first.
  final String? tagKey;
  final String? tagValue;

  final String? osmType;
  final int? osmId;
  final String? poiPointId;

  /// Whether the position has actually moved. Read rather than assumed from
  /// [edited], because a point may have been renamed and not moved.
  bool get positionCorrected =>
      edited &&
      origLat != null &&
      origLng != null &&
      (origLat != lat || origLng != lng);

  /// Whether the name has actually changed.
  bool get nameCorrected => edited && origName != name;

  /// Which kinds this subject can honestly report.
  ///
  /// [OsmReportKind.missing] belongs to a hand-placed point and nothing else;
  /// the correction kinds need a correction; and ground with no element on it
  /// can only say "something else".
  List<OsmReportKind> get availableKinds {
    if (osmKeyOf(this) == null && !edited) {
      return const [OsmReportKind.missing, OsmReportKind.other];
    }
    return [
      if (positionCorrected) OsmReportKind.movedHere,
      if (nameCorrected) OsmReportKind.wrongName,
      OsmReportKind.gone,
      OsmReportKind.other,
    ];
  }

  /// The kind the sheet opens on: whatever the user has just done, if they
  /// have done anything.
  OsmReportKind get defaultKind => availableKinds.first;
}

/// `node/240109189`, or null when there is no upstream identity.
///
/// The id-`0` rule is `Repository.osmKey`'s, restated here so this file stays
/// free of the repository: zero is not a valid OSM id for any element type,
/// it is the placeholder an id-less imported row carries, and a report linking
/// to `node/0` would send a mapper to a 404.
String? osmKeyOf(OsmReportSubject s) {
  final type = s.osmType;
  final id = s.osmId;
  if (type == null || id == null || id == 0) return null;
  return '$type/$id';
}

/// The element's page on osm.org, or null when it has no identity.
String? osmElementUrl(String? osmType, int? osmId) {
  if (osmType == null || osmId == null || osmId == 0) return null;
  return 'https://www.openstreetmap.org/$osmType/$osmId';
}

/// Where the note is pinned.
///
/// For a misplaced element this is the **corrected** position, not the
/// element's: a mapper checking the report should be looking at the ground
/// where the thing actually is, and the text tells them how far off the
/// current mapping is. Everything else is anchored at its subject.
LatLng osmReportAnchor(OsmReportKind kind, OsmReportSubject s) {
  if (kind == OsmReportKind.movedHere) return LatLng(s.lat, s.lng);
  if (s.origLat != null && s.origLng != null) {
    // The element is still where OSM has it; the user's copy has moved.
    return LatLng(s.origLat!, s.origLng!);
  }
  return LatLng(s.lat, s.lng);
}

const Distance _haversine = Distance(calculator: Haversine());

/// The eight-point compass name for a bearing in degrees from north.
String compassName(double degrees) {
  const names = [
    'north',
    'north-east',
    'east',
    'south-east',
    'south',
    'south-west',
    'west',
    'north-west',
  ];
  final normalised = ((degrees % 360) + 360) % 360;
  return names[((normalised + 22.5) ~/ 45) % 8];
}

/// Distance in metres, rounded the way a person would say it: to the metre
/// under 100 m, to five under a kilometre, then to the tenth of a kilometre.
///
/// Deliberately vaguer than the stored coordinates. A GPS fix and a finger on
/// a phone screen do not justify "23.7 m", and a number quoted more precisely
/// than it is known invites a mapper to trust it more than they should.
String describeOffset(double meters) {
  if (!meters.isFinite) return 'some distance';
  if (meters < 100) return '${meters.round()} m';
  if (meters < 1000) return '${(meters / 5).round() * 5} m';
  return '${(meters / 100).round() / 10} km';
}

/// The line every report ends with, so an operator reading their logs can tell
/// where a bad report came from and reach somebody about it.
///
/// The `User-Agent` already carries this, but a note is read by mappers in a
/// web page, not by an operator reading headers.
String get osmReportTrailer =>
    '(reported with ZoneCraft $kAppVersion — '
    '$kAppRepositoryUrl)';

/// Builds the draft note for [kind] about [s].
///
/// The result is what goes in the editable field, not what is sent: the user
/// reads it, changes it, and only then presses Send.
String composeOsmReportText(OsmReportKind kind, OsmReportSubject s) {
  final lines = <String>[];

  final heading = _heading(kind, s);
  if (heading != null) lines.add(heading);
  final url = osmElementUrl(s.osmType, s.osmId);
  if (url != null) lines.add(url);
  if (lines.isNotEmpty) lines.add('');

  lines.add(_body(kind, s));
  lines.add('');
  lines.add(osmReportTrailer);
  return lines.join('\n');
}

String? _heading(OsmReportKind kind, OsmReportSubject s) {
  // The name the report is *about* is the one OSM has, not the corrected one —
  // a mapper searching for it needs the string that is in the database.
  final upstream = kind == OsmReportKind.missing
      ? s.name
      : (s.origName ?? s.name);
  final tag = (s.tagKey != null && s.tagValue != null)
      ? '${s.tagKey}=${s.tagValue}'
      : null;
  final what = switch ((s.categoryLabel, tag)) {
    (final String c, final String t) => '$c ($t)',
    (final String c, null) => c,
    (null, final String t) => t,
    _ => null,
  };
  if (what == null && upstream == null) return null;
  if (upstream == null) return what;
  if (what == null) return '“$upstream”';
  return '$what — “$upstream”';
}

String _body(OsmReportKind kind, OsmReportSubject s) {
  final here = _formatLatLng(s.lat, s.lng);
  switch (kind) {
    case OsmReportKind.movedHere:
      final from = LatLng(s.origLat!, s.origLng!);
      final to = LatLng(s.lat, s.lng);
      final offset = describeOffset(_haversine.as(LengthUnit.Meter, from, to));
      final where = compassName(const Distance().bearing(from, to));
      return 'This is mapped about $offset $where of where it actually is. '
          'I make it $here.';
    case OsmReportKind.wrongName:
      final was = s.origName;
      final now = s.name;
      if (now == null || now.trim().isEmpty) {
        return was == null
            ? 'The name here looks wrong.'
            : 'This does not seem to be called “$was” any more.';
      }
      return was == null
          ? 'This has a name: “$now”.'
          : 'This is named “$was”, but on the ground it is “$now”.';
    case OsmReportKind.gone:
      return 'This does not seem to be here any more.';
    case OsmReportKind.missing:
      return 'This seems to be missing from OpenStreetMap. I make it $here.';
    case OsmReportKind.other:
      return '';
  }
}

String _formatLatLng(double lat, double lng) =>
    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

/// The outbox as a GeoJSON `FeatureCollection` — one `Point` per report.
///
/// This is the second route the feature exists to offer: a mapper who would
/// rather not file anonymous notes can save the file, open it in JOSM or QGIS
/// as a to-do layer, and work through it under their own account with their
/// own tools. Which is why the element identity travels as separate
/// properties as well as inside the text, and why sent and unsent reports both
/// appear, flagged.
String osmReportsGeoJson(List<OsmReport> reports) {
  final features = [
    for (final r in reports)
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          // GeoJSON is longitude-first. Getting this backwards puts Munich in
          // Somalia, silently.
          'coordinates': [r.lng, r.lat],
        },
        'properties': {
          'kind': r.kind,
          'text': r.body,
          'created_at': r.createdAt.toUtc().toIso8601String(),
          if (r.osmType != null && r.osmId != null && r.osmId != 0) ...{
            'osm_type': r.osmType,
            'osm_id': r.osmId,
            'osm_url': osmElementUrl(r.osmType, r.osmId),
          },
          'sent': r.sentAt != null,
          if (r.sentAt != null) ...{
            'sent_at': r.sentAt!.toUtc().toIso8601String(),
            'note_id': r.noteId,
            if (r.noteId != null) 'note_url': osmNoteUrl(r.noteId!),
          },
        },
      },
  ];
  return const JsonEncoder.withIndent('  ').convert({
    'type': 'FeatureCollection',
    'generator': 'ZoneCraft $kAppVersion',
    'features': features,
  });
}

/// Longest note the sheet will let through.
///
/// The API does not publish a limit, so this is the app holding itself to
/// something a mapper will actually read rather than something a server will
/// accept.
const int kOsmReportMaxChars = 1000;

/// After this many notes sent in a day the sheet starts suggesting the export
/// instead, and at [kOsmReportsHardCapPerDay] it stops offering Send at all.
///
/// Both numbers are osm.org's own: its web form warns after five anonymous
/// notes and hides itself after ten. Mirroring them is the point — an app that
/// let one person pour fifty anonymous notes into the database in an afternoon
/// would earn the blanket block on its `User-Agent` that the API usage policy
/// promises, and take every other ZoneCraft user's import with it.
const int kOsmReportsSoftCapPerDay = 5;
const int kOsmReportsHardCapPerDay = 10;
