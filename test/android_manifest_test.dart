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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Guards the intent filters the way `tile_source_test` guards prefetching:
/// the thing being protected is a policy decision, not a computation, and the
/// way it breaks is someone tidying the XML.
void main() {
  final manifest = XmlDocument.parse(
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
  );
  final filters = manifest.findAllElements('intent-filter').toList();

  List<XmlElement> withAction(String action) => filters
      .where(
        (f) => f
            .findElements('action')
            .any((a) => a.getAttribute('android:name') == action),
      )
      .toList();

  Set<String> mimeTypes(XmlElement f) => f
      .findElements('data')
      .map((d) => d.getAttribute('android:mimeType'))
      .whereType<String>()
      .toSet();

  // The reason the new filters are separate <intent-filter> elements: <data>
  // cross-products within its own filter, so a mimeType added here would turn
  // this scheme-only match into a scheme×mime product and shared positions
  // would stop opening — silently, and only on a real device.
  test('the zonecraft:// filter stays scheme-only', () {
    final deepLinks = withAction('android.intent.action.VIEW').where(
      (f) => f
          .findElements('data')
          .any((d) => d.getAttribute('android:scheme') == 'zonecraft'),
    );
    expect(deepLinks, hasLength(1));
    expect(mimeTypes(deepLinks.single), isEmpty);
  });

  // ACTION_SEND resolves on MIME alone, and Android's extension map has no
  // entry for .geojson — so our own exports are shared as octet-stream, and
  // without this ZoneCraft cannot receive the file ZoneCraft just wrote.
  test('the share target accepts what our own exports are labelled', () {
    final send = withAction('android.intent.action.SEND');
    expect(send, hasLength(1));
    expect(
      mimeTypes(send.single),
      containsAll(<String>{
        'application/geo+json',
        'application/vnd.google-earth.kml+xml',
        'application/gpx+xml',
        'application/octet-stream',
      }),
    );
  });

  // text/plain is the "share this text" intent every browser and messenger
  // fires; */* is every photo on the phone. Either would put ZoneCraft in
  // share sheets it has no business being in.
  test('no filter claims text/plain or */*', () {
    for (final f in filters) {
      expect(mimeTypes(f), isNot(contains('text/plain')));
      expect(mimeTypes(f), isNot(contains('*/*')));
    }
  });
}
