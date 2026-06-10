# ZoneCraft — Implementation Plan

Sequenced plan to deliver the features in [PLAN.md](PLAN.md). Ordered so the pieces
many features depend on (data model + rendering engine) come first and later work
slots in without rework.

## Guiding principles

- **One rendering engine** handles core fill, uncertainty band, union (no darkening),
  and inversion uniformly for every object type. Adding a new object type = providing
  its geometry; the engine does fill/band/union/inverse.
- **Geometry is computed in Dart, composited as screen-space `Path`s** via
  `dart:ui` `Path.combine`, and painted by a single `CustomPainter` map layer. This is
  what makes "overlaps stay one flat colour" and "inverse a layer" tractable.
- **Schema changes are migrated**, never destructive. Bump `schemaVersion` each step.

## Decisions (assumptions — override if wrong)

1. **Uncertainty band is the inner ring `R-u … R`** (the band eats into the object;
   matches "the outer 500 m *of the circle*"). Core = the object shrunk by `u`.
2. **Plane "near" side is per-object toggleable**, default = first point.
3. **Union/flat-colour applies within a layer.** Different layers still composite over
   each other (their colours blend where they overlap); a single layer never darkens
   itself.
4. **A layer is locked to one object type** once it contains objects.

---

## Milestone 0 — Data model & settings foundation ✅ DONE

**Status:** complete (2026-06-09). Schema migrated v1→v2 and verified on device
(`user_version=2`, tables `layers/circles/planes/app_settings`, existing data
preserved). DB/repository tests in `test/database_test.dart`.

**Goal:** schema + state that later milestones depend on. No visible change yet.

- `lib/data/database.dart`
  - `Layers`: add `type` (text, default `'circles'`) and `isInverted` (bool, default
    false).
  - New `AppSettings` single-row table: `id` (always 1), `uncertaintyMeters` (real,
    default 0), room for future options.
  - New `Planes` table: `id`, `layerId` (FK cascade), `aLat,aLng,bLat,bLng`,
    `nearA` (bool, default true), `label?`, `createdAt`. (`Circles` stays as is.)
  - `schemaVersion` → 2; `MigrationStrategy` with `onUpgrade` adding the columns/tables
    (keep existing circles).
- `lib/data/repository.dart`: CRUD for planes, layer `type`/`isInverted` updates,
  `watchSettings()` / `updateUncertainty()`. Helper `createLayer(type: …)`.
- `lib/state/providers.dart`: `settingsProvider` (StreamProvider), `planesProvider`.
- **Verify:** `dart run build_runner build`, `flutter analyze`, a Drift migration test
  (open v1 DB → upgrade → assert columns/tables exist and old circles survive).

## Milestone 1 — Rendering engine (core + band + union + inverse) ✅ DONE

**Status:** complete (2026-06-09). `lib/ui/region_layer.dart` composites each layer via
screen-space `Path.combine` (union → flat fill, `outer-core` → lighter band,
`viewport-outer` → inverse). `map_screen.dart` now renders one `RegionLayer` per visible
layer and selects circles with Haversine hit testing (the old `PolygonLayer`/`hitNotifier`
path is removed). Engine reads uncertainty from `settingsProvider`. UI to *toggle* inverse
and *set* uncertainty arrives in M2/M3.

**Goal:** replace the translucent `PolygonLayer` with a composited region layer; ship it
for circles first.

- `lib/geo/` helpers
  - Keep `geodesicCircle`. Add `geodesicCircleCore(center, R, u)` → ring at `max(R-u, 0)`.
  - Add an `ObjectGeometry` abstraction returning, per object, the **outer ring** (at
    `R`) and the **core ring** (at `R-u`) as `List<LatLng>`.
- `lib/ui/region_layer.dart` (new) — a flutter_map child layer:
  - Reads `MapCamera.of(context)`; projects each object's rings to screen `Offset`s
    (confirm the v8 method, e.g. `camera.latLngToScreenOffset`).
  - Builds `Path`s; unions per layer:
    `outerUnion = ∪ outerPaths`, `coreUnion = ∪ corePaths` (via `Path.combine.union`).
  - `band = combine(difference, outerUnion, coreUnion)`.
  - If `isInverted`: `core = combine(difference, viewportRect, outerUnion)` and the band
    flips to the outside edge.
  - `CustomPainter` paints `core` at the layer colour (solid-ish alpha) and `band` at a
    lighter alpha. Painting each unioned region once = **no opacity stacking**.
  - Repaints on camera change (`MapCamera` triggers rebuild).
