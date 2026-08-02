import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Default opacity of a freshly created region layer's **solid fill**. The
/// design intent is a translucent fill so the map shows through — this is that
/// translucency expressed as an opacity (`Layers.opacity` *is* the fill
/// opacity: 1.0 = fully opaque / map hidden, this value = the default look).
/// POI layers instead default to 1.0 (crisp markers). Shared so the painter,
/// the repository (create default + v17 rescale) and the drawer agree.
const double kDefaultRegionLayerOpacity = 0.45;

/// The opacity a freshly created layer of [type] gets.
///
/// Marker/line layers ('poi', 'transit') are crisp at 1.0 — there is no fill to
/// see the map through. One source of truth, because the repository (on create)
/// and the drawer (deciding whether to show an opacity chip) must agree; they
/// used to duplicate the rule inline, which is how a third type silently drifts.
double defaultLayerOpacity(String type) =>
    (type == 'poi' || type == 'transit') ? 1.0 : kDefaultRegionLayerOpacity;

/// A map overlay layer. Layers stack on the map ordered by [sortOrder]
/// (higher = drawn on top) and can be toggled on/off via [isVisible].
///
/// A layer holds a single object [type] ('circles' or 'planes'). When
/// [isInverted] is true the layer fills everything *not* covered by its objects.
class Layers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Fill/stroke colour as a packed ARGB int (see [Color.toARGB32]).
  IntColumn get colorArgb => integer()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer()();

  /// Object kind this layer holds: 'circles' or 'planes'.
  TextColumn get type => text().withDefault(const Constant('circles'))();

  /// When true, render the complement (outside the objects) instead.
  BoolColumn get isInverted => boolean().withDefault(const Constant(false))();

  /// Layer opacity in [0, 1], multiplying the whole layer's paint (fills,
  /// band, outline / markers). 1 = fully opaque (the default); lower values let
  /// the map and lower layers show through.
  RealColumn get opacity => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A geodesic circle belonging to a [Layers] row. The radius is in real-world
/// metres; rendering computes the actual ring geodesically.
class Circles extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();
  RealColumn get centerLat => real()();
  RealColumn get centerLng => real()();
  RealColumn get radiusMeters => real()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A "plane": the region of points closer to one of two points (A, B) than the
/// other — i.e. one side of their perpendicular bisector. [nearA] selects which
/// point's side is the enabled region.
class Planes extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();
  RealColumn get aLat => real()();
  RealColumn get aLng => real()();
  RealColumn get bLat => real()();
  RealColumn get bLng => real()();
  BoolColumn get nearA => boolean().withDefault(const Constant(true))();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A "closest subspace" object: a set of points, exactly one of which is the
