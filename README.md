# ZoneCraft

ZoneCraft turns a map into a canvas for **zones** — coloured regions defined by simple
geometric rules (circles, "closer to here than there", hand-drawn borders and areas) that you
stack into **layers** on top of OpenStreetMap. It runs fully offline of any account: there is
**no login and no server** — every layer, object and setting lives in a local SQLite database
on the device.

Android-first, iOS-ready. Built with Flutter.

> **Transparency:** ZoneCraft was "vibe-coded" collaboratively with Claude (Anthropic's AI
> assistant), which wrote much of the code under human direction.

## What you can build

Each **layer** holds one kind of object and paints a single flat-coloured region (overlapping
objects in a layer never darken each other). Layers stack, and a per-layer **invert** fills
everything *outside* the region instead. There are five object types:

| Type | What it draws |
|---|---|
| **Circle** | A true **geodesic** circle — radius in real-world metres, accurate on the globe (so it looks like an ellipse at high latitudes in Web Mercator, as it should). |
| **Plane** | The "**closer to one of two points**" region — one side of two points' perpendicular bisector, with a toggle for which side. |
| **Subspace** | The "**closest of N points**" region — a Voronoi cell: everywhere closer to a chosen *main* point than to any of the others. |
| **Freehand line** | A polyline **you draw** that splits the view into two sides; the layer fills one (invert flips it). Partial lines are completed by extending the end segments straight. |
| **Freehand area** | A closed polygon **you draw**; the layer fills the inside (invert fills the outside). |

Every object also carries a measurement **uncertainty band** — a lighter strip hugging its
boundary, set globally in Settings. The two freehand types additionally have a signed
**offset** (metres): positive pushes the coloured boundary away from the line / inward from the
area (e.g. *"inside the city **and** more than 5 km from its border"*), negative extends the
fill past the drawn boundary.

## Features

**Map & layers**
- Full-bleed OpenStreetMap base map (live tiles, no API key); a single floating menu button
  (top-left) opens the layers drawer.
- Layers drawer: show/hide, reorder, rename, recolour, **invert**, add, delete. The active
  layer receives new objects; each layer is single-type, chosen when you add it.
- A **compass** button that always points to map-north; tap it to snap back to north-up.

**Editing**
- Tap an object to open a **docked editor** that writes changes live while the map stays
  interactive; the object's points show as draggable-by-tap markers.
- Coordinates use one **"lat, lng"** field that accepts values pasted straight from Google
  Maps. Multi-point objects (subspace, freehand) support add / move-by-tap / delete per point.

**Optional map overlays** (toggled in Settings)
- **Public transport** — transparent ÖPNVKarte (buses/trams/stops) + OpenRailwayMap (rail)
  tile overlays.
- **Public transport** — pick an area (tap two corners) and import every OSM route in it —
  bus, tram, subway, train, ferry — with its stops. Stored offline and drawn in each line's
  own OSM colour; a per-layer **Lines** menu switches whole modes or individual lines on and
  off. (Separate from the ÖPNVKarte/OpenRailwayMap *tile* overlay in Settings.)
- **Points of interest** — OSMAnd-style OSM POI categories (benches, post boxes, drinking
  water, toilets, cafés, …) fetched from Overpass and shown as markers, only at high zoom.
- **Administrative borders** — OSM `admin_level` boundaries (countries → … → suburbs), each a
  toggle with its own colour, fetched from Overpass and drawn as polylines with per-level zoom
  gating.

**Offline & data**
- **Offline-resilient map** — tiles you view (plus a ring around them) are cached on the
  device, so revisited areas don't re-download and the map keeps working for a few minutes
  with no reception (subway, underground). The last POI/border overlays are persisted too, so
  they reappear instantly on launch. A Settings readout shows the cache size, with a **"Clear
  cached map tiles"** button (separate from "Clear all data").
- Global measurement **uncertainty** radius (default 500 m) and a **"Clear all data"** action.
- Opt-in **"Locate me"** — location permission is requested only when you tap it, never at
  launch; nothing runs in the background.
- Fully local persistence via SQLite (Drift). Your data **and** your last map view (centre +
  zoom) survive restarts.

