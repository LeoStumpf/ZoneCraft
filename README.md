# ZoneCraft

A map app for placing **geodesic circles** on OpenStreetMap, organised into stackable
**overlay layers**. No login, no account — everything is stored locally on the device.

This is step 1 toward a broader tool for **geometry projections on maps**.

## Status

**The v1 roadmap is complete — all milestones M0–M6 are done**, plus a round of post-v1
refinements (rename, single-field coordinate input, edit-point markers, persisted map view,
full-bleed UI). See `IMPLEMENTATION_PLAN.md` for the milestone history and `PLAN.md` for the
feature backlog and remaining polish.

## Features

- OpenStreetMap base map (live tiles, no API key). **Full-bleed map** with a single floating
  menu button (top-left) opening the layers drawer.
- **Layers** in a left drawer that stack/overlay: show/hide, reorder, rename, recolour,
  **invert**, add, delete. A layer is **single-type** — it holds *circles* **or** *planes*
  (chosen when you add it); one active layer receives new objects.
- **Circles** are **geodesic** — the radius is in real-world metres and is drawn accurately
  on the globe (so it shows as an ellipse at high latitudes in Web Mercator, as it should).
- **Planes** — the "closer to one of two points" region (one side of two points'
  perpendicular bisector), with a toggleable near side.
- **Composited rendering engine:** a layer's objects are unioned into one flat-coloured
  region (overlaps don't darken), with a lighter **uncertainty band** (global, set in
  Settings) and an optional **inverse** fill (everything outside the objects). Works
  identically for circles and planes.
- **Docked editor:** tap an object to edit it live (map stays interactive). Coordinates use
  a single **"lat, lng"** field that accepts values pasted straight from Google Maps; the
  edited object's points are shown as markers on the map.
- Opt-in **"Locate me"** (location permission requested only on tap, never at launch).
- Fully local persistence via SQLite (Drift). Data — and your **last map view** (centre +
  zoom) — survive restarts. No login, no account.

## Tech stack

| Concern | Package |
|---|---|
| Framework | Flutter (Android-first, iOS-ready) |
| Map | [`flutter_map`](https://pub.dev/packages/flutter_map) |
| Geo math | [`latlong2`](https://pub.dev/packages/latlong2) |
| Local DB | [`drift`](https://pub.dev/packages/drift) + `drift_flutter` (SQLite) |
| State | [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) |

## Project layout

```
lib/
  data/        Drift database (Layers, Circles, Planes, AppSettings) + repository
  geo/         geodesicCircle(), plane half-plane geometry, lat/lng parsing
  state/       Riverpod providers (layers, circles, planes, settings, selection)
  ui/          map_screen, layers_panel (drawer), circle_editor & plane_editor
               (sheets), settings_screen, region_layer (rendering engine)
assets/icon/   app-icon source art (transparent PNG + adaptive foreground)
test/          geodesic_test, plane_test, coords_test, database_test
```

## Develop

```bash
flutter pub get
dart run build_runner build      # regenerate database.g.dart after schema changes
flutter analyze
flutter test
flutter run                      # on a connected Android device / emulator
flutter build apk --debug        # build an installable APK
```

## Roadmap

The v1 milestones (`IMPLEMENTATION_PLAN.md`) are all delivered. Future polish in `PLAN.md`:
offline tile caching, import/export (GeoJSON / KML), more shapes, geodesic refinement of the
plane bisector, and the broader geometry-projection features.