/// main point. The filled region is everywhere closer to the main point than to
/// any other point (the main point's Voronoi cell). A `subspace` layer holds a
/// single [Subspaces] row; its points live in [SubspacePoints].
class Subspaces extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One point of a [Subspaces] object. Exactly one point per subspace has
/// [isMain] set; the filled region is that point's nearest-region.
class SubspacePoints extends Table {
  TextColumn get id => text()();
  TextColumn get subspaceId =>
      text().references(Subspaces, #id, onDelete: KeyAction.cascade)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isMain => boolean().withDefault(const Constant(false))();
  /// Optional name, e.g. the OSM `name` of an imported POI.
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A user-drawn "freehand line": an ordered polyline (points in [FreeLinePoints])
/// that divides the map into two sides. The layer fills the chosen side; the
/// per-layer invert flips to the other. [offsetMeters] is a signed distance that
/// pushes the filled region's boundary away from the line (positive) or past it
/// (negative), independent of the global uncertainty band. A `freeline` layer may
/// hold several lines.
class FreeLines extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().nullable()();

  /// Signed offset in metres (see class doc). 0 = boundary sits on the line.
  RealColumn get offsetMeters => real().withDefault(const Constant(0))();

  /// The line is bounded to an **inclusion circle**: the filled region is
  /// `(disk) ∩ (one side of the line)`, so the two sides read as two clean
  /// half-disks. Null until set (legacy rows / unset) — the renderer then
  /// derives a default circle from the line's own extent.
  RealColumn get inclusionLat => real().nullable()();
  RealColumn get inclusionLng => real().nullable()();
  RealColumn get inclusionRadiusMeters => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One ordered vertex of a [FreeLines] polyline.
class FreeLinePoints extends Table {
  TextColumn get id => text()();
  TextColumn get freeLineId =>
      text().references(FreeLines, #id, onDelete: KeyAction.cascade)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A user-drawn "freehand area": a closed polygon (ring in [FreeAreaPoints]).
/// The layer fills the inside; the per-layer invert fills the outside.
/// [offsetMeters] is a signed distance that insets the filled boundary inward
/// (positive — e.g. "inside the city and >5 km from the border") or outward
/// (negative), independent of the global uncertainty band. A `freearea` layer
/// may hold several areas.
class FreeAreas extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().nullable()();

  /// Signed inward offset in metres (see class doc). 0 = boundary on the ring.
  RealColumn get offsetMeters => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One ordered vertex of a [FreeAreas] ring.
class FreeAreaPoints extends Table {
  TextColumn get id => text()();
  TextColumn get freeAreaId =>
      text().references(FreeAreas, #id, onDelete: KeyAction.cascade)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A "height region": an elevation threshold applied inside a bounded circle
/// (center + radius). The layer fills terrain *above* [thresholdMeters] when
/// [aboveThreshold] is true (or *below* it otherwise), but only within the
/// circle. The actual fill polygons are generated on demand from terrain tiles
/// and stored in [HeightPolygons]; [generatedAt] is null until first generated.
/// A `height` layer may hold several regions.
class HeightRegions extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();
  RealColumn get centerLat => real()();
  RealColumn get centerLng => real()();
  RealColumn get radiusMeters => real()();

  /// Elevation threshold in metres above sea level (may be negative).
  RealColumn get thresholdMeters => real().withDefault(const Constant(0))();

  /// True = fill terrain above the threshold; false = below.
  BoolColumn get aboveThreshold => boolean().withDefault(const Constant(true))();

  /// Slippy zoom of the terrain tiles sampled when generating (12–14).
  IntColumn get sampleZoom => integer().withDefault(const Constant(13))();
  TextColumn get label => text().nullable()();

  /// When the fill polygons were last generated; null until first generation.
  DateTimeColumn get generatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One generated fill polygon of a [HeightRegions] object (regenerated wholesale
/// each time the region is generated). Its ring lives in [HeightPolygonPoints].
class HeightPolygons extends Table {
  TextColumn get id => text()();
  TextColumn get heightRegionId =>
      text().references(HeightRegions, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One ordered vertex of a [HeightPolygons] ring.
class HeightPolygonPoints extends Table {
  TextColumn get id => text()();
  TextColumn get polygonId =>
      text().references(HeightPolygons, #id, onDelete: KeyAction.cascade)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One POI import on a `poi` layer: a category fetched once (Overpass) within a
/// bounded circle (centre + radius) and stored offline — the layer never
/// refetches. A `poi` layer may hold several sets (further imports add more
/// categories/areas). The actual markers live in [PoiPoints].
class PoiSets extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();

  /// [PoiCategory.key] of the imported category (picks the marker icon).
  TextColumn get categoryKey => text()();
  RealColumn get centerLat => real()();
  RealColumn get centerLng => real()();
  RealColumn get radiusMeters => real()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One stored POI of a [PoiSets] import: its position and OSM `name` (if any).
class PoiPoints extends Table {
  TextColumn get id => text()();
  TextColumn get poiSetId =>
      text().references(PoiSets, #id, onDelete: KeyAction.cascade)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  TextColumn get name => text().nullable()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One public-transport import on a `transit` layer: every **station** in a
/// chosen bounding box, fetched once (Overpass) and stored offline — the layer
/// never refetches. A `transit` layer may hold several sets.
///
/// Line geometry is deliberately **not** stored: fetching route relations with
/// geometry proved unobtainable from the public API for anything larger than a
/// few km² (see `data/transit.dart`), while stops for a whole city come back in
/// seconds. Each station records only *which modes serve it*.
class TransitSets extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();

  /// The imported bounding box.
  RealColumn get south => real()();
  RealColumn get west => real()();
  RealColumn get north => real()();
  RealColumn get east => real()();

  /// Which modes were fetched (packed `TransitMode.bit`s), chosen in the import
  /// dialog. This is the **contents** of the set, not a filter: what it omits
  /// was never stored, so widening it means importing again — which is exactly
  /// what a retry of a failed import must not do differently.
  IntColumn get modeMask => integer()();

  /// Which of those modes are **shown**. This is what the filter sheet writes;
  /// it starts from `modeMask & defaultVisibleModes(diagonal)`, which hides
  /// buses on a city-sized import because they outnumber everything else ~7:1.
  IntColumn get visibleModeMask => integer().withDefault(const Constant(-1))();

  TextColumn get label => text().nullable()();

  /// When the data was pulled from OSM. **Null = the import hasn't succeeded
  /// yet** — the layer shows it as a retry row until it does, so a failure is
  /// something you can come back to rather than a lost snackbar.
  DateTimeColumn get fetchedAt => dateTime().nullable()();

  /// Why the last attempt failed, shown on that retry row.
  TextColumn get lastError => text().nullable()();

  /// Denormalised for the Elements subtitle without a join: stations stored,
  /// and how many raw OSM nodes merged into them.
  IntColumn get stationCount => integer().withDefault(const Constant(0))();
  IntColumn get nodeCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One station of a [TransitSets] import — several OSM nodes (a `stop_position`
/// per platform, plus `platform` nodes) merged into the stop a person would
/// name. Munich's 8 215 raw nodes are 2 672 stations; Pasing Bahnhof alone is
/// 31 of them.
class TransitStops extends Table {
  TextColumn get id => text()();
  TextColumn get setId =>
      text().references(TransitSets, #id, onDelete: KeyAction.cascade)();

  /// The OSM node the station was keyed on (the `station` node when there was
  /// one), so it can be looked up on osm.org.
  IntColumn get osmId => integer()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  TextColumn get name => text().nullable()();

  /// The modes serving this station (packed bits); 0 = the data doesn't say.
  /// A station is drawn iff `modeMask & set.visibleModeMask != 0`.
  IntColumn get modeMask => integer().withDefault(const Constant(0))();

  /// How many OSM nodes merged into this station.
  IntColumn get nodeCount => integer().withDefault(const Constant(1))();

  /// The OSM `route_ref` tag when present (~18 % of stops) — free text shown as
  /// a hint. Never parsed, never relied on.
  TextColumn get routeRef => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// On-disk cache of map tile images, keyed by their full fetch [url] (so the base
/// OSM layer and the transport overlays — which have distinct URLs — share one
/// table). Filled as tiles are browsed/prefetched; evicted least-recently-used
/// first once the total exceeds a size cap. This is *cache*, not user data:
/// "Clear all data" leaves it alone; it has its own "Clear cached map tiles"
/// button. Lets the map keep rendering already-seen/prefetched tiles offline.
class TileCache extends Table {
  /// Full resolved tile URL (`{z}/{x}/{y}` already substituted).
  TextColumn get url => text()();

  /// Raw image bytes (PNG) as returned by the tile server.
  BlobColumn get bytes => blob()();

  /// HTTP ETag if the server sent one (currently stored, not yet revalidated).
  TextColumn get etag => text().nullable()();

  /// Byte length of [bytes], denormalised so the size cap can sum cheaply.
  IntColumn get sizeBytes => integer()();

  /// When the tile was fetched (ms since epoch).
  IntColumn get fetchedAt => integer()();

  /// When the tile was last served from cache (ms since epoch). Drives LRU
  /// eviction.
  IntColumn get lastUsedAt => integer()();

  @override
  Set<Column> get primaryKey => {url};
}

/// Persisted last-successful Overpass overlay result, one row per [kind]
/// ('poi' or 'border'). Stores the parsed results as [payload] JSON plus the
/// bounds and filter mask they were fetched for, so the overlays reappear
/// instantly on launch (including offline) and the in-memory coverage check can
/// suppress a redundant refetch while the view stays inside [south]…[east].
class OverpassCache extends Table {
  /// 'poi' or 'border'.
  TextColumn get kind => text()();

  /// JSON-encoded list of results (see toJson helpers in overpass/borders.dart).
  TextColumn get payload => text()();

  RealColumn get south => real()();
  RealColumn get west => real()();
  RealColumn get north => real()();
  RealColumn get east => real()();

  /// The category/level bitmask (POI categories or active border-level bits)
  /// the payload was fetched with.
  IntColumn get maskBits => integer()();

  /// When the payload was fetched (ms since epoch).
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {kind};
}

/// App-wide settings, stored as a single row (id == 1).
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Global measurement uncertainty in metres; rendered as a lighter band.
  RealColumn get uncertaintyMeters =>
      real().withDefault(const Constant(500))();

  /// Last map camera, restored on launch. Null until the user has moved the map.
  RealColumn get lastLat => real().nullable()();
  RealColumn get lastLng => real().nullable()();
  RealColumn get lastZoom => real().nullable()();

  /// When true, transparent public-transport tile overlays (ÖPNVKarte +
  /// OpenRailwayMap) are drawn above the base map.
  BoolColumn get transportOverlay =>
      boolean().withDefault(const Constant(false))();

  /// The Overpass endpoint that last served a transit import, so the next one
  /// starts with the instance that was actually up. Null = start at the top of
  /// `transitEndpoints`.
  TextColumn get transitEndpoint => text().nullable()();

  /// Packed bitmask of enabled map-POI categories (see `poiCategories` in
  /// `overpass.dart`). 0 = none shown.
  IntColumn get poiCategories => integer().withDefault(const Constant(0))();

  /// Packed bitmask of enabled administrative-border levels (see `borderLevels`
  /// in `borders.dart`). 0 = none shown.
  IntColumn get borderLevels => integer().withDefault(const Constant(0))();

  /// Whether the right-side utility FABs are shown (vs. collapsed behind the
  /// expand/hide toggle). Persisted so the choice survives a relaunch.
  BoolColumn get toolsExpanded =>
      boolean().withDefault(const Constant(true))();

  /// Whether the base OSM tile layer is drawn. The base map behaves like a
  /// pinned bottom "layer": it can be hidden (this flag) but never deleted.
  BoolColumn get basemapVisible =>
      boolean().withDefault(const Constant(true))();

  /// Opacity of the base OSM tile layer in [0, 1] — how strongly the map shows
  /// through beneath the zone layers. 1 = fully opaque (the default).
  RealColumn get basemapOpacity => real().withDefault(const Constant(1.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Layers,
    Circles,
    Planes,
    AppSettings,
    Subspaces,
    SubspacePoints,
    FreeLines,
    FreeLinePoints,
    FreeAreas,
    FreeAreaPoints,
    HeightRegions,
    HeightPolygons,
    HeightPolygonPoints,
    PoiSets,
    PoiPoints,
    TransitSets,
    TransitStops,
    TileCache,
    OverpassCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'zonecraft'));

  /// Constructor for tests, taking an in-memory executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(layers, layers.type);
            await m.addColumn(layers, layers.isInverted);
            await m.createTable(planes);
            await m.createTable(appSettings);
          }
          if (from < 3) {
            await m.addColumn(appSettings, appSettings.lastLat);
            await m.addColumn(appSettings, appSettings.lastLng);
            await m.addColumn(appSettings, appSettings.lastZoom);
          }
          if (from < 4) {
            // New default uncertainty is 500 m. Bump an existing row that is
            // still on the old default of 0 (the column default only governs
            // freshly inserted rows). A user who deliberately chose 0 is reset
            // to 500 — accepted as a one-tap change.
            await customStatement(
              'UPDATE app_settings SET uncertainty_meters = 500 '
              'WHERE uncertainty_meters = 0',
            );
          }
          if (from < 5) {
            await m.createTable(subspaces);
            await m.createTable(subspacePoints);
          }
          if (from < 6) {
            await m.addColumn(appSettings, appSettings.transportOverlay);
          }
          if (from < 7) {
            await m.addColumn(appSettings, appSettings.poiCategories);
          }
          if (from < 8) {
            await m.addColumn(appSettings, appSettings.borderLevels);
          }
          if (from < 9) {
            await m.createTable(freeLines);
            await m.createTable(freeLinePoints);
            await m.createTable(freeAreas);
            await m.createTable(freeAreaPoints);
          }
          if (from < 10) {
            await m.createTable(tileCache);
            await m.createTable(overpassCache);
          }
          if (from < 11) {
            await m.createTable(heightRegions);
            await m.createTable(heightPolygons);
            await m.createTable(heightPolygonPoints);
          }
          if (from < 12) {
            await m.addColumn(appSettings, appSettings.toolsExpanded);
          }
          if (from < 13) {
            await m.addColumn(subspacePoints, subspacePoints.label);
          }
          if (from < 14) {
            await m.addColumn(freeLines, freeLines.inclusionLat);
            await m.addColumn(freeLines, freeLines.inclusionLng);
            await m.addColumn(freeLines, freeLines.inclusionRadiusMeters);
          }
          if (from < 15) {
            await m.createTable(poiSets);
            await m.createTable(poiPoints);
          }
          if (from < 16) {
            await m.addColumn(layers, layers.opacity);
            await m.addColumn(appSettings, appSettings.basemapVisible);
            await m.addColumn(appSettings, appSettings.basemapOpacity);
          }
          if (from < 17) {
            // v16 stored `opacity` as a *multiplier* of the built-in fill
            // translucency (1.0 = the default look). v17 makes `opacity` the
            // fill opacity itself (1.0 = fully opaque, hiding the map).
            // Rescale existing region layers so they look unchanged; POI
            // layers use opacity as marker opacity (same in both), so skip them.
            await customStatement(
              'UPDATE layers SET opacity = opacity * '
              '$kDefaultRegionLayerOpacity '
              "WHERE type != 'poi'",
            );
          }
          if (from < 18) {
            // v18 introduced the `transit` layer type; v19 reshaped it, so its
            // tables are created once in the v19 block below.
          }
          if (from < 19) {
            // Transit became **stations only**: route geometry is not
            // obtainable from the public API at any useful scale (see
            // data/transit.dart), so the three route tables go, and the two
            // survivors change shape — `fetched_at` becomes nullable to mean
            // "not imported yet", which SQLite cannot relax in place.
            //
            // So the transit tables are dropped and recreated rather than
            // altered. This DOES discard a v18 transit import — deliberately:
            // the v18 model is the one being abandoned, and re-importing is now
            // the cheap path (a whole city in seconds, where geometry never
            // worked at all). Nothing outside `transit_*` is touched.
            for (final t in const [
              'transit_route_stops',
              'transit_route_parts',
              'transit_routes',
              'transit_stops',
              'transit_sets',
            ]) {
              await customStatement('DROP TABLE IF EXISTS $t');
            }
            await m.createTable(transitSets);
            await m.createTable(transitStops);
            await m.addColumn(appSettings, appSettings.transitEndpoint);
          }
        },
        beforeOpen: (details) async {
          // Required for the Circles/Planes -> Layers ON DELETE CASCADE to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
