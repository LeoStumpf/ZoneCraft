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
  POI/border overlays, so the map survives a few minutes with no reception.
- Fully local SQLite (Drift), **schema v10**.

## Open points

### 1. Import / export (GeoJSON / KML)

Save layers and objects to a file and load them back. The most-requested next step.

- Serialise per object type (circle → point+radius, plane/subspace/freehand → point
  lists, plus layer colour/type/invert/offset) to **GeoJSON** features; consider **KML**
  for interop with Google Earth / Maps.
- Round-trip through the existing `Repository` CRUD; reuse the `geo/coords.dart` parsing
  conventions. Decide on a sharing mechanism (share sheet vs. file picker) and whether
  import merges into existing layers or creates new ones.

### 2. Offline — "download this area"

Add an explicit bulk-download for guaranteed offline coverage beyond the automatic browse
cache + one-tile prefetch ring.

- A Settings/map button that downloads all tiles for the current viewport across a few
  zoom levels (base map + enabled overlays) into the existing `TileCache`, with a progress
  indicator and a size estimate.
- Reuse `geo/tiles.dart` tile enumeration and `CachedTileProvider.prefetch`; respect the
  200 MB LRU cap (or let this pin an area exempt from eviction — decide).

---

> Living document — add open points as they come up, and move them to
> [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) as architecture notes once delivered.
