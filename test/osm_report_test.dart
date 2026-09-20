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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart' show OsmReport;
import 'package:zonecraft/data/osm_report.dart';

/// What a report *says* is the part of this feature that reaches a stranger.
///
/// OSM's guidance for apps is that a note must carry "sufficient information
/// and detail for an experienced mapper to be able to fix the issue", so the
/// draft is held to that here: the element it is about, where the reporter
/// thinks it should be, and how far that is from where it is mapped. The other
/// half is what must *not* appear — a link to `node/0`, a tag nobody chose, a
/// name the reporter invented presented as the one OSM holds.
void main() {
  const munich = OsmReportSubject(
    lat: 48.137400,
    lng: 11.575000,
    name: 'West gate bench',
    origLat: 48.137180,
    origLng: 11.575000,
    origName: 'West gate bench',
    edited: true,
    categoryLabel: 'Benches',
    tagKey: 'amenity',
    tagValue: 'bench',
    osmType: 'node',
    osmId: 240109189,
  );

  group('upstream identity', () {
    test('a real node gets a link', () {
      expect(
        osmElementUrl('node', 240109189),
        'https://www.openstreetmap.org/node/240109189',
      );
      expect(osmElementUrl('way', 7), 'https://www.openstreetmap.org/way/7');
      expect(
        osmElementUrl('relation', 9),
        'https://www.openstreetmap.org/relation/9',
      );
    });

    test('id 0 is no identity at all, so no link is offered', () {
      // Zero is the placeholder an id-less imported row carries, not an id.
      // Linking it would send a mapper to a 404 — the same rule `osmKey` has
      // lived by since it made every id-less border area look like one
      // relation.
      expect(osmElementUrl('node', 0), isNull);
      expect(osmElementUrl(null, 7), isNull);
      expect(osmElementUrl('node', null), isNull);
      expect(
        composeOsmReportText(
          OsmReportKind.gone,
          const OsmReportSubject(
            lat: 48.1,
            lng: 11.5,
            osmType: 'node',
            osmId: 0,
          ),
        ),
        isNot(contains('openstreetmap.org/node')),
      );
    });
  });

  group('which kinds a subject can honestly report', () {
    test('an untouched import cannot claim a correction', () {
      // "It is in the wrong place" quotes the corrected position. Without one
      // there is nothing to say, so the chip is not offered at all rather than
      // producing a sentence with a hole in it.
      const untouched = OsmReportSubject(
        lat: 48.1,
        lng: 11.5,
        osmType: 'node',
        osmId: 7,
      );
      expect(untouched.availableKinds, [
        OsmReportKind.gone,
        OsmReportKind.other,
      ]);
      expect(untouched.defaultKind, OsmReportKind.gone);
    });

    test('a moved point opens on the move', () {
      expect(munich.defaultKind, OsmReportKind.movedHere);
      expect(munich.availableKinds, contains(OsmReportKind.movedHere));
    });

    test('a renamed-but-not-moved point offers only the rename', () {
      const renamed = OsmReportSubject(
        lat: 48.1,
        lng: 11.5,
        name: 'Cafe Kranz',
        origLat: 48.1,
        origLng: 11.5,
        origName: 'Kranz',
        edited: true,
        osmType: 'node',
        osmId: 7,
      );
      expect(renamed.availableKinds, isNot(contains(OsmReportKind.movedHere)));
      expect(renamed.defaultKind, OsmReportKind.wrongName);
    });

    test('a hand-placed point can only be missing', () {
      // It has no upstream, so "it is not there any more" would be about
      // nothing.
      const manual = OsmReportSubject(lat: 48.1, lng: 11.5, name: 'My bench');
      expect(manual.availableKinds, [
        OsmReportKind.missing,
        OsmReportKind.other,
      ]);
    });

    test('bare ground can only say "something else"', () {
      const place = OsmReportSubject.place(48.1, 11.5);
      expect(place.availableKinds, [
        OsmReportKind.missing,
        OsmReportKind.other,
      ]);
      expect(place.positionCorrected, isFalse);
      expect(place.nameCorrected, isFalse);
    });
  });

  group('where the note is pinned', () {
    test('a misplaced element is reported where it actually is', () {
      // Not at the element: a mapper checking this should be looking at the
      // ground where the thing is, and the text says how far off the mapping
      // is.
      final anchor = osmReportAnchor(OsmReportKind.movedHere, munich);
      expect(anchor.latitude, 48.137400);
    });

    test('every other kind is anchored at the element OSM has', () {
      for (final kind in [OsmReportKind.wrongName, OsmReportKind.gone]) {
        expect(
          osmReportAnchor(kind, munich).latitude,
          48.137180,
          reason: '$kind should point at the element, not the correction',
        );
      }
    });

    test('a hand-placed point is reported where it was placed', () {
      const manual = OsmReportSubject(lat: 48.9, lng: 11.9, name: 'My bench');
      expect(osmReportAnchor(OsmReportKind.missing, manual).latitude, 48.9);
    });
  });

  group('the draft', () {
    test(
      'a misplaced bench names itself, links itself and measures itself',
      () {
        final text = composeOsmReportText(OsmReportKind.movedHere, munich);
        expect(text, startsWith('Benches (amenity=bench) — “West gate bench”'));
        expect(text, contains('https://www.openstreetmap.org/node/240109189'));
        // 0.00022° of latitude is about 24 m, due north.
        expect(text, contains('24 m north'));
        expect(text, contains('48.137400, 11.575000'));
        expect(text, contains('ZoneCraft'));
      },
    );

    test('the heading quotes the name OSM has, not the corrected one', () {
      // A mapper searches the database for the string that is in it. Leading
      // with the reporter's replacement would send them looking for something
      // that is not there yet.
      const renamed = OsmReportSubject(
        lat: 48.1,
        lng: 11.5,
        name: 'Cafe Kranz',
        origLat: 48.1,
        origLng: 11.5,
        origName: 'Kranz',
        edited: true,
        categoryLabel: 'Cafés',
        tagKey: 'amenity',
        tagValue: 'cafe',
        osmType: 'node',
        osmId: 7,
      );
      final text = composeOsmReportText(OsmReportKind.wrongName, renamed);
      expect(text, startsWith('Cafés (amenity=cafe) — “Kranz”'));
      expect(text, contains('it is “Cafe Kranz”'));
    });

    test('a name added where OSM has none reads as an addition', () {
      const unnamed = OsmReportSubject(
        lat: 48.1,
        lng: 11.5,
        name: 'Kranz',
        origLat: 48.1,
        origLng: 11.5,
        edited: true,
        osmType: 'node',
        osmId: 7,
      );
      expect(
        composeOsmReportText(OsmReportKind.wrongName, unnamed),
        contains('This has a name: “Kranz”.'),
      );
    });

    test('a hand-placed POI in a preset category suggests its tag', () {
      const manual = OsmReportSubject(
        lat: 48.137400,
        lng: 11.575000,
        name: 'My bench',
        categoryLabel: 'Benches',
        tagKey: 'amenity',
        tagValue: 'bench',
      );
      final text = composeOsmReportText(OsmReportKind.missing, manual);
      expect(text, contains('amenity=bench'));
      expect(text, contains('missing from OpenStreetMap'));
      expect(text, contains('48.137400, 11.575000'));
      expect(
        text,
        isNot(contains('openstreetmap.org/node')),
        reason: 'it has no upstream to link to',
      );
    });

    test('a category built from a bare icon suggests nothing', () {
      // Guessing a tag is worse than silence: a mapper can tag an unlabelled
      // bench, but has to undo a wrong suggestion first.
      const manual = OsmReportSubject(
        lat: 48.1,
        lng: 11.5,
        name: 'Secret spot',
        categoryLabel: 'Secret spots',
      );
      final text = composeOsmReportText(OsmReportKind.missing, manual);
      expect(text, contains('Secret spots — “Secret spot”'));
      expect(text, isNot(contains('=')));
    });

    test('every kind produces something, and every one is signed', () {
      for (final kind in OsmReportKind.values) {
        final text = composeOsmReportText(kind, munich);
        expect(text.trim(), isNotEmpty);
        expect(
          text,
          contains(osmReportTrailer),
          reason:
              'an operator reading a bad report has to be able to '
              'trace it back to this app',
        );
      }
    });

    test('"something else" leaves the sentence to the human', () {
      // It is the one kind the app has nothing to say about, so it hands over
      // a heading, a link and an empty line rather than a guess.
      final text = composeOsmReportText(
        OsmReportKind.other,
        const OsmReportSubject.place(48.1, 11.5),
      );
      expect(text.trim(), osmReportTrailer);
    });
  });

  group('how a distance is stated', () {
    test('it is vaguer than the coordinates, on purpose', () {
      // A finger on a phone screen does not justify "23.7 m", and a number
      // quoted more precisely than it is known invites more trust than it has
      // earned.
      expect(describeOffset(23.7), '24 m');
      expect(describeOffset(232), '230 m');
      expect(describeOffset(1640), '1.6 km');
      expect(describeOffset(double.nan), 'some distance');
    });

    test('the compass name covers the whole circle', () {
      expect(compassName(0), 'north');
      expect(compassName(359), 'north');
      expect(compassName(90), 'east');
      expect(compassName(180), 'south');
      expect(compassName(270), 'west');
      expect(compassName(-90), 'west', reason: 'a negative bearing wraps');
      expect(compassName(45), 'north-east');
    });
  });

  group('the GeoJSON export', () {
    OsmReport report({
      String id = 'r1',
      String kind = 'gone',
      String? osmType = 'node',
      int? osmId = 7,
      DateTime? sentAt,
      int? noteId,
    }) => OsmReport(
      id: id,
      createdAt: DateTime.utc(2026, 3, 12, 9, 30),
      lat: 48.1,
      lng: 11.5,
      kind: kind,
      body: 'Not there any more.',
      osmType: osmType,
      osmId: osmId,
      sentAt: sentAt,
      noteId: noteId,
    );

    test('is longitude-first, like every other GeoJSON', () {
      // Getting this backwards puts Munich in Somalia, silently.
      final decoded =
          jsonDecode(osmReportsGeoJson([report()])) as Map<String, Object?>;
      final features = decoded['features']! as List<Object?>;
      final feature = features.single! as Map<String, Object?>;
      final geom = feature['geometry']! as Map<String, Object?>;
      expect(geom['coordinates'], [11.5, 48.1]);
    });

    test('carries the element identity as properties, for JOSM', () {
      // The whole point of the file: somebody with an account opens it as a
      // to-do layer and works through it with their own tools, so the identity
      // has to be readable without parsing the prose.
      final props = _props(osmReportsGeoJson([report()]));
      expect(props['osm_type'], 'node');
      expect(props['osm_id'], 7);
      expect(props['osm_url'], 'https://www.openstreetmap.org/node/7');
      expect(props['text'], 'Not there any more.');
      expect(props['sent'], false);
    });

    test('a sent report links to its note', () {
      final props = _props(
        osmReportsGeoJson([
          report(sentAt: DateTime.utc(2026, 3, 12, 10), noteId: 4812345),
        ]),
      );
      expect(props['sent'], true);
      expect(props['note_url'], 'https://www.openstreetmap.org/note/4812345');
    });

    test(
      'a report with no element omits the identity rather than faking it',
      () {
        final props = _props(
          osmReportsGeoJson([report(osmType: null, osmId: null)]),
        );
        expect(props.containsKey('osm_id'), isFalse);
        expect(props.containsKey('osm_url'), isFalse);
        // And a placeholder id is not an identity either.
        final zero = _props(osmReportsGeoJson([report(osmId: 0)]));
        expect(zero.containsKey('osm_id'), isFalse);
      },
    );

    test('an empty outbox is still a valid FeatureCollection', () {
      final decoded =
          jsonDecode(osmReportsGeoJson(const [])) as Map<String, Object?>;
      expect(decoded['type'], 'FeatureCollection');
      expect(decoded['features'], isEmpty);
    });
  });

  test('the caps are osm.org\'s own numbers', () {
    // Its web form warns after five anonymous notes and hides itself after
    // ten. Mirroring them is deliberate: an app that let one person pour fifty
    // anonymous notes in would earn the block on its User-Agent that the API
    // usage policy promises, and take every other install's imports with it.
    expect(kOsmReportsSoftCapPerDay, 5);
    expect(kOsmReportsHardCapPerDay, 10);
    expect(kOsmReportsSoftCapPerDay, lessThan(kOsmReportsHardCapPerDay));
  });
}

Map<String, Object?> _props(String geoJson) {
  final decoded = jsonDecode(geoJson) as Map<String, Object?>;
  final features = decoded['features']! as List<Object?>;
  final feature = features.single! as Map<String, Object?>;
  return feature['properties']! as Map<String, Object?>;
}
