# ZoneCraft

ZoneCraft turns a map into a deduction board. You draw **zones** — coloured regions defined by
simple geometric rules — stack them as **layers** over OpenStreetMap, and watch the possible
area shrink to where it has to be. There is **no login and no server**: every layer, object and
setting lives in a local SQLite database on the device.

Android-first, iOS-ready. Built with Flutter.

> **Transparency:** ZoneCraft was "vibe-coded" collaboratively with Claude (Anthropic's AI
> assistant), which wrote much of the code under human direction.

## What you can build

Each **layer** holds one kind of object. The six *region* types paint a single flat-coloured
area — overlapping objects within a layer never darken each other — and a per-layer **invert**
fills everything *outside* the region instead. The three *import* types pull a snapshot of real
OpenStreetMap data and draw it directly.

### Region types

| Type | What it draws |
|---|---|
| **Circle** | A true **geodesic** circle — radius in real-world metres, accurate on the globe (so it looks like an ellipse at high latitudes in Web Mercator, as it should). |
| **Plane** | The "**closer to one of two points**" region — one side of two points' perpendicular bisector, with a toggle for which side. |
| **Subspace** | The "**closest of N points**" region — a Voronoi cell: everywhere closer to a chosen *main* point than to any of the others. |
| **Freehand line** | A polyline **you draw** that cuts an inclusion circle in two; the layer fills one half-disk, invert fills the other. |
| **Freehand area** | A closed polygon **you draw**; the layer fills the inside (invert fills the outside). |
| **Height** | Terrain **above or below an elevation**, bounded to a circle. Generated once from public terrain tiles by marching squares, then stored — so it renders cheaply and works offline afterwards. |

