# Zonecraft

A map app for placing **geodesic circles** on OpenStreetMap, organised into stackable
**overlay layers**. No login, no account — everything is stored locally on the device.

This is step 1 toward a broader tool for **geometry projections on maps**.

## Status

Milestones **M0–M2 are complete** (data model + settings, rendering engine, UI
restructure). See `IMPLEMENTATION_PLAN.md` for the full roadmap and `PLAN.md` for the
feature backlog. Up next: **M3** settings screen (uncertainty value), then locate-me,
plane objects, and the app icon.

## Features

- OpenStreetMap base map (live tiles, no API key).
- **Layers** in a left drawer that stack/overlay: show/hide, reorder, rename, recolour,
  **invert**, add, delete; one active layer receives new objects.
- Each layer holds **multiple circles**. Tap the map (or the *Add circle* button) to drop
  a circle in the active layer.
- Circles are **geodesic** — the radius is in real-world metres and is drawn accurately
  on the globe (so it shows as an ellipse at high latitudes in Web Mercator, as it should).
- **Composited rendering engine:** a layer's objects are unioned into one flat-coloured
  region (overlaps don't darken), with a lighter **uncertainty band** and an optional
  **inverse** fill (everything outside the objects).
- **Docked editor:** tap a circle to edit centre, radius (slider), label, or layer — live,
  with the map still interactive — or remove it.
- Fully local persistence via SQLite (Drift). Data survives restarts.

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
  geo/         geodesicCircle() ring generator
  state/       Riverpod providers (layers, circles, planes, settings, selection)
  ui/          map_screen, layers_panel (drawer), circle_editor (sheet), region_layer
test/          geodesic_test.dart, database_test.dart
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

Near-term milestones (`IMPLEMENTATION_PLAN.md`): settings screen (uncertainty value),
opt-in "locate me", **plane** objects ("closer to one of two points"), app icon.

Later: offline tile caching, import/export (GeoJSON / KML), more shapes, and the broader
geometry-projection features.
