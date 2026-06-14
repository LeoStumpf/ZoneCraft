# ZoneCraft — working notes for Claude

Flutter app: composable **zone layers** on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

## At a glance (current app)

- **Six object types**, one per layer: `circles` (geodesic), `planes` (closer-of-two-points
  half-plane), `subspace` (closest-of-N Voronoi cell), `freeline` (drawn polyline dividing the
  view), `freearea` (drawn closed polygon), `height` (terrain above/below an elevation, bounded
  to a circle; generated from terrain tiles via marching squares, stored as fill polygons).
  Each has a `geo/*.dart` region builder and a `ui/*_editor.dart` docked editor.
- **Compositing engine** (`ui/region_layer.dart`): per layer, every object yields an
  `outer`+`core` screen-space polygon; these union via `Path.combine`, then paint core (solid)
  + band (`outer−core`, lighter) + outline, or `viewport−outer` when the layer is **inverted**.
  Global uncertainty widens the band; freehand objects add a signed per-object `offsetMeters`.
- **Layers drawer** (show/hide, reorder, recolour, rename, invert, add/delete) + **compass**,
  opt-in **Locate me** (also reads the terrain elevation there), a **Measure-elevation**
  probe (tap any point for its height), **persisted camera**, and a **Settings** screen
  (uncertainty, clear-all, and the overlay toggles below).
- **Optional overlays** (Overpass / tiles, all in Settings): public-transport tiles, OSMAnd
  POIs, administrative borders.
- **Offline caching:** a Drift-backed `TileCache` + custom `CachedTileProvider`
  (`data/cached_tile_provider.dart`) serve map tiles cache-first then network, plus a
  one-tile-ring **viewport prefetch** (`map_screen._prefetchTiles`, slippy maths in
  `geo/tiles.dart`), so the map survives a few minutes with no reception; `OverpassCache`
  persists the last POI/border results. LRU eviction (200 MB cap) + a Settings size readout /
  "Clear cached map tiles" button.
- **Per-layer & external import/export:** besides whole-DB GeoJSON/KML, each layer can be
  exported alone and files imported as a new layer or **merged** into an existing same-type
  one (`ui/import_actions.dart`); generic **GeoJSON/KML/KMZ/GPX** tracks import into freehand
  layers (`data/geo_import.dart`).
- **Drift schema is at v11**; migrations are append-only `if (from < N)` blocks.

## Current status

Feature-complete for everything planned so far: six object types with the shared
compositing engine (union / band / invert; the `height` type uses even-odd fill and is
bounded, so it skips band/invert), the layers drawer + per-type editors, settings
(uncertainty, clear-all, overlay toggles), opt-in locate-me, persisted camera, optional
overlays (public-transport tiles, OSMAnd POIs, admin borders), offline resilience
(cache-first tiles + prefetch, persisted POI/border overlays), and import/export
(whole-DB + per-layer + external GeoJSON/KML/KMZ/GPX). Drift schema is **v11**.

`PLAN.md` has no open roadmap items; future polish ideas are listed there.

## Workflow rule (required)

- **Build & verify with the script:** before wrapping up a task, run
  `./scripts/build.sh --install --run` (analyze + test + build + install + launch) and check
  the change on the device. Use `--skip-checks` only for quick iteration.
- After completing **all** the steps of a task, **update the docs** — drop the delivered
  item from `PLAN.md`'s open points and, if it introduced a new pattern/invariant, add it
  to `IMPLEMENTATION_PLAN.md` (the architecture reference) — then **commit and push to
  `main`**. Do the doc update + commit/push once at the end, not after every step.

## Toolchain

- **Build / install / run — use the script** (`scripts/build.sh`; it puts `flutter` on
  `PATH` itself):
  - `./scripts/build.sh` — `flutter analyze` + `flutter test`, then build a **debug** APK.
  - `./scripts/build.sh --install` — also install on the device with `-r` (preserves data,
    exercises migrations).
  - `./scripts/build.sh --install --run` — install, then launch the app.
  - `./scripts/build.sh --skip-checks` — skip analyze/test for faster rebuilds;
    `--release` for a release APK; `DEVICE=<serial>` to target another device.
- `flutter`/`dart` are otherwise NOT on PATH — prefix manual commands with:
  `export PATH="$PATH:/home/leo/development/flutter/bin"`
- After Drift schema changes: `dart run build_runner build` (then `scripts/build.sh`).
- Device `09291JEC226042` (Pixel 4a), `adb` at `/usr/bin/adb`. No Android emulator is
  available, so on-device is the only interactive run.

## Layout

```
lib/
  data/        Drift database (Layers, Circles, Planes, Subspaces,
               SubspacePoints, FreeLines, FreeLinePoints, FreeAreas,
               FreeAreaPoints, HeightRegions, HeightPolygons, HeightPolygonPoints,
               TileCache, OverpassCache, AppSettings) + repository; Overpass POI
               client (overpass.dart) + admin-border client (borders.dart);
               offline tile cache (cached_tile_provider.dart); GeoJSON/KML
               import-export (serialization.dart); generic GeoJSON/KML/KMZ/GPX
               parser (geo_import.dart); height-layer terrain generation
               (height_generator.dart)
  geo/         geodesicCircle(), plane half-plane + subspace Voronoi-cell
               geometry, freehand line/area region geometry (freeline.dart,
               freearea.dart), height contouring/marching-squares (height.dart),
               slippy-tile maths (tiles.dart), lat/lng parsing
  state/       Riverpod providers (layers, circles, planes, subspaces,
               freehand lines/areas, height regions/polygons, settings, selection)
  ui/          map_screen, layers_panel, circle_editor, plane_editor,
               subspace_editor, freeline_editor, freearea_editor, height_editor,
               import_actions, settings_screen, region_layer
```

## Plans

- `PLAN.md` — current state + open points (the roadmap).
- `IMPLEMENTATION_PLAN.md` — architecture reference (rendering contract, data model,
  caching, known approximations). No milestone history.
