# ZoneCraft — working notes for Claude

Flutter app: composable **zone layers** on OpenStreetMap, stored locally (Drift/SQLite),
no login. Android-first, iOS-ready. Map via flutter_map; state via Riverpod.

## At a glance (current app)

- **Seven object types**, one per layer (several layers group into a **folder** — see below):
  `circles` (geodesic), `subspace` (closest-of-N Voronoi cell; with two points it is the
  closer-of-two half-plane — the former `planes` type, which v27 folded in), `freeline` (drawn
  polyline dividing the view), `freearea` (drawn closed polygon), `height` (terrain
  above/below an elevation, bounded to a circle; generated from terrain tiles via marching
  squares, stored as fill polygons; any generated region can be **converted to a freehand
  area** — outer contours only, holes dropped, the same contract as the border conversion),
  `poi` (markers — since v31 an imported one can be **corrected by hand**, which flags the
  row as a fork and offers to pass the correction to OSM as a note; in three kinds of **set**
  told apart by `PoiSets.source` — see **POI
  sets** below: an `area` category import (a `radius` one before that — legacy, still read and
  retried), a `box` **station** import (the former `transit`
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
  (`manual` / `radius` / `box` / `area`), replacing the v25 `isManual` bool; read it through the
  `PoiSetKind` extension (`isManual`, `isStationImport`, `isAreaImport`, `isImport`,
  `isPending`, `bbox`). **Every import covers a box** — a category (`area`), stations (`box`)
  and borders are all armed the same way: two corner taps (`_kPlacePois` / `_kPlaceStations` /
  `borders`, `_isBoxImport`) or the Add banner's **Visible map**, then a sheet built on the
  shared `BboxFields` (`ui/bbox_fields.dart`) with the box drawn live. People found a radius
  for POIs beside a box for stations odd, and the POI query was a box underneath anyway.
  `area` needed **no schema change** (text column, box columns exist) and is kept apart from
  `box` because `isStationImport` drives the mode filter — a bench import must never be
  filtered as stations. `_importBox` takes the armed token **as an argument**, captured before
  `_exitAddMode` clears `_placeType`. An old `radius` set still shows "within X m" and retries
  over its circle (`_runCategoryImport(within:)`); nothing creates one. A
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
- **A control that cannot act is greyed, and says why when pressed**
  (`unavailableReason` in `ui/map_controls.dart`, `_mapFab` in `map_screen`). The buttons used
  to lie: "Fill outside" on an empty layer lit up, flipped the layer sheet's switch and wrote
  `isInverted` — while the painter returned before the viewport complement was ever taken
  (`region_layer.dart`, `if (outer == null) return`), so the map was byte-identical. A control
  reporting success and changing nothing is worse than one plainly unavailable.
  The load-bearing mechanic: **`onPressed: null` makes a FAB untappable** — no recogniser, no
  ripple — so the one moment a user wants an explanation is the one moment the button cannot
  give one. Unavailable controls therefore stay **live** and are only *painted* disabled
  (Material's faded pair, `onSurface` at 12 %/38 %, not `disabledColor`, which is a dark grey
  that read as the *lit* state on this light row). `undo_buttons._Button` takes the same
  `unavailable` parameter for the same reason.
  **What a control can act on is asked per control, not per layer**
  (`layerActionUnavailable` in `ui/layer_actions.dart`). The quick toggle is one
  button with three identities, and its availability used to read one boolean —
  "does the layer hold *anything*". A layer of nothing but POI markers
  is far from empty and still has no outside, so Fill outside lit up, wrote
  `isInverted` and left the map byte-identical: the very failure this mechanism
  exists to prevent, back again one layer type along. `kInvertibleTypes`
  (`data/layer_types.dart`) is the one list of what invert can act on — circles,
  subspace, freeline, freearea; **not `height`**, whose painter ignores
  `inverted` and bands along the elevation contour instead — and both
  `visibleLayerActions` and the greying read it, so the menu item and "can it do
  anything?" cannot disagree. Colour areas likewise needs an *area*, not just a
  border set, since an import can come back empty.
  Two rules keep it honest. **A toggle that is already on can always be turned
  off**: the flag is stored, and a layer left inverted with nothing to invert
  would fill the viewport the moment a shape was merged in — with the only
  control that could undo it greyed out. And **the answer is written once**, in
  `layerActionUnavailable`, because the same question is asked by three
  surfaces; `unavailableReason` (`ui/map_controls.dart`) keeps only the *map's*
  own half (is there a layer at all, is it visible) and `map_screen` falls back
  to the action's.
  **Where there is room, say it before the press; where there is not, answer the
  press.** The layer sheet and the drawer menu print the reason under the option
  and go inert — a disabled row that already explains itself needs no tap. Only
  the map's bare icon buttons, which have nowhere to put a sentence, stay live.
  The exception is a *value*: `layerOpacityNote` says why transparency is not
  visible yet (a borders layer without Colour areas draws no fill) beside a
  control that still works, because the
  number is stored and applies the moment the layer has a fill.
  These answers are **never counted by `UiHints`**: a tip that teaches goes quiet after three
  showings, but "why did nothing happen?" has to come every time or the third press of a dead
  button is silent again. A control the layer *type* can never use stays **hidden** — "never"
  is not a thing to wait for, and only "not yet" is worth greying.
- **A button that cannot be labelled is explained three other ways.** The map is eleven
  same-size icon buttons, and a `tooltip:` only appears on a long press nobody thinks to try.
  So: `LayerAction.description` is the one line saying what an option *does* (rendered as the
  layer sheet's subtitle, folded into the FAB's tooltip, and spoken as the tip below);
  `ui/map_controls.dart` is a pure catalogue of every map control that both the buttons' static
  tooltips and the **"What the buttons do"** guide (`ui/map_controls_screen.dart`, in the
  drawer) read, so the guide cannot fall behind the map; and the quick-toggle FAB answers a
  press with a one-line tip saying what is now true. Toggles are named by their **result**, not
  their operation — `invert` is "Fill outside"/"Fill inside", because "Invert" made the user
  ask invert *what*, into what.
- **The tips count themselves quiet** (`UiHints`, schema v29; `Repository.noteHintShown`). Each
  key shows 3 times and then never again; `AppSettings.hintsEnabled` stops them sooner and
  Settings → Tips / the guide's "Show all tips again" (`resetHints`) hands them all back. Two
  rules are load-bearing: the count is spent only on a tip actually **shown**, so switching
  them off does not silently burn them; and the read-modify-write is one transaction, or two
  taps in a frame both read the same count. `ui_hints` is in `undoExcludedTables` — pressing a
  button is not an edit, and an undo step for "the app explained something" is one the user
  cannot see and would have to press past.
- **Two map icons must not collide.** `typeIcon('poi')` and the OSM-import FAB were both
  `Icons.travel_explore`, so on a POI layer Add and Import were the same symbol side by side;
  POI is now `place_outlined`, the by-name search is `travel_explore` (a globe with a
  magnifier is what it does) and the nearby import is `cloud_download_outlined`.
  `test/map_controls_test.dart` fails if two controls in one area share an icon.
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
- **The active layer is on screen unless you ask otherwise**: the chrome row carries a chip
  (swatch · type · name) that opens the **layer sheet** (`ui/layer_sheet.dart`) — a switcher
  row plus every setting of the active layer as a direct control, two taps from the map to
  anything the drawer's ⋮ offers. The sheet is opened with the *map's* context/ref and pops
  itself before a `needsMap`/delete action runs. Beside Edit, one **per-type quick toggle**
  FAB: borders → Colour areas, region layers → Invert, a POI layer with stations → the filter.
- **The FABs are hidden by whatever is in the sheet slot, not by a list of it.**
  The map's `bottomSheet` slot is shared by four things — a pending import's
  Keep/Discard, an import's options form (`_importSheet`), a received place, and
  the selected element's editor — and the FAB column and bottom row are drawn
  *over* that slot. So `floatingActionButton` was `null` while a sheet was up,
  keyed off a second list of the things that raise one; the import form was
  added to the slot and never to that list, and its buttons landed on top of the
  form's own corner fields and its close button. Both now read one hoisted
  `final Widget? bottomSheet`, so a fifth kind of sheet cannot reintroduce it.
- **One toggle collapses the map to the map** (`AppSettings.toolsExpanded`). It takes down the
  right-hand tool column, the undo/redo pair **and the active-layer chip**, leaving the burger
  menu, the credit and the bottom row. The menu stays because the way *back* has to survive
  the collapse — with gesture navigation a left-edge swipe is system back, not the drawer, so
  a hidden ☰ would be genuinely hard to recover. Hiding the chip costs the "which layer am I
  editing" answer, which is why it is a choice the user makes and undoes in one tap and never
  something the app does on its own (an editor sheet hides the *FABs*, never this).
- **Every button in the bottom row is the same small round icon button**, and the tools toggle
  is the **last** of them — it acts on the column anchored to the right edge, so at the left it
  was the furthest thing on the row from what it opens. Uniform size is not only cosmetic: the
  row is Edit + quick toggle + up to two imports + Add + the toggle, and an extended Add with a
  label ran past the screen edge on a Pixel 4a. A guard existed (`smallFabs < 4 || textScale <=
  1.15`) but read `||`, so it never collapsed the label at the *default* font size — exactly
  the case that overflowed. Icon-only makes the overflow impossible by construction.
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
- **One `User-Agent`, built from the version** (`zoneCraftUserAgent` in `app_info.dart`).
  Every policy the app is subject to requires a string naming *this* app and forbids a
  library default, and all three operators **block by exactly that string** — it is the
  app's identity to them (OSMF blanket-blocked flutter_map's `com.example.app` in Aug 2025).
  It lived as four hand-kept literals that had all drifted to `1.0` at app version 1.3.0;
  `test/app_info_test.dart` now pins that they agree and carry `kAppVersion`.
- **The app id is `io.github.leostumpf.zonecraft`, in five places nothing compares.** It is
  the reverse of `leostumpf.github.io` — a name that is provably ours, which is the entire
  point of a reverse-DNS id (the old `com.leostumpf.*` claimed a domain nobody owns). It moved
  in Sep 2026, while no Play listing existed yet; after the first upload the id *is* the app and
  a different one is a different listing, so this is final. It is written in `namespace` +
  `applicationId`, the Kotlin `package` (and the directory that package requires), the
  `MethodChannel` name on **both** sides of `platform_files.dart` ↔ `MainActivity.kt`,
  `userAgentPackageName`, and `APP_ID` in the two adb scripts — plus six
  `PRODUCT_BUNDLE_IDENTIFIER` lines on iOS. The channel pair is the dangerous one: a half-done
  rename analyzes, compiles and launches clean and fails only when a file is shared in or saved
  out, so `test/app_id_test.dart` reads the files and asserts they still agree. The
  `zonecraft://` scheme is **not** derived from it — a scheme is user-facing and travels in
  shared messages.
- **Attribution is the app's own chrome, not flutter_map's** (`_MapAttribution` in
  `map_screen`). `RichAttributionWidget` renders among the *map's* children, which on this
  screen is underneath the FAB row and the system navigation bar — the credit was there and
  invisible, and it also starts collapsed behind an (i). ODbL attribution is the one
  obligation here that is a licence term rather than an acceptable-use courtesy, so it is a
  permanently visible bottom-left pill whose tap opens `_showCredits` — OpenStreetMap plus the terrain sources Tilezen's list requires be named.
  The pill prints the tile source's own line verbatim: it already carries its `©`, and a
  keyed provider's names two parties. It lives in the Scaffold's `bottomNavigationBar` slot
  (`extendBody: true`), **under** the FAB row: the Scaffold lifts the FABs by the pill's real
  height, one line or two, where a fixed padding in the body Stack floated it above them.
- **Redirecting the tiles does not grant prefetching.** `TILE_URL` and
  `TILE_ALLOWS_PREFETCH` are separate defines because leaving `tile.openstreetmap.org` says
  nothing about the next provider's terms — MapTiler forbids "batch or excessive bulk
  download of map tiles" on every plan, Thunderforest forbids "pre-downloading, pre-caching
  or anything similar" below Small Business. `scripts/build.sh` refuses the flag without a
  `TILE_URL`. `TileSource.configured` is the build-time source; `TileSource.resolve(userUrl)`
  applies the **runtime** override and forces `allowsPrefetch: false` — a URL typed into a
  settings field asserts nothing about anyone's terms.
- **The three service addresses are data** (`data/service_overrides.dart`, schema v28's
  `tileUrlOverride` / `overpassEndpointOverride` / `nominatimHostOverride`). Nominatim's
  policy asks that "apps must make sure that they can switch the service at our request at
  any time", and Overpass's own docs say an app leaning on the public instances as a backend
  is what running your own is for. `ServiceOverride` is the one definition (label, hint,
  default, validation) and Settings → **Data sources** renders whatever it holds, collapsed.
  The Overpass and Nominatim overrides are **process-wide** (`overpassEndpointOverride`,
  `nominatimHostOverride`), pushed in from `map_screen`'s settings watch rather than threaded
  through four layers that have no opinion about them; `overpassEndpointList` keeps the
  public instances behind the override, so a typo costs a slow import, not a dead app.
- **A refused tile is explained, not left as grey squares** (`data/tile_health.dart`).
  A server that *answers* and says no — a spent daily quota, a refused key, a blocked client —
  looks exactly like a broken app at an hour nobody can predict, and the visible symptom (the
  map vanishing) reads as data loss. `TileHealth` watches every fetch and raises one banner
  with a **Why?** dialog that says the reassuring half first. Two judgements keep it quiet:
  **not reaching the server says nothing** (offline is the normal state the cache exists for,
  and a banner would fire on every subway ride) and **one refusal is not news** — three
  consecutive, since tiles go out in bursts. Any success clears it. The streak check lives in
  the `failure` getter as well as the notify, or a listener rebuilding for its own reasons
  shows the banner on the first refusal. The wording differs for the community OSM servers
  (donated, may block, does not fix itself) and a keyed provider (an allowance that resets).
- **There is a way to reach a human** (`ui/service_policy_screen.dart`, "Servers and limits",
  linked from About and from the failure dialog). Operators identify a misbehaving client by
  its `User-Agent` and then need somebody to write to; when they cannot find one, blocking is
  the remedy left. So the page prints the exact UA their logs will contain next to
  `kContactEmail` and `kIssuesUrl`, both copyable. `mailto` is declared in the manifest's
  `<queries>` block for the same API-30 reason as `https` — without it `canLaunchUrl` reports
  no mail app and the contact button is dead exactly when it is needed
  (`test/android_manifest_test.dart` guards both schemes). `canLaunchExternalUrl`
  (`ui/external_link.dart`) is the one probe: `canLaunchUrl` *throws* with no platform
  implementation, so no screen may call it directly.
- **The app gives back, once per press** (`data/osm_notes.dart`, `data/osm_report.dart`,
  `ui/osm_report_sheet.dart`, `ui/osm_reports_screen.dart`). ZoneCraft consumes OSM heavily and
  used to return nothing, and an imported POI you could see was wrong was read-only. Both
  halves changed together, and neither works without the other:
  - **A correction is allowed because it is now recorded.** `movePoiPoint` / `updatePoiPoint`
    capture what the import returned (`PoiPoints.origLat/origLng/origName`) and stamp
    `editedAt` on the *first* edit only — the `BorderAreas.editedAt` contract, one layer type
    along, and load-bearing for the same reason: the row keeps its `osmId`, so a fork nothing
    records lets one person's guess beat whatever OSM says next, invisibly. Unlike a boundary
    the original **is** kept (a POI is three scalars, not a 119 238-point ring), which buys
    both `revertPoiPoint` and a note that can state what changed. A move that changes nothing
    is not a fork.
  - **Only a change of the user's own is published.** `OsmReportSubject.availableKinds` offers
    exactly one kind or none — `missing` for a hand-placed point, `movedHere` for a moved
    correction (its note carries a rename too: one visit, one note), `wrongName` for a rename —
    and `canPublish` is what shows the editor's Publish button. `gone` is offered by exactly
    one act, **deleting** an imported POI (`deletePoiPointFlow` in `ui/poi_delete.dart`, the one
    single-POI delete: it always asks, and for something OSM has offers *Delete & tell OSM…*;
    the note is composed before the row goes). `other` is retired, read only so old outbox rows
    still display; the long-press "Tell OpenStreetMap about this place" is gone. An untouched
    import has nothing to publish — it *is* what OSM has. The editor's name and position are
    facts with **Edit** buttons whose dialog says **Save** or **Save & publish…** (one write,
    one undo step — the old live field wrote on every keystroke), and the subject for "Save &
    publish" is composed from the values being saved (`_subject(name:/lat:/lng:)`), not the
    row that has not come back yet. `osmSubjectFor` (`data/poi_sets.dart`) is the one
    point→subject builder. A new place's note lists the tags a mapper would type
    (`amenity=bench`, `name=…`); a category with no tag says so rather than guessing. Rows show
    `PoiPublishState` (not published / in your OSM list / sent to OSM), from the newest report
    per `poiPointId`.
  - **Moving a POI is a mode, not a write** (`poiMoveProvider`, `ui/poi_move.dart`). The
    editor's Move puts out a `_dragHandle` pin whose drags only update the mode's `to`; the
    POI's own marker stays at `from` as the ghost, a dashed `Polyline` joins them, and
    `PoiMoveBanner` says "Moved 24 m north-east" with Cancel / Save / Save & publish. Only
    Save writes — one `movePoiPoint`, sealed as one undo step — and "publish" composes via
    `osmSubjectFor(point, sets, lat:, lng:)` from the row read **before** the write (the row
    that comes back has forgotten where it was). A map tap while armed drops the pin there
    (the old tap-to-place, kept as the fallback), double-tap zoom is off while armed
    (`tapPlaces`), and the pin is put away when the selection moves to another point or any
    transient mode is cleared. `poiPointPlacementProvider` is gone.
  - **A note is unsigned.** `composeOsmReportText` adds no "reported with ZoneCraft" line: a
    note is the user's own post, OSM's Notes guidance asks apps for no attribution (only "no
    automated notes"), and the request's `User-Agent` already names the app to the operator,
    which is what the API policy requires. It also keeps `PRIVACY.md` literally true — the note
    is the text you wrote and where you pinned it.
  - **Notes, not edits, and that is not a stopgap.** `parseOverpassResponse` keeps no tag map
    and no element `version`, and uses `out center`, so a `PUT` would strip tags off live OSM
    objects. A note is the only report this data model can make honestly — and it is the
    sanctioned one: OSM's developer guidance says outright that third-party apps may use the
    Notes API, provided a report carries enough detail for a mapper to act on.
  - **Three of OSM's rules are structure here, not comments.** *"Create no automated notes"* →
    the draft `composeOsmReportText` builds is editable and Send is off until it says
    something, the outbox has **no timer, no flush-on-reconnect, no send-at-launch**, and
    `submitOsmNote` **never retries and never fails over** (a POST that timed out may well
    have been applied, and there is only one OpenStreetMap). *"Tell users this is for map data,
    not feedback about your app"* → the sheet's warning is unconditional and is **never
    counted by `UiHints`**, because a warning that goes quiet after three showings stops
    warning exactly the people comfortable enough to be careless. And the app holds itself to
    osm.org's own anonymous-note numbers — warn at 5 a day, stop offering Send at 10 — since
    a block lands on the `User-Agent`, i.e. on every install at once.
  - **Two ways out, because not everyone wants to file anonymously.** Send now, or keep it in
    the `OsmReports` outbox and **export the lot as GeoJSON** to work through in JOSM under
    your own account. The outbox is in `undoExcludedTables`: writing a report is not a map
    edit, and for one already sent an undo would be a lie.
  - `OSM_API_URL` is a **dart-define**, not a `ServiceOverride` — the OSM database is not a
    service you swap, and a typed-in URL would send somebody's contribution to a stranger's
    server. Point it at `https://master.apis.dev.openstreetmap.org` for every test; a note
    filed against the live database to see whether a button works is one a volunteer then has
    to read and close by hand.
- **No telemetry, ever.** No crash reporting, no analytics, no advertising id. Sentry was
  wired in and deliberately removed: `PRIVACY.md` and the Play Data safety form can now
  answer "none", which is worth more than the diagnostics were. Anything added back has to
  be reflected in both. An OSM note is not an exception to this — it carries nothing the user
  did not type, goes nowhere but OpenStreetMap, and only on a press — but it *is* the one
  thing that leaves the device, so PRIVACY.md names it in full.
- **The app names the free services it uses, at the moment it uses them**
  (`data/service_credits.dart`, drawn by `ui/service_credit_line.dart`). One friendly line
  each: the Overpass import dialog says volunteers run it and requests queue together (why a
  wait can take minutes — `showImportProgress(credit:)`), the two place searches credit
  Nominatim, the height editor credits the open terrain data, the credits sheet says who draws
  the tiles (`tileCredit(TileSource)`), and the publish sheet and point editor open with why
  giving back matters (`kGiveBackCredit` / `kGiveBackShort`); "Servers and limits" adds a
  **Why this matters** section. The strings are defined once so the surfaces cannot drift,
  and they are **never counted by `UiHints`** — they sit inside a wait or a form already on
  screen, and the fourth import is as slow as the first.
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
- **The GeoJSON export is a fixed point** (format schema **v6**, `geoJsonSchemaVersion`):
  `export → import → export` must be byte-identical, and `test/export_roundtrip_test.dart`
  asserts exactly that against real rows for all seven types, alongside a whole-DB and a
  per-layer round-trip. **Anything the DB stores and the UI shows has to survive the trip** —
  so a hidden layer stays hidden, a `height` region travels **with its generated fill rings**
  (regenerating needs the network and the layer draws *nothing* until it happens), POIs keep
  their `osmType`/`osmId` (dedup identity — without it a re-import draws them all twice), a
  station import keeps its box, masks and per-point modes (a box set writes **no**
  `radiusMeters` — it is derived), a border area keeps its import's `setLabel`, and a failed
  import comes back as its retry row, and a layer in a folder comes back in it. Format is
  **v6** (`geoJsonSchemaVersion`); since v4 a layer names its folder and the folders ride in
  `zonecraft.folders`, both written only when there are folders — so a file from a map without
  them is what v3 wrote. **v6** carries the `area` POI set: a `poi` with a `bbox` whose
  `categoryKey` is not `transit_station` — how the reader tells it from a station import, so
  no new key. **v5** adds `pointOrigLat`/`pointOrigLng`/`pointOrigNames`: what OSM
  returned for a POI somebody has since corrected by hand, written only when a set holds one,
  so an untouched import still exports exactly what v4 wrote. The *flag* travels, not the
  timestamp — and it has to, because the row keeps its `osmId`, so a file whose corrections
  arrived silently would launder one person's guess into "what OSM says" on the next device
  and re-import dedup would then keep it.
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
- **Drift schema is at v31**; migrations are append-only `if (from < N)` blocks. (Two
  exceptions drop tables: v19 *drops* the transit route tables, because route geometry was
  abandoned — see `data/transit.dart`'s header for the measurements behind that — and v27
  copies `planes` → `subspaces` and `transit_*` → `poi_*` then drops them, plus `tracks`.
  **v30 splits** every `mixed` layer into one layer per kind it holds, inside a folder when
  that is more than one, and deletes the row it split.
  Earlier blocks that once `createTable`d a dropped table no longer do; the raw `ALTER
  TABLE`s in v22/v26 keep the columns v27 copies on a database old enough to have them.
  **v31** adds the four `poi_points` fork columns and the `osm_reports` outbox, and is purely
  additive — every existing row reads as untouched, which it is.)
  v20…v31 are snapshotted in `drift_schemas/` and guarded by `test/migration_test.dart`. **Any schema change must dump a
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
  error and a Try again), `imported_point_editor` (one POI or station — the same row;
  since v31 **name and position are both editable**, because there is now a column that says
  one was changed — see the OSM contribution bullet), and `border_area_editor`. Individual POIs/stations are [ObjectKind]s
  (`poiPoint`) but **not elements** (`isElement`): `layerSummariesProvider` — what the
  drawer, the layer sheet and the recolour picker *count* — still yields one row per set.
- **The Elements list lists everything, and POIs by type** (`ui/layer_objects_sheet.dart`).
  Three pure, tested layers feed one `ListView.builder`: `object_summary.dart` (one
  `ObjectSummary` per element, now with `sortName` + a per-kind `sizeMeasure`, and lines /
  areas quoting their ground length / area from `geo/measure.dart`), `ui/poi_groups.dart`
  (a POI layer's *points* filed under `PoiTypeGroup`s — a category across every import of
  it **and every hand-made set that is the same thing**, a station's `primaryTransitMode` —
  the same pick `transitIconFor` makes, so icon and group can't disagree — or a hand-made
  category of the user's own, one group per name), and `ui/elements_list_model.dart`
  (`buildElementRows`: sort, search, which groups are open). **There is no Imports section**:
  a finished import is not a row, and the only trace of one is a **pending import's retry
  row, floating to the top** so no fold can hide it. `poiSetCatalogueCategory`
  (`data/poi_sets.dart`) is **the one rule for "this hand-made set is a bench"** — a
  catalogue key *and* a name that agrees (empty, or the catalogue label up to case and
  plural); the icon alone is not enough. The list files by it and `poiCategoryTag` reports
  by it, so a set is never listed as Benches and sent to OSM as something else.
  `deletePoiPoints` (a heading's "Delete N POIs") drops an import it empties — nothing
  could show or remove it any more — and keeps a hand-made category, which is where the
  next point goes. A station group's heading carries the
  visibility tick box (`setPoiVisibleModes`, the same write as the Stations sheet; the
  Rail-only/Show-all/Hide-all `TransitModeShortcuts` are shared). **Z-order menu flags are
  computed from stack order, never display order**, so "Bring to front" stays right under a
  name or size sort. Sort and expansion are per-visit state, deliberately not persisted.
  **The sort is a labelled button** ("Sort: Name ▾"), and it orders the POIs *inside* each
  type group too (the groups keep their fixed order). The two distance sorts measure from
  `myPositionProvider` (the Locate-me fix, which `map_screen._myPosition` now reads and
  writes) and `mapCenterProvider` (written from the map's event stream — **not**
  `AppSettings.lastLat`, which is only saved on pause). Choosing "Distance from you" with no
  fix is itself the opt-in: it runs `currentPosition()` (`data/location.dart`, shared with
  Locate me) and switches only once there is a fix; a failure is printed beside the button,
  since a snackbar would land behind the modal sheet. POI *sets* are not rows, so they do
  not make "Stack order" a choice — on a POI layer it would otherwise be the default.
  **A POI row is told apart by where it is**: `poiRowSubtitle` (pure, tested) prints
  distance from you / from the centre, the point's own subtitle only when it differs from its
  heading (a station's modes, never "Benches" under Benches) and "edited" for a hand
  correction; its leading `PoiThumbnail` (`ui/poi_thumbnail.dart`) is **at most four cached
  tile `Image`s, never a `FlutterMap` per row**, placed by the pure `tileWindow`
  (`geo/tiles.dart`). It reads the map's own `CachedTileProvider`, published as
  `mapTileProviderProvider` (same cache, same client, same `User-Agent`), at **zoom 16 on
  purpose** — the zoom the map is read at, so a thumbnail is mostly tiles already cached and
  the list fetches next to nothing; `Image` defers loading during a fling, and only visible
  rows build, so what is fetched is what is looked at (viewing, not prefetching).
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
- **Folders group layers without destroying them** (schema v30, `Folders` +
  `Layers.folderId`, `ui/layer_tree.dart`). They replace the `mixed` layer, which grouped by
  *merging*: what went in lost its own colour, opacity and Fill outside and could never come
  out again — which is why merging an inverted line layer into one made the line stop being
  inverted. A folder leaves its members layers. It offers exactly three things: hide the group,
  **Fill outside** the group, and collapse it so seven settled layers take one line.
  - It **paints nothing**, so it carries no colour and no opacity. Its invert **flips each
    member's own** rather than compositing them into one region: a member that was already
    inverted goes back to normal, because inverting twice is the identity and that is what
    makes the switch a switch. There is no cross-layer compositing anywhere in the app.
  - `resolveLayers` folds a folder into its members (`isVisible && folder.isVisible`,
    `isInverted != folder.isInverted`) and **that is the whole rendering change** — the band
    sweep, the fill loop and the hit test read `drawLayersProvider` and go on knowing nothing
    about folders. The drawer and the layer sheet read the **raw** rows, so their controls show
    the layer's own settings; a member's row says `· inverted (folder)` when the two differ, or
    the drawer and the map would appear to contradict each other.
  - Order is two-level: a folder's `sortOrder` places it among the root items, a member's
    places it within its folder. Everything order-shaped is pure and tested in
    `ui/layer_tree.dart` under the rule `movedLayerOrder` already lives by — bottom-to-top
    everywhere except `drawerRows`, which *is* the display list.
  - **A drop changes the parent of the dropped row only.** Reading the parent off the row above
    for every row swept every layer below the drop into the folder too, because nothing in the
    list says where a folder's members end. A collapsed folder adopts nothing; a folder drags
    as a block and never lands inside another (there is one level). The last member leaving
    downwards is the case a drag cannot express, which is why **Move out of folder** stays in
    the menu — and why this is a tested function rather than something inferred in a widget.
  - **Deleting a folder keeps its layers** (`onDelete: setNull`): getting layers back out is
    the thing the combined layer could never do, so deleting the group must never be a way to
    delete its contents by accident.
  - **`mixed` is retired, not forgotten.** `kMixedType` / `kMixedContentTypes` stay in
    `layer_types.dart` as legacy, read by exactly two things — the v30 migration and the
    GeoJSON reader — which do the same thing with them: split the layer into one per kind it
    actually holds, in `kMixedContentTypes` order (the order its painter drew them), inside a
    folder when that is more than one. A combined layer holding a single kind was a layer of
    that kind wearing the wrong label and becomes one. `layerHolds` / `layerContentTypes`
    survive as one-liners rather than being inlined at a hundred call sites: the day a layer
    holds several kinds again it is one edit, not forty.
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
clustering, per-point hand corrections that are flagged as forks and revertible, and a
**"Publish to OpenStreetMap"** route — for your own changes only: a place you added, moved,
renamed or deleted — that files it as an anonymous note or keeps it in an exportable outbox) and `borders` (offline area imports per admin level, neighbour-distinct
colouring, name plates, per-area convert-to-freehand, hand-reshapeable outlines that are
flagged as forks) — the layers drawer + an editor for every type, settings (uncertainty,
clear-all, offline cache, import/export), opt-in locate-me (the app's only use of location),
persisted camera, offline resilience (cache-first tiles; **no** prefetch on the community OSM
servers — see `data/tile_source.dart`), and import/export
(whole-DB + per-layer + external GeoJSON/KML/KMZ/GPX; freeline imports prompt for their
inclusion-circle radius). Drift schema is **v31**, GeoJSON format **v6**.

`planning/PLAN.md` has no open roadmap items; future polish ideas are listed there.
`planning/PRODUCTION_AUDIT.md` records the production-readiness pass (what was found, what
was fixed, what is deliberately left). `planning/RELEASE.md` is the Play Store checklist —
release notes, store listing copy and the exact data-safety answers live there.

## Workflow rule (required)

- **Build & verify with the script:** before wrapping up a task, run
  `./scripts/build.sh --install --run` (analyze + test + build + install + launch) and check
  the change on the device. Use `--skip-checks` only for quick iteration.
- **CI runs the same gate on every push to `main`** (`.github/workflows/ci.yml`): lockfile
  (`--enforce-lockfile`), `dart format`, analyze, test, then a **release** APK — the last
  because R8 and the native-asset path exist only in release, which is how `share_plus`
  13.3.0 got through everything else. It does not replace the device check: an emulator-less
  runner cannot tell you a control is unreachable or a band is invisible.
  **The release build CI keeps is the shippable one.** Five repository secrets mirror the two
  files that live outside version control — `ANDROID_KEYSTORE_BASE64` / `_PASSWORD` and
  `ANDROID_KEY_PASSWORD` from `android/key.properties` + the upload keystore, and
  `TILE_URL` / `TILE_ATTRIBUTION` from `~/.config/zonecraft/release.env` — so rotating either
  side means rotating both. The alias `upload` is a literal in the workflow, **not** a secret:
  GitHub masks every occurrence of a secret's value, and the word "upload" is in half the log.
  CI writes them back into `key.properties` and a `.jks`, builds
  the APK **and** the App Bundle through `scripts/build.sh` (never a bare `flutter build`, so
  the dart-defines cannot drift from the laptop build), fails unless both carry a non-debug
  certificate (`apksigner` for the APK — its v2/v3 signature is invisible to `keytool`, which
  reads only the AAB's jar signature), and uploads both as the artifact `zonecraft-release-<sha>` (30 days;
  `gh run download -n ...`). A fork's PR sees no secrets: every one of those steps is gated
  on `env.HAVE_KEYSTORE`, and the debug-signed OSM-tiled smoke build is not uploaded. There
  is deliberately **no** Play upload step.
  **`origin` is SSH (`git@github.com:LeoStumpf/ZoneCraft.git`), and that is load-bearing.**
  A push that adds or edits anything under `.github/workflows/` is refused over HTTPS unless
  the token carries the `workflow` scope — and the scope is a property of *tokens*, so an SSH
  key, which has no scopes, is never subject to it. If a push of a workflow file is ever
  rejected with "refusing to allow an OAuth App to create or update workflow", the remote has
  been put back to HTTPS; the fix is the URL, not the file.
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
               TileCache, OverpassCache, AppSettings, UiHints, OsmReports)
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
               file that talks to MainActivity.kt;
               the one definition of the three switchable service addresses
               (service_overrides.dart); why the tiles stopped, in words
               (tile_health.dart); the one outbound *write* — one OSM note per
               press, never retried, never batched (osm_notes.dart) — and what
               it says, purely (osm_report.dart)
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
               osm_report_sheet (write a correction: send, keep or copy) +
               osm_reports_screen (the outbox, and its GeoJSON export),
               transit_import_dialog, transit_modes_sheet
               (the station-type tick boxes + the pure `transitTally`,
               embedded in the Elements list), border_layer (area fills +
               outlines + name plates, no Path.combine), border_import_dialog,
               screen_cluster (greedy screen-space clustering), screen_clip
               (viewport pre-clip, rings and segments),
               external_link (the one way the app opens someone else's URL),
               service_policy_screen (what the app asks of other people's
               servers, and how an operator reaches a human),
               map_controls + map_controls_screen (every map button named and
               explained, once, for both its tooltip and the guide)
```

## Docs — `docs/` is the wiki

**The public wiki is generated from `docs/`, and is never edited by hand.** A GitHub wiki is a
*second* git repository (`ZoneCraft.wiki.git`, cloned at `~/git/ZoneCraft.wiki`) — GitHub's
design, not a choice — so left to itself it is invisible to everything that keeps this project
honest: a wiki edit appears in no diff and no review, `ci.yml` cannot see it, and no test can
check it. The docs therefore live in `docs/` here, and
`.github/workflows/wiki.yml` publishes them on any push to `main` that touches `docs/**`.
- **Edit `docs/`, never `~/git/ZoneCraft.wiki`** — that clone is now *output*, and a change made
  there is silently overwritten by the next publish. Same for a browser edit of the wiki.
- **Links are relative `.md` links** (`[Layer Types](Layer-Types.md)`), which is what renders in
  the repo; the publish step strips the `.md` because that is what a wiki resolves. It strips it
  **only** from targets with no `/` and no `:`, so the absolute `github.com/.../PRIVACY.md` links
  keep their extension. Wiki-native `[[Page]]` links do not render outside a wiki — never
  reintroduce them.
- **`docs/Layer-Types.md` quotes every `kLayerTypeChoices` subtitle word for word**, and
  `test/docs_quotes_test.dart` fails when they diverge. A subtitle edit in `ui/layer_actions.dart`
  is a `docs/` edit in the same commit. The same test checks every cross-page link resolves.
- The filename *is* the page name (`Layer-Types.md` → the "Layer Types" page), so renaming a file
  moves a public URL.

## Plans

**All planning docs live in the `planning/` folder, which is gitignored — they are local-only
and never committed.** New plans/notes go there too. This is strict: **no planning/checklist/TODO
`.md` files may live anywhere outside `planning/`** (the repo root keeps only genuine public docs
— `README.md`, `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`, `CLAUDE.md`; `docs/` is the published
wiki, see above, and is exempt from this rule). Likewise, generated
release artifacts (Play Store screenshots, icons, feature graphics) go under
`planning/play-store-assets/`, never committed.


- `planning/PLAN.md` — current state + open points (the roadmap).
- `planning/IMPLEMENTATION_PLAN.md` — architecture reference (rendering contract, data model,
  caching, known approximations). No milestone history.
