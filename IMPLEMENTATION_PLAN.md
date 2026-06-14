# ZoneCraft — Architecture reference

How the app is built and the invariants to preserve when extending it. This is a
design reference, not a task log — the feature backlog lives in [PLAN.md](PLAN.md).

## Guiding principles

- **One rendering engine** handles core fill, the uncertainty band, union (no
  darkening), and inversion uniformly for every object type. Adding a new object
  type = providing its geometry; the engine does fill / band / union / inverse.
- **Geometry is built geodesically in lat/lng, then projected** to screen-space `Path`s
  and composited via `dart:ui` `Path.combine`, painted by a single `CustomPainter` map
  layer. Every object type produces lat/lng `outer`/`core` rings the painter projects with
  `latLngToScreenOffset` — never bisecting or offsetting in pixel space. This is what makes
  "overlaps stay one flat colour" and "invert a layer" tractable.
- **Schema changes are migrated, never destructive.** Bump `schemaVersion` and add an
  append-only `if (from < N)` block each step; installing with `-r` exercises it.
- **No login, no server.** Every layer, object and setting lives in local SQLite.
  Networked data (tiles, Overpass) is cache-backed and must degrade gracefully offline.

## Rendering contract (`lib/ui/region_layer.dart`)

- Each object yields **two lat/lng rings**: an `outer` and a shrunk `core`. The painter
  projects them (`_ringToPath`) and, per layer, unions all `outer`s together and all
  `core`s together (`Path.combine`).
- Paint order per layer: **core** solid → **band** (`outer − core`) lighter → outline
  stroke. When the layer is **inverted**, paint `viewport − outer` instead.
- The **global uncertainty** (metres, in `AppSettings`) widens the band; the two
  freehand types add a signed per-object `offsetMeters` that shifts the boundary
  (`outer = offset − halfBand`, `core = offset + halfBand`). All widths are **metres on
  the ground**, applied geodesically by the geometry builders — no per-reference-point
  pixel conversion. The plane/subspace band half-width is half the global uncertainty (so
  the band straddling a divide is `uncertainty` wide), matching the circle's core inset.
- This single `outer`/`core` contract is shared by all the bisector/ring object types, so
  invert and the band work the same everywhere. A new object type only has to emit `outer`
  and `core` lat/lng rings; the painter projects to the current camera.
- **Height is the exception to the band/invert flow** (`_paintHeight`). A height region's
  generated polygons are pre-bounded to its circle and already encode above/below, so the
  painter builds one **even-odd** `Path` per region from its rings (which yields correct
  sub-threshold *holes* without any union/subtraction) and fills it solid. The uncertainty
  band is drawn as a wide translucent **stroke along the elevation contour only** (edges
  whose endpoints both sit on the bounding circle are the clip arc, not a real border, and
  are skipped) — but clipped to **`circle − fill`** so the confident core stays solid and
  only the uncertain strip *outside* the fill (and inside holes) is lightened (no
  compounding/darkening). Stroke width = the global uncertainty in px (`_metersToPixels`).
  Height never takes the unbounded `viewport − outer` invert path; its Invert menu item is
  hidden.

## Geometry (`lib/geo/`)

- `geodesic.dart` — true geodesic circle ring (real-world metres).
- `spherical.dart` — ECEF (unit-vector) helpers + spherical Sutherland–Hodgman clipping
  (`sphericalCell`): the shared geodesic core of plane and subspace. The equidistant locus
  of two points is the **great circle** with pole `ecef(main) − ecef(other)`; the band is a
  small-circle threshold `sin(band/R)`; results densify along great-circle arcs.
- `plane.dart` / `subspace.dart` — thin lat/lng wrappers over `sphericalCell` (a plane is a
  subspace with one "other"). Bisectors are geodesic, returned as densified lat/lng rings.
- `freeline.dart` / `freearea.dart` — drawn polyline splitting the view (ends extended along
  their end **bearings**) / drawn closed ring filled inside; both offset each vertex on the
  ground with `Distance.offset` along its normal bearing (constant real-world width at any
  latitude). `freearea` insets per-vertex along the inward bisector, with collapse rejection.
- `coords.dart` — `parseLatLng` / `formatLatLng` ("lat, lng", pastes from Google Maps).
- `tiles.dart` — Web-Mercator slippy-tile maths (`tileXFor`/`tileYFor`) for prefetch.
- `height.dart` — elevation contouring (pure, isolate-safe): decode Terrarium terrain PNGs
  (`elev = R*256 + G + B/256 − 32768`), sample an elevation grid over the region's circle
  bbox, trace the threshold with **marching squares** (padded border so loops close; pad side
  selects above/below), stitch segments into loops, and clip each to the circle
  (Sutherland–Hodgman). Returns flat `[lat,lng,…]` rings for even-odd fill.

