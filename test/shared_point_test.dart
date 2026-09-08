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
import 'package:zonecraft/data/shared_point.dart';

void main() {
  SharedPoint p(double lat, double lng, [String? n]) =>
      SharedPoint.named(lat, lng, n)!;

  group('SharedPoint.named', () {
    test('normalises an empty or whitespace-only name to null', () {
      expect(p(48.1, 11.5, '').name, isNull);
      expect(p(48.1, 11.5, '   ').name, isNull);
      expect(p(48.1, 11.5, '  Nordbad  ').name, 'Nordbad');
    });

    test('rejects non-finite and out-of-range coordinates', () {
      // The receiving end is a pasted chat message, so garbage arrives; a
      // NaN centre would put the camera somewhere unrecoverable.
      expect(SharedPoint.named(double.nan, 11.5), isNull);
      expect(SharedPoint.named(48.1, double.infinity), isNull);
      expect(SharedPoint.named(91, 11.5), isNull);
      expect(SharedPoint.named(-91, 11.5), isNull);
      expect(SharedPoint.named(48.1, 181), isNull);
      expect(SharedPoint.named(48.1, -181), isNull);
      // The edges themselves are valid.
      expect(SharedPoint.named(90, 180), isNotNull);
      expect(SharedPoint.named(-90, -180), isNotNull);
    });
  });

  group('encode → decode round-trips', () {
    test('a plain coordinate', () {
      final back = decodeSharedPointLink(encodeSharedPointLink(p(48.169123, 11.56789)))!;
      expect(back.lat, closeTo(48.169123, 1e-9));
      expect(back.lng, closeTo(11.567890, 1e-9));
      expect(back.name, isNull);
    });

    test('a name with separators, spaces and emoji survives encoding', () {
      // Built with Uri, so an unescaped `&` cannot truncate the query at the
      // next parameter and silently drop the longitude.
      const awkward = 'Bar & Grill 🍺 / "Zum Stiftl"';
      final back =
          decodeSharedPointLink(encodeSharedPointLink(p(48.1, 11.5, awkward)))!;
      expect(back.name, awkward);
      expect(back.lat, closeTo(48.1, 1e-9));
      expect(back.lng, closeTo(11.5, 1e-9));
    });

    test('a negative and a southern-hemisphere coordinate', () {
      final back =
          decodeSharedPointLink(encodeSharedPointLink(p(-33.8688, 151.2093)))!;
      expect(back.lat, closeTo(-33.8688, 1e-6));
      expect(back.lng, closeTo(151.2093, 1e-6));
    });
  });

  group('decode accepts what a chat message actually carries', () {
    test('a bare "lat, lng" pair, as copied from Google Maps', () {
      final r = decodeSharedPointLink('48.137154, 11.575382')!;
      expect(r.lat, closeTo(48.137154, 1e-9));
      expect(r.lng, closeTo(11.575382, 1e-9));
    });

    test('a German comma-decimal pair', () {
      final r = decodeSharedPointLink('48,137154 11,575382')!;
      expect(r.lat, closeTo(48.137154, 1e-9));
      expect(r.lng, closeTo(11.575382, 1e-9));
    });

    test('a geo: URI, with and without a labelled q', () {
      final plain = decodeSharedPointLink('geo:48.137,11.575')!;
      expect(plain.lat, closeTo(48.137, 1e-9));
      expect(plain.name, isNull);

      final labelled =
          decodeSharedPointLink('geo:0,0?q=48.137,11.575(Marienplatz)')!;
      expect(labelled.lat, closeTo(48.137, 1e-9));
      expect(labelled.lng, closeTo(11.575, 1e-9));
      expect(labelled.name, 'Marienplatz');
    });

    test('an OpenStreetMap marker link — our own fallback line', () {
      final r = decodeSharedPointLink(osmMarkerLink(p(48.137, 11.575)))!;
      expect(r.lat, closeTo(48.137, 1e-6));
      expect(r.lng, closeTo(11.575, 1e-6));
    });

    test('a whole pasted WhatsApp message, words and all', () {
      // The reason the scan exists: nobody trims the message by hand.
      const msg = 'hey, meet me here! Nordbad — 48.169123, 11.567890\n'
          'see you at 7';
      final r = decodeSharedPointLink(msg)!;
      expect(r.lat, closeTo(48.169123, 1e-9));
      expect(r.lng, closeTo(11.567890, 1e-9));
    });

    test('our own three-line share message, whole', () {
      final msg = shareMessage(p(48.169123, 11.56789, 'Nordbad'));
      final r = decodeSharedPointLink(msg)!;
      expect(r.lat, closeTo(48.169123, 1e-6));
      expect(r.lng, closeTo(11.567890, 1e-6));
      // The link line carries the name; the bare coordinate line does not, so
      // whichever the scan reaches first must still be the named one.
      expect(r.name, 'Nordbad');
    });

    test('rejects text with no coordinate in it', () {
      expect(decodeSharedPointLink(''), isNull);
      expect(decodeSharedPointLink('   '), isNull);
      expect(decodeSharedPointLink('see you at 7'), isNull);
      expect(decodeSharedPointLink('https://example.com/nothing'), isNull);
      expect(decodeSharedPointLink('zonecraft://q?lat=48.1&lng=11.5'), isNull);
    });

    test('rejects an out-of-range coordinate inside a well-formed link', () {
      expect(
        decodeSharedPointLink('zonecraft://p?lat=99.0&lng=11.5'),
        isNull,
      );
    });
  });

  // ZoneCraft now offers itself for every geo: and openstreetmap.org link, so
  // what it can and cannot read out of one stopped being an internal detail:
  // a shape it silently fails on opens the app to a map that did not move.
  group('map links from other apps', () {
    test('an osm.org address-bar link, whose position is in the fragment', () {
      final p = decodeSharedPointLink(
          'https://www.openstreetmap.org/#map=17/48.13700/11.57500')!;
      expect(p.latLng.latitude, closeTo(48.137, 1e-6));
      expect(p.latLng.longitude, closeTo(11.575, 1e-6));
    });

    test('the fragment can carry more than the position', () {
      final p = decodeSharedPointLink(
          'https://www.openstreetmap.org/#map=12/-33.8688/151.2093&layers=N')!;
      expect(p.latLng.latitude, closeTo(-33.8688, 1e-6));
      expect(p.latLng.longitude, closeTo(151.2093, 1e-6));
    });

    // The marker form still wins where both could apply — it names a *point*,
    // while the fragment only names where the map was looking.
    test('mlat/mlon is preferred over the fragment', () {
      final p = decodeSharedPointLink(
          'https://www.openstreetmap.org/?mlat=1.5&mlon=2.5#map=17/9/9')!;
      expect(p.latLng.latitude, closeTo(1.5, 1e-9));
      expect(p.latLng.longitude, closeTo(2.5, 1e-9));
    });

    // A link with no position in it must decode to null rather than to
    // something plausible — the caller turns null into a message, and a wrong
    // position would be worse than no position.
    test('links with no readable position decode to null', () {
      expect(decodeSharedPointLink('https://www.openstreetmap.org/node/240109189'),
          isNull);
      expect(decodeSharedPointLink('https://www.openstreetmap.org/'), isNull);
      expect(decodeSharedPointLink('https://www.openstreetmap.org/#map='), isNull);
    });

    test('a geo: URI with an uncertainty suffix', () {
      final p = decodeSharedPointLink('geo:48.137,11.575;u=35')!;
      expect(p.latLng.latitude, closeTo(48.137, 1e-6));
      expect(p.latLng.longitude, closeTo(11.575, 1e-6));
    });
  });

  group('shareMessage', () {
    test('leads with the name when there is one, the coordinate when not', () {
      expect(
        shareMessage(p(48.169123, 11.56789, 'Nordbad')).split('\n').first,
        'Nordbad — 48.169123, 11.567890',
      );
      expect(
        shareMessage(p(48.169123, 11.56789)).split('\n').first,
        '48.169123, 11.567890',
      );
    });

    test('carries all three lines, each independently decodable', () {
      final lines = shareMessage(p(48.169123, 11.56789, 'Nordbad')).split('\n');
      expect(lines.length, 3);
      for (final line in lines) {
        expect(
          decodeSharedPointLink(line),
          isNotNull,
          reason: 'a message that survives only partially still has to work: '
              '"$line" did not decode',
        );
      }
    });
  });
}