- `lib/ui/map_screen.dart`: swap `_buildPolygons`/`PolygonLayer` for one `RegionLayer`
  per layer (bottom-to-top). Remove the translucent-stacking path.
- **Hit testing:** keep each object's projected outer `Path`; on tap, pick the topmost
  object whose `Path.contains(tapOffset)` is true (replaces the `hitNotifier` flow). For
  inverted layers, selection still uses the object outer paths.
- **Verify:** on device — overlapping circles in one layer show a flat colour (no dark
  overlap); a circle shows a lighter outer band when uncertainty > 0; toggling a layer's
  inverse fills the complement.

## Milestone 2 — UI restructure (drawer, bottom editor, add/remove) ✅ DONE

**Status:** complete (2026-06-09). Verified on device (screenshots): left `LayersDrawer`
(visibility/reorder/colour/rename/**invert**/delete/active + type icon), docked
`CircleEditorSheet` (live radius slider + lat/lng/label/layer, delete/close) with the map
still interactive, and add/remove via FABs + tap-to-select/deselect. Confirmed overlapping
circles render as one flat union.

**Goal:** the requested navigation/editing UX.

- **Left drawer for layers:** move `layers_panel.dart` content into a `Drawer`
  (`Scaffold.drawer`), opened by the AppBar leading button. Keep visibility/reorder/
  colour/rename/active + a new **inverse** toggle and **layer type** indicator.
- **Bottom edit sheet:** replace the `AlertDialog` in `circle_editor.dart` with a docked
  bottom panel (persistent `bottomSheet` / `DraggableScrollableSheet`) that stays while
  the map is interactive. Shows the selected object's fields and live-updates the map.
- **Add / remove buttons:** explicit "add object" (creates an object of the active
  layer's `type`, selects it, opens the bottom editor) and "remove" (deletes selection).
  Map tap still places/selects.
- **Verify:** add/edit/remove a circle entirely from the drawer + bottom sheet without a
  floating dialog; map stays pannable while editing.

## Milestone 3 — Settings screen + uncertainty wiring ✅ DONE

**Status:** complete (2026-06-10). `lib/ui/settings_screen.dart` is a routed screen
reached from a **Settings** entry in the layers drawer footer. It sets
`uncertaintyMeters` via a linked slider (0–2000 m) + metres text field, persisted live
through `updateUncertainty`. The engine already watches `settingsProvider` (M1 wiring), so
changes re-render every layer's band immediately. `flutter analyze`/`flutter test` green.

**Goal:** global settings, starting with uncertainty.

- `lib/ui/settings_screen.dart`: route from the drawer. Field to set
  `uncertaintyMeters` (e.g. slider + number field), persisted via `updateUncertainty`.
- Engine already reads uncertainty from `settingsProvider` (Milestone 1 wiring) — confirm
  changing it live re-renders all bands.
- **Verify:** set uncertainty to 500 m → every object gains a lighter 500 m inner band;
  set 0 → bands disappear.

## Milestone 4 — "Locate me" (strictly opt-in) ✅ DONE

**Status:** complete (2026-06-10). Added `geolocator` only (it covers the permission flow,
so `permission_handler` was unnecessary). Manifest declares fine/coarse location;
iOS has `NSLocationWhenInUseUsageDescription`. A small `my_location` FAB runs `_locateMe`
**only on tap**: checks services, requests permission *then*, and on grant centres the map
(zoom 14) + drops a marker; denial/disabled services show a dismissible SnackBar and change
nothing. A non-finite fix is guarded (returns a hint) so a NaN position can't corrupt the
map camera. Verified on device: no permission prompt at launch (`granted=false`); prompt
appears only on the button tap; grant centres on the real position with a marker; a bad fix
shows the hint instead of crashing.

**Goal:** optional current-location centring.

- Add deps `geolocator`, `permission_handler`. Add the **minimal** Android/iOS location
  permission strings, but **never request at launch**.
- A map button: on tap → request permission *then*; if granted, centre map + show a
  position marker; if denied, show a dismissible hint and do nothing else. No background
  location, no tracking.
- **Verify:** fresh install never prompts for location until the button is tapped;
  denying leaves the app fully usable.

## Milestone 5 — Plane object type ✅ DONE

**Status:** complete (2026-06-10). `lib/geo/plane.dart` builds the half-plane closer to the
near point as a viewport-clipped polygon (planar bisector in screen space, single-edge
Sutherland–Hodgman). To reuse the engine's `band = outer − core` model, the uncertainty band
straddles the bisector: `outer` is the near side pushed `u/2` onto the far side, `core` is it
pulled `u/2` back. `RegionLayer`/`_RegionPainter` now composite planes alongside circles
(union/band/inverse identical); `canvas.clipRect` hides the half-plane's viewport-edge stroke.
`PlaneEditorSheet` edits A/B (typed or placed by map taps via `planePlacementProvider`),
near-side toggle, layer, label, delete. The drawer's **Add** is a type chooser (circles |
planes); layers are single-type and the add FAB / map-tap adapt. Selection is unified
(topmost object across layers; `selectedPlaneProvider`). Plane hit-testing is geographic
(closer-to-near). **Fixed** a latent overlap: the floating Add/remove FABs sat over the
editor sheet's controls (taps hit the FAB) — FABs now hide while an editor is open. Plane
geometry unit-tested (`test/plane_test.dart`); `flutter analyze`/`flutter test` (13) green.
Verified on device: a plane fills the half nearer its point, the near-side toggle flips it,
a lighter band straddles the divide when uncertainty > 0, and inverse fills the complement.

