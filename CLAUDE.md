# Zonecraft — working notes for Claude

Flutter app: geodesic circle/zone layers on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

## Current status

Milestones **M0–M5 done** (data model + settings schema; composited rendering engine with
union/band/inverse for circles **and planes**; UI restructure: layers left drawer, docked
live editor, add/remove; settings screen with global uncertainty; opt-in locate-me via
`geolocator`; plane "closer-to-one-of-two-points" object with a circles|planes layer type
chooser). Next: **M6** app icon. Track in `IMPLEMENTATION_PLAN.md` (milestone status) and
`PLAN.md` (feature backlog).

## Workflow rule (required)

- After completing **all** the steps of a task/milestone, **update the plan docs**
  (`PLAN.md` and `IMPLEMENTATION_PLAN.md`) — tick off the items that are now done —
  and then **commit and push to `main`**. Do plan-update + commit/push once at the end,
  not after every individual step.

## Toolchain

- `flutter`/`dart` are NOT on PATH. Prefix commands with:
  `export PATH="$PATH:/home/leo/development/flutter/bin"`
- After Drift schema changes: `dart run build_runner build`
- Checks: `flutter analyze` && `flutter test`
- Android build/run: device `09291JEC226042` (Pixel 4a). `adb` at `/usr/bin/adb`.
  Build: `flutter build apk --debug`; install preserving data (exercises migrations):
  `adb -s <dev> install -r build/app/outputs/flutter-apk/app-debug.apk`.
  No Android emulator is available, so on-device is the only interactive run.

## Layout

```
lib/
  data/        Drift database (Layers, Circles, Planes, AppSettings) + repository
  geo/         geodesicCircle() and geometry helpers
  state/       Riverpod providers
  ui/          map_screen, layers_panel, circle_editor, region_layer
```

## Plans

- `PLAN.md` — feature backlog (checklist).
- `IMPLEMENTATION_PLAN.md` — sequenced milestones (M0…M6) with decisions & verification.
