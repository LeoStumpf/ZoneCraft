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

# v2 — post-v1 features

These build on the completed v1 engine. Numbered M7+; independent unless noted. Each ends
green (`flutter analyze`, `flutter test`, on-device check) and persists every new setting in
`AppSettings`.

## Milestone 7 — Compass & north-up reset ✅ DONE

**Status:** complete (2026-06-10). `map_screen.dart` tracks map rotation via
`MapOptions.onPositionChanged` (`_rotation`, degrees) and adds a `FloatingActionButton.small`
at the top of the lower-right FAB column: a red `Icons.navigation` needle wrapped in
`Transform.rotate(-_rotation·π/180)` so it always points to map-north; tapping it calls
`_mapController.rotate(0)`. It's hidden while an editor sheet is open (shares the FAB column).
Verified on device: rotating the map tilts the needle to keep pointing north, and tapping
snaps the map back to north-up with the needle upright.

**Goal:** a compass control that reflects map rotation and snaps the map back to north-up.

- `lib/ui/map_screen.dart`: add a `FloatingActionButton.small` to the lower-right FAB column
  (above "Locate me"), hidden while an editor sheet is open (same rule as the others).
- The child is a compass needle (e.g. `Icons.navigation`) wrapped in
  `Transform.rotate(angle: -camera.rotationRad)` so it always points to map-north.
- Rebuild the needle on rotation change: listen to `_mapController.mapEventStream`
  (or `onPositionChanged`) and `setState` the current rotation.
- On tap: `_mapController.rotate(0)` (optionally animated) to reset the bearing to north-up.
- **Decision:** always visible (at rotation 0 the needle simply points up), matching the
  "always points to map-north" request — no auto-hide.
- **Verify:** two-finger-rotate the map → the needle rotates to keep pointing north; tap →
  the map snaps north-up and the needle points straight up.

## Milestone 8 — Settings: 500 m default, persistence, clear-data ✅ DONE

**Status:** complete (2026-06-11). `AppSettings.uncertaintyMeters` now defaults to `500`
(column default + `watchSettings()` empty-row fallback); **schema bumped to v4** with a
`from < 4` migration that runs `UPDATE app_settings SET uncertainty_meters = 500 WHERE
uncertainty_meters = 0` (only an untouched old default is bumped). `Repository.clearAll()`
deletes every layer (cascading to circles/planes), drops the settings row (so it reverts to
defaults — uncertainty 500, camera null), then re-seeds an empty default layer; the Settings
screen gained a **Data** section with a red "Clear all data" button behind an `AlertDialog`
confirmation (it also clears the selection/active-layer providers before wiping). Persistence
already holds by construction — every general setting is a column in `AppSettings`, written
live and read via `settingsProvider`. Tests updated (default → 500; new `clearAll` test);
`flutter analyze`/`flutter test` (21) green. Verified on device: an existing install migrated
to `user_version=4` with its non-zero uncertainty and camera **preserved** (non-destructive);
Settings shows the new section; "Clear all data" → confirm dialog → Cancel leaves data intact.

**Goal:** sensible defaults, durable settings, and a safe reset.

- **Default uncertainty 500 m:** change `AppSettings.uncertaintyMeters` column default to
  `500` and the `watchSettings()` empty-row fallback to `500`. Add migration **v3 → v4**
  that sets the existing settings row's `uncertaintyMeters` to `500` *iff* it is still the
  old default `0` (a row already exists for anyone who has moved the map, since `saveCamera`
  creates it). **Decision/tradeoff:** a user who deliberately chose `0` is reset to `500`;
  acceptable as it's one tap to change. Bump `schemaVersion` to 4.
- **Persistence audit:** every general setting lives as a column in `AppSettings` (or a small
  key/value settings table), written immediately on change and read via `settingsProvider`,
  so all settings survive close/relaunch by construction. New toggles (M10/M11) follow this.
- **Clear database:** `Repository.clearAll()` deletes all layers (cascade removes
  circles/planes/subspaces), resets `AppSettings` to defaults (uncertainty 500, camera null,
  overlays off), then re-seeds the default layer. A "Clear all data" button in
  `settings_screen.dart` shows an `AlertDialog` confirmation before calling it.