## How rendering works

All region geometry is computed per frame in **screen space** at the current camera (project
points → bisect / clip / offset → fill). For each layer the engine builds two polygons per
object — an `outer` and a shrunk `core` — unions them across the layer with `dart:ui`
`Path.combine`, then paints the **core** solid, the **band** (`outer − core`) lighter, and the
outline as a stroke. **Invert** simply paints `viewport − outer` instead. This single
`outer`/`core` contract is shared by all five object types, so invert and the uncertainty band
work uniformly. The approximation is planar (accurate at city scale); geodesic refinement is a
possible follow-up.

## Tech stack

| Concern | Package |
|---|---|
| Framework | Flutter (Android-first, iOS-ready) |
| Map | [`flutter_map`](https://pub.dev/packages/flutter_map) |
| Geo math | [`latlong2`](https://pub.dev/packages/latlong2) |
| Local DB | [`drift`](https://pub.dev/packages/drift) + `drift_flutter` / `sqlite3_flutter_libs` |
| State | [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) |
| Overlays | [`http`](https://pub.dev/packages/http) (Overpass API: POIs, transit, borders) |
| Location | [`geolocator`](https://pub.dev/packages/geolocator) (opt-in) |
| Colour picker | [`flutter_colorpicker`](https://pub.dev/packages/flutter_colorpicker) |
| Icon / splash | `flutter_launcher_icons`, `flutter_native_splash` (dev) |

## Project layout

```
lib/
  data/   Drift schema + repository (Layers, Circles, Planes, Subspaces+points,
          FreeLines+points, FreeAreas+points, TileCache, OverpassCache, AppSettings);
          Overpass clients for POIs (overpass.dart), public transport
          (transit.dart) and admin borders (borders.dart);
          offline tile cache (cached_tile_provider.dart)
  geo/    region geometry — geodesic.dart, plane.dart, subspace.dart,
          freeline.dart, freearea.dart — slippy-tile maths (tiles.dart),
          plus lat/lng parsing (coords.dart)
  state/  Riverpod providers (per-object lists, settings, selection/placement)
  ui/     map_screen, layers_panel (drawer), one *_editor.dart per object type,
          settings_screen, region_layer (the compositing engine)
assets/icon/   app-icon source art (transparent PNG + adaptive foreground)
scripts/       build.sh — analyze / test / build / install / run helper
test/          geometry, parsing, Overpass and database unit tests
```

## Develop

### Build script (recommended)

`scripts/build.sh` runs the checks and builds the APK in one step (it puts `flutter` on
`PATH` itself, so it works even when the SDK isn't installed globally):

```bash
./scripts/build.sh                 # flutter analyze + test, then build a debug APK
./scripts/build.sh --install       # also install on the connected Android device (-r, keeps data)
./scripts/build.sh --install --run # install, then launch the app
./scripts/build.sh --release       # build a release APK instead of debug
./scripts/build.sh --skip-checks   # skip analyze/test (faster rebuilds)
DEVICE=<adb-serial> ./scripts/build.sh --install   # target a specific device
```

### Manual commands

```bash
flutter pub get
dart run build_runner build      # regenerate database.g.dart after schema changes
flutter analyze
flutter test
flutter run                      # on a connected Android device
flutter build apk --debug        # build an installable APK
```

The local database is **schema v18**; installing with `-r` (as the build script does) preserves
existing data and exercises the migrations.

## Roadmap

[`PLAN.md`](PLAN.md) is the roadmap (current state + open points) and
[`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) is the architecture reference. Open points:
**import/export** (GeoJSON / KML), **geodesic refinement** of the planar geometry, and an
explicit **"download this area"** button for guaranteed offline coverage.

## License

ZoneCraft is released under the **Beer-Ware License (Revision 42)** — see [`LICENSE`](LICENSE).
Do whatever you want with the code; if we meet some day and you think it's worth it, buy me a
beer. 🍺

It builds on open-source packages and OpenStreetMap data whose attribution must be retained —
see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) (their full license texts are also
viewable on the app's in-app licenses page).