The bisector/offset maths are **geodesically accurate** (great-circle bisectors, ground-metre
offsets); the only approximations left are the per-edge densification count and treating the
viewport as a spherical quad (the painter still `clipRect`s to the true screen rectangle).

## Data model (`lib/data/database.dart`, schema **v11**)

- `Layers` — `type` (circles | planes | subspace | freeline | freearea | height),
  `isInverted`, colour, order, visibility, name. A layer is locked to one object type once
  it holds objects.
- `Circles`, `Planes`; `Subspaces` + `SubspacePoints`; `FreeLines` + `FreeLinePoints`;
  `FreeAreas` + `FreeAreaPoints` (parents carry `offsetMeters`). Child points cascade-
  delete; `PRAGMA foreign_keys = ON` in `beforeOpen`.
- `HeightRegions` (centre/radius/threshold/`aboveThreshold`/`sampleZoom`/`generatedAt`) +
  `HeightPolygons` + `HeightPolygonPoints`: the region's bound + parameters, and its
  *generated* fill rings. Generation is decoupled from rendering — `replaceHeightPolygons`
  rewrites the polygons wholesale and `markHeightGenerated` stamps the region; editing any
  geometry parameter clears `generatedAt` (stale until regenerated). Only the parameters
  export to GeoJSON/KML; the importer recreates the region un-generated and the user taps
  Generate.
- `AppSettings` (single row) — uncertainty, last camera (centre+zoom), transport-overlay
  toggle, packed POI-category bitmask, packed border-level bitmask.
- `TileCache` (offline map tiles, LRU-evicted under a 200 MB cap) and `OverpassCache`
  (last POI/border results per kind) — caches, not user data.
- `Repository` is the only CRUD surface; Riverpod providers (`lib/state/`) watch it.

## Import / export (`lib/data/serialization.dart`)

- A drift-free intermediate (`ExportData` → `ExportLayer` → `ExportObject`) decouples the
  encoders from the database, so GeoJSON/KML codecs are pure and unit-testable.
  `Repository.exportData({onlyLayerId})` snapshots the DB (all layers, or one) into it;
  `importData()` writes it into **new** layers and `mergeIntoLayer()` appends a parsed
  layer's objects into an existing same-type layer (both share `_insertObject`, which
  batch-inserts ring points). Per-layer Export / Import track / Import live in the layers
  drawer (`ui/import_actions.dart`); the new-vs-merge prompt and target picker are there too.
