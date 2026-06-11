# ZoneCraft — Roadmap / TODO

Backlog of planned features beyond v1. Grouped by area; check items off as they land.
Notes under each item are implementation hints, not final decisions. Open design
questions are collected at the bottom.

> **Progress:** **All milestones M0–M6 are done** — see `IMPLEMENTATION_PLAN.md`. The
> engine handles union/flat-colour, the uncertainty band, and inverse rendering for
> **circles and planes**; the layers **left drawer** (with visibility/reorder/colour/
> rename/**invert**/delete and a circles|planes **type chooser**), the docked **bottom
> editor**, **add/remove**, a **Settings screen** (global uncertainty radius), an opt-in
> **Locate me** button, and the **app icon + launch splash** are in. The v1 roadmap is
> complete; a round of **post-v1 refinements** (below) has also landed. Remaining items are
> future polish.

## Post-v1 refinements (done)

- [x] **Renamed the app to "ZoneCraft"** (launcher label, iOS display name, in-app title).
- [x] **Single coordinate field per point** ("lat, lng") in the circle/plane editors,
  accepting coordinates pasted straight from Google Maps. Shared parser `geo/coords.dart`.
- [x] **Edit-point markers:** while editing, the circle's centre / a plane's two endpoints
  show as dots on the map.
- [x] **Persisted map camera:** centre + zoom are saved (AppSettings, schema v3) and the
  app reopens on the same view.
- [x] **Full-bleed map:** removed the app bar; a single floating menu button (top-left)
  opens the layers drawer.

---

## UI & navigation

- [x] **Move the layers menu to a left side drawer.**
  - Replace the bottom-sheet `showLayersPanel` (`lib/ui/layers_panel.dart`) with a
    left `Drawer` opened from the AppBar / a hamburger button.
  - Keep all existing layer controls (visibility, reorder, colour, rename, active).

- [x] **Add an explicit add / remove button (object add/delete).**
  - A clear "add object" action and a "remove" action, instead of relying only on
    map taps. Add button creates an object in the active layer; remove deletes the
    selected object.
  - Decide how it pairs with the bottom edit menu below (e.g. add → object becomes
    selected → bottom menu opens for placement/tuning).

- [x] **Add a nice app icon / symbol.**
  - Replace the default Flutter launcher icon (`android/app/src/main/res/mipmap-*`,
    `ios/.../AppIcon.appiconset`). Use `flutter_launcher_icons` to generate all sizes
    from one source asset. Done: transparent rounded-square at `assets/icon/zonecraft.png`
    (+ adaptive foreground); also shown as the launch splash via `flutter_native_splash`.

## Object editing

- [x] **Edit objects via a bottom menu, not a dialog floating over the map.**
  - Replace the `AlertDialog` in `lib/ui/circle_editor.dart` with a persistent /
    docked **bottom panel** (e.g. bottom sheet that stays while the map is visible),
    so the map stays usable while editing.
  - Selecting an object on the map opens this bottom menu; it shows the object's
    fields (centre, radius, label, layer) plus add/remove.

## Location

- [x] **"Locate me" button to centre the map on the phone's position.**
  - **Strictly optional** — never force it. Only request location permission when the
    user taps the button; degrade gracefully if denied. No background location.
  - Likely `geolocator` + `permission_handler`. Show the current position marker only
    after explicit opt-in.

## Settings & uncertainty

- [x] **Add a general Settings screen.**
  - A place for app-wide options (persisted locally, e.g. a `Settings` table or
    key/value store via Drift / `shared_preferences`).

- [x] **Uncertainty radius as a global setting (e.g. 500 m).**
  - Configurable in Settings. Applied to objects so the **outer band** of the object
    is drawn lighter than the inner core, representing measurement uncertainty.
  - For a circle of radius `R` and uncertainty `u`: render an inner solid region and
    an outer, lighter band. See open question on which band (inner `R-u..R`, or an
    extra ring `R..R+u`).
  - Applies to planes too (lighter band along the dividing edge — see below).

## Layer behaviour

- [x] **Per-layer "inverse" toggle.**
  - When inverted, fill everything **not** covered by the layer's objects instead of
    the covered area (e.g. a circles layer fills the outside, leaving holes where the
    circles are). Store as a `isInverted` flag on the layer.

- [x] **Union rendering — overlaps don't darken.**
  - Overlapping objects within a layer (and overlapping layers) must show a **single
    flat colour**, not compounded opacity. The interior is one uniform colour; only
    the **uncertainty band** differs.
  - Implementation: composite each layer's objects as a unioned `Path` (or draw the
    union at full alpha) rather than stacking translucent polygons. The current
    per-polygon translucent fill in `lib/ui/map_screen.dart` `_buildPolygons` stacks —
    needs to change to a union/merge approach.

## New geometry types

- [x] **Layers are single-type: a layer holds circles **or** planes (or future types),
      not a mix.**
  - Add an object/layer `type` to the data model. The add button and editor adapt to
    the layer's type.

- [x] **"Plane" object: closer-to-one-of-two-points region.**
  - Defined by **two points**; the enabled region is all points **closer to one point
    than the other** — i.e. the half-plane on one side of the two points'
    perpendicular bisector. (Geodesic equivalent on the sphere.)
  - Has an **uncertainty area**: a lighter band straddling the bisector edge (width
    from the global uncertainty setting).
  - Works with the inverse toggle and union rendering like circles.

---

## v2 backlog (planned — see `IMPLEMENTATION_PLAN.md` M7–M11)

The next batch of features. Each general setting is stored in `AppSettings` and so persists
across close/relaunch by construction.

### Map chrome

