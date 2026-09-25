# Building

## Prerequisites

- **Flutter 3.44.0** (stable) — the version CI pins; Dart SDK ≥ 3.12 per `pubspec.yaml`.
- **JDK 21** and the Android SDK with build-tools (for `apksigner`). The Gradle/AGP versions
  are pinned in `android/`.
- An Android device with USB debugging, or an emulator. There is no iOS build set up yet,
  though the project is iOS-ready.

If `flutter` is not on your `PATH`, `scripts/build.sh` puts it there itself
(it looks in `~/development/flutter/bin`, the path in the script — edit `FLUTTER_BIN` there if yours differs); for manual commands, export it.

## The build script

`scripts/build.sh` is the one way the project is built, on the laptop and in CI, so the
dart-defines cannot drift between the two.

```sh
scripts/build.sh                     # analyze + test, then build a debug APK
scripts/build.sh --install           # also install on the connected device (-r: keeps data)
scripts/build.sh --install --run     # install, then launch the app
scripts/build.sh --release           # build a release APK instead of debug
scripts/build.sh --bundle            # build a release App Bundle (.aab) for Play
scripts/build.sh --skip-checks       # skip format/analyze/test (fast rebuilds)
DEVICE=<adb-serial> scripts/build.sh --install    # target a specific device
```

Installing with `-r` keeps the app's data, so every install exercises the database
migrations on a real map.

### Environment variables

| Variable | Meaning |
|---|---|
| `DEVICE` | adb serial to install on. |
| `ZONECRAFT_ENV` | A file of release settings sourced first (default `~/.config/zonecraft/release.env`). It lives outside the repo because `TILE_URL` carries an API key. Anything already exported wins over the file. |
| `TILE_URL` | Base-map tile URL template, e.g. `https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=KEY`. Unset = OpenStreetMap's community servers. |
| `TILE_ATTRIBUTION` | The attribution line shown for it, verbatim (it must carry its own `©`). |
| `TILE_ALLOWS_PREFETCH=true` | **Re-enables** the viewport prefetch and the *Download this area* button. Off by default because OpenStreetMap's tile policy forbids them on the community servers — and so do MapTiler and Thunderforest on their cheaper plans. Set it only when the provider you pointed `TILE_URL` at says in writing that you may; the script refuses it without a `TILE_URL`. |
| `OSM_API_URL` | Where *Publish to OpenStreetMap* sends notes. Unset = the real database. **Use `https://master.apis.dev.openstreetmap.org` to test** — a note filed against the live database to see whether a button works is one a volunteer has to close by hand. |

The key belongs in `TILE_URL` in your environment, never in the repo. Leave all three tile
variables unset for a policy-compliant build against `tile.openstreetmap.org`.

## Manual commands

```sh
export PATH="$PATH:$HOME/development/flutter/bin"
flutter pub get --enforce-lockfile   # what CI runs: the lockfile is an assertion
dart run build_runner build          # regenerate database.g.dart after a schema change
dart format lib test
flutter analyze
flutter test
flutter run                          # on a connected device
```

## Tests

`flutter test` runs the whole suite (unit tests over geometry, parsing, serialization,
migrations against a real SQLite database, the export round-trip, and a set of *guard* tests
that read source files and fail when an invariant drifts — licence headers, the app id in
its five places, the User-Agent, the manifest's intent filters, the tile-source policy). The
[Contributing](Contributing.md) page lists the ones a change is most likely to trip.

## Verifying on a device

A debug build installed with `--install --run` is the normal loop. A **release** build is
signed with a different key and Android will not install it over the debug one; uninstalling
takes the map with it (there is no backup), so test release builds on an emulator or a second
device. See [Continuous Integration and Releases](Continuous-Integration-and-Releases.md) for the bundletool recipe.

## Screenshots

`scripts/screenshots.sh` builds a seeded map (`tool/make_screenshot_seed.dart`) and drives
emulators of the Play Store's phone and tablet sizes, creating the AVDs it needs with
`avdmanager`.
