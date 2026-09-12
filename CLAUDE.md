# ZoneCraft — working notes for Claude

Flutter app: composable **zone layers** on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

## At a glance (current app)

- **Seven object types**, one per layer (or several at once — see **combined layers** below):
  `circles` (geodesic), `subspace` (closest-of-N Voronoi cell; with two points it is the
  closer-of-two half-plane — the former `planes` type, which v27 folded in), `freeline` (drawn
  polyline dividing the view), `freearea` (drawn closed polygon), `height` (terrain
  above/below an elevation, bounded to a circle; generated from terrain tiles via marching
  squares, stored as fill polygons; any generated region can be **converted to a freehand
  area** — outer contours only, holes dropped, the same contract as the border conversion),
  `poi` (markers, in three kinds of **set** told apart by `PoiSets.source` — see **POI
  sets** below: a `radius` category import, a `box` **station** import (the former `transit`
  type, folded in at v27) and a `manual` hand-made category; rendered as icon markers that
  collapse into count-badge clusters when they'd overlap — no region compositing; the import
  FAB offers both imports),
  `borders` (administrative **areas** of one OSM `admin_level`, chosen when the layer is
  created, fetched **once** over a tap-two-corners bbox and stored offline; whole relations
  are downloaded — clipped member ways have no fillable interior — then assembled and
  thinned on the device. **Nothing is cut to the box**: the box limits what is fetched, not
  what is kept, so an area may reach well past it. Drawn as outlines in the layer colour
  with two per-layer toggles, **Colour areas** (a 6-colour palette assigned so no two
  neighbours match, adjacency = shared OSM way id) and **Show names**. The Elements list
  names the **areas** ("Maxvorstadt"), not the imports, and each row can be
  **converted to a freehand area layer** — the offline twin of the by-name feature import,
  and the only way geometry leaves this read-only snapshot).
  The region types have a `geo/*.dart` region builder and a `ui/*_editor.dart` docked editor.
  **Three types are gone**: `planes` and `transit` were folded into `subspace` and `poi` by
  the v27 migration (rows retyped, ids kept), `track` (GPS recording) was dropped with its
  data. The GeoJSON reader still translates a v1/v2 file's `plane`/`transitstop` kinds and
  `planes`/`transit` layer types (`legacyLayerType`); `track` objects and layers are skipped.
- **POI sets** (`data/poi_sets.dart`): `PoiSets.source` is the **one** discriminator
  (`manual` / `radius` / `box`), replacing the v25 `isManual` bool; read it through the
  `PoiSetKind` extension (`isManual`, `isStationImport`, `isImport`, `isPending`, `bbox`). A
  box set stores its bbox, `modeMask` (types **fetched**) and `visibleModeMask` (types
  **shown**), and its points carry `PoiPoints.modeMask`; its NOT NULL centre/radius are
  derived from the box (`boxCoveringRadiusMeters`, used by the repository **and** the
  migration so the two agree). **Every import is born pending** (`fetchedAt` null — the
  Elements list shows a retry row) and `fillPoiSet` marks it done; `createPoiSet` +
  `fillPoiSet` + `markPoiImportFailed` are the one lifecycle both imports share
  (`map_screen._fetchWithProgress` / `_settleImportRow`). `poiPointVisible(point, set)` is
  **the one drawn == tappable predicate** (painter and hit test): a box set filters by
  `transitStationVisible`, every other kind always draws. A station icons itself from its
  modes (`poiPointIcon`); station name plates appear from zoom 14, other POIs' always.
  "Stations…" shows only once the layer holds a box set; the Elements list carries the same
  switch as a tick box on each station type's group heading.
- **Compositing engine** (`ui/region_layer.dart`): per layer, every object yields an
  `outer`+`core` screen-space polygon; these union via `Path.combine`, then paint core (solid)
  + band (`outer−core`, lighter) + outline, or `viewport−outer` when the layer is **inverted**.
  Global uncertainty widens the band; freehand objects add a signed per-object `offsetMeters`.