- [x] **Compass control (M7).** A small button in the lower-right stack whose needle always
  points to map-north; tapping it snaps the map back to north-up (rotation = 0).

### Settings

- [x] **Default uncertainty = 500 m (M8)**, not 0. Migration bumps an existing stored `0` to
  `500`.
- [x] **All general settings persist (M8)** across app close/start (stored in `AppSettings`).
- [x] **"Clear all data" button (M8)** in Settings, behind a confirmation dialog — wipes
  layers/objects, resets settings, re-seeds an empty default layer.

### Map data overlays (toggled in Settings)

- [x] **Public-transport overlay (M10).** Load the train/bus network and stops — as an
  optional OSM-based tile overlay (ÖPNVKarte for buses/stops, OpenRailwayMap for rail).
- [x] **OSMAnd-style POIs (M11).** Toggle OSM POI categories (park benches, post boxes, …),
  fetched from Overpass and shown as markers, **only at high zoom** to match OSMAnd's
  behaviour (no clutter when zoomed out).
- [x] **Administrative borders (post-v2).** Toggle OSM `admin_level` boundaries individually
  (countries → states → counties → cities → districts → suburbs), each its own colour, fetched
  from Overpass (relations → member ways clipped to the viewport, tagged via `convert`) and
  drawn as polylines. Per-level zoom gating keeps queries bounded. Stored in
  `AppSettings.borderLevels` (bitmask, schema v8).

### New geometry type

- [x] **"Closest subspace" object (M9).** Like the two-point plane but with **N points**: one
  object holds all points, one is the **main** point, and the filled region is everywhere
  closer to the main point than to any other (its Voronoi cell). In a subspace layer the
  **Add** button adds *points* to the single object. Uncertainty band along the internal
  divides, and the per-layer **inverse** fills everything except the main cell.

---

## v3 backlog (planned — see `IMPLEMENTATION_PLAN.md` M12–M13)

User-drawn (freehand) regions, as opposed to the geometric primitives above.

### New geometry types

- [x] **"Freehand line" object (M12).** A user-drawn **polyline** that divides the map into
  two sides; the layer colours one side and the per-layer **invert** flips to the other. A
  partial line (e.g. a stretch of the Isar) is completed by **extending its first/last
  segments straight** so it still splits the whole view. New `freeline` layer type,
  `FreeLines` + `FreeLinePoints` tables (schema v9), `geo/freeline.dart`,
  `ui/freeline_editor.dart`.
- [x] **"Freehand area" object (M13).** A user-drawn **closed polygon**; the layer colours
  the inside and **invert** the outside (e.g. a city outline). New `freearea` layer type,
  `FreeAreas` + `FreeAreaPoints` tables (schema v9), `geo/freearea.dart`,
  `ui/freearea_editor.dart`.
- [x] **Signed per-object offset (M12/M13).** Each freehand object carries an
  `offsetMeters`, separate from the global uncertainty: positive pushes the coloured
  boundary away from the line / inward from the area ("inside the city **and** >5 km from
  the border"); negative extends the fill past the drawn boundary. The uncertainty band
  straddles the shifted boundary as before.

---

## Data model impact (Drift — `lib/data/database.dart`)

- `Layers`: `isInverted` (bool) and `type` ✅ done (circles | planes | **subspace** ✅ M9).
- `Circles` ✅ and `Planes` ✅ (two points). `Subspaces` + `SubspacePoints` ✅ (one object, N
  points, one `isMain`) added in M9 (schema v5).
- `AppSettings` ✅ holds uncertainty + camera + transport-overlay toggle ✅ (M10, schema v6) +
  enabled-POI-category bitmask ✅ (M11, schema v7) + enabled-border-levels bitmask ✅
  (post-v2, schema v8); **default uncertainty → 500** ✅ (M8).
- `FreeLines` + `FreeLinePoints` and `FreeAreas` + `FreeAreaPoints` ✅ (one object, N ordered
  points, signed `offsetMeters` on the parent) added in M12/M13 (schema v9).
- `Repository.clearAll()` for the clear-data button (M8).
- Remember to bump `schemaVersion` and add migrations for each (M8 → v4, then M9, M10/M11).

## Open questions / decisions (all resolved during v1)

1. **Uncertainty band geometry:** ✅ inner band `R-u..R` for circles (the band eats into
   the object); for planes the band straddles the dividing bisector.
2. **Plane region:** ✅ user-toggleable per plane (the "Nearer side: A | B" switch).
3. **Union across layers vs per layer:** ✅ flat union applies *within* a layer; different
   layers still composite (blend) over each other.
4. **Single source of truth for object type:** ✅ per-layer `type`, chosen at layer
   creation; a layer holds one object kind.

### v2 open questions

5. **Default-500 migration:** bumping a stored `0` to `500` also overrides a user who
   deliberately set `0`. Accepted (one tap to change) — confirm if a smarter "only if never
   touched" check is wanted instead.
6. **Transport data source:** rendered tile overlay (ÖPNVKarte / OpenRailwayMap — chosen for
   v1 simplicity) vs. interactive vector stops via Overpass (tappable, heavier). Start tiles.
7. **POI source & limits:** Overpass API at high zoom with debounce + caching. Which Overpass
   instance, how aggressive the cache/zoom-gate, and the initial category list?
8. **Subspace storage:** separate `Subspaces` + `SubspacePoints` tables (chosen) vs. a JSON
   point list on one row. Tables keep it relational and queryable.
9. **Subspace "main" + inverse:** exactly one main point per object; inverse fills the
   complement of the main cell. Confirm whether multiple "shown" cells are ever wanted (no —
   spec says one shown region).

---

> This is a living document — refine items and tick them off as we build. Each item is
> a candidate for its own focused implementation pass.