- **Verify:** fresh install shows 500 m (and a 500 m band on objects); a toggle survives a
  force-stop/relaunch; "Clear all data" → confirm → app returns to first-run state (one empty
  layer, default settings) without crashing.

## Milestone 9 — "Closest subspace" multi-point plane ✅ DONE

**Status:** complete (2026-06-11). New `subspace` layer type holding a single object of N
points (one `isMain`); the filled region is the main point's Voronoi cell. **Schema bumped to
v5** with a `from < 5` migration creating `Subspaces` + `SubspacePoints` (both cascade-deleted
from their parent). `lib/geo/subspace.dart` builds the main cell by clipping the inflated
viewport rect by each `main-vs-Pⱼ` half-plane in sequence (reusing the plane bisector idea);
`outer` pushes each bisector `+u/2` toward the others and `core` pulls `−u/2`, so `band =
outer − core` hugs the internal divides — degenerate (no others / a point coincident with main)
→ empty. `RegionLayer`/`_RegionPainter` composite the convex cell exactly like a plane
(union/band, inverse = viewport − outer). `lib/ui/subspace_editor.dart` lists each point (a
"lat, lng" field + a main `RadioGroup` + move-by-tap + delete), an Add-point button, the layer,
a label and delete-object; markers show every point with the main one drawn larger/white.
The drawer's add-type chooser gained a **Subspace layer** option (`scatter_plot_outlined`); the
Add FAB seeds a new object (main + two flanking points, immediately visible) or appends a point
to the existing one ("Add point"); selection is unified (`selectedSubspaceProvider`,
`subspacePlacementProvider`) and hit-testing picks the subspace iff its main point is the nearest
of its points to the tap. Repository CRUD with `setMainPoint` keeping exactly one main; deleting
the main promotes another. Tests: `test/subspace_test.dart` (geometry: central-strip cell, band
offsets, empty/degenerate) and DB CRUD/cascade/single-main; `flutter analyze`/`flutter test`
(26) green. Verified on device (migrated to `user_version=5`): a 3-point subspace fills the main
cell, switching the main point reshapes it live, invert fills the complement (compositing over
the circle layers beneath), and the object/point counts show in the drawer.