- **Every band is painted below every fill, map-wide** (`RegionPhase`). A band says the region
  *might* reach here; once elements could be reordered, a front element's band started landing
  on a back element's solid — the uncertain shape drawn over the certain one. So each layer
  builds **two** `RegionLayer` widgets, and `map_screen` stacks every layer's `band` pass
  (`bandPassLayers`, straight above the base tiles) below every layer's `fill` pass. Bands keep
  the same relative order the fills have. At **0 m uncertainty the band pass is not built at
  all**, so the render is exactly what it was before the split.
  The load-bearing part is that the two passes composite separately (they are separate
  widgets), so a band left *under* a fill would blend with it into a third colour — the very
  thing the flat-union model exists to avoid. Within a layer they are therefore kept
  **disjoint** by `BlendMode.clear`, never by a path-op: the band pass draws the whole
  footprint and then clears the fill pass's area out of itself, and because those clears are
  **deferred to the end of the layer** (`_deferredClears`) they remove *other* colour runs'
  fills too — clearing per run as it goes would let a front run's band paint over a back run's
  already-cleared fill. `freeline`/`height` are the mirror image (their band is a stroke
  *inside* their own fill), so there the **fill** pass punches the strip out and the band pass
  below shows through. Dropping the old `outer − core` difference also removed the one
  `_tryCombine` in the engine — Skia path-ops' worst case, two near-parallel outlines.
- **Every layer action is defined once** (`ui/layer_actions.dart`): `visibleLayerActions`
  (pure, tested over every type) says *which* actions a layer gets, `layerActionsFor` attaches
  label + body, and three surfaces render the list — the drawer's ⋮ menu, the map's **layer
  sheet** and the FAB row's **quick toggle**. Never add a per-layer action inline in one of
  them. Actions that need the map (an import's form, a mode's banner, a border import over
  the visible bounds) are `needsMap` and only post a `MapRequest` (`mapRequestProvider`, the
  `pendingImportRetryProvider` shape); `map_screen._runMapRequest` answers post-frame, so the
  asker must dismiss itself first. Deleting a layer / making it combined ends in a snackbar
  with UNDO that goes through the `ProviderContainer` (`applyUndoIn`), because the tile that
  raised it is unmounted by the time the button is pressed; the drawer has its own
  `ScaffoldMessenger` since a Scaffold draws its drawer above its snackbars.
- **The active layer is always on screen**: the chrome row ends in a chip (swatch · type ·
  name) that opens the **layer sheet** (`ui/layer_sheet.dart`) — a switcher row plus every
  setting of the active layer as a direct control, two taps from the map to anything the
  drawer's ⋮ offers. The sheet is opened with the *map's* context/ref and pops itself before
  a `needsMap`/delete action runs. Beside Edit, one **per-type quick toggle** FAB: borders →
  Colour areas, region layers → Invert, a POI layer with stations → the type filter.
- **A View-mode tap *shows* but never *changes*.** It selects, creates and deselects nothing
  (nudging the map must never open or close an editor); what it may do is raise the transient
  **info chip** naming what was hit, whose Edit button is the deliberate act. **Hits are
  cross-layer** (`_hitsAt` spans every visible layer with an editor; `HitCandidate.layerZ`
  ranks above the per-table `z` and below edge distance / size) and choosing one makes its
  layer active — so an element you can see is always reachable, whichever layer is active.
  ✎ Edit mode is enabled when *any* visible layer holds something to select. The four
  top-centre banners and the chip stack in one column under the chrome row (`kBannerTop`).
  The same rule covers a **cluster badge**: tapping one shows a chip, it never zooms.
