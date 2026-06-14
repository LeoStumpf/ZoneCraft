# ZoneCraft — Roadmap

A short overview of what's built and what's still open. For *how* it's built, see
[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) (architecture reference).

## Current state

ZoneCraft is feature-complete for everything planned so far. It has:

- **Six object types**, one per layer: circle (geodesic), plane (closer-of-two-points),
  subspace (closest-of-N Voronoi cell), freehand line, freehand area, and **height**
  (terrain above/below an elevation, bounded to a circle) — all driven by one compositing
  engine (union / flat colour / uncertainty band / per-layer **invert**).
- **Layers** drawer (show/hide, reorder, recolour, rename, invert, add/delete, type
  chooser), docked **per-type editors**, add/remove, **compass**, opt-in **Locate me**,
  persisted camera, full-bleed map.
- **Settings**: global uncertainty (default 500 m), clear-all, and overlay toggles.
- **Optional overlays**: public-transport tiles, OSMAnd-style POIs, administrative borders.
- **Offline resilience**: cache-first map tiles + viewport prefetch and persisted
  POI/border overlays, so the map survives a few minutes with no reception. Plus an
  explicit **"download this area"** button (map FAB) that bulk-caches the current view
  across a few zoom levels, with an estimate, a progress dialog and cancel.
- **Import / export**: share all layers + objects (or a **single layer**, from the layers
  drawer) as **GeoJSON** (lossless round-trip) or **KML** (Google Earth / Maps); import
  back as new layers **or merged into an existing same-type layer**. Import accepts
  ZoneCraft GeoJSON plus generic **GeoJSON / KML / KMZ / GPX**, so tracks/borders drawn in
  other apps can be brought in as freehand lines/areas (per-layer "Import track…").
- **Height layer**: enter an elevation; the layer colours terrain above (or below) it inside
  a chosen circle. "Generate" fetches public AWS Terrarium terrain tiles (cache-first),
  contours the threshold with marching squares off the UI thread, and stores the fill
  polygons so it renders cheaply and offline thereafter. The global uncertainty shows as a
  lighter band just outside the height border (the solid core stays solid). A map
  **"Measure elevation"** probe reads the height of any tapped point, and "Locate me" shows
  the elevation at your current position.
- Fully local SQLite (Drift), **schema v11**.

## Open points

_None — everything on the roadmap has shipped._ Add new ideas below as they come up.

Possible future polish (not committed): elevation-band mode (between two thresholds),
contour simplification to shrink stored polygons, and exporting generated height polygons
(currently only the region's parameters export; the importer regenerates).

---

> Living document — add open points as they come up, and move them to
> [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) as architecture notes once delivered.
