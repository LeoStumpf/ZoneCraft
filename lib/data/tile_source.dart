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
/// the tiles come from somewhere that permits it** — and "somewhere else" is
/// not the same claim as "somewhere that permits it". Leaving the community
/// server is necessary; it is nowhere near sufficient. The commercial providers
/// this app documents forbid the very same thing:
///
/// > Absolutely no bulk-downloading, scraping, pre-downloading, pre-caching or
/// > anything similar — Thunderforest, below its Small Business plan
///
/// > It is prohibited to batch or excessive bulk download of map tiles
/// > — MapTiler Cloud, on every plan
///
/// Both allow a per-user on-device cache of what was actually displayed, which
/// is exactly the shape of the OSM rule. So `TILE_URL` alone must **not** turn
/// the offline features on: prefetching is its own define, set by someone who
/// has read that provider's terms and found permission there.
///
/// Configure at build time:
///
/// ```sh
/// flutter build apk \
///   --dart-define=TILE_URL='https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=YOURKEY' \
///   --dart-define=TILE_ATTRIBUTION='© MapTiler © OpenStreetMap contributors' \
///   --dart-define=TILE_ALLOWS_PREFETCH=true   # only if their terms say so
/// ```
///
/// (`scripts/build.sh` forwards all three from the environment, so exporting
/// them is enough. The key belongs in the environment, never in the repo.)
library;

import '../app_info.dart';

/// Build-time tile URL template. Empty = the default community OSM server.
const String _tileUrlOverride = String.fromEnvironment('TILE_URL');

/// Build-time attribution line for [_tileUrlOverride].
const String _tileAttributionOverride = String.fromEnvironment(
  'TILE_ATTRIBUTION',
);

/// Build-time opt-in to pre-emptive fetching, deliberately separate from
/// [_tileUrlOverride]: see the library doc. Defaults to false, so a build that
/// only redirects the tiles stays as conservative as the stock one.
const bool _tileAllowsPrefetch = bool.fromEnvironment('TILE_ALLOWS_PREFETCH');

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
  /// library doc. It is true only when a build both pointed the app somewhere
  /// else *and* asserted, via `TILE_ALLOWS_PREFETCH`, that the provider's terms
  /// permit it — two separate statements, because being off
  /// `tile.openstreetmap.org` says nothing about the second.
  final bool allowsPrefetch;

  /// True when this is the stock community server (nothing was configured).
  bool get isCommunityOsm => urlTemplate == _osmUrl;

  static const String _osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _osmAttribution = '© OpenStreetMap contributors';

  /// What this build ships with, resolved from the build-time defines.
  /// Compared against `''` rather than using `.isEmpty`, which is not a const
  /// expression.
  static const TileSource configured = _tileUrlOverride == ''
      ? TileSource(
          urlTemplate: _osmUrl,
          attribution: _osmAttribution,
          // Community server: no pre-emptive fetching, no offline downloads.
          allowsPrefetch: false,
        )
      : TileSource(
          urlTemplate: _tileUrlOverride,
          attribution: _tileAttributionOverride == ''
              ? _osmAttribution
              : _tileAttributionOverride,
          // Not implied by the redirect: a second, deliberate statement.
          allowsPrefetch: _tileAllowsPrefetch,
        );

  /// The source to draw with, given the user's stored [userUrlTemplate].
  ///
  /// A runtime override changes *where* the tiles come from and nothing else.
  /// [allowsPrefetch] is deliberately forced off: it is a claim that somebody
  /// read a provider's terms and found permission there, which a URL typed into
  /// a settings field cannot make on its own — and the failure mode of getting
  /// that wrong is bulk-downloading somebody else's server.
  static TileSource resolve(String? userUrlTemplate) {
    final url = userUrlTemplate?.trim();
    if (url == null || url.isEmpty) return configured;
    return TileSource(
      urlTemplate: url,
      // We do not know whose tiles these are, and the ODbL credit is the one
      // thing that must not go missing, so keep the configured line.
      attribution: configured.attribution,
      allowsPrefetch: false,
    );
  }
}

/// The descriptive `User-Agent` the policy requires:
///
/// > Send a valid HTTP User-Agent that clearly identifies your application.
/// > [Do not] masquerade as another app's User-Agent, or rely on a library's
/// > default User-Agent.
///
/// One string for every service (see [zoneCraftUserAgent]) — these are the
/// same operators, and four hand-maintained copies had already drifted a
/// version and a half behind the app.
const String tileUserAgent = zoneCraftUserAgent;

/// Substitutes `{z}`/`{x}`/`{y}` into a tile URL [template].
String fillTileUrl(String template, int z, int x, int y) => template
    .replaceAll('{z}', '$z')
    .replaceAll('{x}', '$x')
    .replaceAll('{y}', '$y');
