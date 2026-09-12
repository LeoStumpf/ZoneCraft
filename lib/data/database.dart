// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'poi_sets.dart';
import 'undo_journal.dart';

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
/// The marker layer type ('poi') is crisp at 1.0 — there is no fill to see
/// the map through. One source of truth, because the repository (on create)
/// and the drawer (deciding whether to show an opacity chip) must agree; they
/// used to duplicate the rule inline, which is how a third type silently
/// drifts. 'borders' is region-like (it has an area fill), so it takes the
/// region default even though its fill is off until "Colour areas" is ticked.
/// A **mixed** layer takes the region default: its opacity governs the region
/// composite, while its markers stay crisp (they are drawn, not filled — there
/// is nothing to see the map through). Defaulting it to 1.0 instead would make
/// a circle moved into it opaque, which is the more surprising of the two.
double defaultLayerOpacity(String type) =>
    type == 'poi' ? 1.0 : kDefaultRegionLayerOpacity;

/// A map overlay layer. Layers stack on the map ordered by [sortOrder]
/// (higher = drawn on top) and can be toggled on/off via [isVisible].
///
/// A layer holds a single object [type] (see `layer_types.dart`). When
/// [isInverted] is true the layer fills everything *not* covered by its objects.
class Layers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Fill/stroke colour as a packed ARGB int (see [Color.toARGB32]).
  IntColumn get colorArgb => integer()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer()();

  /// Object kind this layer holds: one of the `k*` types in `layer_types.dart`.
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

  /// Where this element sits in its layer's stack (v26). **Higher is drawn
  /// later, i.e. in front**, and the scope is one layer *and one table*: a
  /// mixed layer's cross-kind order stays fixed (regions -> markers),
  /// because that is the only order its separate painters can honour.
  ///
  /// Deliberately not [colorShade], which used to imply this: that column also
  /// picks the auto shade, so moving an element forward would have recoloured
  /// it. Assigned one past the layer's current maximum on create, so a new
  /// element lands on top — which is what "the newest element wins an overlap"
  /// already meant, now said out loud instead of inferred.
  IntColumn get zOrder => integer().withDefault(const Constant(0))();


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

  /// Where this element sits in its layer's stack (v26). **Higher is drawn
  /// later, i.e. in front**, and the scope is one layer *and one table*: a
  /// mixed layer's cross-kind order stays fixed (regions -> markers),
  /// because that is the only order its separate painters can honour.
  ///
  /// Deliberately not [colorShade], which used to imply this: that column also
  /// picks the auto shade, so moving an element forward would have recoloured
  /// it. Assigned one past the layer's current maximum on create, so a new
  /// element lands on top — which is what "the newest element wins an overlap"
  /// already meant, now said out loud instead of inferred.
  IntColumn get zOrder => integer().withDefault(const Constant(0))();


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

  /// Where this element sits in its layer's stack (v26). **Higher is drawn
  /// later, i.e. in front**, and the scope is one layer *and one table*: a
  /// mixed layer's cross-kind order stays fixed (regions -> markers),
  /// because that is the only order its separate painters can honour.
  ///
  /// Deliberately not [colorShade], which used to imply this: that column also
  /// picks the auto shade, so moving an element forward would have recoloured
  /// it. Assigned one past the layer's current maximum on create, so a new
  /// element lands on top — which is what "the newest element wins an overlap"
  /// already meant, now said out loud instead of inferred.
  IntColumn get zOrder => integer().withDefault(const Constant(0))();


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

  /// Where this element sits in its layer's stack (v26). **Higher is drawn
  /// later, i.e. in front**, and the scope is one layer *and one table*: a
  /// mixed layer's cross-kind order stays fixed (regions -> markers),
  /// because that is the only order its separate painters can honour.
  ///
  /// Deliberately not [colorShade], which used to imply this: that column also
  /// picks the auto shade, so moving an element forward would have recoloured
  /// it. Assigned one past the layer's current maximum on create, so a new
  /// element lands on top — which is what "the newest element wins an overlap"
  /// already meant, now said out loud instead of inferred.
  IntColumn get zOrder => integer().withDefault(const Constant(0))();


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

  /// Where this element sits in its layer's stack (v26). **Higher is drawn
  /// later, i.e. in front**, and the scope is one layer *and one table*: a
  /// mixed layer's cross-kind order stays fixed (regions -> markers),
  /// because that is the only order its separate painters can honour.
  ///
  /// Deliberately not [colorShade], which used to imply this: that column also
  /// picks the auto shade, so moving an element forward would have recoloured
  /// it. Assigned one past the layer's current maximum on create, so a new
  /// element lands on top — which is what "the newest element wins an overlap"
  /// already meant, now said out loud instead of inferred.
  IntColumn get zOrder => integer().withDefault(const Constant(0))();


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