- **Map gestures follow Google Maps** (`map_screen._interactionOptions`, `ui/two_finger_gestures.dart`).
  Double-tap zooms in at the finger, **two-finger tap zooms out** around the fingers
  (`TwoFingerTapDetector` — flutter_map has no such gesture), and **rotation is never
  flutter_map's**: its `rotate` flag stays off because without its multi-finger race every
  wobble of a pinch turned the map, and *with* the race a horizontal pinch reads as a 359°
  twist (Flutter's `ScaleUpdateDetails.rotation` is un-normalised and flutter_map compares
  `.abs()` — measured on device, still so in 8.3.2). `TwistDetector` gates it instead: a
  deliberate ≥ `kRotationThresholdDegrees` (20°) twist, then the map follows the fingers via
  `rotateAroundPoint`; pinch zoom/pan stay flutter_map's throughout. Both detectors are fed
  by one *watching* `Listener` around `FlutterMap` (`HitTestBehavior.translucent`, never in
  the gesture arena). **Every camera move the app makes itself glides** through
  `_animateTo`/`_animateToFit` (`kCameraGlide`; a user gesture stops it, a continent-away hop
  cuts) — Locate me, Zoom to, a received place, an import fit, a cluster's Zoom in, the
  two-finger tap. **Double-tap zoom is off only while a tap *places*** (Add, Draw, the
  measuring modes, an armed placement — two quick corner taps must not become a zoom); View
  and ✎ Edit keep it. **A tap never moves the camera**: a cluster badge raises the info chip
  ("12 POIs · layer" with a *Zoom in* button, the same deliberate act as an element chip's
  Edit) instead of zooming on its own — `_InfoTarget` is `_HitInfo | _ClusterInfo`.
- **Layers drawer** (show/hide, reorder, recolour, adjust opacity, rename, invert, add/delete),
  plus a pinned bottom **Map** tile (the base OSM tiles as a hideable, opacity-adjustable
  layer that can never be deleted or reordered; its state lives in `AppSettings`) + **compass**,
  opt-in **Locate me** (also reads the terrain elevation there), a **Measure-elevation**
  probe (tap any point for its height), **persisted camera**, and a **Settings** screen
  (uncertainty, clear-all, offline cache, import/export).
- **No map overlays.** All three global Settings toggles are gone: map POIs became the
  `poi` layer type, public-transport tiles and administrative borders were superseded by
  `poi` station imports and `borders`. `AppSettings.transportOverlay` / `.borderLevels` survive as
  documented **dead columns** (the precedent `poiCategories` set), as does the now-unused
  `OverpassCache` table.
- **Offline caching:** a Drift-backed `TileCache` + custom `CachedTileProvider`
  (`data/cached_tile_provider.dart`) serve map tiles cache-first then network, with LRU
  eviction (200 MB cap) + a Settings size readout / "Clear cached map tiles" button.
  Caching what you *displayed* is required by OSM's policy and always on.
- **Pre-emptive tile fetching is gated on the tile source** (`data/tile_source.dart`).
  The one-tile-ring **viewport prefetch** (`map_screen._prefetchTiles`) and the
  **"Download this area"** button are both "bulk downloading" under OSM's tile policy —
  which defines it as *any* pre-emptive fetching, so there is no compliant ring size — and
  are therefore **off by default**. They switch on only when the build sets
  `--dart-define=TILE_URL=...` (a keyed provider or your own server); `scripts/build.sh`
  forwards `TILE_URL`/`TILE_ATTRIBUTION` from the environment. Never flip
  `TileSource.allowsPrefetch` for the community server — `test/tile_source_test.dart`
  guards it.
- **One Overpass client** (`data/overpass_client.dart`): endpoint failover, transient-vs-fatal
  status handling and a size cap, shared by `transit.dart` (station fetch + merge),
  `borders.dart` **and `overpass.dart`** (POI imports) — all three return `OverpassOutcome` and drive the shared
  `ui/import_progress.dart` dialog. The endpoint that last answered is remembered in
  `AppSettings.transitEndpoint` (old name, shared use).
