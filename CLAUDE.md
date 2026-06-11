# ZoneCraft — working notes for Claude

Flutter app: composable **zone layers** on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

## At a glance (current app)

- **Five object types**, one per layer: `circles` (geodesic), `planes` (closer-of-two-points
  half-plane), `subspace` (closest-of-N Voronoi cell), `freeline` (drawn polyline dividing the
  view), `freearea` (drawn closed polygon). Each has a `geo/*.dart` region builder and a
  `ui/*_editor.dart` docked editor.
- **Compositing engine** (`ui/region_layer.dart`): per layer, every object yields an
  `outer`+`core` screen-space polygon; these union via `Path.combine`, then paint core (solid)
  + band (`outer−core`, lighter) + outline, or `viewport−outer` when the layer is **inverted**.
  Global uncertainty widens the band; freehand objects add a signed per-object `offsetMeters`.
- **Layers drawer** (show/hide, reorder, recolour, rename, invert, add/delete) + **compass**,
  opt-in **Locate me**, **persisted camera**, and a **Settings** screen (uncertainty,
  clear-all, and the overlay toggles below).
- **Optional overlays** (Overpass / tiles, all in Settings): public-transport tiles, OSMAnd
  POIs, administrative borders.
- **Drift schema is at v9**; migrations are append-only `if (from < N)` blocks.

## Current status

**All milestones M0–M6 done** (data model + settings schema; composited rendering engine
with union/band/inverse for circles **and planes**; UI restructure: layers left drawer,
docked live editor, add/remove; settings screen with global uncertainty; opt-in locate-me
via `geolocator`; plane "closer-to-one-of-two-points" object with a circles|planes layer
type chooser; app icon + launch splash via `flutter_launcher_icons`/`flutter_native_splash`,
source art at `assets/icon/`). The v1 roadmap is complete.

**Post-v1 refinements (done):** app renamed to **ZoneCraft**; single "lat, lng" coordinate
field per point in the editors (pastes Google Maps coords; parser in `geo/coords.dart`);
edit-point markers (circle centre / plane endpoints) while editing; **persisted map camera**
(centre + zoom in `AppSettings`, **schema now v3**); **full-bleed map** with no app bar —
just a floating top-left menu button opens the drawer.

**v2 progress:** M7 compass/north-up **done**; M8 settings (500 m default uncertainty,
schema **v4** migration, `clearAll`/"Clear all data") **done**; M9 "closest subspace"
multi-point object (new `subspace` layer type, `Subspaces`+`SubspacePoints`, schema **v5**,
`geo/subspace.dart`, `ui/subspace_editor.dart`) **done**; M10 public-transport tile overlay
(ÖPNVKarte + OpenRailwayMap, `AppSettings.transportOverlay`, schema **v6**) **done**; M11
OSMAnd-style POI toggles (Overpass via `data/overpass.dart` + `http`, packed
`AppSettings.poiCategories`, schema **v7**, debounced/zoom-gated marker fetch) **done**.
**The v2 roadmap (M7–M11) is complete.** See `IMPLEMENTATION_PLAN.md`.

**Post-v2 additions:** toggleable **administrative borders** (OSM `admin_level` 2–10,
per-level on/off + colour, `data/borders.dart` via Overpass, packed
`AppSettings.borderLevels`, schema **v8**, per-level zoom gating, rendered as
`PolylineLayer`). Overpass `convert ::geom=geom()` returns GeoJSON `LineString`
(`[lon,lat]`), parsed in `parseBordersResponse`.

**v3 progress:** two **freehand (user-drawn)** layer types — M12 **freehand line** (a drawn
polyline dividing the view into two sides, ends extended straight; `geo/freeline.dart`,
`ui/freeline_editor.dart`) and M13 **freehand area** (a drawn closed polygon, fill inside;
`geo/freearea.dart`, `ui/freearea_editor.dart`) — each a new layer type (`freeline`,
`freearea`) with `FreeLines`+`FreeLinePoints` / `FreeAreas`+`FreeAreaPoints` tables and a
signed per-object `offsetMeters` (schema **v9**). Both mirror the `subspace` pattern, reuse
the per-layer **invert** to flip side/inside-outside, and feed `outer`/`core` polygons into
the existing compositor. **The v3 freehand types are complete.**

Track in `IMPLEMENTATION_PLAN.md` (milestone status) and `PLAN.md` (feature backlog).

## Workflow rule (required)

- **Build & verify with the script:** before wrapping up a task, run
  `./scripts/build.sh --install --run` (analyze + test + build + install + launch) and check
  the change on the device. Use `--skip-checks` only for quick iteration.
- After completing **all** the steps of a task/milestone, **update the plan docs**
  (`PLAN.md` and `IMPLEMENTATION_PLAN.md`) — tick off the items that are now done —
  and then **commit and push to `main`**. Do plan-update + commit/push once at the end,
  not after every individual step.

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
               FreeAreaPoints, AppSettings) + repository; Overpass POI client
               (overpass.dart) + admin-border client (borders.dart)
  geo/         geodesicCircle(), plane half-plane + subspace Voronoi-cell
               geometry, freehand line/area region geometry (freeline.dart,
               freearea.dart), lat/lng parsing
  state/       Riverpod providers (layers, circles, planes, subspaces,
               freehand lines/areas, settings, selection)
  ui/          map_screen, layers_panel, circle_editor, plane_editor,
               subspace_editor, freeline_editor, freearea_editor,
               settings_screen, region_layer
```

## Plans

- `PLAN.md` — feature backlog (checklist).
- `IMPLEMENTATION_PLAN.md` — sequenced milestones (M0…M6) with decisions & verification.
