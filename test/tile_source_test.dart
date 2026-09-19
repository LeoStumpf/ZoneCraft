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
import 'package:zonecraft/data/tile_source.dart';

/// Pins the one rule in `tile_source.dart` that is a legal constraint rather
/// than a preference: **the community OpenStreetMap tile servers never get
/// pre-emptive fetching.**
///
/// Their policy defines bulk downloading as "any pre-emptive fetching of tiles
/// other than those a user is actively viewing", and says outright that
/// "offline use is not permitted on `tile.openstreetmap.org`". The viewport
/// prefetch ring and the "download this area" button are both exactly that, so
/// they hang off [TileSource.allowsPrefetch] — and the default build must have
/// it off. This test exists because that flag is a one-character change away
/// from putting the app back in breach, with nothing else to notice.
///
/// These tests run against the **default** build (no `--dart-define=TILE_URL`),
/// which is the configuration that ships unless someone deliberately points the
/// app elsewhere.
void main() {
  group('the shipped default', () {
    test('is the community OSM server', () {
      expect(TileSource.configured.isCommunityOsm, isTrue);
      expect(TileSource.configured.urlTemplate,
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    });

    test('does NOT permit pre-emptive fetching', () {
      // If this fails, the app is bulk-downloading from OSM's donated
      // infrastructure. That is a policy breach, not a tuning regression.
      expect(TileSource.configured.allowsPrefetch, isFalse);
    });

    test('attributes OpenStreetMap', () {
      expect(TileSource.configured.attribution, contains('OpenStreetMap'));
    });
  });

  group('a configured provider', () {
    // The override path can't be exercised through `TileSource.configured` (it
    // is fixed at compile time), so check the invariant on the type itself:
    // prefetch travels with the source, and is never assumed. Note that
    // redirecting the tiles is NOT what turns it on — that needs a second
    // define, because MapTiler and Thunderforest forbid pre-downloading just as
    // OSM does.
    test('is what turns prefetching on — it is never the default', () {
      const configured = TileSource(
        urlTemplate: 'https://example.test/{z}/{x}/{y}.png',
        attribution: '© Example',
        allowsPrefetch: true,
      );
      expect(configured.isCommunityOsm, isFalse);
      expect(configured.allowsPrefetch, isTrue);
    });

    test('a non-OSM host is still not automatically allowed', () {
      // Being off tile.openstreetmap.org is necessary but not sufficient —
      // some other community server would have its own terms. The flag is set
      // by whoever configured the build, not inferred from the URL.
      const unknown = TileSource(
        urlTemplate: 'https://tiles.example.test/{z}/{x}/{y}.png',
        attribution: '© Example',
        allowsPrefetch: false,
      );
      expect(unknown.isCommunityOsm, isFalse);
      expect(unknown.allowsPrefetch, isFalse);
    });
  });

  group('fillTileUrl', () {
    test('substitutes z/x/y', () {
      expect(
        fillTileUrl('https://t.test/{z}/{x}/{y}.png', 13, 4402, 2830),
        'https://t.test/13/4402/2830.png',
      );
    });

    test('leaves a keyed query string intact', () {
      expect(
        fillTileUrl('https://t.test/{z}/{x}/{y}.png?key=abc', 1, 2, 3),
        'https://t.test/1/2/3.png?key=abc',
      );
    });
  });

  group('a runtime override', () {
    // A settings field can say *where* the tiles come from. It cannot say what
    // the app may do with them: that is a claim about somebody's terms, and
    // nobody read any terms to type a URL into a text box.
    test('changes the URL', () {
      final t = TileSource.resolve('https://mine.test/{z}/{x}/{y}.png');
      expect(t.urlTemplate, 'https://mine.test/{z}/{x}/{y}.png');
      expect(t.isCommunityOsm, isFalse);
    });

    test('never enables pre-emptive fetching', () {
      expect(
        TileSource.resolve('https://mine.test/{z}/{x}/{y}.png').allowsPrefetch,
        isFalse,
      );
    });

    test('keeps the attribution — the credit must not go missing', () {
      expect(
        TileSource.resolve('https://mine.test/{z}/{x}/{y}.png').attribution,
        TileSource.configured.attribution,
      );
    });

    test('empty or blank means the configured source, not a blank map', () {
      expect(TileSource.resolve(null), same(TileSource.configured));
      expect(TileSource.resolve(''), same(TileSource.configured));
      expect(TileSource.resolve('   '), same(TileSource.configured));
    });
  });
}
