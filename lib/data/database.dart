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
/// 'borders' is region-like (it has an area fill), so it takes the region
/// default even though its fill is off until "Colour areas" is ticked.
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

  /// **`borders` layers only.** The OSM `admin_level` this layer holds, as a
  /// string ('2', '4', '6', '8', '9', '10'); null on every other type.
  ///
  /// Chosen when the layer is created and never changed: one layer holds one
  /// level, which is what makes "no two neighbours share a colour" well defined
  /// (areas of different levels nest rather than tile, so mixing them would
  /// make adjacency meaningless).
  TextColumn get borderLevel => text().nullable()();

  /// **`borders` only.** Fill each area with its [BorderAreas.colorIndex]
  /// palette colour, instead of drawing outlines alone.
  BoolColumn get borderFillAreas =>
      boolean().withDefault(const Constant(false))();

  /// **`borders` only.** Draw each area's name on a plate at its label anchor.
  BoolColumn get borderShowNames =>
      boolean().withDefault(const Constant(false))();

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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

  /// The OSM element this POI came from, so a second import over overlapping
  /// ground can recognise it (v21). **Both** parts are needed: ids are only
  /// unique *within* a type, so node 240109189 and way 240109189 are different
  /// things.
  ///
  /// Nullable because rows imported before v21 never recorded it, and a
  /// backfill is impossible — the id was not merely unstored, it was never
  /// fetched. An unidentified row simply doesn't participate in dedup; see
  /// [Repository.addPoiPoints].
  TextColumn get osmType => text().nullable()();
  IntColumn get osmId => integer().nullable()();

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

  /// Per-element colour (v22). Null = follow the layer: the element paints in
  /// its auto **shade** of the layer colour, picked by [colorShade] so the
  /// elements of one layer tell each other apart and all follow a layer
  /// recolour. A set value overrides that and survives a layer recolour, which
  /// is what makes the recolour dialog ask what to do with them.
  IntColumn get colorArgb => integer().nullable()();

  /// Which auto shade this element takes, assigned in creation order within the
  /// layer. **0 is the layer colour exactly**, which is what every row
  /// migrating in from v21 gets — an untouched map must look untouched.
  IntColumn get colorShade => integer().withDefault(const Constant(0))();


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

