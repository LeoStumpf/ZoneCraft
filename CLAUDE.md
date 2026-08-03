# ZoneCraft — working notes for Claude

Flutter app: composable **zone layers** on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

## At a glance (current app)

- **Nine object types**, one per layer: `circles` (geodesic), `planes` (closer-of-two-points
  half-plane), `subspace` (closest-of-N Voronoi cell), `freeline` (drawn polyline dividing the
  view), `freearea` (drawn closed polygon), `height` (terrain above/below an elevation, bounded
  to a circle; generated from terrain tiles via marching squares, stored as fill polygons),
  `poi` (a category of OSM POIs fetched **once** from Overpass within a chosen radius and
  stored offline; rendered as icon markers that collapse into count-badge clusters when they'd
  overlap — no region compositing, no editor; the FAB re-imports more sets),
  `transit` (public-transport **stations** fetched **once** from Overpass over a
  tap-two-corners bbox and stored offline; **no line geometry is ever fetched** — only which
  transit *types* serve each station — drawn as clustered markers and filtered by a per-layer
  **Stations** menu; a failed import stays on the layer as a retry row, no editor.
  The import dialog also asks **which types to fetch**, pre-ticked from the box size and
  size-limited per type — bus stops are ~25× the data of train stops, so a state-sized
  train-only import works while a bus one is refused),
  `borders` (administrative **areas** of one OSM `admin_level`, chosen when the layer is
  created, fetched **once** over a tap-two-corners bbox and stored offline; whole relations
  are downloaded — clipped member ways have no fillable interior — then assembled and
  thinned on the device. **Nothing is cut to the box**: the box limits what is fetched, not
  what is kept, so an area may reach well past it. Drawn as outlines in the layer colour
  with two per-layer toggles, **Colour areas** (a 6-colour palette assigned so no two
  neighbours match, adjacency = shared OSM way id) and **Show names**. The Elements list
  names the **areas** ("Maxvorstadt"), not the imports, and each row can be
  **converted to a freehand area layer** — the offline twin of the by-name feature import,
  and the only way geometry leaves this read-only snapshot. No editor).
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
  (uncertainty, clear-all, offline cache, import/export).
- **No map overlays.** All three global Settings toggles are gone: map POIs became the
  `poi` layer type, public-transport tiles and administrative borders were superseded by
  `transit` and `borders`. `AppSettings.transportOverlay` / `.borderLevels` survive as
  documented **dead columns** (the precedent `poiCategories` set), as does the now-unused
  `OverpassCache` table.
- **Offline caching:** a Drift-backed `TileCache` + custom `CachedTileProvider`
  (`data/cached_tile_provider.dart`) serve map tiles cache-first then network, with LRU
  eviction (200 MB cap) + a Settings size readout / "Clear cached map tiles" button.
  Caching what you *displayed* is required by OSM's policy and always on.
- **Pre-emptive tile fetching is gated on the tile source** (`data/tile_source.dart`).
  The one-tile-ring **viewport prefetch** (`map_screen._prefetchTiles`) and the
  **"Download this area"** button are both "bulk downloading" under OSM's tile policy —
  which defines it as *any* pre-emptive fetching, so there is no compliant ring size — and
  are therefore **off by default**. They switch on only when the build sets
  `--dart-define=TILE_URL=...` (a keyed provider or your own server); `scripts/build.sh`
  forwards `TILE_URL`/`TILE_ATTRIBUTION` from the environment. Never flip
  `TileSource.allowsPrefetch` for the community server — `test/tile_source_test.dart`
  guards it.
- **One Overpass client** (`data/overpass_client.dart`): endpoint failover, transient-vs-fatal
  status handling and a size cap, shared by `transit.dart`, `borders.dart` **and
  `overpass.dart`** (POI imports) — all three return `OverpassOutcome` and drive the shared
  `ui/import_progress.dart` dialog. The endpoint that last answered is remembered in
  `AppSettings.transitEndpoint` (old name, shared use).
- **Every outbound HTTP call is timed out.** `package:http` has no default timeout, so each
  call site sets one explicitly (`kTerrainTileTimeout`, `CachedTileProvider.fetchTimeout`,
  the Overpass per-request budgets), plus `kHeightGenBudget` as an overall deadline on a
  height generation and a `timeLimit` on `getCurrentPosition`. Add one to any new call.