- **External geometry import** (`lib/data/geo_import.dart`): `parseExternalGeometry` reads
  generic **GeoJSON / KML / KMZ / GPX** (not just ZoneCraft's tagged GeoJSON) into
  line/area features, so tracks/borders from other apps import as freehand lines/areas.
  Depends on `xml` + `archive` (both pure Dart).
- **GeoJSON** is the lossless round-trip format: a `FeatureCollection` where each object is a
  `Feature` (circle→Point+`radiusMeters`, plane→LineString of the two foci+`nearA`,
  subspace→MultiPoint+`mainIndex`, freeline→LineString, freearea→Polygon, both +`offsetMeters`).
  Layer attributes (name/colour/type/invert) ride in a non-standard top-level `zonecraft`
  member; each feature references its layer by index in `properties.zonecraftLayer`. Import
  requires that extension (so foreign GeoJSON is cleanly rejected rather than half-parsed).
- **KML** is export-only (Google Earth / Maps): one `<Folder>` per layer, source geometry per
  object (circle as a geodesic ring polygon via `geodesicCircle`). Re-import via GeoJSON.
- UI lives in Settings (`_export` shares a temp file via `share_plus`; `_import` reads a file via
  `file_selector`). `path_provider` supplies the temp dir. `file_selector` is used instead of
  `file_picker` to avoid a `win32` version clash with `share_plus`.

## Networking & caching

- **Tiles:** `CachedTileProvider` (`lib/data/cached_tile_provider.dart`) serves
  cache-first then network, writing fresh tiles back. One screen-owned `http.Client` is
  shared across all tile layers + the viewport prefetcher (so toggling an overlay off
  can't close it). Prefetch (`map_screen._prefetchTiles`) caches the viewport + a
  one-tile ring at zoom ≥ 10, capped and failure-safe. An explicit **"download this
  area"** map FAB (`map_screen._downloadArea`) caches the current viewport across the
  current zoom + a couple deeper levels (base + enabled overlays) via the same
  `prefetch`, behind a confirm-with-estimate + cancellable progress dialog. Both share
  the `tilesCovering` enumerator (`geo/tiles.dart`). No pinning: just-downloaded tiles are
  the most-recently-used, so the 200 MB LRU evicts older areas first.
- **Terrain (height layer):** `height_generator.dart` fetches the covering public AWS
  Terrarium terrain tiles **cache-first via the same `TileCache`** (URL-keyed, so they
  coexist with map tiles), then runs the CPU-heavy decode + marching squares in a
  `compute()` isolate (raw bytes + doubles cross the boundary — no drift/`ui.Image`). Caps:
  radius ≤ 25 km, ≤ 80 tiles. A 404/offline tile is treated as sea level rather than
  failing; an all-missing fetch throws a user-facing message and keeps prior geometry.
  The map also offers a single-point **elevation probe** (`queryElevation` +
  `elevationFromTilePng`): a "Measure elevation" FAB arms a mode where a tap reads the
  terrain height at that point (one cache-first tile, decoded on the main isolate), and
  "Locate me" reads the elevation at the current position — both shown in a small readout
  card. Probe taps yield to any armed point-placement and pre-empt object selection.
- **Overpass (POIs + admin borders):** debounced, zoom-gated, viewport-inflated fetches
  that **keep stale data and retry on failure** (never clear on a network error). Use a
  polite User-Agent, cap result counts, fail silently. Results persist via `OverpassCache`
  so overlays reappear instantly on launch.

## Known approximations / risks

- **Densification cost** — geodesic plane/subspace rings densify each edge (~20 segments)
  along great-circle arcs; raise for smoother curves at the cost of `Path.combine` work.
- **Spherical quad clip** — the viewport is unprojected to four lat/lng corners and treated
  as a spherical quad; non-finite corners (extreme zoom-out / near-pole) skip plane/subspace.
- **`Path.combine` cost** with many objects — union once per layer per frame; cull
  off-screen objects; cache when the camera is idle if it ever bites.
- **Degenerate cameras** — zoom-out gestures can briefly yield a NaN camera; guard
  reads of `camera.visibleBounds` and snap back to the last good camera.
- **Height fidelity** — contours come from a capped elevation grid (≤ 512²) sampled
  nearest-pixel from terrain tiles, so very fine features are smoothed; lower `sampleZoom`
  trades detail for fewer tiles. Generation needs network the first time (then renders from
  stored polygons offline). Holes are handled by even-odd fill, not polygon subtraction.
- **Third-party tile/Overpass usage** — respect attribution and rate limits; keep
  zoom-gating and debouncing in place.
- **iOS** — only the Android build has been run on a device; the iOS path is unverified.
- **KGP build warning (upstream, non-actionable)** — the Android build prints "plugins that
  apply Kotlin Gradle Plugin (KGP): package_info_plus, share_plus". Both are already at their
  latest published versions (share_plus 13.1.0, package_info_plus 10.1.0) and *still* apply
  `kotlin-android` the legacy way, so there's no upgrade that silences it. `package_info_plus`
  is transitive via `geolocator` (Locate me); `share_plus` is used by import/export. The
  warning is forward-compat only — the build succeeds — and clears once those packages migrate
  to Flutter's "Built-in Kotlin". Don't bother re-trying a version bump; re-check upstream.

## Release / Play Store

- **App id** `com.leostumpf.zonecraft` (namespace + `applicationId` in
  `android/app/build.gradle.kts`, Kotlin package, `scripts/build.sh`). Don't change it again —
  it's the published identity.
- **Signing:** release builds read `android/key.properties` (gitignored) for the upload key and
  **fall back to the debug key when it's absent**, so dev/CI without secrets still build.
- **Bundle:** `scripts/build.sh --bundle` → a release `.aab` (Play requires App Bundles).
- **Crash reporting:** `lib/main.dart` initialises Sentry only when a `SENTRY_DSN` is baked in via
  `--dart-define`; empty DSN (dev) skips it. Crash data is off-device → disclosed in `PRIVACY.md`.
- **Manifest:** `INTERNET` is declared in the **main** manifest (not just the debug overlay), or
  release builds can't load tiles/Overpass.
- Full step-by-step (keystore, Play Console, data-safety, internal testing) lives in `RELEASE.md`.

## Toolchain reminders

- Build/verify with `./scripts/build.sh` (`--install --run` to deploy; `--skip-checks`
  for quick rebuilds; `--bundle` for a Play App Bundle). `flutter`/`dart` aren't on `PATH` otherwise.
- After schema changes: `dart run build_runner build`, then the build script.