/// One administrative-border import on a `borders` layer: every area of the
/// layer's [Layers.borderLevel] intersecting a chosen bounding box, fetched
/// once (Overpass) and stored offline — the layer never refetches. A `borders`
/// layer may hold several sets.
///
/// **Whole relations are downloaded and then clipped on the device.** A
/// boundary is only fillable if you have all of it: asking Overpass for member
/// ways clipped to the viewport (what the old settings overlay did) gives loose
/// lines with no interior side. So the query fetches complete relations and the
/// import stores only the part inside [south]…[east] — which is also what keeps
/// a country-level box (17 MB downloaded near the DE/AT border) small on disk.
class BorderSets extends Table {
  TextColumn get id => text()();
  TextColumn get layerId =>
      text().references(Layers, #id, onDelete: KeyAction.cascade)();

  /// The imported box. Doubles as the clip rectangle the stored geometry was
  /// cut to, which is what lets the painter drop outline segments lying on it.
  RealColumn get south => real()();
  RealColumn get west => real()();
  RealColumn get north => real()();
  RealColumn get east => real()();

  /// The OSM `admin_level` fetched, copied from the layer so a set stays
  /// self-describing.
  TextColumn get adminLevel => text()();

  TextColumn get label => text().nullable()();

  /// When the data was pulled from OSM. A failed import writes **nothing** —
  /// unlike transit there is no retry row, because re-running an import is two
  /// taps and a half-written set would have to remember the whole query.
  DateTimeColumn get fetchedAt => dateTime()();

  /// Denormalised for the Elements subtitle without a join.
  IntColumn get areaCount => integer().withDefault(const Constant(0))();
  IntColumn get pointCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One administrative area of a [BorderSets] import, clipped to its set's box.
///
/// **Geometry is an encoded blob, not point rows.** One state boundary is
/// 119 238 points; the `HeightPolygons → HeightPolygonPoints` pattern would
/// mean that many UUIDs and rows for a single area. Border areas are derived,
/// non-editable OSM snapshots (like transit stops), so [rings] carries the whole
/// multi-ring geometry through one codec instead — see `geo/border_areas.dart`.
class BorderAreas extends Table {
  TextColumn get id => text()();
  TextColumn get setId =>
      text().references(BorderSets, #id, onDelete: KeyAction.cascade)();

  /// The OSM relation id, so the area can be looked up on osm.org — and the key
  /// adjacency is computed against.
  IntColumn get osmId => integer()();
  TextColumn get name => text().nullable()();

  /// Index into the painter's palette, assigned so no two areas sharing a
  /// border get the same one. Stored rather than derived, so the palette can be
  /// retuned without re-importing.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// The area's own bounding box, for viewport culling without decoding
  /// [rings].
  RealColumn get south => real()();
  RealColumn get west => real()();
  RealColumn get north => real()();
  RealColumn get east => real()();

  /// Precomputed anchor for the name plate.
  RealColumn get labelLat => real()();
  RealColumn get labelLng => real()();

  IntColumn get pointCount => integer()();

  /// `encodeRings` output: `[[[lat,lng], …], …]`, outer ring first, holes
  /// after. **Holes carry no role flag** — the painter fills with
  /// [PathFillType.evenOdd], exactly as the height layer does.
  TextColumn get rings => text()();

  /// JSON array of the relation's member way ids, kept only for adjacency:
  /// two areas share a border iff they share a way id, which is exact and free.
  TextColumn get wayIds => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  /// Per-area colour override (v22). Null = the layer's own rule: the
  /// neighbour-distinct palette entry at [colorIndex] when "Colour areas" is
  /// on, the layer colour otherwise. Set = this exact colour, either way.
  IntColumn get colorArgb => integer().nullable()();

  /// When the outline was last reshaped by hand (v23). **Null = untouched**:
  /// the geometry is exactly what OSM returned.
  ///
  /// Reshaping is allowed, but it forks the area from upstream, and a fork
  /// nothing records is the real problem — the row still carries its
  /// [osmId], so a later import over the same ground skips it as "already
  /// present" and the edit silently wins over whatever OSM now says. This
  /// column is what lets the Elements list and the editor say so out loud.
  /// The original geometry is **not** kept: an area is one blob and storing a
  /// second copy of a 119 238-point boundary to enable an undo nobody asked
  /// for is not a trade worth making — "Convert to freehand area" exists for
  /// people who want an editable copy alongside the snapshot.
  DateTimeColumn get editedAt => dateTime().nullable()();


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
    BorderSets,
    BorderAreas,
    TileCache,
    OverpassCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'zonecraft'));

  /// Constructor for tests, taking an in-memory executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 23;

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
          if (from < 20) {
            // The `borders` layer type, replacing the two Settings overlays.
            // `AppSettings.transportOverlay` and `.borderLevels` become dead
            // columns rather than being dropped — the same treatment
            // `poiCategories` got when the POI layer type replaced *its*
            // overlay. Nothing reads them; nothing needs migrating out of them.
            await m.addColumn(layers, layers.borderLevel);
            await m.addColumn(layers, layers.borderFillAreas);
            await m.addColumn(layers, layers.borderShowNames);
            await m.createTable(borderSets);
            await m.createTable(borderAreas);
          }
          if (from < 21) {
            // POIs gain the OSM identity they never stored, so re-importing
            // overlapping ground stops duplicating them. Transit and borders
            // already had `osm_id` — they just weren't consulting it.
            //
            // Existing rows stay null: the id wasn't dropped on the way in, it
            // was never requested from Overpass, so there is nothing to
            // backfill from. They keep working and are simply invisible to
            // dedup, which is the honest outcome — guessing identity from
            // coordinates would silently merge two genuinely different POIs
            // that share a doorway.
            await m.addColumn(poiPoints, poiPoints.osmType);
            await m.addColumn(poiPoints, poiPoints.osmId);
          }
          if (from < 22) {
            // Per-element colours. Every existing row keeps `color_argb` null
            // and `color_shade` 0, and shade 0 *is* the layer colour, so an
            // upgraded map renders pixel-identically until the user adds or
            // recolours something. Only new elements start taking shades.
            await m.addColumn(circles, circles.colorArgb);
            await m.addColumn(circles, circles.colorShade);
            await m.addColumn(planes, planes.colorArgb);
            await m.addColumn(planes, planes.colorShade);
            await m.addColumn(subspaces, subspaces.colorArgb);
            await m.addColumn(subspaces, subspaces.colorShade);
            await m.addColumn(freeLines, freeLines.colorArgb);
            await m.addColumn(freeLines, freeLines.colorShade);
            await m.addColumn(freeAreas, freeAreas.colorArgb);
            await m.addColumn(freeAreas, freeAreas.colorShade);
            await m.addColumn(heightRegions, heightRegions.colorArgb);
            await m.addColumn(heightRegions, heightRegions.colorShade);
            await m.addColumn(poiSets, poiSets.colorArgb);
            await m.addColumn(poiSets, poiSets.colorShade);
            await m.addColumn(transitSets, transitSets.colorArgb);
            await m.addColumn(transitSets, transitSets.colorShade);
            await m.addColumn(borderAreas, borderAreas.colorArgb);
          }
          if (from < 23) {
            // Border outlines became reshapeable. Every existing area is by
            // definition untouched OSM geometry, so `edited_at` starts null —
            // which is exactly what the column means.
            await m.addColumn(borderAreas, borderAreas.editedAt);
          }
        },
        beforeOpen: (details) async {
          // Required for the Circles/Planes -> Layers ON DELETE CASCADE to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
