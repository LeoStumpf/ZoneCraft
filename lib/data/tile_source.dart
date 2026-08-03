/// Where base-map tiles come from, and what the app is allowed to do with them.
///
/// ZoneCraft's offline story — a viewport prefetch ring and a "download this
/// area" button — is **not permitted against OpenStreetMap's community tile
/// servers**. Their
/// [tile usage policy](https://operations.osmfoundation.org/policies/tiles/)
/// is explicit on both counts:
///
/// > Bulk downloading is any pre-emptive fetching of tiles other than those a
/// > user is actively viewing.
///
/// > Offline use is not permitted on `tile.openstreetmap.org`.
///
/// Note how wide the first sentence is. It is not a limit on *how many* tiles
/// you may fetch ahead — fetching *any* tile the user is not looking at is the
/// prohibited thing, so the one-tile ring around the viewport is bulk
/// downloading every bit as much as the 4 000-tile button was. There is no
/// "small enough" version of it. Caching what you *did* display is the
/// opposite case: the policy positively requires it.
///
/// So the rule this file encodes: **pre-emptive fetching is enabled only when
/// the tiles come from somewhere that permits it.** Point the app at a keyed
/// provider or your own server and the offline features switch back on;
/// leave it on the default community server and they stay off.
///
/// Configure at build time:
///
/// ```sh
/// flutter build apk \
///   --dart-define=TILE_URL='https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=YOURKEY' \
///   --dart-define=TILE_ATTRIBUTION='© MapTiler © OpenStreetMap contributors'
/// ```
///
/// (`scripts/build.sh` forwards `TILE_URL` / `TILE_ATTRIBUTION` from the
/// environment, so exporting them is enough.)
library;

/// Build-time tile URL template. Empty = the default community OSM server.
const String _tileUrlOverride = String.fromEnvironment('TILE_URL');

/// Build-time attribution line for [_tileUrlOverride].
const String _tileAttributionOverride =
    String.fromEnvironment('TILE_ATTRIBUTION');

/// The base-map tile source in force for this build.
class TileSource {
  const TileSource({
    required this.urlTemplate,
    required this.attribution,
    required this.allowsPrefetch,
  });

  /// `{z}/{x}/{y}` template passed to both the [TileLayer] and the prefetcher.
  final String urlTemplate;

  /// The line shown in the map's attribution control.
  final String attribution;

  /// Whether this source permits fetching tiles the user is not currently
  /// looking at — i.e. whether the viewport prefetch ring and the "download
  /// this area" button are available at all.
  ///
  /// False for the community OSM servers, and that is not a tuneable: see the
  /// library doc. It is true only because *you* pointed the app at a provider
  /// whose terms you have read.
  final bool allowsPrefetch;

  /// True when this is the stock community server (nothing was configured).
  bool get isCommunityOsm => urlTemplate == _osmUrl;

  static const String _osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _osmAttribution = '© OpenStreetMap contributors';

  /// Resolved once from the build-time defines. Compared against `''` rather
  /// than using `.isEmpty`, which is not a const expression.
  static const TileSource current = _tileUrlOverride == ''
      ? TileSource(
          urlTemplate: _osmUrl,
          attribution: _osmAttribution,
          // Community server: no pre-emptive fetching, no offline downloads.
          allowsPrefetch: false,
        )
      : TileSource(
          urlTemplate: _tileUrlOverride,
          attribution: _tileAttributionOverride == ''
              ? '© OpenStreetMap contributors'
              : _tileAttributionOverride,
          allowsPrefetch: true,
        );
}

/// A descriptive `User-Agent`, required by the policy:
///
/// > Send a valid HTTP User-Agent that clearly identifies your application.
/// > [Do not] masquerade as another app's User-Agent, or rely on a library's
/// > default User-Agent.
const String tileUserAgent =
    'ZoneCraft/1.0 (https://github.com/LeoStumpf/zonecraft)';

/// Substitutes `{z}`/`{x}`/`{y}` into a tile URL [template].
String fillTileUrl(String template, int z, int x, int y) => template
    .replaceAll('{z}', '$z')
    .replaceAll('{x}', '$x')
    .replaceAll('{y}', '$y');
