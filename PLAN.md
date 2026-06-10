# Zonecraft — Roadmap / TODO

Backlog of planned features beyond v1. Grouped by area; check items off as they land.
Notes under each item are implementation hints, not final decisions. Open design
questions are collected at the bottom.

> **Progress:** M0 (data model + settings), M1 (rendering engine), M2 (UI restructure) and
> M3 (settings screen + uncertainty UI), M4 (opt-in locate-me) and M5 (plane object type)
> are **done** — see `IMPLEMENTATION_PLAN.md`. The engine handles union/flat-colour, the
> uncertainty band, and inverse rendering for **circles and planes**; the layers **left
> drawer** (with visibility/reorder/colour/rename/**invert**/delete and a circles|planes
> **type chooser**), the docked **bottom editor**, **add/remove**, a **Settings screen**
> (global uncertainty radius), and an opt-in **Locate me** button are in. Remaining: the
> app icon.

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

- [ ] **Add a nice app icon / symbol.**
  - Replace the default Flutter launcher icon (`android/app/src/main/res/mipmap-*`,
    `ios/.../AppIcon.appiconset`). Use `flutter_launcher_icons` to generate all sizes
    from one source asset.

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

## Data model impact (Drift — `lib/data/database.dart`)

- `Layers`: add `isInverted` (bool) and `type` (enum: circles | planes | …).
- New object representation: either extend `Circles` into a generic `Objects` table
  with a `type` + type-specific columns, or add a separate `Planes` table
  (two points: `aLat,aLng,bLat,bLng`). Decide during design.
- New `Settings` storage for the global uncertainty value (+ future options).
- Remember to bump `schemaVersion` and add migrations.

## Open questions / decisions

1. **Uncertainty band geometry:** is the lighter band the *inner* ring `R-u..R`
   (uncertainty eats into the circle), or an *extra outer* ring `R..R+u` (uncertainty
   extends beyond)? The note says "outer 500 m of the circle" → leaning inner band
   `R-u..R`. Confirm.
2. **Plane region:** which of the two points' side is "enabled" — fixed, or
   user-toggleable per plane?
3. **Union across layers vs per layer:** does "overlaps don't darken" apply only
   within a layer, or also between different layers of the same colour? (Different
   colours presumably still blend where they overlap.)
4. **Single source of truth for object type:** per-layer `type` (chosen here) vs
   per-object — confirm a layer is locked to one type once it has objects.

---

> This is a living document — refine items and tick them off as we build. Each item is
> a candidate for its own focused implementation pass.