/// How a [PoiSets] row came to be — see [PoiSets.source].
const kPoiSourceManual = 'manual';
const kPoiSourceRadius = 'radius';
const kPoiSourceBox = 'box';

/// One set of markers on a `poi` layer. Three kinds share the table, told
/// apart by [source]:
///
/// * **radius** — an OSM category fetched once (Overpass) within a bounded
///   circle (centre + radius) and stored offline; the layer never refetches.
/// * **box** — every public-transport **station** in a chosen bounding box
///   (v27; formerly the `transit` layer type). Line geometry is deliberately
///   **not** stored: fetching route relations with geometry proved
///   unobtainable from the public API for anything larger than a few km² (see
///   `data/transit.dart`), while stops for a whole city come back in seconds.
///   Each station records only *which modes serve it* ([PoiPoints.modeMask]).
/// * **manual** — a category the user named and fills by tapping (v25).
///
/// A `poi` layer may hold several sets. The actual markers live in [PoiPoints].
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

  /// Where this element sits in its layer's stack (v26). **Higher is drawn
  /// later, i.e. in front**, and the scope is one layer *and one table*: a
  /// mixed layer's cross-kind order stays fixed (regions -> markers),
  /// because that is the only order its separate painters can honour.
  ///
  /// Deliberately not [colorShade], which used to imply this: that column also
  /// picks the auto shade, so moving an element forward would have recoloured
  /// it. Assigned one past the layer's current maximum on create, so a new
  /// element lands on top — which is what "the newest element wins an overlap"
  /// already meant, now said out loud instead of inferred.
  IntColumn get zOrder => integer().withDefault(const Constant(0))();

  /// Which kind of set this is: [kPoiSourceManual], [kPoiSourceRadius] or
  /// [kPoiSourceBox] (v27; replaced the v25 `is_manual` flag when station
  /// imports joined the table — a bool and a nullable box read together in
  /// eight places is exactly the two-copies rule this app keeps avoiding).
  ///
  /// The distinction is what keeps an import honest: a fetched set is a
  /// snapshot of what OSM returned, so its query describes something that
  /// already ran and nothing may be added to it by hand. A manual set describes
  /// no query at all — [centerLat]/[centerLng]/[radiusMeters] hold the map
  /// centre and 0 purely because the columns are NOT NULL, and the editor does
  /// not show them. A box set likewise holds its box's centre and half-diagonal
  /// there; nothing reads them for a box either.
  // A literal, not [kPoiSourceRadius]: the schema dump copies the default
  // expression verbatim into a file that cannot see this library's constants.
  TextColumn get source => text().withDefault(const Constant('radius'))();

  /// **Box sets only.** The imported bounding box; null on the other kinds.
  RealColumn get south => real().nullable()();
  RealColumn get west => real().nullable()();
  RealColumn get north => real().nullable()();
  RealColumn get east => real().nullable()();

  /// **Box sets only.** Which modes were fetched (packed `TransitMode.bit`s),
  /// chosen in the import dialog. This is the **contents** of the set, not a
  /// filter: what it omits was never stored, so widening it means importing
  /// again — which is exactly what a retry of a failed import must not do
  /// differently. 0 on the other kinds.
  IntColumn get modeMask => integer().withDefault(const Constant(0))();

  /// **Box sets only.** Which of those modes are **shown**. This is what the
  /// filter sheet writes; it starts from `modeMask & defaultVisibleModes(...)`,
  /// which hides buses on a city-sized import because they outnumber
  /// everything else ~7:1.
  IntColumn get visibleModeMask => integer().withDefault(const Constant(-1))();

  /// When the data was pulled from OSM. **Null on an import = it hasn't
  /// succeeded yet** — the layer shows it as a retry row until it does, so a
  /// failure is something you can come back to rather than a lost snackbar.
  /// Always null on a manual set, which was never fetched.
  DateTimeColumn get fetchedAt => dateTime().nullable()();

  /// Why the last attempt failed, shown on that retry row.
  TextColumn get lastError => text().nullable()();

  /// Marker icon for a manual set — a key into `poiIcons` (`ui/poi_icons.dart`).
  ///
  /// Null on an import, which takes its icon from [categoryKey] instead, and
  /// null on a manual set that chose one of the built-in categories. Resolved
  /// in one place, `poiSetIcon`.
  TextColumn get iconKey => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One stored point of a [PoiSets] set: its position and OSM `name` (if any).
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
  /// [Repository.fillPoiSet].
  TextColumn get osmType => text().nullable()();
  IntColumn get osmId => integer().nullable()();

  /// **Stations only** (a box set's points): the modes serving this station
  /// (packed bits); 0 = the data doesn't say, and 0 on every other kind of
  /// point. A station is drawn iff `poiPointVisible` says so — one predicate
  /// for the painter and the hit test.
  IntColumn get modeMask => integer().withDefault(const Constant(0))();

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
    BorderSets,
    BorderAreas,
    TileCache,
    OverpassCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// `driftDatabase(name:)` resolves to `NativeDatabase.createBackgroundConnection`
  /// in `singleClientMode`, with drift's read-pool size left at its default of
  /// **0** — so the whole app talks to exactly one sqlite3 connection on one
  /// background isolate.
  ///
  /// [undo] depends on that: its journal lives in TEMP tables, which belong to a
  /// connection rather than to the file. Passing `DriftNativeOptions` with a
  /// read pool or `shareAcrossIsolates` would split reads onto a connection
  /// where those tables do not exist — and it would fail as "no such table",
  /// far from here. `test/undo_journal_test.dart` pins it.
  AppDatabase() : super(driftDatabase(name: 'zonecraft'));

  /// Constructor for tests, taking an in-memory executor.
  AppDatabase.forTesting(super.e);

  /// Row-level undo/redo. Installed in `beforeOpen` so its triggers are in
  /// place before any user statement can run.
  late final UndoJournal undo = UndoJournal(this);

  @override
  Future<void> close() async {
    // Before `super`, not after: the journal holds an idle timer and a write
    // subscription, and either firing against a closed database throws.
    await undo.dispose();
    return super.close();
  }

  @override
  int get schemaVersion => 27;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(layers, layers.type);
            await m.addColumn(layers, layers.isInverted);
            // `planes` was created here until v27 folded the type into
            // `subspace`. A v1 database has no planes to carry across, so the
            // table is simply never built; v27 copies only when `from >= 2`.
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
            // The two survivors were created here until v27 merged them into
            // `poi_sets`/`poi_points`; a database this old has no stations to
            // carry, so v27 copies only when `from >= 19`.
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
            // `planes` and `transit_sets` are gone in v27, but the copy there
            // reads these columns, so a database that still has the tables
            // gets them by raw SQL (the Dart table classes no longer exist).
            if (from >= 2) {
              await customStatement(
                'ALTER TABLE planes ADD COLUMN color_argb INTEGER NULL',
              );
              await customStatement(
                'ALTER TABLE planes ADD COLUMN color_shade INTEGER '
                'NOT NULL DEFAULT 0',
              );
            }
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
            if (from >= 19) {
              await customStatement(
                'ALTER TABLE transit_sets ADD COLUMN color_argb INTEGER NULL',
              );
              await customStatement(
                'ALTER TABLE transit_sets ADD COLUMN color_shade INTEGER '
                'NOT NULL DEFAULT 0',
              );
            }
            await m.addColumn(borderAreas, borderAreas.colorArgb);
          }
          if (from < 23) {
            // Border outlines became reshapeable. Every existing area is by
            // definition untouched OSM geometry, so `edited_at` starts null —
            // which is exactly what the column means.
            await m.addColumn(borderAreas, borderAreas.editedAt);
          }
          if (from < 24) {
            // The `track` type (recorded GPS lines) was added here and removed
            // in v27. Its tables and the two `layers` columns are no longer
            // created on the way up: v27 drops them wherever they exist.
          }
          if (from < 25) {
            // Hand-placed POIs. Every existing set is an Overpass import by
            // definition, so `is_manual` starts false and `icon_key` null —
            // which is exactly what those columns mean for an import.
            // `is_manual` was added here and folded into `source` in v27; a
            // database this old has no manual sets, and `source` defaults to
            // radius, so only `icon_key` is still added.
            await m.addColumn(poiSets, poiSets.iconKey);
          }
          if (from < 26) {
            // Per-element draw order. Existing maps must render pixel-for-pixel
            // as they did, so every row is backfilled with the order it already
            // paints in: the region painter groups by colour and orders the
            // groups by `color_shade` (the per-layer creation counter), so
            // ranking each layer's rows by (color_shade, created_at, id)
            // reproduces exactly today's stack. Where several elements share a
            // colour they union flat, so any total order over *them* is a new
            // fact rather than a changed one.
            // `createTable` in an earlier block builds **today's** table, so a
            // table this upgrade run has just created already has the column
            // and adding it again is a hard SQL error. Each add is therefore
            // guarded by the version its table was introduced in: at or above
            // it, the table came from the old database and needs the column;
            // below it, `createTable` above already put it there.
            await m.addColumn(circles, circles.zOrder); // in the first schema
            if (from >= 2) {
              await customStatement(
                'ALTER TABLE planes ADD COLUMN z_order INTEGER '
                'NOT NULL DEFAULT 0',
              );
            }
            if (from >= 5) await m.addColumn(subspaces, subspaces.zOrder);
            if (from >= 9) await m.addColumn(freeLines, freeLines.zOrder);
            if (from >= 9) await m.addColumn(freeAreas, freeAreas.zOrder);
            if (from >= 11) {
              await m.addColumn(heightRegions, heightRegions.zOrder);
            }
            if (from >= 15) await m.addColumn(poiSets, poiSets.zOrder);
            if (from >= 19) {
              await customStatement(
                'ALTER TABLE transit_sets ADD COLUMN z_order INTEGER '
                'NOT NULL DEFAULT 0',
              );
            }
            // `planes` and `transit_sets` are ranked too, although v27 drops
            // them: the copy there carries `z_order` across, so the order a
            // plane or a station import painted in survives the fold.
            for (final table in [
              'circles',
              if (from >= 2) 'planes',
              'subspaces',
              'free_lines',
              'free_areas',
              'height_regions',
              'poi_sets',
              if (from >= 19) 'transit_sets',
            ]) {
              // A correlated count is O(n^2) in a layer's element count, which
              // is tens — not the thousands a *point* table holds. These are
              // element tables only.
              await customStatement(
                'UPDATE $table SET z_order = ('
                'SELECT COUNT(*) FROM $table o '
                'WHERE o.layer_id = $table.layer_id AND ('
                'o.color_shade < $table.color_shade OR '
                '(o.color_shade = $table.color_shade AND '
                'o.created_at < $table.created_at) OR '
                '(o.color_shade = $table.color_shade AND '
                'o.created_at = $table.created_at AND o.id < $table.id)))',
              );
            }
          }
          if (from < 27) {
            // Ten object types became seven. Nothing is silently lost except
            // `track`, which the user chose to drop:
            //
            // * `planes` -> `subspace`. A plane *is* the two-point subspace
            //   (`sphericalCell(main, [far])`), so each row becomes a subspace
            //   with two points, the near side as main. Ids are kept (the
            //   plane id is the subspace id) and z is lifted above the layer's
            //   existing subspaces so the two stacks concatenate.
            // * `transit` -> `poi`. Station imports become box-sourced POI
            //   sets, stations become points with a `mode_mask`; ids kept.
            //   A pending/failed import stays a pending row.
            // * `track` is gone: tables, layer rows and the two `layers`
            //   columns. FKs are off during migration, so the layer delete
            //   cascades nothing — the child tables are dropped regardless.
            //
            // Every raw statement names only columns that exist on *every*
            // database old enough to have the table: the guards above put the
            // v22/v26 columns on `planes`/`transit_sets` by raw SQL.
            if (from >= 2) {
              await customStatement(
                'INSERT INTO subspaces '
                '(id, layer_id, label, created_at, color_argb, color_shade, '
                'z_order) '
                'SELECT p.id, p.layer_id, p.label, p.created_at, p.color_argb, '
                'p.color_shade, p.z_order + (SELECT COALESCE(MAX(s.z_order), '
                '-1) + 1 FROM subspaces s WHERE s.layer_id = p.layer_id) '
                'FROM planes p',
              );
              await customStatement(
                'INSERT INTO subspace_points '
                '(id, subspace_id, lat, lng, sort_order, is_main, label, '
                'created_at) '
                "SELECT p.id || '-a', p.id, "
                'CASE WHEN p.near_a THEN p.a_lat ELSE p.b_lat END, '
                'CASE WHEN p.near_a THEN p.a_lng ELSE p.b_lng END, '
                '0, 1, NULL, p.created_at FROM planes p',
              );
              await customStatement(
                'INSERT INTO subspace_points '
                '(id, subspace_id, lat, lng, sort_order, is_main, label, '
                'created_at) '
                "SELECT p.id || '-b', p.id, "
                'CASE WHEN p.near_a THEN p.b_lat ELSE p.a_lat END, '
                'CASE WHEN p.near_a THEN p.b_lng ELSE p.a_lng END, '
                '1, 0, NULL, p.created_at FROM planes p',
              );
              await customStatement(
                "UPDATE layers SET type = 'subspace' WHERE type = 'planes'",
              );
              await customStatement('DROP TABLE planes');
            }

            // The POI tables grow what a station import needs. Guarded like
            // v26: below v15 `createTable` already built today's shape.
            if (from >= 15) {
              await m.addColumn(poiSets, poiSets.source);
              await m.addColumn(poiSets, poiSets.south);
              await m.addColumn(poiSets, poiSets.west);
              await m.addColumn(poiSets, poiSets.north);
              await m.addColumn(poiSets, poiSets.east);
              await m.addColumn(poiSets, poiSets.modeMask);
              await m.addColumn(poiSets, poiSets.visibleModeMask);
              await m.addColumn(poiSets, poiSets.fetchedAt);
              await m.addColumn(poiSets, poiSets.lastError);
              await m.addColumn(poiPoints, poiPoints.modeMask);
            }
            if (from >= 25) {
              await customStatement(
                "UPDATE poi_sets SET source = '$kPoiSourceManual' "
                'WHERE is_manual = 1',
              );
              await m.dropColumn(poiSets, 'is_manual');
            }
            // A radius set was only ever created *after* a successful fetch,
            // so its creation instant is its fetch instant. Without this every
            // existing import would come up as a retry row.
            await customStatement(
              'UPDATE poi_sets SET fetched_at = created_at '
              "WHERE source = '$kPoiSourceRadius'",
            );

            if (from >= 19) {
              await customStatement(
                'INSERT INTO poi_sets '
                '(id, layer_id, category_key, center_lat, center_lng, '
                'radius_meters, label, created_at, color_argb, color_shade, '
                'z_order, icon_key, source, south, west, north, east, '
                'mode_mask, visible_mode_mask, fetched_at, last_error) '
                "SELECT t.id, t.layer_id, '$kTransitStationCategoryKey', "
                '(t.south + t.north) / 2.0, (t.west + t.east) / 2.0, 0, '
                't.label, t.created_at, t.color_argb, t.color_shade, '
                't.z_order + (SELECT COALESCE(MAX(s.z_order), -1) + 1 '
                'FROM poi_sets s WHERE s.layer_id = t.layer_id), '
                "NULL, '$kPoiSourceBox', t.south, t.west, t.north, t.east, "
                't.mode_mask, t.visible_mode_mask, t.fetched_at, t.last_error '
                'FROM transit_sets t',
              );
              // The covering radius is derived in Dart, by the same helper
              // the repository uses for a new box set, so the database and
              // the app agree by construction rather than by two formulas.
              final boxes = await customSelect(
                'SELECT id, south, west, north, east FROM poi_sets '
                "WHERE source = '$kPoiSourceBox'",
              ).get();
              for (final b in boxes) {
                final r = boxCoveringRadiusMeters(
                  south: b.read<double>('south'),
                  west: b.read<double>('west'),
                  north: b.read<double>('north'),
                  east: b.read<double>('east'),
                );
                await customStatement(
                  'UPDATE poi_sets SET radius_meters = $r '
                  "WHERE id = '${b.read<String>('id')}'",
                );
              }
              // A station's `osm_id` of 0 was the "no identity" placeholder;
              // as a POI that is a NULL id (the `osmKey` rule).
              await customStatement(
                'INSERT INTO poi_points '
                '(id, poi_set_id, lat, lng, name, sort_order, created_at, '
                'osm_type, osm_id, mode_mask) '
                'SELECT x.id, x.set_id, x.lat, x.lng, x.name, '
                'ROW_NUMBER() OVER (PARTITION BY x.set_id '
                'ORDER BY x.created_at, x.rowid) - 1, '
                "x.created_at, 'node', "
                'CASE WHEN x.osm_id = 0 THEN NULL ELSE x.osm_id END, '
                'x.mode_mask FROM transit_stops x',
              );
              await customStatement(
                "UPDATE layers SET type = 'poi' WHERE type = 'transit'",
              );
              await customStatement('DROP TABLE transit_stops');
              await customStatement('DROP TABLE transit_sets');
            }

            await customStatement('DROP TABLE IF EXISTS track_points');
            await customStatement('DROP TABLE IF EXISTS tracks');
            await customStatement("DELETE FROM layers WHERE type = 'track'");
            if (from >= 24) {
              await m.dropColumn(layers, 'track_stroke_width');
              await m.dropColumn(layers, 'track_min_distance_meters');
            }
          }
        },
        beforeOpen: (details) async {
          // Required for the element -> Layers ON DELETE CASCADE to fire.
          await customStatement('PRAGMA foreign_keys = ON');
          // ...and, because they fire *inside* SQLite where no Dart code sees
          // what a cascade removed, the undo journal has to be installed here
          // too: it is the only thing that records it.
          await undo.install();
        },
      );
}