- **ZoneCraft is AGPL-3.0-or-later** (`LICENSE` is the verbatim FSF text). **Every
  non-generated `.dart` file carries the 15-line licence header** — `test/license_test.dart`
  fails when a new one does not, and also fails if the docs drift back to the old licence.
  Generated code (`*.g.dart`, `test/generated_migrations/`) is deliberately exempt: a header
  there would not survive the next `build_runner` run. The licence covers ZoneCraft's own code
  only; bundled packages keep theirs (`THIRD_PARTY_NOTICES.md` and the in-app **Open-source
  licences** page, which is Flutter's `showLicensePage`).
- **The About screen's links are real links** (`url_launcher`). They need the `https`
  `<intent>` in the Android manifest's `<queries>` block: since API 30 a package is invisible
  unless queried for, so without it `canLaunchUrl` reports no browser and every link silently
  does nothing. `_AboutScreenState` probes that **once** for the whole screen — all the links
  are `https`, so the answer is the same for each — and falls back to selectable text rather
  than a link that would do nothing.
- **No telemetry, ever.** No crash reporting, no analytics, no advertising id. Sentry was
  wired in and deliberately removed: `PRIVACY.md` and the Play Data safety form can now
  answer "none", which is worth more than the diagnostics were. Anything added back has to
  be reflected in both.
- **Every outbound HTTP call is timed out.** `package:http` has no default timeout, so each
  call site sets one explicitly (`kTerrainTileTimeout`, `CachedTileProvider.fetchTimeout`,
  the Overpass per-request budgets), plus `kHeightGenBudget` as an overall deadline on a
  height generation and a `timeLimit` on `getCurrentPosition`. Add one to any new call.
- **Requests to the donated OSM services are paced** (`data/request_pacer.dart`).
  `nominatimPacer` (1.1 s — the policy's ceiling is 1 req/s) and `overpassPacer` (1 s) queue
  and space calls; they are **pacers, not debouncers** — these are explicit user actions, so
  a late request is right and a dropped one would look like a dead button. Nominatim results
  additionally go through `placeSearchCache` (a `QueryCache`), because its policy *requires*
  client-side caching and blocks clients that repeat identical queries. **Never add
  autocomplete/per-keystroke geocoding** — the policy forbids it outright.
- **Number entry goes through `parseDecimal`** (`geo/coords.dart`), never bare
  `double.tryParse` — a comma-decimal locale would otherwise make the field silently no-op.
- **Editors use the shared shell** (`ui/editor_sheet.dart`): `EditorSheet` (capped at 60 %
  of the viewport, scrolls the rest), `EditorLayerPicker` (one-line ellipsis) and
  `scaledPx(context, px)` for any pixel size chosen against text. A bottom sheet clips
  **silently** — no overflow stripes — so a plain `Column` of `Row`s loses its bottom rows
  at a large system font. Prefer `Wrap` over `Row` for label+field pairs.
- **Per-layer & external import/export:** besides whole-DB GeoJSON/KML, each layer can be
  exported alone and files imported as a new layer or **merged** into an existing same-type
  one (`ui/import_actions.dart`); generic **GeoJSON/KML/KMZ/GPX** tracks import into freehand
  layers (`data/geo_import.dart`). There is **one routine** for both scopes —
  `Repository.exportData({onlyLayerId})` and `importLayerFlow` — so a per-layer file and a
  whole-DB file differ only in how many layers they hold.
- **The GeoJSON export is a fixed point** (format schema **v2**, `geoJsonSchemaVersion`):
  `export → import → export` must be byte-identical, and `test/export_roundtrip_test.dart`
  asserts exactly that against real rows for all seven types, alongside a whole-DB and a
  per-layer round-trip. **Anything the DB stores and the UI shows has to survive the trip** —
  so a hidden layer stays hidden, a `height` region travels **with its generated fill rings**
  (regenerating needs the network and the layer draws *nothing* until it happens), POIs keep
  their `osmType`/`osmId` (dedup identity — without it a re-import draws them all twice), a
  station import keeps its box, masks and per-point modes (a box set writes **no**
  `radiusMeters` — it is derived), a border area keeps its import's `setLabel`, and a failed
  import comes back as its retry row. Format is **v3** (`geoJsonSchemaVersion`).
  `serialization_test.dart` covers the pure model; it is the *repository* half where losses
  hide, because that is the half nothing used to look at. Deliberately not preserved: `createdAt`,
  a border set holding **zero** areas (the format has no representation of a set), and the
  original `editedAt`/`fetchedAt` instants (the *flag* travels, the timestamp is new).
- **Imported geometry is thinned only when the file is foreign.** `importData`/`mergeIntoLayer`
  take `simplify` (default **true**, for GPX jitter and thousand-point city lines);
  `importLayerFlow` passes `simplify: !fromZonecraft`, because RDP-thinning what this app
  itself wrote makes an export/import silently change shapes — and do it again every round-trip.
- **`osmKey` treats id `0` as no identity at all.** It is not a valid OSM id; it is the
  placeholder an id-less imported row is stored with (`BorderAreas.osmId` is NOT NULL). Read as
  a real id it made every such area look like the same relation, so a re-import kept one and
  dropped the rest.
- **Drift schema is at v27**; migrations are append-only `if (from < N)` blocks. (Two
  exceptions drop tables: v19 *drops* the transit route tables, because route geometry was
  abandoned — see `data/transit.dart`'s header for the measurements behind that — and v27
  copies `planes` → `subspaces` and `transit_*` → `poi_*` then drops them, plus `tracks`.
  Earlier blocks that once `createTable`d a dropped table no longer do; the raw `ALTER
  TABLE`s in v22/v26 keep the columns v27 copies on a database old enough to have them.)
  v20…v27 are
  snapshotted in `drift_schemas/` and guarded by `test/migration_test.dart`. **Any schema change must dump a
  new snapshot** (`dart run drift_dev schema dump lib/data/database.dart drift_schemas/`, then
  `... schema generate drift_schemas/ test/generated_migrations/`) — a snapshot cannot be
  reconstructed after the version ships, and the test fails until it exists.
- **Elements carry their own colour** (`ui/element_color.dart`, schema v22). Every element
  has a nullable `colorArgb` override and a `colorShade` slot; **shade 0 is the layer colour
  exactly**, which is what every pre-v22 row migrated in as, so an old map is untouched. With
  no override an element paints an auto *shade* of the layer colour (same hue, van der Corput
  lightness), so new elements tell each other apart and all follow a layer recolour. The
  region painter runs **one pass per run of consecutive same-colour elements** in the layer's
  stack order (`ui/paint_order.dart`'s `colorRuns`), composited with `BlendMode.src` inside
  one `saveLayer`, so the front-most element wins an overlap and fills stay flat. Global
  colour *groups* could not express green → blue → green, which is the first thing a
  reorder produces. Inverted layers
  stay single-colour: their fill is the complement, which belongs to no element.
- **Point rows reach the renderer pre-grouped by owner** (`state/providers.dart`'s
  `*By*Provider`s build `Map<ownerId, List<point>>` once per stream emission). `RegionLayer`
  takes maps, not flat lists: it rebuilds on every camera tick, so a linear scan per object
  there costs O(objects × all points) *per frame*.
- **Every type has an editor** (`layerHasEditor` in `ui/object_summary.dart` is the one
  definition, and returns **false** for an unknown type so Edit mode can't arm tap-to-select
  against something nothing opens). `selection_test.dart` keeps an explicit — currently
  empty — `unselectable` set so a future kind without a selection has to be stated. The
  imports' editors are scoped to what a snapshot can honestly offer: `poi_set_editor`
  (label, layer; a station import's *shown* types — never its box, radius or fetched types,
  which describe a query that already ran; a hand-made category's icon; a pending import's
  error and a Try again), `imported_point_editor` (one POI or station — the same row:
  **rename and delete only** — a position is the fetched fact, and no column would say one
  had been moved), and `border_area_editor`. Individual POIs/stations are [ObjectKind]s
  (`poiPoint`) but **not elements** (`isElement`): `layerSummariesProvider` — what the
  drawer, the layer sheet and the recolour picker *count* — still yields one row per set.
- **The Elements list lists everything, and POIs by type** (`ui/layer_objects_sheet.dart`).
  Three pure, tested layers feed one `ListView.builder`: `object_summary.dart` (one
  `ObjectSummary` per element, now with `sortName` + a per-kind `sizeMeasure`, and lines /
  areas quoting their ground length / area from `geo/measure.dart`), `ui/poi_groups.dart`
  (a POI layer's *points* filed under `PoiTypeGroup`s — a category across every import of
  it, a station's `primaryTransitMode` — the same pick `transitIconFor` makes, so icon and
  group can't disagree — or a hand-made category, which is its own group and appears
  nowhere else), and `ui/elements_list_model.dart` (`buildElementRows`: sort, search, which
  groups are open). The **Imports** section holds the sets, collapsed; a **pending import's
  retry row floats to the top** so no fold can hide it. A station group's heading carries the
  visibility tick box (`setPoiVisibleModes`, the same write as the Stations sheet; the
  Rail-only/Show-all/Hide-all `TransitModeShortcuts` are shared). **Z-order menu flags are
  computed from stack order, never display order**, so "Bring to front" stays right under a
  name or size sort. Sort and expansion are per-visit state, deliberately not persisted.
- **A reshaped border outline is flagged** (`BorderAreas.editedAt`, schema v23; null =
  untouched OSM geometry). Reshaping forks the area from upstream while it keeps its
  `osmId`, so re-import dedup then keeps the edited version — which is why the fork is
  recorded, shown in the editor and the Elements list, and travels through GeoJSON
  (`ExportObject.edited`) so a shared file can't launder it back into "what OSM says".
  `reshapeBorderArea` recomputes the denormalised bounds (the painter culls on them) and
  **skips the write when the rings come back identical**, so a drag that ends where it
  started is not a fork. Moving the **name plate** deliberately does not go through it: an
  anchor is presentation, so `updateBorderArea(labelLat:/labelLng:)` never stamps `editedAt`.
  Reshaping is a *mode* (`borderReshapeProvider`), not always-on handles, and the screen-space
  half of it — which vertices get a handle, where an inserted one belongs — is pure in
  `ui/border_reshape.dart`, because a boundary carries hundreds of vertices where a drawn
  area carries eight.
- **Combined layers** (`data/layer_types.dart`): a `mixed` layer holds every element type
  **except `borders`** (its `borderLevel` is per-layer, and neighbour-distinct colouring is
  only meaningful within one admin level). **No schema change** — `Layers.type` is text.
  `layerHolds(layer, type)` / `layerContentTypes(layer)` are **the one predicate**, replacing
  every `layer.type == 'x'` in the painter, hit test, Elements list, exporter and drawer.
  Draw order is fixed (regions → markers); opacity governs the region composite only;
  invert applies to the region half; Add mode asks which kind to place; auto shades are taken
  across every table the layer holds. `layerHasEditor` answers true for mixed, and the colour
  path resolves `ColoredElement` from the row's kind. `combineLayers` is now exhaustive — its old `default:` arm silently
  lost every row of an unknown type to the cascade.
- **Hand-placed POIs** (v25, `PoiSets.source == 'manual'` + `.iconKey`): a `poi` layer holds
  Overpass imports **and** categories you name and fill by tapping. `addManualPoiPoint` /
  `moveManualPoiPoint` **refuse an import** at the repository level — an import records what
  OSM returned, and a hand-placed point in it would make that a lie. Icons come from
  `ui/poi_icons.dart` and **must be `const IconData` literals**: release tree-shakes the icon
  font to what it can see referenced, so a runtime-built one is a blank box in release only.
- **Sharing a position** (`data/shared_point.dart`): long-press → Share/Copy, a share FAB, a
  `zonecraft://` deep link (`app_links`) and a clipboard-prefilled paste box. **Receiving
  writes nothing** — it is a provider value, not a row, until "Add to layer…". A custom
  scheme, not a verified https App Link (that needs a domain), so the message also carries
  plain coordinates. `kMinFocusZoom` is a **floor**: Locate me and a received link never zoom
  you out.
- **Receiving a shared file, and saving one** (`data/platform_files.dart` +
  `MainActivity.kt`, the app's **only** platform code — one `MethodChannel`, no new
  dependency, no new permission, no schema change). `ACTION_SEND`/`ACTION_VIEW` filters put
  ZoneCraft in other apps' share sheets, and `ACTION_CREATE_DOCUMENT` gives an export a
  **Save to file** beside Share (`file_selector_android` implements `openFile` but throws
  `UnimplementedError` from `getSaveLocation`, which is why saving was impossible before).
  The load-bearing details:
  - **The new filters are separate `<intent-filter>` elements.** `<data>` cross-products
    within its own filter, so a `mimeType` added to the `zonecraft://` filter would turn its
    scheme-only match into a scheme×mime product and kill shared positions — silently, and
    only on a device. `test/android_manifest_test.dart` guards it.
  - **`ACTION_SEND` resolves on MIME alone** (the `EXTRA_STREAM` uri is invisible to the
    matcher), and Android's extension map has no entry for `.geojson` — so our own exports
    are shared as `application/octet-stream`, which is why that type is declared, exactly as
    in `_importGroup`. `text/plain` and `*/*` are refused: the first is every "share this
    text", the second every photo.
  - **The GeoJSON MIME stays `application/geo+json`.** DocumentsUI swaps the title's
    extension for the one the MIME maps to unless they agree; Android has no mapping for
    `geo+json`, so `x.geojson` is saved verbatim — `application/json` would write
    `x.geojson.json`.
  - **Delivery is pull, never push**: Kotlin caches the uri, Dart pulls at startup and on
    every resume. `onNewIntent` always precedes `onResume` (singleTop redelivery cycles
    pause/resume even when already foreground), so no EventChannel is needed. `onNewIntent`
    must `super` first — that keeps app_links alive — then `setIntent`, which the framework
    does not do. `restored` (captured *before* `super.onCreate`) stops a recents restore
    replaying the import.
  - **`FlutterActivity extends android.app.Activity`, not `ComponentActivity`** — no
    `registerForActivityResult`; `onActivityResult` must call **`super` first** or geolocator
    and file_selector stop receiving their results.
  - **The `content:` uri never reaches Dart** (its grant is task-scoped and revocable): Kotlin
    copies to `cacheDir` and passes a path plus the provider's display name, which the import
    needs because `parseExternalGeometry` sniffs its extension.
  - **`importBytesFlow` is the one import routine** — picker and share both enter it, so
    `simplify: !fromZonecraft` (and the export fixed point) cannot drift.
    **`askExportChoice`/`deliverExport` are the one export routine** for both scopes.
- **What is drawn and what can be tapped share one predicate.** `poiPointVisible`
  (`data/poi_sets.dart`, over `transitStationVisible`) is read by both `poi_layer` and
  `hit_test`; when the station rule existed twice
  the copies disagreed on the empty filter, leaving mode-less stations tappable over blank
  ground after every type was unticked. Likewise the borders hit-test **culls on the stored
  bounds before projecting any ring** — a state boundary is 119 238 points, and the cull is
  exact, since a ring lies inside its own box.

## Current status

Feature-complete for everything planned so far: seven object types — five region types with
the shared compositing engine (union / band / invert; the `height` type uses even-odd fill
and is bounded, so it bands along the elevation contour only and skips invert, and converts
to freehand areas), plus two import types with their own painters:
`poi` (offline sets — radius category imports, box station imports with per-type
visibility and retryable failed imports, hand-made categories — with screen-space
clustering) and `borders` (offline area imports per admin level, neighbour-distinct
colouring, name plates, per-area convert-to-freehand, hand-reshapeable outlines that are
flagged as forks) — the layers drawer + an editor for every type, settings (uncertainty,
clear-all, offline cache, import/export), opt-in locate-me (the app's only use of location),
persisted camera, offline resilience (cache-first tiles; **no** prefetch on the community OSM
servers — see `data/tile_source.dart`), and import/export
(whole-DB + per-layer + external GeoJSON/KML/KMZ/GPX; freeline imports prompt for their
inclusion-circle radius). Drift schema is **v27**, GeoJSON format **v3**.

`planning/PLAN.md` has no open roadmap items; future polish ideas are listed there.
`planning/PRODUCTION_AUDIT.md` records the production-readiness pass (what was found, what
was fixed, what is deliberately left). `planning/RELEASE.md` is the Play Store checklist —
release notes, store listing copy and the exact data-safety answers live there.

## Workflow rule (required)

- **Build & verify with the script:** before wrapping up a task, run
  `./scripts/build.sh --install --run` (analyze + test + build + install + launch) and check
  the change on the device. Use `--skip-checks` only for quick iteration.
- **Always commit and push directly to `main`** (the project's "master"/integration branch).
  **Do not create feature branches and do not open PRs** — work on `main`, commit there, and
  push there. After completing **every** task, **always commit and push to `main`
  automatically** without waiting to be asked. (This overrides the default "branch first when
  on the default branch / commit only when asked" behaviour — for this repo, direct-to-`main`
  is the rule.)
- After completing **all** the steps of a task, **update the docs** — drop the delivered
  item from `planning/PLAN.md`'s open points and, if it introduced a new pattern/invariant,
  add it to `planning/IMPLEMENTATION_PLAN.md` (the architecture reference) — then **commit and
  push the code to `main`**. Do the doc update + commit/push once at the end, not after every
  step. **Note:** the `planning/` folder is gitignored (see [Plans](#plans)), so updating those
  plan files is a local-only edit — it is never part of the commit; only the code changes are
  committed and pushed.

## Toolchain

- **Build / install / run — use the script** (`scripts/build.sh`; it puts `flutter` on
  `PATH` itself):
  - `./scripts/build.sh` — `flutter analyze` + `flutter test`, then build a **debug** APK.
  - `./scripts/build.sh --install` — also install on the device with `-r` (preserves data,
    exercises migrations).
  - `./scripts/build.sh --install --run` — install, then launch the app.
  - `./scripts/build.sh --skip-checks` — skip analyze/test for faster rebuilds;
    `--release` for a release APK; `DEVICE=<serial>` to target another device.
- `flutter`/`dart` are otherwise NOT on PATH — prefix manual commands with:
  `export PATH="$PATH:/home/leo/development/flutter/bin"`
- After Drift schema changes: `dart run build_runner build` (then `scripts/build.sh`).
- Device `09291JEC226042` (Pixel 4a), `adb` at `/usr/bin/adb`. No Android emulator is
  available, so on-device is the only interactive run.

## Layout

```
lib/
  data/        Drift database (Layers, Circles, Subspaces,
               SubspacePoints, FreeLines, FreeLinePoints, FreeAreas,
               FreeAreaPoints,
               HeightRegions, HeightPolygons, HeightPolygonPoints,
               PoiSets, PoiPoints,
               BorderSets, BorderAreas,
               TileCache, OverpassCache, AppSettings)
               + repository; shared Overpass transport with endpoint failover
               (overpass_client.dart); Overpass POI client (overpass.dart);
               offline tile cache (cached_tile_provider.dart); GeoJSON/KML
               import-export (serialization.dart); generic GeoJSON/KML/KMZ/GPX
               parser (geo_import.dart); height-layer terrain generation
               (height_generator.dart); public-transport station fetch + merge
               (transit.dart); administrative-area Overpass client (borders.dart);
               the POI-set kinds + the one marker-visibility predicate
               (poi_sets.dart); the location permission gate (location.dart) —
               the only file that talks to geolocator besides map_screen;
               the Android file channel (platform_files.dart) — receiving a
               shared file and saving one through the document picker, the only
               file that talks to MainActivity.kt
  geo/         geodesicCircle(), subspace Voronoi-cell geometry (two points =
               a half-plane), freehand line/area region geometry (freeline.dart,
               freearea.dart), height contouring/marching-squares (height.dart),
               border ring assembly / box clipping / area colouring
               (border_areas.dart), slippy-tile maths (tiles.dart), lat/lng parsing
  state/       Riverpod providers (layers, circles, subspaces,
               freehand lines/areas, height regions/polygons, poi sets/points,
               border sets/areas, settings, selection, map mode)
  ui/          map_screen, layers_panel, layer_actions (the one definition of
               per-layer actions), layer_sheet (the map's active-layer sheet),
               circle_editor,
               subspace_editor, freeline_editor, freearea_editor, height_editor,
               import_actions, settings_screen, region_layer, poi_layer
               (clustered POI + station markers, one painter),
               poi_set_editor / imported_point_editor,
               transit_import_dialog, transit_modes_sheet
               (the station-type tick boxes + the pure `transitTally`,
               embedded in the Elements list), border_layer (area fills +
               outlines + name plates, no Path.combine), border_import_dialog,
               screen_cluster (greedy screen-space clustering), screen_clip
               (viewport pre-clip, rings and segments)
```

## Plans

**All planning docs live in the `planning/` folder, which is gitignored — they are local-only
and never committed.** New plans/notes go there too. This is strict: **no planning/checklist/TODO
`.md` files may live anywhere outside `planning/`** (the repo root keeps only genuine public docs
— `README.md`, `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`, `CLAUDE.md`). Likewise, generated
release artifacts (Play Store screenshots, icons, feature graphics) go under
`planning/play-store-assets/`, never committed.


- `planning/PLAN.md` — current state + open points (the roadmap).
- `planning/IMPLEMENTATION_PLAN.md` — architecture reference (rendering contract, data model,
  caching, known approximations). No milestone history.
