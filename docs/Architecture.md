# Architecture

One page, not the whole reference. Flutter, `flutter_map` for the map, Riverpod for state,
Drift (SQLite) for storage, `package:http` for the four services. No backend of its own.

## Layout

```
lib/
  data/    Drift schema + repository (database.dart); the Overpass transport with endpoint
           failover (overpass_client.dart) shared by overpass.dart (POIs), transit.dart
           (stations) and borders.dart; request pacing + result caching
           (request_pacer.dart); Nominatim (place_search.dart); the tile-source policy
           (tile_source.dart); the offline tile cache (cached_tile_provider.dart) and why it
           stopped, in words (tile_health.dart); GeoJSON/KML export (serialization.dart)
           and GeoJSON/KML/KMZ/GPX import (geo_import.dart); terrain generation
           (height_generator.dart); the POI-set kinds + the one marker-visibility predicate
           (poi_sets.dart); the location gate (location.dart); the Android file channel
           (platform_files.dart); the three switchable service addresses
           (service_overrides.dart); the one outbound write, an OSM note (osm_notes.dart)
           and what it says (osm_report.dart); undo (undo_triggers.dart, undo_journal.dart)
  geo/     region geometry — geodesic circles, Voronoi cells (subspace), freehand
           line/area, height contouring by marching squares, border ring assembly and
           colouring, Douglas–Peucker simplification, slippy-tile maths, coordinate parsing
  state/   Riverpod providers — per-object streams, point rows pre-grouped by owner,
           settings, selection and placement, the map mode, folders resolved into layers
  ui/      map_screen (the map and everything docked to it), layers_panel (the drawer),
           layer_actions (the one definition of per-layer actions), layer_sheet,
           map_controls + map_controls_screen (every button named once), one *_editor per
           type on a shared editor_sheet, region_layer (the compositing engine), poi_layer
           and border_layer (the two painters outside it), the import dialogs,
           settings/about/service-policy screens, osm_report_sheet + osm_reports_screen
android/app/src/main/kotlin/.../MainActivity.kt   the only platform code: one MethodChannel
drift_schemas/   schema snapshots that guard the migrations
scripts/         build.sh, screenshots.sh
test/            unit tests + the guard tests listed in [Contributing](Contributing.md)
```

## The rendering contract

Every region type builds its boundary in **lat/lng**, geodesically, then a painter
(`ui/region_layer.dart`) projects it to screen and composites **one layer at a time**:

- Each object yields an `outer` and a `core` polygon (the difference is the uncertainty
  band). Within a layer they union with `Path.combine`, and the result paints as **core**
  (solid) + **band** (lighter) + outline — or **viewport − outer** when the layer is set to
  Fill outside. This single contract is why invert and the band behave the same for every
  region type.
- **Every band is painted below every fill, map-wide.** A band says *the region might reach
  here*; once elements could be reordered, a front element's band was landing on a back
  element's solid — the uncertain shape over the certain one. So each layer builds two
  widgets, a band pass and a fill pass, and the map stacks every layer's band pass under
  every layer's fill pass. Within a layer the two are kept disjoint with `BlendMode.clear`,
  never with a path-op. At 0 m uncertainty the band pass is not built at all.
- **Elements carry their own colour.** The painter runs one pass per run of consecutive
  same-colour elements in stack order, composited with `BlendMode.src` inside one
  `saveLayer`, so the front-most element wins an overlap and fills stay flat. A layer set to
  Fill outside stays single-colour: its fill is the complement and belongs to no element.
- Geometry that does not depend on the camera — buffered offsets, Voronoi clips, circle
  rings — is resolved once and memoised; a pan re-projects cached rings.
- **Freehand areas, borders and POIs have their own painters.** Buffered city-sized outlines
  are exactly the input Skia's path-ops fail on, so those composite by overpainting inside a
  layer rather than by boolean operations. POIs are icon markers with greedy screen-space
  clustering, no region compositing at all.
- **There is no cross-layer compositing anywhere.** A folder's *Fill outside* flips each
  member's own switch; `resolveLayers` folds a folder into its members (`visible && folder
  visible`, `inverted != folder inverted`) and that is the whole rendering change — the band
  sweep, the fill loop and the hit test read the resolved list and know nothing about folders.

## One definition, many surfaces

The pattern that recurs most: something the user sees in three places is *defined* in one,
and a test says so.

| Defined once in | Rendered by | Guarded by |
|---|---|---|
| `ui/layer_actions.dart` — which actions a layer type gets, their labels and descriptions, and whether one is unavailable and why | the drawer's ⋮ menu, the layer sheet, the bottom-row switch, the FAB tooltip | `layer_actions_test.dart` over every type |
| `ui/map_controls.dart` — every map control's name, what it does, when it is absent | the buttons' tooltips and the *What the buttons do* screen | `map_controls_test.dart` (no shared icons in an area) |
| `poiPointVisible` in `data/poi_sets.dart` — is this marker drawn? | the POI painter **and** the hit test, so what is drawn is exactly what is tappable | — |
| `layerHasEditor` in `ui/object_summary.dart` — can this kind be selected? | Select-by-tapping's arming, the info chip's Edit | `selection_test.dart` keeps an explicit set of unselectable kinds |
| `zoneCraftUserAgent` in `app_info.dart` | every HTTP call | `app_info_test.dart` (carries `kAppVersion`) |
| the app id, written in five places no compiler compares | Gradle, Kotlin, the MethodChannel on both sides, the UA, the scripts | `app_id_test.dart` reads the files |
| `parseDecimal` in `geo/coords.dart` | every number field | — (a rule, see [Contributing](Contributing.md)) |

## Controls that cannot act

A control that cannot act is **greyed, and says why when pressed** — `onPressed: null` would
make a button untappable, so the one moment a user wants an explanation would be the one
moment it could not give one. Unavailable controls stay live and are only painted disabled.
Where there is room (the layer sheet, the drawer) the reason is printed under the option and
the row goes inert; where there is not (the map's bare icon buttons) the press answers. A
control the layer's *type* can never use is hidden: "never" is not a thing to wait for. These
answers are never counted by the tips system (`UiHints`), which silences a tip after three
showings — *"why did nothing happen?"* has to come every time.

## Map gestures

`flutter_map`'s own rotation stays off (a horizontal pinch reads as a 359° twist there); a
`TwistDetector` gates rotation on a deliberate ≥ 20° twist and a `TwoFingerTapDetector` adds
the two-finger zoom-out `flutter_map` lacks. Both are fed by one watching `Listener` around
the map, never in the gesture arena. Every camera move the app makes glides through one
animation routine; a user gesture stops it. A tap never moves the camera.

## Undo

Undo is a journal written by SQLite triggers (`data/undo_triggers.dart`) and replayed by
`data/undo_journal.dart`: every table is journalled except the tile cache, the hint counters
and the OSM outbox (`undoExcludedTables`) — pressing a button is not an edit, and undoing a
report already sent would be a lie. Up to 50 steps, each named.

## Where the full reference is

The architecture reference with the measurements and the history behind each of these
decisions is a local planning document, not in the repository. The source files' header
comments carry the same reasoning next to the code — most files open with *why*, not *what*.
