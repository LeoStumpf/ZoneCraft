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
      expect(TileSource.current.isCommunityOsm, isTrue);
      expect(TileSource.current.urlTemplate,
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    });

    test('does NOT permit pre-emptive fetching', () {
      // If this fails, the app is bulk-downloading from OSM's donated
      // infrastructure. That is a policy breach, not a tuning regression.
      expect(TileSource.current.allowsPrefetch, isFalse);
    });

    test('attributes OpenStreetMap', () {
      expect(TileSource.current.attribution, contains('OpenStreetMap'));
    });
  });

  group('a configured provider', () {
    // The override path can't be exercised through `TileSource.current` (it is
    // fixed at compile time), so check the invariant on the type itself:
    // prefetch travels with the source, and is never assumed.
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

  test('the User-Agent identifies the app, as the policy requires', () {
    // "Send a valid HTTP User-Agent that clearly identifies your application"
    // — not a library default, not another app's.
    expect(tileUserAgent, startsWith('ZoneCraft/'));
    expect(tileUserAgent, contains('github.com'));
  });
}
