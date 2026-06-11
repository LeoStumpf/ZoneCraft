import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

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

  /// Packed bitmask of enabled map-POI categories (see `poiCategories` in
  /// `overpass.dart`). 0 = none shown.
  IntColumn get poiCategories => integer().withDefault(const Constant(0))();

  /// Packed bitmask of enabled administrative-border levels (see `borderLevels`
  /// in `borders.dart`). 0 = none shown.
  IntColumn get borderLevels => integer().withDefault(const Constant(0))();

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'zonecraft'));

  /// Constructor for tests, taking an in-memory executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

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
        },
        beforeOpen: (details) async {
          // Required for the Circles/Planes -> Layers ON DELETE CASCADE to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