**Goal:** a new object type — the region closest to a chosen "main" point among N points
(the main point's Voronoi cell) — with the same union/band/inverse behaviour as planes.

- **Concept:** for points P₁…Pₙ with main `Pₘ`, the filled region is
  `{ q : dist(q,Pₘ) ≤ dist(q,Pⱼ) ∀ j }` — the **intersection** of the half-planes "closer to
  main than to Pⱼ". Reuses the bisector/half-plane already in `geo/plane.dart`.
- **Data model** (`lib/data/database.dart`, schema bump): a `Subspaces` table (id, layerId,
  label?, createdAt) — one row = one object — and a `SubspacePoints` table (id, subspaceId
  FK-cascade, lat, lng, sortOrder, isMain). Exactly one point per subspace has `isMain`. A
  `subspace` layer holds a **single** `Subspaces` object.
- **Layer type:** add `'subspace'` to the layer `type` set and the drawer's add-type chooser.
  When a subspace layer is active, the **Add** button adds a *point* to its single object
  (creating the object on the first add) — not a new object.
- **Geometry** (`lib/geo/subspace.dart`): build the main cell by starting from the (inflated)
  viewport rect and successively clipping by each `main-vs-Pⱼ` half-plane — the same
  `_clipRectByHalfPlane` used for planes, applied in sequence. `outer` pushes each bisector
  `+u/2` toward the others, `core` pulls `−u/2`; band = `outer − core`. Degenerate
  (n < 2 / coincident main) → empty.
- **Engine:** `RegionLayer`/`_RegionPainter` composite the (convex) cell exactly like a plane
  — fill/band, and inverse = viewport − outer.
- **Editor** (`lib/ui/subspace_editor.dart`): list points (each a single "lat, lng" field + a
  "main" radio + delete), an add-point button, place-by-tap per point (reuse the
  placement-arming pattern), layer/label, delete-object. Show every point as a marker, the
  main one distinct.
- **Hit-testing:** a tap selects the subspace iff its main point is the nearest of its points
  to the tap (Haversine) — i.e. inside the main cell.
- **Decision:** planar (screen-space) bisectors as with planes; geodesic refinement deferred.
- **Verify:** add ≥3 points and pick a main → the main's nearest-region fills; moving/adding
  points reshapes it live; a lighter band hugs the internal divides; invert fills the
  complement; two such layers composite correctly.

## Milestone 10 — Public-transport overlay

**Goal:** an optional overlay of the public train/bus network and stops.

- **Approach (tile-based, pragmatic):** a persistent settings toggle "Public transport" that
  adds overlay `TileLayer`(s) above the base map — ÖPNVKarte
  (`https://tile.memomaps.de/tilegen/{z}/{x}/{y}.png`, buses/trams/stops) and/or
  OpenRailwayMap (`https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png`, rail lines).
  Both are transparent OSM-based overlays — no Overpass querying, fast to ship.
- Render the overlay layer(s) in `map_screen.dart` **below** the region layers (zones stay on
  top); add the required attributions.
- **Decision:** ship a rendered tile overlay first; tappable/interactive vector stops (via
  Overpass) are a heavier follow-up.
- **Verify:** toggle on → rail/bus lines and stops appear and follow pan/zoom; toggle off →
  gone; attribution shown; setting persists.

## Milestone 11 — Toggleable map POIs (OSMAnd-style)

**Goal:** optionally show OSM POI categories (benches, post boxes, …) like OSMAnd.

- **Settings:** a "Map points of interest" section with per-category toggles (benches
  `amenity=bench`, post boxes `amenity=post_box`, drinking water, toilets, waste baskets, …).
  Enabled categories persisted in `AppSettings` (a packed set / bitmask).
- **Data** (`lib/data/overpass.dart`, new dep `http`): query the Overpass API for the enabled
  categories within the current viewport bbox, **only at high zoom** (≥ ~15, matching
  OSMAnd's detail level) and **debounced on map-idle**; cache by (bbox, category) and cap the
  result count to respect Overpass usage limits.
- **Render:** a `MarkerLayer` of small category icons, built only above the zoom threshold so
  the map stays consistent with OSMAnd (no clutter when zoomed out). Fail silently (show no
  POIs rather than errors).
- **Verify:** enable "benches" and zoom past the threshold → bench markers appear; pan →
  refresh (debounced); zoom out → hide; toggle off → gone; choices persist across relaunch.

---

## New dependencies (by milestone)

- M4: `geolocator`, `permission_handler`
- M6: `flutter_launcher_icons` (dev)
- M11: `http` (Overpass POI queries)

## Cross-cutting risks

- **flutter_map v8 projection API** — confirm the exact `LatLng → screen Offset` method
  and camera-change rebuild before building `RegionLayer` (Milestone 1).
- **`Path.combine` performance** with many objects — union once per layer per frame; cull
  off-screen objects; cache when camera is idle if needed.
- **Inverse + uncertainty interaction** — define the band side precisely for inverted
  layers (band sits just outside the object boundary).
- **Plane accuracy** — planar bisector is an approximation; acceptable at city scale,
  revisit for geodesic correctness if needed (also applies to the M9 subspace cell).
- **Default-uncertainty migration (M8)** — bumping a stored `0` to `500` also resets a
  deliberately-chosen `0`; judged acceptable.
- **Subspace cell (M9)** — the main cell is the intersection of half-planes (always convex);
  iterate the clip carefully and offset each bisector edge for the band.
- **Overpass usage (M11)** — third-party rate limits and latency; zoom-gate, debounce, cache,
  cap results, and fail silently. Use a polite user-agent / a public instance.
- **Overlay tile sources (M10)** — third-party tiles (memomaps / OpenRailwayMap) need correct
  attribution and may have their own usage policies.

## Suggested order & checkpoints

**v1:** M0 → M1 are the backbone (do first, they unblock everything). M2/M3 are UX and can go
in parallel after M0. M4 and M6 are independent and can land any time. M5 depends on M0 + M1.

**v2:** M7 (compass) and M8 (settings) are small and independent — do them first. M10
(transport overlay) is independent and cheap. M9 (subspace) builds on the M5 plane geometry.
M11 (POIs) is the heaviest (Overpass + caching) — last. Every milestone ends green:
`flutter analyze`, `flutter test`, and an on-device check.
