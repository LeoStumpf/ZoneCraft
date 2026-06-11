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
| `flutter`, `flutter_map`, `http` | BSD-3-Clause |
| `latlong2` | Apache-2.0 |
| `drift`, `drift_flutter`, `flutter_riverpod`, `uuid`, `flutter_colorpicker`, `geolocator`, `sqlite3_flutter_libs`, `cupertino_icons` | MIT |

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
  [tile usage policy](https://operations.osmfoundation.org/policies/tiles/) (fair use; not for
  heavy traffic).
- **ÖPNVKarte** ([memomaps.de](https://memomaps.de/)) — optional public-transport tile overlay.
- **OpenRailwayMap** — optional rail tile overlay, licensed CC-BY-SA 2.0.
- **Overpass API** ([overpass-api.de](https://overpass-api.de/)) — queried for POIs and
  administrative borders; returns OpenStreetMap data (ODbL), used under its fair-use policy
  (requests are debounced and zoom-gated in the app).
