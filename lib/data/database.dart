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

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Layers, Circles, Planes, AppSettings, Subspaces, SubspacePoints],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'zonecraft'));

  /// Constructor for tests, taking an in-memory executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

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
        },
        beforeOpen: (details) async {
          // Required for the Circles/Planes -> Layers ON DELETE CASCADE to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
