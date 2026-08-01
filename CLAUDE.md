# ZoneCraft — working notes for Claude

Flutter app: composable **zone layers** on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

## At a glance (current app)

- **Eight object types**, one per layer: `circles` (geodesic), `planes` (closer-of-two-points
  half-plane), `subspace` (closest-of-N Voronoi cell), `freeline` (drawn polyline dividing the
  view), `freearea` (drawn closed polygon), `height` (terrain above/below an elevation, bounded
  to a circle; generated from terrain tiles via marching squares, stored as fill polygons),
  `poi` (a category of OSM POIs fetched **once** from Overpass within a chosen radius and
  stored offline; rendered as icon markers that collapse into count-badge clusters when they'd
  overlap — no region compositing, no editor; the FAB re-imports more sets),
  `transit` (public-transport **stations** fetched **once** from Overpass over a
  tap-two-corners bbox and stored offline; **no line geometry is ever fetched** — only which
  transit *types* serve each station — drawn as clustered markers and filtered by a per-layer
  **Stations** menu; a failed import stays on the layer as a retry row, no editor).
  The region types have a `geo/*.dart` region builder and a `ui/*_editor.dart` docked editor.
- **Compositing engine** (`ui/region_layer.dart`): per layer, every object yields an
  `outer`+`core` screen-space polygon; these union via `Path.combine`, then paint core (solid)
  + band (`outer−core`, lighter) + outline, or `viewport−outer` when the layer is **inverted**.
  Global uncertainty widens the band; freehand objects add a signed per-object `offsetMeters`.
- **Layers drawer** (show/hide, reorder, recolour, adjust opacity, rename, invert, add/delete),
  plus a pinned bottom **Map** tile (the base OSM tiles as a hideable, opacity-adjustable
  layer that can never be deleted or reordered; its state lives in `AppSettings`) + **compass**,
  opt-in **Locate me** (also reads the terrain elevation there), a **Measure-elevation**
  probe (tap any point for its height), **persisted camera**, and a **Settings** screen
  (uncertainty, clear-all, and the overlay toggles below).
- **Optional overlays** (Overpass / tiles, all in Settings): public-transport tiles and
  administrative borders. (Map POIs used to be a third settings overlay; they are now the
  `poi` **layer type** — imported per area, offline, clustered.)
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
- **Drift schema is at v19**; migrations are append-only `if (from < N)` blocks. (v19 is the
  one exception: it *drops* the transit route tables, because route geometry was abandoned —
  see `data/transit.dart`'s header for the measurements behind that.)

## Current status

Feature-complete for everything planned so far: eight object types — six region types with
the shared compositing engine (union / band / invert; the `height` type uses even-odd fill
and is bounded, so it skips band/invert) plus the marker-based `poi` type (offline sets,
screen-space clustering) and the `transit` type (offline station imports over a bbox,
per-type visibility, retryable failed imports) — the layers drawer + per-type editors, settings (uncertainty,
clear-all, overlay toggles), opt-in locate-me, persisted camera, optional overlays
(public-transport tiles, admin borders), offline resilience (cache-first tiles + prefetch,
persisted border overlay), and import/export (whole-DB + per-layer + external
GeoJSON/KML/KMZ/GPX; freeline imports prompt for their inclusion-circle radius).
Drift schema is **v19**.

`planning/PLAN.md` has no open roadmap items; future polish ideas are listed there.

## Workflow rule (required)

- **Build & verify with the script:** before wrapping up a task, run
  `./scripts/build.sh --install --run` (analyze + test + build + install + launch) and check
  the change on the device. Use `--skip-checks` only for quick iteration.
- **Always commit and push directly to `main`** (the project's "master"/integration branch).
  **Do not create feature branches and do not open PRs** — work on `main`, commit there, and
  push there. After completing **every** task, **always commit and push to `main`
  automatically** without waiting to be asked. (This overrides the default "branch first when
  on the default branch / commit only when asked" behaviour — for this repo, direct-to-`main`
  is the rule.)
- After completing **all** the steps of a task, **update the docs** — drop the delivered
  item from `planning/PLAN.md`'s open points and, if it introduced a new pattern/invariant,
  add it to `planning/IMPLEMENTATION_PLAN.md` (the architecture reference) — then **commit and
  push the code to `main`**. Do the doc update + commit/push once at the end, not after every
  step. **Note:** the `planning/` folder is gitignored (see [Plans](#plans)), so updating those
  plan files is a local-only edit — it is never part of the commit; only the code changes are
  committed and pushed.

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
               PoiSets, PoiPoints, TransitSets, TransitStops,
               TileCache, OverpassCache, AppSettings)
               + repository; Overpass POI
               client (overpass.dart) + admin-border client (borders.dart);
               offline tile cache (cached_tile_provider.dart); GeoJSON/KML
               import-export (serialization.dart); generic GeoJSON/KML/KMZ/GPX
               parser (geo_import.dart); height-layer terrain generation
               (height_generator.dart); public-transport Overpass client
               (transit.dart)
  geo/         geodesicCircle(), plane half-plane + subspace Voronoi-cell
               geometry, freehand line/area region geometry (freeline.dart,
               freearea.dart), height contouring/marching-squares (height.dart),
               slippy-tile maths (tiles.dart), lat/lng parsing
  state/       Riverpod providers (layers, circles, planes, subspaces,
               freehand lines/areas, height regions/polygons, poi sets/points,
               transit sets/stops, settings, selection, map mode)
  ui/          map_screen, layers_panel, circle_editor, plane_editor,
               subspace_editor, freeline_editor, freearea_editor, height_editor,
               import_actions, settings_screen, region_layer, poi_layer
               (clustered POI markers), transit_layer (clustered station
               markers), transit_import_dialog, transit_modes_sheet
               (the station-type tick boxes + the pure `transitTally`,
               embedded in the Elements list), screen_cluster (greedy
               screen-space clustering), screen_clip (viewport pre-clip)
```

## Plans

**All planning docs live in the `planning/` folder, which is gitignored — they are local-only
and never committed.** New plans/notes go there too. This is strict: **no planning/checklist/TODO
`.md` files may live anywhere outside `planning/`** (the repo root keeps only genuine public docs
— `README.md`, `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`, `CLAUDE.md`). Likewise, generated
release artifacts (Play Store screenshots, icons, feature graphics) go under
`planning/play-store-assets/`, never committed.


- `planning/PLAN.md` — current state + open points (the roadmap).
- `planning/IMPLEMENTATION_PLAN.md` — architecture reference (rendering contract, data model,
  caching, known approximations). No milestone history.