**Goal:** "closer to one of two points" regions with uncertainty, inverse, union.

- `lib/geo/plane.dart`: from points A, B build the **half-plane closer to the near
  point** as a viewport-clipped polygon (perpendicular bisector of A,B). v1 uses a
  planar approximation in projected screen space (project A,B, bisect, fill the near
  side); note geodesic refinement as a follow-up.
  - Uncertainty band = strip around the bisector of width corresponding to `u`.
- Make `ObjectGeometry` cover planes so `RegionLayer` composites them identically
  (core/band/union/inverse, single-type layer).
- Plane editor in the bottom sheet: edit A, B, near-side toggle, label, delete; place the
  two points by map taps.
- Layer creation: choose `type` (circles | planes); enforce single-type per layer.
- **Verify:** a plane fills the half nearer its chosen point, with a lighter band along
  the divide; inverse flips it; two planes in a layer union flat.

## Milestone 6 — App icon / branding ✅ DONE

**Status:** complete (2026-06-10). Source art (`assets/icon/zonecraft.png`, a transparent
rounded-square; white background removed via morphological reconstruction so interior
white roads/outlines survive) plus a padded adaptive foreground
(`assets/icon/zonecraft_foreground.png`). `flutter_launcher_icons` generates Android
(adaptive: white bg + foreground) and iOS icons (alpha flattened to white); the app label
is "ZoneCraft" (renamed post-M6). `flutter_native_splash` shows the icon centred on white at
launch (incl. the Android-12 splash API). Both configured in `pubspec.yaml`. Verified on
device: launcher shows the new circle-masked icon, and the splash shows the icon when
opening the app.

- Add `flutter_launcher_icons`; supply one source icon (`assets/icon/zonecraft.png`),
  generate Android/iOS launcher icons, replace the default Flutter icon.
- **Verify:** installed app shows the new icon and label "ZoneCraft".

---

## New dependencies (by milestone)

- M4: `geolocator`, `permission_handler`
- M6: `flutter_launcher_icons` (dev)

## Cross-cutting risks

- **flutter_map v8 projection API** — confirm the exact `LatLng → screen Offset` method
  and camera-change rebuild before building `RegionLayer` (Milestone 1).
- **`Path.combine` performance** with many objects — union once per layer per frame; cull
  off-screen objects; cache when camera is idle if needed.
- **Inverse + uncertainty interaction** — define the band side precisely for inverted
  layers (band sits just outside the object boundary).
- **Plane accuracy** — planar bisector is an approximation; acceptable at city scale,
  revisit for geodesic correctness if needed.

## Suggested order & checkpoints

M0 → M1 are the backbone (do first, they unblock everything). M2/M3 are UX and can go in
parallel after M0. M4 and M6 are independent and can land any time. M5 depends on M0 + M1.
Each milestone ends green: `flutter analyze`, `flutter test`, and an on-device check.
