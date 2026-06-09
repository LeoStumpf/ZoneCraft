# Zonecraft

A map app for placing **geodesic circles** on OpenStreetMap, organised into stackable
**overlay layers**. No login, no account — everything is stored locally on the device.

This is step 1 toward a broader tool for **geometry projections on maps**.

## Features (v1)

- OpenStreetMap base map (live tiles, no API key).
- **Layers** that stack/overlay: show/hide, reorder, rename, recolour, add, delete.
- Each layer holds **multiple circles**. Tap the map to drop a circle in the active layer.
- Circles are **geodesic** — the radius is in real-world metres and is drawn accurately
  on the globe (so it shows as an ellipse at high latitudes in Web Mercator, as it should).
- Tap a circle to edit its centre, radius, label, or layer, or to delete it.
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
  data/        Drift database (Layers, Circles) + repository
  geo/         geodesicCircle() ring generator
  state/       Riverpod providers
  ui/          map_screen, layers_panel, circle_editor
test/          geodesic_test.dart
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

- Offline tile caching
- Import/export (GeoJSON / KML)
- More shapes (polygons, lines, sectors) and the geometry-projection features