- **Requests to the donated OSM services are paced** (`data/request_pacer.dart`).
  `nominatimPacer` (1.1 s — the policy's ceiling is 1 req/s) and `overpassPacer` (1 s) queue
  and space calls; they are **pacers, not debouncers** — these are explicit user actions, so
  a late request is right and a dropped one would look like a dead button. Nominatim results
  additionally go through `placeSearchCache` (a `QueryCache`), because its policy *requires*
  client-side caching and blocks clients that repeat identical queries. **Never add
  autocomplete/per-keystroke geocoding** — the policy forbids it outright.
- **Number entry goes through `parseDecimal`** (`geo/coords.dart`), never bare
  `double.tryParse` — a comma-decimal locale would otherwise make the field silently no-op.
- **Editors use the shared shell** (`ui/editor_sheet.dart`): `EditorSheet` (capped at 60 %
  of the viewport, scrolls the rest), `EditorLayerPicker` (one-line ellipsis) and
  `scaledPx(context, px)` for any pixel size chosen against text. A bottom sheet clips
  **silently** — no overflow stripes — so a plain `Column` of `Row`s loses its bottom rows
  at a large system font. Prefer `Wrap` over `Row` for label+field pairs.
- **Per-layer & external import/export:** besides whole-DB GeoJSON/KML, each layer can be
  exported alone and files imported as a new layer or **merged** into an existing same-type
  one (`ui/import_actions.dart`); generic **GeoJSON/KML/KMZ/GPX** tracks import into freehand
  layers (`data/geo_import.dart`).
- **Drift schema is at v20**; migrations are append-only `if (from < N)` blocks. (v19 is the
  one exception: it *drops* the transit route tables, because route geometry was abandoned —
  see `data/transit.dart`'s header for the measurements behind that.) v20 is snapshotted in
  `drift_schemas/` and guarded by `test/migration_test.dart`. **Any schema change must dump a
  new snapshot** (`dart run drift_dev schema dump lib/data/database.dart drift_schemas/`, then
  `... schema generate drift_schemas/ test/generated_migrations/`) — a snapshot cannot be
  reconstructed after the version ships, and the test fails until it exists.
- **Point rows reach the renderer pre-grouped by owner** (`state/providers.dart`'s
  `*By*Provider`s build `Map<ownerId, List<point>>` once per stream emission). `RegionLayer`
  takes maps, not flat lists: it rebuilds on every camera tick, so a linear scan per object
  there costs O(objects × all points) *per frame*.

## Current status

Feature-complete for everything planned so far: nine object types — six region types with
the shared compositing engine (union / band / invert; the `height` type uses even-odd fill
and is bounded, so it skips band/invert) plus three import types with their own painters:
`poi` (offline sets, screen-space clustering), `transit` (offline station imports over a
bbox, per-type visibility, retryable failed imports) and `borders` (offline area imports
per admin level, neighbour-distinct colouring, name plates, per-area convert-to-freehand)
— the layers drawer + per-type
editors, settings (uncertainty, clear-all, offline cache, import/export), opt-in locate-me,
persisted camera, offline resilience (cache-first tiles; **no** prefetch on the community OSM
servers — see `data/tile_source.dart`), and import/export
(whole-DB + per-layer + external GeoJSON/KML/KMZ/GPX; freeline imports prompt for their
inclusion-circle radius). Drift schema is **v20**.

`planning/PLAN.md` has no open roadmap items; future polish ideas are listed there.
`planning/PRODUCTION_AUDIT.md` records the production-readiness pass (what was found, what
was fixed, what is deliberately left). `planning/RELEASE.md` is the Play Store checklist —
release notes, store listing copy and the exact data-safety answers live there.

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
               BorderSets, BorderAreas,
               TileCache, OverpassCache, AppSettings)
               + repository; shared Overpass transport with endpoint failover
               (overpass_client.dart); Overpass POI client (overpass.dart);
               offline tile cache (cached_tile_provider.dart); GeoJSON/KML
               import-export (serialization.dart); generic GeoJSON/KML/KMZ/GPX
               parser (geo_import.dart); height-layer terrain generation
               (height_generator.dart); public-transport Overpass client
               (transit.dart); administrative-area Overpass client (borders.dart)
  geo/         geodesicCircle(), plane half-plane + subspace Voronoi-cell
               geometry, freehand line/area region geometry (freeline.dart,
               freearea.dart), height contouring/marching-squares (height.dart),
               border ring assembly / box clipping / area colouring
               (border_areas.dart), slippy-tile maths (tiles.dart), lat/lng parsing
  state/       Riverpod providers (layers, circles, planes, subspaces,
               freehand lines/areas, height regions/polygons, poi sets/points,
               transit sets/stops, border sets/areas, settings, selection,
               map mode)
  ui/          map_screen, layers_panel, circle_editor, plane_editor,
               subspace_editor, freeline_editor, freearea_editor, height_editor,
               import_actions, settings_screen, region_layer, poi_layer
               (clustered POI markers), transit_layer (clustered station
               markers), transit_import_dialog, transit_modes_sheet
               (the station-type tick boxes + the pure `transitTally`,
               embedded in the Elements list), border_layer (area fills +
               outlines + name plates, no Path.combine), border_import_dialog,
               screen_cluster (greedy screen-space clustering), screen_clip
               (viewport pre-clip, rings and segments)
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
