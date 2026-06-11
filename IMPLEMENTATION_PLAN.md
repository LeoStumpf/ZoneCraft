# ZoneCraft — Architecture reference

How the app is built and the invariants to preserve when extending it. This is a
design reference, not a task log — the feature backlog lives in [PLAN.md](PLAN.md).

## Guiding principles

- **One rendering engine** handles core fill, the uncertainty band, union (no
  darkening), and inversion uniformly for every object type. Adding a new object
  type = providing its geometry; the engine does fill / band / union / inverse.
- **Geometry is computed in Dart, composited as screen-space `Path`s** via `dart:ui`
  `Path.combine`, painted by a single `CustomPainter` map layer. This is what makes
  "overlaps stay one flat colour" and "invert a layer" tractable.
- **Schema changes are migrated, never destructive.** Bump `schemaVersion` and add an
  append-only `if (from < N)` block each step; installing with `-r` exercises it.
- **No login, no server.** Every layer, object and setting lives in local SQLite.
  Networked data (tiles, Overpass) is cache-backed and must degrade gracefully offline.

## Rendering contract (`lib/ui/region_layer.dart`)

- Each object yields **two screen-space polygons**: an `outer` and a shrunk `core`.
  Per layer, all objects' `outer`s union together and all `core`s union together
  (`Path.combine`).
- Paint order per layer: **core** solid → **band** (`outer − core`) lighter → outline
  stroke. When the layer is **inverted**, paint `viewport − outer` instead.
- The **global uncertainty** (metres, in `AppSettings`) widens the band; the two
  freehand types add a signed per-object `offsetMeters` that shifts the boundary
  (`outer = offset − halfBand`, `core = offset + halfBand`). Metres→pixels is
  converted at the object's reference point (`_pxPerMeter`).
- This single `outer`/`core` contract is shared by all five object types, so invert
  and the band work the same everywhere. A new object type only has to emit `outer`
  and `core` for the current camera.

## Geometry (`lib/geo/`)

- `geodesic.dart` — true geodesic circle ring (real-world metres).
- `plane.dart` — half-plane on one side of two points' perpendicular bisector.
- `subspace.dart` — Voronoi cell of a chosen *main* point (intersection of half-planes;
  always convex).
- `freeline.dart` / `freearea.dart` — drawn polyline splitting the view (ends extended
  straight) / drawn closed ring filled inside; both apply the signed offset.
- `coords.dart` — `parseLatLng` / `formatLatLng` ("lat, lng", pastes from Google Maps).
- `tiles.dart` — Web-Mercator slippy-tile maths (`tileXFor`/`tileYFor`) for prefetch.

The bisector/offset maths are **planar approximations** — accurate at city scale,
not geodesically exact (see [PLAN.md](PLAN.md) for the refinement backlog item).

## Data model (`lib/data/database.dart`, schema **v10**)

- `Layers` — `type` (circles | planes | subspace | freeline | freearea), `isInverted`,
  colour, order, visibility, name. A layer is locked to one object type once it holds
  objects.
- `Circles`, `Planes`; `Subspaces` + `SubspacePoints`; `FreeLines` + `FreeLinePoints`;
  `FreeAreas` + `FreeAreaPoints` (parents carry `offsetMeters`). Child points cascade-
  delete; `PRAGMA foreign_keys = ON` in `beforeOpen`.
- `AppSettings` (single row) — uncertainty, last camera (centre+zoom), transport-overlay
  toggle, packed POI-category bitmask, packed border-level bitmask.
- `TileCache` (offline map tiles, LRU-evicted under a 200 MB cap) and `OverpassCache`
  (last POI/border results per kind) — caches, not user data.
- `Repository` is the only CRUD surface; Riverpod providers (`lib/state/`) watch it.

## Networking & caching

- **Tiles:** `CachedTileProvider` (`lib/data/cached_tile_provider.dart`) serves
  cache-first then network, writing fresh tiles back. One screen-owned `http.Client` is
  shared across all tile layers + the viewport prefetcher (so toggling an overlay off
  can't close it). Prefetch (`map_screen._prefetchTiles`) caches the viewport + a
  one-tile ring at zoom ≥ 10, capped and failure-safe.
- **Overpass (POIs + admin borders):** debounced, zoom-gated, viewport-inflated fetches
  that **keep stale data and retry on failure** (never clear on a network error). Use a
  polite User-Agent, cap result counts, fail silently. Results persist via `OverpassCache`
  so overlays reappear instantly on launch.

## Known approximations / risks

- **Planar geometry** — bisectors/offsets aren't geodesic; revisit for global accuracy.
- **`Path.combine` cost** with many objects — union once per layer per frame; cull
  off-screen objects; cache when the camera is idle if it ever bites.
- **Degenerate cameras** — zoom-out gestures can briefly yield a NaN camera; guard
  reads of `camera.visibleBounds` and snap back to the last good camera.
- **Third-party tile/Overpass usage** — respect attribution and rate limits; keep
  zoom-gating and debouncing in place.
- **iOS** — only the Android build has been run on a device; the iOS path is unverified.

## Toolchain reminders

- Build/verify with `./scripts/build.sh` (`--install --run` to deploy; `--skip-checks`
  for quick rebuilds). `flutter`/`dart` aren't on `PATH` otherwise.
- After schema changes: `dart run build_runner build`, then the build script.
