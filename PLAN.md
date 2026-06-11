# ZoneCraft — Roadmap

A short overview of what's built and what's still open. For *how* it's built, see
[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) (architecture reference).

## Current state

ZoneCraft is feature-complete for everything planned so far. It has:

- **Five object types**, one per layer: circle (geodesic), plane (closer-of-two-points),
  subspace (closest-of-N Voronoi cell), freehand line, freehand area — all driven by one
  compositing engine (union / flat colour / uncertainty band / per-layer **invert**).
- **Layers** drawer (show/hide, reorder, recolour, rename, invert, add/delete, type
  chooser), docked **per-type editors**, add/remove, **compass**, opt-in **Locate me**,
  persisted camera, full-bleed map.
- **Settings**: global uncertainty (default 500 m), clear-all, and overlay toggles.
- **Optional overlays**: public-transport tiles, OSMAnd-style POIs, administrative borders.
- **Offline resilience**: cache-first map tiles + viewport prefetch and persisted
  POI/border overlays, so the map survives a few minutes with no reception. Plus an
  explicit **"download this area"** button (map FAB) that bulk-caches the current view
  across a few zoom levels, with an estimate, a progress dialog and cancel.
- **Import / export**: share all layers + objects as **GeoJSON** (lossless round-trip) or
  **KML** (Google Earth / Maps); import GeoJSON back as new layers (Settings → Import & export).
- Fully local SQLite (Drift), **schema v10**.

## Open points

_None — everything on the roadmap has shipped._ Add new ideas below as they come up.

---

> Living document — add open points as they come up, and move them to
> [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) as architecture notes once delivered.