Every region carries a measurement **uncertainty band** — a lighter strip on the *coloured* side
of the boundary, so the fill only turns solid a band-width in. It is set globally in Settings.
The two freehand types additionally have a signed **offset** in metres: positive pushes the
boundary inward from the area / away from the line (*"inside the city **and** more than 5 km
from its border"*), negative extends the fill past what you drew.

### Import types

These fetch from Overpass **once**, on your explicit request, and store the result offline. They
never refetch and never poll.

| Type | What it imports |
|---|---|
| **Points of interest** | One OSM category (cafés, benches, drinking water, toilets…) within a radius. Drawn as icon markers that collapse into count badges when they would overlap. |
| **Transit** | Every public-transport **station** in a box you tap out, plus which types serve each one — bus, tram, subway, light rail, train, monorail, ferry. Per-layer tick boxes switch types on and off; a station stays visible while at least one ticked type stops there, so "Rail only" keeps the big interchanges. **Line geometry is deliberately never fetched** — it proved unobtainable from the public API at any useful scale. |
| **Borders** | Administrative areas of one OSM `admin_level`, chosen when the layer is created. Whole relations come down (a clipped boundary has no fillable interior) and are assembled on the device. **Nothing is cut to the box** — it limits the download, not the result — so an area may reach well past it. Optional neighbour-distinct colouring and name plates; any area can be **converted to a freehand area** you can then edit. |

## Features

**Map & layers**
- Full-bleed OpenStreetMap base map (no API key needed); one floating menu button opens the
  layers drawer.
- Layers drawer: show/hide, reorder, rename, recolour, adjust opacity, **invert**, add, delete.
  The active layer receives new objects; each layer is single-type, chosen when you add it.
  The base map is a pinned bottom layer — hideable and dimmable, never deletable.
- An **Elements** list per layer, naming that layer's objects with Edit / Zoom to / Rename /
  Delete.
- A **compass** that always points to map-north, a **Measure elevation** probe for any point,
  and a **Measure distance** tool.

**Editing**
- One explicit **map mode**. In the default *view* mode a tap is a no-op, so panning and
  pinching never pop an editor. Select by **long-press** (a ranked chooser of what is under
  your finger) or turn on the **✎ Edit** button and tap. **Add** is a sticky mode: each tap
  places one object, with Undo / Edit / Done in a banner.
- Points are **draggable handles** — drag to move with a live region reshape, long-press for
  the per-point menu, long-press the map to insert a vertex.
- A docked **editor sheet** writes every change live while the map stays interactive. It
  collapses to a grip bar so you can reach the map behind it.
- Coordinates use one **"lat, lng"** field that accepts values pasted straight from Google
  Maps, and number entry accepts either decimal separator (`1.5` and `1,5` both work).

**Import & export**
- Whole-database or **per-layer** export as **GeoJSON** (lossless round-trip) or **KML**
  (Google Earth / Maps).
- Import ZoneCraft GeoJSON plus generic **GeoJSON / KML / KMZ / GPX**, either as new layers or
  **merged** into an existing same-type one — so tracks and borders drawn elsewhere come in as
  freehand lines and areas.
- **Import a feature by name**: geocode a city, district, river, road or park through Nominatim
  and bring its geometry in as a freehand area or line.

**Offline & data**
- Map tiles you view are cached on the device, so revisiting an area does not re-download it and
  the map keeps working with no reception. A Settings readout shows the cache size, with a
  **"Clear cached map tiles"** button separate from "Clear all data".
- Imported POIs, stations, border areas and generated height polygons are stored locally and
  need no network after the import.
- Opt-in **"Locate me"** — location permission is requested only when you tap it, never at
  launch, never in the background.
- Fully local persistence via SQLite (Drift). Your data **and** your last map view survive
  restarts.

### A note on offline map tiles

ZoneCraft does **not** pre-fetch map tiles, and has no "download this area" button in the
default build. That is deliberate. OpenStreetMap's
[tile usage policy](https://operations.osmfoundation.org/policies/tiles/) defines bulk
downloading as *"any pre-emptive fetching of tiles other than those a user is actively
viewing"*, and states that *"offline use is not permitted on `tile.openstreetmap.org`"*. There
is no compliant amount of it, so on the community servers the app fetches only what you are
looking at. Caching what it *did* show you is separate — the policy requires that, and it is
always on.

Point the app at a tile provider of your own and both features return; see
[Configuring a tile provider](#configuring-a-tile-provider).

## How rendering works

Every region type builds its boundary in **lat/lng**, geodesically. The painter projects those
rings to screen and composites one layer at a time: each object yields an `outer` and a `core`
polygon, they union across the layer with `dart:ui` `Path.combine`, and the result paints as
core (solid) + band (`outer − core`, lighter) + outline — or `viewport − outer` when the layer
is inverted. That single contract is why invert and the uncertainty band behave the same for
every type.

Geometry that does not depend on where the camera is — buffered freehand offsets, plane and
Voronoi clips, circle rings — is resolved once and memoised, so a pan re-projects cached rings
instead of rebuilding them. Freehand areas and the three import types have their own painters:
buffered city-sized outlines are exactly the input Skia's path-ops fail on, so those composite
by overpainting inside a layer rather than by boolean operations.

## Tech stack

| Concern | Package |
|---|---|
| Framework | Flutter (Android-first, iOS-ready) |
| Map | [`flutter_map`](https://pub.dev/packages/flutter_map), [`flutter_map_dragmarker`](https://pub.dev/packages/flutter_map_dragmarker) |
| Geo math | [`latlong2`](https://pub.dev/packages/latlong2) |
| Local DB | [`drift`](https://pub.dev/packages/drift) + `drift_flutter` / `sqlite3_flutter_libs` |
| State | [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) |
| Network | [`http`](https://pub.dev/packages/http) — Overpass (POIs, transit, borders), Nominatim, terrain tiles |
| Files | [`share_plus`](https://pub.dev/packages/share_plus), [`file_selector`](https://pub.dev/packages/file_selector), [`path_provider`](https://pub.dev/packages/path_provider), [`xml`](https://pub.dev/packages/xml), [`archive`](https://pub.dev/packages/archive) |
| Location | [`geolocator`](https://pub.dev/packages/geolocator) (opt-in) |
| Colour picker | [`flutter_colorpicker`](https://pub.dev/packages/flutter_colorpicker) |
| Icon / splash | `flutter_launcher_icons`, `flutter_native_splash` (dev) |

## Project layout

```
lib/
  data/   Drift schema + repository (Layers; Circles, Planes, Subspaces,
          FreeLines, FreeAreas, HeightRegions and their point tables;
          PoiSets, TransitSets, BorderSets and their rows; TileCache,
          AppSettings). Shared Overpass transport with endpoint failover
          (overpass_client.dart) used by overpass.dart (POIs),
          transit.dart and borders.dart; request pacing + result caching
          (request_pacer.dart); Nominatim geocoding (place_search.dart);
          tile source policy (tile_source.dart); offline tile cache
          (cached_tile_provider.dart); GeoJSON/KML export (serialization.dart)
          and GeoJSON/KML/KMZ/GPX import (geo_import.dart); terrain
          generation (height_generator.dart)
  geo/    region geometry — geodesic, plane, subspace, freeline, freearea,
          height (marching squares), border_areas (ring assembly + colouring),
          simplify (Douglas–Peucker), tiles (slippy maths), coords (parsing)
  state/  Riverpod providers — per-object streams, point lookups grouped by
          owner, settings, selection/placement, map mode
  ui/     map_screen, layers_panel (drawer), one *_editor.dart per region type
          on a shared editor_sheet, settings_screen, region_layer (the
          compositing engine), poi/transit/border layers, import dialogs
assets/icon/   app-icon source art (transparent PNG + adaptive foreground)
drift_schemas/ schema snapshots that guard the migrations
scripts/       build.sh — analyze / test / build / install / run / bundle
test/          geometry, parsing, network, migration and database unit tests
```

## Develop

### Build script (recommended)

`scripts/build.sh` runs the checks and builds in one step (it puts `flutter` on `PATH` itself,
so it works even when the SDK isn't installed globally):

```bash
./scripts/build.sh                 # flutter analyze + test, then build a debug APK
./scripts/build.sh --install       # also install on the connected device (-r, keeps data)
./scripts/build.sh --install --run # install, then launch the app
./scripts/build.sh --release       # build a release APK instead of debug
./scripts/build.sh --bundle        # build a signed release App Bundle (.aab) for Play
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
```

### Configuring a tile provider

Setting `TILE_URL` switches the base map away from the community OSM servers and — because you
have then chosen a provider whose terms you have read — **re-enables the viewport prefetch and
the "download this area" button**:

```bash
export TILE_URL='https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=YOURKEY'
export TILE_ATTRIBUTION='© MapTiler © OpenStreetMap contributors'
./scripts/build.sh --release
```

Leave them unset for a policy-compliant build against `tile.openstreetmap.org`. See
[`lib/data/tile_source.dart`](lib/data/tile_source.dart).

### Database schema

The local database is at **schema v22**; migrations are append-only. Installing with `-r` (as
the build script does) preserves existing data and exercises them.

Any schema change must snapshot the new version, or `test/migration_test.dart` fails — a
snapshot cannot be reconstructed after the version ships:

```bash
dart run drift_dev schema dump lib/data/database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

## Privacy

No account, no analytics, no crash reporting, no advertising identifier — the app sends no
telemetry at all. Everything you create stays on the device. It talks to OpenStreetMap tile
servers, Overpass, Nominatim and a public elevation dataset only to draw the map and to run the
imports you ask for. Full detail in [`PRIVACY.md`](PRIVACY.md).

## License

ZoneCraft is released under the **Beer-Ware License (Revision 42)** — see [`LICENSE`](LICENSE).
Do whatever you want with the code; if we meet some day and you think it's worth it, buy me a
beer. 🍺

It builds on open-source packages and OpenStreetMap data whose attribution must be retained —
see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) (their full license texts are also
viewable on the app's in-app licenses page).
