# ZoneCraft — working notes for Claude

Flutter app: geodesic circle/zone layers on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

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
`geo/subspace.dart`, `ui/subspace_editor.dart`) **done**. Next (planned, not yet built):
M10 public-transport overlay, M11 OSMAnd-style POI toggles. See `IMPLEMENTATION_PLAN.md`.

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
               SubspacePoints, AppSettings) + repository
  geo/         geodesicCircle(), plane half-plane + subspace Voronoi-cell
               geometry, lat/lng parsing
  state/       Riverpod providers (layers, circles, planes, subspaces,
               settings, selection)
  ui/          map_screen, layers_panel, circle_editor, plane_editor,
               subspace_editor, settings_screen, region_layer
```

## Plans

- `PLAN.md` — feature backlog (checklist).
- `IMPLEMENTATION_PLAN.md` — sequenced milestones (M0…M6) with decisions & verification.
