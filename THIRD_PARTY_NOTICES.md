# Third-party notices

ZoneCraft's own code is released under the Beer-Ware License (see [`LICENSE`](LICENSE)). The
app builds on third-party open-source packages and uses OpenStreetMap data and tiles whose
copyright/license notices must be retained. This file collects those attributions.

Flutter automatically aggregates the **full license text of every bundled package** into the
app's in-app licenses page (via `LicenseRegistry` / `showLicensePage`), so end users can view
them directly. The version-exact list of all packages (direct and transitive) is in
[`pubspec.lock`](pubspec.lock).

## Bundled packages

All dependencies are permissive. The direct runtime dependencies:

| Package | License |
|---|---|
| `flutter`, `flutter_map`, `flutter_map_dragmarker`, `http`, `share_plus`, `path_provider`, `file_selector` | BSD-3-Clause |
| `latlong2` | Apache-2.0 |
| `drift`, `drift_flutter`, `flutter_riverpod`, `uuid`, `flutter_colorpicker`, `geolocator`, `sqlite3_flutter_libs`, `cupertino_icons`, `sentry_flutter`, `xml`, `archive`, `image` | MIT |

Build/dev-only tools (`build_runner`, `drift_dev`, `flutter_lints`, `flutter_launcher_icons`,
`flutter_native_splash`) and all transitive dependencies are likewise permissive — MIT,
BSD-3-Clause or Apache-2.0, plus three MPL-2.0 packages (`dbus`, `gsettings`, `geoclue`) that
are Linux-desktop-only and not shipped in the Android/iOS app. `sqlite3_flutter_libs` bundles
SQLite, which is public domain.

## Map data, tiles & services

Attribution for these is also shown in-app (the attribution control on the map):

- **OpenStreetMap** — base map tiles © OpenStreetMap contributors; map data licensed under the
  [Open Database License (ODbL)](https://www.openstreetmap.org/copyright). The public
  `tile.openstreetmap.org` server is used under the
  [tile usage policy](https://operations.osmfoundation.org/policies/tiles/). That policy
  defines bulk downloading as "any pre-emptive fetching of tiles other than those a user is
  actively viewing" and states that "offline use is not permitted on
  `tile.openstreetmap.org`". The app therefore fetches **only the tiles being viewed** when
  using this server: the viewport prefetch and the "Download this area" button are compiled
  out unless the build is pointed at a different tile provider
  (`--dart-define=TILE_URL=...`). Caching already-displayed tiles, which the policy requires,
  is always on.
- **Overpass API** — queried once per import for points of interest, public-transport stations
  and administrative areas; returns OpenStreetMap data (ODbL), used under its fair-use policy.
  Requests are user-initiated only (never on a timer or on map movement), size-capped, paced to
  at most one per second, and spread across three community instances
  ([overpass-api.de](https://overpass-api.de/), `overpass.kumi.systems`,
  `overpass.private.coffee`).
- **Nominatim** ([nominatim.openstreetmap.org](https://nominatim.openstreetmap.org/)) —
  geocoding for "import a feature by name"; returns OpenStreetMap data (ODbL), used under its
  [usage policy](https://operations.osmfoundation.org/policies/nominatim/). That policy sets an
  absolute ceiling of one request per second and requires results to be cached client-side; the
  app enforces both, and deliberately implements **no** autocomplete — a search happens only
  when you submit one, never per keystroke, which the policy forbids.
- **AWS Terrain Tiles** (`s3.amazonaws.com/elevation-tiles-prod`) — elevation data for height
  layers and the elevation probe. Public dataset on the
  [AWS Open Data registry](https://registry.opendata.aws/terrain-tiles/), aggregated from
  sources with their own attribution requirements (SRTM, NED, and others — see the
  [dataset's attribution list](https://github.com/tilezen/joerd/blob/master/docs/attribution.md)).
