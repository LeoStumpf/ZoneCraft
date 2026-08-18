import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:uuid/uuid.dart';

import '../geo/border_areas.dart';
import '../geo/simplify.dart';
import 'database.dart';
import 'overpass.dart' show PoiResult;
import 'serialization.dart';

/// What an import actually wrote, against what the layer already held.
///
/// [skipped] exists so the result can be *reported*. Silently importing 12 of
/// 49 areas looks like a broken import; "12 imported, 37 already here" looks
/// like the feature it is.
class ImportTally {
  const ImportTally({required this.added, required this.skipped});

  static const ImportTally none = ImportTally(added: 0, skipped: 0);

  final int added;
  final int skipped;

  int get total => added + skipped;

  /// Everything on offer was already stored — worth saying out loud, because
  /// the map does not visibly change.
  bool get allSkipped => added == 0 && skipped > 0;
}

/// `type/id` — the only safe identity for an OSM element, because ids are
/// unique only *within* a type: node 240109189 and way 240109189 are different
/// things. Null when either half is missing.
String? osmKey(String? type, int? id) =>
    (type == null || id == null) ? null : '$type/$id';

/// Whether an element is new here, recording it in [seen] as a side effect —
/// so duplicates *within one response* are caught as well as duplicates against
/// what is already stored.
///
/// A null key means the element carries no OSM identity (rows written before
/// v21, or an answer that omitted it). Those are always kept: the alternative
/// is inferring identity from coordinates, which would silently merge two
/// genuinely different POIs sharing a doorway.
bool _isNew(Set<String> seen, String? key) => key == null || seen.add(key);

/// Thin CRUD/stream API over [AppDatabase] used by the Riverpod providers.
class Repository {
  Repository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  // --- Layers ---------------------------------------------------------------

  /// All layers ordered by draw order (ascending; last item is drawn on top).
  Stream<List<Layer>> watchLayers() {
    return (_db.select(_db.layers)
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)]))
        .watch();
  }

  /// Creates a layer placed on top of all existing ones. Returns its id.
  /// [type] is the object kind the layer holds ('circles' or 'planes').
  ///
  /// [borderLevel] is the OSM `admin_level` a `borders` layer holds — the one
  /// creation-time sub-choice any type has, because one layer holds one level
  /// (see [Layers.borderLevel]).
  Future<String> createLayer({
    required String name,
    required int colorArgb,
    String type = 'circles',
    String? borderLevel,
  }) async {
    final maxOrder = await _maxSortOrder();
    final id = _uuid.v4();
    await _db.into(_db.layers).insert(
          LayersCompanion.insert(
            id: id,
            name: name,
            colorArgb: colorArgb,
            sortOrder: maxOrder + 1,
            type: Value(type),
            // Region layers default to a translucent fill (map shows through);
            // marker/line layers are crisp, so fully opaque.
            opacity: Value(defaultLayerOpacity(type)),
            borderLevel: Value(borderLevel),
          ),
        );
    return id;
  }

  Future<void> updateLayer(
    String id, {
    String? name,
    int? colorArgb,
    bool? isVisible,
    bool? isInverted,
    double? opacity,
  }) {
    return (_db.update(_db.layers)..where((l) => l.id.equals(id))).write(
      LayersCompanion(
        name: name == null ? const Value.absent() : Value(name),
        colorArgb: colorArgb == null ? const Value.absent() : Value(colorArgb),
        isVisible:
            isVisible == null ? const Value.absent() : Value(isVisible),
        isInverted:
            isInverted == null ? const Value.absent() : Value(isInverted),
        opacity: opacity == null ? const Value.absent() : Value(opacity),
      ),
    );
  }

  Future<void> deleteLayer(String id) {
    return (_db.delete(_db.layers)..where((l) => l.id.equals(id))).go();
  }

  /// Irreversibly merges [sourceId] into [targetId] (must be the same type):
  /// re-points every object of the source to the target layer, then deletes the
  /// emptied source. Lossless — no geometry re-simplification, height polygons
  /// preserved — because only the objects' `layerId` FK is reassigned (child
  /// point/polygon rows key off their parent object, so they follow). Throws
  /// [ArgumentError] on a missing layer or a type mismatch.
  Future<void> combineLayers({
    required String sourceId,
    required String targetId,
  }) async {
    if (sourceId == targetId) return;
    final src = await (_db.select(_db.layers)
          ..where((l) => l.id.equals(sourceId)))
        .getSingleOrNull();
    final tgt = await (_db.select(_db.layers)
          ..where((l) => l.id.equals(targetId)))
        .getSingleOrNull();
    if (src == null || tgt == null) throw ArgumentError('Layer no longer exists');
    if (src.type != tgt.type) {
      throw ArgumentError('Layers must be the same type');
    }
    // One borders layer holds one admin level: the "no two neighbours share a
    // colour" rule is only meaningful within a level, since areas of different
    // levels nest rather than tile.
    if (src.type == 'borders' && src.borderLevel != tgt.borderLevel) {
      throw ArgumentError('Border layers must hold the same level');
    }
    await _db.transaction(() async {
      // Only the table for this layer's type holds rows to re-point.
      switch (src.type) {
        case 'planes':
          await (_db.update(_db.planes)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(PlanesCompanion(layerId: Value(targetId)));
        case 'subspace':
          await (_db.update(_db.subspaces)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(SubspacesCompanion(layerId: Value(targetId)));
        case 'freeline':
          await (_db.update(_db.freeLines)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(FreeLinesCompanion(layerId: Value(targetId)));
        case 'freearea':
          await (_db.update(_db.freeAreas)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(FreeAreasCompanion(layerId: Value(targetId)));
        case 'height':
          await (_db.update(_db.heightRegions)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(HeightRegionsCompanion(layerId: Value(targetId)));
        case 'poi':
          await (_db.update(_db.poiSets)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(PoiSetsCompanion(layerId: Value(targetId)));
        case 'transit':
          await (_db.update(_db.transitSets)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(TransitSetsCompanion(layerId: Value(targetId)));
        case 'borders':
          await (_db.update(_db.borderSets)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(BorderSetsCompanion(layerId: Value(targetId)));
        case 'circles':
        default:
          // WARNING: a new layer type that forgets its `case` above lands here,
          // re-points nothing, and then loses all its rows to the cascade when
          // the source layer is deleted below. Add the case when adding a type.
          await (_db.update(_db.circles)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(CirclesCompanion(layerId: Value(targetId)));
      }
      // The source now holds no objects, so deleting it won't cascade the
      // re-pointed rows away.
      await (_db.delete(_db.layers)..where((l) => l.id.equals(sourceId))).go();
    });
    // The target now holds areas from two imports that were coloured
    // independently, so its seam has to be resolved.
    if (src.type == 'borders') await recolourBorderLayer(targetId);
  }

  /// Persists a new ordering. [orderedIds] is bottom-to-top draw order.
  Future<void> reorderLayers(List<String> orderedIds) async {
    await _db.batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          _db.layers,
          LayersCompanion(sortOrder: Value(i)),
          where: (l) => l.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<int> _maxSortOrder() async {
    final max = _db.layers.sortOrder.max();
    final row = await (_db.selectOnly(_db.layers)..addColumns([max]))
        .getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Circles --------------------------------------------------------------

  Stream<List<Circle>> watchAllCircles() {
    return _db.select(_db.circles).watch();
  }

  // --- Per-element colour (v22) ---------------------------------------------

  /// Sets — or with null clears — one element's colour override. Clearing puts
  /// the element back on its auto shade of the layer colour, so it follows
  /// later layer recolours again.
  Future<void> setElementColor(ColoredElement kind, String id, int? argb) {
    final v = Value<int?>(argb);
    return switch (kind) {
      ColoredElement.circle =>
        (_db.update(_db.circles)..where((t) => t.id.equals(id)))
            .write(CirclesCompanion(colorArgb: v)),
      ColoredElement.plane =>
        (_db.update(_db.planes)..where((t) => t.id.equals(id)))
            .write(PlanesCompanion(colorArgb: v)),
      ColoredElement.subspace =>
        (_db.update(_db.subspaces)..where((t) => t.id.equals(id)))
            .write(SubspacesCompanion(colorArgb: v)),
      ColoredElement.freeLine =>
        (_db.update(_db.freeLines)..where((t) => t.id.equals(id)))
            .write(FreeLinesCompanion(colorArgb: v)),
      ColoredElement.freeArea =>
        (_db.update(_db.freeAreas)..where((t) => t.id.equals(id)))
            .write(FreeAreasCompanion(colorArgb: v)),
      ColoredElement.heightRegion =>
        (_db.update(_db.heightRegions)..where((t) => t.id.equals(id)))
            .write(HeightRegionsCompanion(colorArgb: v)),
      ColoredElement.poiSet =>
        (_db.update(_db.poiSets)..where((t) => t.id.equals(id)))
            .write(PoiSetsCompanion(colorArgb: v)),
      ColoredElement.transitSet =>
        (_db.update(_db.transitSets)..where((t) => t.id.equals(id)))
            .write(TransitSetsCompanion(colorArgb: v)),
      ColoredElement.borderArea =>
        (_db.update(_db.borderAreas)..where((t) => t.id.equals(id)))
            .write(BorderAreasCompanion(colorArgb: v)),
    };
  }

  /// The ids of [layerId]'s elements that carry an explicit colour — what the
  /// layer-recolour dialog needs to know, since those are exactly the elements
  /// a recolour would *not* reach on its own.
  Future<List<String>> elementsWithColorOverride(
    String layerId,
    String layerType,
  ) async {
    final kind = ColoredElement.forLayerType(layerType);
    if (kind == null) return const [];
    // Border areas hang off their import set, not off the layer directly.
    final sql = kind == ColoredElement.borderArea
        ? 'SELECT a.id AS id FROM border_areas a '
              'JOIN border_sets s ON a.set_id = s.id '
              'WHERE s.layer_id = ? AND a.color_argb IS NOT NULL'
        : 'SELECT id FROM ${kind.table} '
              'WHERE layer_id = ? AND color_argb IS NOT NULL';
    final rows = await _db.customSelect(
      sql,
      variables: [Variable<String>(layerId)],
    ).get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Clears the colour override on [ids], putting them back on auto shades.
  Future<void> clearElementColors(ColoredElement kind, List<String> ids) async {
    for (final id in ids) {
      await setElementColor(kind, id, null);
    }
  }

  /// The auto-shade slot a new element of [table] takes in [layerId]: one past
  /// the highest already used, so elements are shaded in creation order and
  /// deleting one never re-shades the others — a single delete repainting the
  /// whole layer in different colours would be alarming.
  ///
  /// Shade 0 is the layer colour itself, so the first element of a layer looks
  /// exactly as it did before per-element colours existed.
  Future<int> _nextColorShade(String table, String layerId) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(MAX(color_shade), -1) + 1 AS next '
      'FROM $table WHERE layer_id = ?',
      variables: [Variable<String>(layerId)],
    ).getSingle();
    return row.read<int>('next');
  }

  Future<String> createCircle({
    required String layerId,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    String? label,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('circles', layerId);
    await _db.into(_db.circles).insert(
          CirclesCompanion.insert(
            id: id,
            layerId: layerId,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            label: Value(label),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  Future<void> updateCircle(
    String id, {
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) {
    return (_db.update(_db.circles)..where((c) => c.id.equals(id))).write(
      CirclesCompanion(
        centerLat:
            centerLat == null ? const Value.absent() : Value(centerLat),
        centerLng:
            centerLng == null ? const Value.absent() : Value(centerLng),
        radiusMeters:
            radiusMeters == null ? const Value.absent() : Value(radiusMeters),
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        label: label,
      ),
    );
  }

  Future<void> deleteCircle(String id) {
    return (_db.delete(_db.circles)..where((c) => c.id.equals(id))).go();
  }

  // --- Planes ---------------------------------------------------------------

  Stream<List<Plane>> watchAllPlanes() {
    return _db.select(_db.planes).watch();
  }

  Future<String> createPlane({
    required String layerId,
    required double aLat,
    required double aLng,
    required double bLat,
    required double bLng,
    bool nearA = true,
    String? label,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('planes', layerId);
    await _db.into(_db.planes).insert(
          PlanesCompanion.insert(
            id: id,
            layerId: layerId,
            aLat: aLat,
            aLng: aLng,
            bLat: bLat,
            bLng: bLng,
            nearA: Value(nearA),
            label: Value(label),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  Future<void> updatePlane(
    String id, {
    double? aLat,
    double? aLng,
    double? bLat,
    double? bLng,
    bool? nearA,
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) {
    return (_db.update(_db.planes)..where((p) => p.id.equals(id))).write(
      PlanesCompanion(
        aLat: aLat == null ? const Value.absent() : Value(aLat),
        aLng: aLng == null ? const Value.absent() : Value(aLng),
        bLat: bLat == null ? const Value.absent() : Value(bLat),
        bLng: bLng == null ? const Value.absent() : Value(bLng),
        nearA: nearA == null ? const Value.absent() : Value(nearA),
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        label: label,
      ),
    );
  }

  Future<void> deletePlane(String id) {
    return (_db.delete(_db.planes)..where((p) => p.id.equals(id))).go();
  }

  // --- Subspaces ------------------------------------------------------------

  Stream<List<Subspace>> watchAllSubspaces() {
    return _db.select(_db.subspaces).watch();
  }

  /// All points across every subspace, ordered by their [SubspacePoints.sortOrder].
  Stream<List<SubspacePoint>> watchAllSubspacePoints() {
    return (_db.select(_db.subspacePoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  Future<String> createSubspace({required String layerId, String? label}) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('subspaces', layerId);
    await _db.into(_db.subspaces).insert(
          SubspacesCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  Future<void> updateSubspace(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) {
    return (_db.update(_db.subspaces)..where((s) => s.id.equals(id))).write(
      SubspacesCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        label: label,
      ),
    );
  }

  Future<void> deleteSubspace(String id) {
    return (_db.delete(_db.subspaces)..where((s) => s.id.equals(id))).go();
  }

  /// Appends a point to [subspaceId] (placed last). The first point of a fresh
  /// subspace should pass [isMain] true so the object always has a main point.
  Future<String> addSubspacePoint({
    required String subspaceId,
    required double lat,
    required double lng,
    bool isMain = false,
    String? label,
  }) async {
    final order = await _maxPointOrder(subspaceId);
    final id = _uuid.v4();
    await _db.into(_db.subspacePoints).insert(
          SubspacePointsCompanion.insert(
            id: id,
            subspaceId: subspaceId,
            lat: lat,
            lng: lng,
            sortOrder: order + 1,
            isMain: Value(isMain),
            label: Value(label),
          ),
        );
    return id;
  }

  Future<void> updateSubspacePoint(
    String id, {
    double? lat,
    double? lng,
    Value<String?> label = const Value.absent(),
  }) {
    return (_db.update(_db.subspacePoints)..where((p) => p.id.equals(id))).write(
      SubspacePointsCompanion(
        lat: lat == null ? const Value.absent() : Value(lat),
        lng: lng == null ? const Value.absent() : Value(lng),
        label: label,
      ),
    );
  }

  /// Makes [pointId] the single main point of [subspaceId] (clears the flag on
  /// every other point in one batch, so exactly one stays main).
  Future<void> setMainPoint(String subspaceId, String pointId) {
    return _db.batch((b) {
      b.update(
        _db.subspacePoints,
        const SubspacePointsCompanion(isMain: Value(false)),
        where: (p) => p.subspaceId.equals(subspaceId),
      );
      b.update(
        _db.subspacePoints,
        const SubspacePointsCompanion(isMain: Value(true)),
        where: (p) => p.id.equals(pointId),
      );
    });
  }

  Future<void> deleteSubspacePoint(String id) {
    return (_db.delete(_db.subspacePoints)..where((p) => p.id.equals(id))).go();
  }

  Future<int> _maxPointOrder(String subspaceId) async {
    final max = _db.subspacePoints.sortOrder.max();
    final row = await (_db.selectOnly(_db.subspacePoints)
          ..addColumns([max])
          ..where(_db.subspacePoints.subspaceId.equals(subspaceId)))
        .getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Freehand lines -------------------------------------------------------

  Stream<List<FreeLine>> watchAllFreeLines() {
    return _db.select(_db.freeLines).watch();
  }

  /// All points across every freehand line, ordered by [FreeLinePoints.sortOrder].
  Stream<List<FreeLinePoint>> watchAllFreeLinePoints() {
    return (_db.select(_db.freeLinePoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  Future<String> createFreeLine({
    required String layerId,
    String? label,
    double? inclusionLat,
    double? inclusionLng,
    double? inclusionRadiusMeters,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('free_lines', layerId);
    await _db.into(_db.freeLines).insert(
          FreeLinesCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
            inclusionLat: Value(inclusionLat),
            inclusionLng: Value(inclusionLng),
            inclusionRadiusMeters: Value(inclusionRadiusMeters),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  Future<void> updateFreeLine(
    String id, {
    String? layerId,
    double? offsetMeters,
    double? inclusionLat,
    double? inclusionLng,
    double? inclusionRadiusMeters,
    Value<String?> label = const Value.absent(),
  }) {
    return (_db.update(_db.freeLines)..where((l) => l.id.equals(id))).write(
      FreeLinesCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        offsetMeters:
            offsetMeters == null ? const Value.absent() : Value(offsetMeters),
        inclusionLat:
            inclusionLat == null ? const Value.absent() : Value(inclusionLat),
        inclusionLng:
            inclusionLng == null ? const Value.absent() : Value(inclusionLng),
        inclusionRadiusMeters: inclusionRadiusMeters == null
            ? const Value.absent()
            : Value(inclusionRadiusMeters),
        label: label,
      ),
    );
  }

  Future<void> deleteFreeLine(String id) {
    return (_db.delete(_db.freeLines)..where((l) => l.id.equals(id))).go();
  }

  Future<String> addFreeLinePoint({
    required String freeLineId,
    required double lat,
    required double lng,
  }) async {
    final order = await _maxFreeLinePointOrder(freeLineId);
    final id = _uuid.v4();
    await _db.into(_db.freeLinePoints).insert(
          FreeLinePointsCompanion.insert(
            id: id,
            freeLineId: freeLineId,
            lat: lat,
            lng: lng,
            sortOrder: order + 1,
          ),
        );
    return id;
  }

  /// Inserts a point into [freeLineId] at ordered position [sortOrder]
  /// (shifting every point at or after that order down by one), so a vertex can
  /// be dropped *between* two existing ones — e.g. a long-press on a segment.
  Future<String> insertFreeLinePointAt({
    required String freeLineId,
    required int sortOrder,
    required double lat,
    required double lng,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE free_line_points SET sort_order = sort_order + 1 '
        'WHERE free_line_id = ? AND sort_order >= ?',
        [freeLineId, sortOrder],
      );
      await _db.into(_db.freeLinePoints).insert(
            FreeLinePointsCompanion.insert(
              id: id,
              freeLineId: freeLineId,
              lat: lat,
              lng: lng,
              sortOrder: sortOrder,
            ),
          );
    });
    return id;
  }

  /// Appends many points to [freeLineId] in one batch (used by track import,
  /// where a city border can carry thousands of vertices).
  Future<void> addFreeLinePoints(String freeLineId, List<LatLng> pts) async {
    if (pts.isEmpty) return;
    var order = await _maxFreeLinePointOrder(freeLineId);
    await _db.batch((b) {
      for (final p in pts) {
        order++;
        b.insert(
          _db.freeLinePoints,
          FreeLinePointsCompanion.insert(
            id: _uuid.v4(),
            freeLineId: freeLineId,
            lat: p.latitude,
            lng: p.longitude,
            sortOrder: order,
          ),
        );
      }
    });
  }

  Future<void> updateFreeLinePoint(String id, {double? lat, double? lng}) {
    return (_db.update(_db.freeLinePoints)..where((p) => p.id.equals(id))).write(
      FreeLinePointsCompanion(
        lat: lat == null ? const Value.absent() : Value(lat),
        lng: lng == null ? const Value.absent() : Value(lng),
      ),
    );
  }

  Future<void> deleteFreeLinePoint(String id) {
    return (_db.delete(_db.freeLinePoints)..where((p) => p.id.equals(id))).go();
  }

  /// Swaps the ordering of two line points (used to reorder a vertex up/down).
  Future<void> swapFreeLinePointOrder(String idA, String idB) async {
    await _db.transaction(() async {
      final a = await (_db.select(_db.freeLinePoints)
            ..where((p) => p.id.equals(idA)))
          .getSingle();
      final b = await (_db.select(_db.freeLinePoints)
            ..where((p) => p.id.equals(idB)))
          .getSingle();
      await (_db.update(_db.freeLinePoints)..where((p) => p.id.equals(idA)))
          .write(FreeLinePointsCompanion(sortOrder: Value(b.sortOrder)));
      await (_db.update(_db.freeLinePoints)..where((p) => p.id.equals(idB)))
          .write(FreeLinePointsCompanion(sortOrder: Value(a.sortOrder)));
    });
  }

  Future<int> _maxFreeLinePointOrder(String freeLineId) async {
    final max = _db.freeLinePoints.sortOrder.max();
    final row = await (_db.selectOnly(_db.freeLinePoints)
          ..addColumns([max])
          ..where(_db.freeLinePoints.freeLineId.equals(freeLineId)))
        .getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Freehand areas -------------------------------------------------------

  Stream<List<FreeArea>> watchAllFreeAreas() {
    return _db.select(_db.freeAreas).watch();
  }

  /// All points across every freehand area, ordered by [FreeAreaPoints.sortOrder].
  Stream<List<FreeAreaPoint>> watchAllFreeAreaPoints() {
    return (_db.select(_db.freeAreaPoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  Future<String> createFreeArea({required String layerId, String? label}) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('free_areas', layerId);
    await _db.into(_db.freeAreas).insert(
          FreeAreasCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  Future<void> updateFreeArea(
    String id, {
    String? layerId,
    double? offsetMeters,
    Value<String?> label = const Value.absent(),
  }) {
    return (_db.update(_db.freeAreas)..where((a) => a.id.equals(id))).write(
      FreeAreasCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        offsetMeters:
            offsetMeters == null ? const Value.absent() : Value(offsetMeters),
        label: label,
      ),
    );
  }

  Future<void> deleteFreeArea(String id) {
    return (_db.delete(_db.freeAreas)..where((a) => a.id.equals(id))).go();
  }

  Future<String> addFreeAreaPoint({
    required String freeAreaId,
    required double lat,
    required double lng,
  }) async {
    final order = await _maxFreeAreaPointOrder(freeAreaId);
    final id = _uuid.v4();
    await _db.into(_db.freeAreaPoints).insert(
          FreeAreaPointsCompanion.insert(
            id: id,
            freeAreaId: freeAreaId,
            lat: lat,
            lng: lng,
            sortOrder: order + 1,
          ),
        );
    return id;
  }

  /// Inserts a point into [freeAreaId] at ordered position [sortOrder]
  /// (shifting every point at or after that order down by one), so a vertex can
  /// be dropped *between* two existing ones — e.g. a long-press on an edge.
  Future<String> insertFreeAreaPointAt({
    required String freeAreaId,
    required int sortOrder,
    required double lat,
    required double lng,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE free_area_points SET sort_order = sort_order + 1 '
        'WHERE free_area_id = ? AND sort_order >= ?',
        [freeAreaId, sortOrder],
      );
      await _db.into(_db.freeAreaPoints).insert(
            FreeAreaPointsCompanion.insert(
              id: id,
              freeAreaId: freeAreaId,
              lat: lat,
              lng: lng,
              sortOrder: sortOrder,
            ),
          );
    });
    return id;
  }

  /// Appends many points to [freeAreaId] in one batch (used by area import).
  Future<void> addFreeAreaPoints(String freeAreaId, List<LatLng> pts) async {
    if (pts.isEmpty) return;
    var order = await _maxFreeAreaPointOrder(freeAreaId);
    await _db.batch((b) {
      for (final p in pts) {
        order++;
        b.insert(
          _db.freeAreaPoints,
          FreeAreaPointsCompanion.insert(
            id: _uuid.v4(),
            freeAreaId: freeAreaId,
            lat: p.latitude,
            lng: p.longitude,
            sortOrder: order,
          ),
        );
      }
    });
  }

  Future<void> updateFreeAreaPoint(String id, {double? lat, double? lng}) {
    return (_db.update(_db.freeAreaPoints)..where((p) => p.id.equals(id))).write(
      FreeAreaPointsCompanion(
        lat: lat == null ? const Value.absent() : Value(lat),
        lng: lng == null ? const Value.absent() : Value(lng),
      ),
    );
  }

  Future<void> deleteFreeAreaPoint(String id) {
    return (_db.delete(_db.freeAreaPoints)..where((p) => p.id.equals(id))).go();
  }

  /// Swaps the ordering of two area ring points (used to reorder a vertex).
  Future<void> swapFreeAreaPointOrder(String idA, String idB) async {
    await _db.transaction(() async {
      final a = await (_db.select(_db.freeAreaPoints)
            ..where((p) => p.id.equals(idA)))
          .getSingle();
      final b = await (_db.select(_db.freeAreaPoints)
            ..where((p) => p.id.equals(idB)))
          .getSingle();
      await (_db.update(_db.freeAreaPoints)..where((p) => p.id.equals(idA)))
          .write(FreeAreaPointsCompanion(sortOrder: Value(b.sortOrder)));
      await (_db.update(_db.freeAreaPoints)..where((p) => p.id.equals(idB)))
          .write(FreeAreaPointsCompanion(sortOrder: Value(a.sortOrder)));
    });
  }

  Future<int> _maxFreeAreaPointOrder(String freeAreaId) async {
    final max = _db.freeAreaPoints.sortOrder.max();
    final row = await (_db.selectOnly(_db.freeAreaPoints)
          ..addColumns([max])
          ..where(_db.freeAreaPoints.freeAreaId.equals(freeAreaId)))
        .getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Height regions -------------------------------------------------------

  Stream<List<HeightRegion>> watchAllHeightRegions() {
    return _db.select(_db.heightRegions).watch();
  }

  /// All generated height polygons across every region, ordered.
  Stream<List<HeightPolygon>> watchAllHeightPolygons() {
    return (_db.select(_db.heightPolygons)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  /// All height-polygon ring points across every polygon, ordered.
  Stream<List<HeightPolygonPoint>> watchAllHeightPolygonPoints() {
    return (_db.select(_db.heightPolygonPoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  Future<String> createHeightRegion({
    required String layerId,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    double thresholdMeters = 0,
    bool aboveThreshold = true,
    int sampleZoom = 13,
    String? label,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('height_regions', layerId);
    await _db.into(_db.heightRegions).insert(
          HeightRegionsCompanion.insert(
            id: id,
            layerId: layerId,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            thresholdMeters: Value(thresholdMeters),
            aboveThreshold: Value(aboveThreshold),
            sampleZoom: Value(sampleZoom),
            label: Value(label),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  /// Updates a height region. Editing a parameter that changes the geometry
  /// (centre/radius/threshold/above/zoom) clears [generatedAt] so the editor
  /// shows the result is stale until regenerated.
  Future<void> updateHeightRegion(
    String id, {
    String? layerId,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    double? thresholdMeters,
    bool? aboveThreshold,
    int? sampleZoom,
    Value<String?> label = const Value.absent(),
  }) {
    final geometryChanged = centerLat != null ||
        centerLng != null ||
        radiusMeters != null ||
        thresholdMeters != null ||
        aboveThreshold != null ||
        sampleZoom != null;
    return (_db.update(_db.heightRegions)..where((r) => r.id.equals(id))).write(
      HeightRegionsCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        centerLat: centerLat == null ? const Value.absent() : Value(centerLat),
        centerLng: centerLng == null ? const Value.absent() : Value(centerLng),
        radiusMeters:
            radiusMeters == null ? const Value.absent() : Value(radiusMeters),
        thresholdMeters: thresholdMeters == null
            ? const Value.absent()
            : Value(thresholdMeters),
        aboveThreshold: aboveThreshold == null
            ? const Value.absent()
            : Value(aboveThreshold),
        sampleZoom: sampleZoom == null ? const Value.absent() : Value(sampleZoom),
        label: label,
        generatedAt: geometryChanged ? const Value(null) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteHeightRegion(String id) {
    return (_db.delete(_db.heightRegions)..where((r) => r.id.equals(id))).go();
  }

  /// Replaces all generated polygons for [regionId] with [rings] (delete + batch
  /// insert). Each ring is an ordered list of vertices.
  Future<void> replaceHeightPolygons(
      String regionId, List<List<LatLng>> rings) async {
    await (_db.delete(_db.heightPolygons)
          ..where((p) => p.heightRegionId.equals(regionId)))
        .go();
    if (rings.isEmpty) return;
    await _db.batch((b) {
      for (var ri = 0; ri < rings.length; ri++) {
        final polyId = _uuid.v4();
        b.insert(
          _db.heightPolygons,
          HeightPolygonsCompanion.insert(
            id: polyId,
            heightRegionId: regionId,
            sortOrder: ri,
          ),
        );
        final ring = rings[ri];
        for (var i = 0; i < ring.length; i++) {
          b.insert(
            _db.heightPolygonPoints,
            HeightPolygonPointsCompanion.insert(
              id: _uuid.v4(),
              polygonId: polyId,
              lat: ring[i].latitude,
              lng: ring[i].longitude,
              sortOrder: i,
            ),
          );
        }
      }
    });
  }

  /// Stamps [regionId] as freshly generated (now).
  Future<void> markHeightGenerated(String regionId) {
    return (_db.update(_db.heightRegions)..where((r) => r.id.equals(regionId)))
        .write(HeightRegionsCompanion(generatedAt: Value(DateTime.now())));
  }

  // --- POI sets -------------------------------------------------------------

  Stream<List<PoiSet>> watchAllPoiSets() {
    return _db.select(_db.poiSets).watch();
  }

  /// All stored POIs across every set, ordered by [PoiPoints.sortOrder].
  Stream<List<PoiPoint>> watchAllPoiPoints() {
    return (_db.select(_db.poiPoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  /// Creates a POI set (one import: a category within a bounded circle) on a
  /// `poi` layer. Returns its id; the POIs themselves go in via [addPoiPoints].
  Future<String> createPoiSet({
    required String layerId,
    required String categoryKey,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    String? label,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('poi_sets', layerId);
    await _db.into(_db.poiSets).insert(
          PoiSetsCompanion.insert(
            id: id,
            layerId: layerId,
            categoryKey: categoryKey,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            label: Value(label),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  /// Appends the fetched POIs to [poiSetId] in one batch, **skipping any this
  /// layer already holds** (see [ImportTally]).
  ///
  /// Scoped to the layer, not the set: overlapping imports land in *different*
  /// sets, which is exactly the case that used to draw the same café twice.
  /// Two layers deliberately holding the same POIs is a legitimate thing to
  /// want, so it stays possible.
  /// Takes [PoiResult]s rather than a bare record: it is exactly what the
  /// importer already holds, and it keeps the OSM identity from having to be
  /// spelled out (as two explicit nulls) at every seed and test call site.
  Future<ImportTally> addPoiPoints(
    String poiSetId,
    List<PoiResult> pts,
  ) async {
    if (pts.isEmpty) return ImportTally.none;
    return _db.transaction(() async {
      final seen = await _poiOsmKeysInLayerOf(poiSetId);
      final keep = [
        for (final p in pts)
          if (_isNew(seen, osmKey(p.osmType, p.osmId))) p,
      ];
      // Sort order restarts per set, so it indexes `keep`, not `pts` — a gap
      // would put the markers in a different order than the list.
      await _db.batch((b) {
        for (var i = 0; i < keep.length; i++) {
          b.insert(
            _db.poiPoints,
            PoiPointsCompanion.insert(
              id: _uuid.v4(),
              poiSetId: poiSetId,
              lat: keep[i].lat,
              lng: keep[i].lng,
              name: Value(keep[i].name),
              sortOrder: i,
              osmType: Value(keep[i].osmType),
              osmId: Value(keep[i].osmId),
            ),
          );
        }
      });
      return ImportTally(added: keep.length, skipped: pts.length - keep.length);
    });
  }

  /// Every `type/id` already stored on the layer that owns [poiSetId].
  Future<Set<String>> _poiOsmKeysInLayerOf(String poiSetId) async {
    final layerId = await (_db.selectOnly(_db.poiSets)
          ..addColumns([_db.poiSets.layerId])
          ..where(_db.poiSets.id.equals(poiSetId)))
        .map((r) => r.read(_db.poiSets.layerId))
        .getSingleOrNull();
    if (layerId == null) return <String>{};
    final rows = await (_db.selectOnly(_db.poiPoints)
          ..addColumns([_db.poiPoints.osmType, _db.poiPoints.osmId])
          ..join([
            innerJoin(
              _db.poiSets,
              _db.poiSets.id.equalsExp(_db.poiPoints.poiSetId),
            ),
          ])
          ..where(_db.poiSets.layerId.equals(layerId) &
              _db.poiPoints.osmId.isNotNull()))
        .get();
    return {
      for (final r in rows)
        ?osmKey(r.read(_db.poiPoints.osmType), r.read(_db.poiPoints.osmId)),
    };
  }

  /// Renames a POI set (or moves it to another `poi` layer). The set's search
  /// circle and its stored POIs are immutable — a different area means a new
  /// import.
  Future<void> updatePoiSet(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) async {
    await (_db.update(_db.poiSets)..where((s) => s.id.equals(id))).write(
      PoiSetsCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        label: label,
      ),
    );
  }

  Future<void> deletePoiSet(String id) {
    return (_db.delete(_db.poiSets)..where((s) => s.id.equals(id))).go();
  }

  // --- Transit sets ---------------------------------------------------------

  Stream<List<TransitSet>> watchAllTransitSets() {
    return _db.select(_db.transitSets).watch();
  }

  Stream<List<TransitStop>> watchAllTransitStops() {
    return _db.select(_db.transitStops).watch();
  }

  /// Records an import **before** fetching, so a failure leaves something the
  /// user can come back to rather than a snackbar they missed. `fetchedAt` stays
  /// null until [fillTransitSet] succeeds.
  Future<String> createPendingTransitSet({
    required String layerId,
    required double south,
    required double west,
    required double north,
    required double east,
    required int modeMask,
    required int visibleModeMask,
    String? label,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('transit_sets', layerId);
    await _db.into(_db.transitSets).insert(
          TransitSetsCompanion.insert(
            id: id,
            layerId: layerId,
            south: south,
            west: west,
            north: north,
            east: east,
            modeMask: modeMask,
            visibleModeMask: Value(visibleModeMask),
            label: Value(label),
            colorShade: Value(shade),
          ),
        );
    return id;
  }

  /// Writes the fetched stations into [setId] and marks it done.
  ///
  /// Replaces whatever was there, so a retry after a partial failure is
  /// idempotent. One transaction, one batch — a city import is thousands of
  /// rows and must not be a loop of awaited inserts.
  Future<ImportTally> fillTransitSet(
    String setId,
    List<({
      int osmId,
      double lat,
      double lng,
      String? name,
      int modeMask,
      int nodeCount,
      String? routeRef,
    })> stations,
  ) async {
    return _db.transaction(() async {
      await (_db.delete(_db.transitStops)
            ..where((s) => s.setId.equals(setId)))
          .go();
      // Stations this layer's *other* sets already hold. Two boxes that overlap
      // put the same station in two sets, which is what drew Pasing twice.
      final seen = await _transitOsmIdsInLayerOf(setId);
      final keep = [
        for (final s in stations)
          if (_isNew(seen, osmKey('node', s.osmId))) s,
      ];
      await _db.batch((b) {
        for (final s in keep) {
          b.insert(
            _db.transitStops,
            TransitStopsCompanion.insert(
              id: _uuid.v4(),
              setId: setId,
              osmId: s.osmId,
              lat: s.lat,
              lng: s.lng,
              name: Value(s.name),
              modeMask: Value(s.modeMask),
              nodeCount: Value(s.nodeCount),
              routeRef: Value(s.routeRef),
            ),
          );
        }
      });
      await (_db.update(_db.transitSets)..where((t) => t.id.equals(setId)))
          .write(TransitSetsCompanion(
        fetchedAt: Value(DateTime.now()),
        lastError: const Value(null),
        // The counts describe what is *stored*, so they keep matching the rows
        // and the "N stations" the layer tile shows.
        stationCount: Value(keep.length),
        nodeCount: Value(keep.fold(0, (a, s) => a + s.nodeCount)),
      ));
      return ImportTally(
          added: keep.length, skipped: stations.length - keep.length);
    });
  }

  /// Station ids held by the *other* sets of the layer owning [setId].
  ///
  /// Excludes [setId] itself so a retry of the same box doesn't dedup against
  /// its own previous attempt — which would make every retry import nothing.
  Future<Set<String>> _transitOsmIdsInLayerOf(String setId) async {
    final layerId = await (_db.selectOnly(_db.transitSets)
          ..addColumns([_db.transitSets.layerId])
          ..where(_db.transitSets.id.equals(setId)))
        .map((r) => r.read(_db.transitSets.layerId))
        .getSingleOrNull();
    if (layerId == null) return <String>{};
    final rows = await (_db.selectOnly(_db.transitStops)
          ..addColumns([_db.transitStops.osmId])
          ..join([
            innerJoin(
              _db.transitSets,
              _db.transitSets.id.equalsExp(_db.transitStops.setId),
            ),
          ])
          ..where(_db.transitSets.layerId.equals(layerId) &
              _db.transitSets.id.equals(setId).not()))
        .get();
    return {
      for (final r in rows)
        ?osmKey('node', r.read(_db.transitStops.osmId)),
    };
  }

  /// Records why an import didn't finish. The set stays, so the layer can offer
  /// a retry for exactly that box.
  Future<void> markTransitImportFailed(String setId, String message) {
    return (_db.update(_db.transitSets)..where((t) => t.id.equals(setId)))
        .write(TransitSetsCompanion(lastError: Value(message)));
  }

  /// Renames an import (or moves it to another `transit` layer). The imported
  /// area is immutable — a different area means a new import.
  Future<void> updateTransitSet(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) async {
    await (_db.update(_db.transitSets)..where((s) => s.id.equals(id))).write(
      TransitSetsCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        label: label,
      ),
    );
  }

  /// Which transit modes are shown — what the filter sheet writes. One batch,
  /// so toggling a mode is a single write and a single stream emission.
  Future<void> setTransitVisibleModes(
    Iterable<String> setIds,
    int visibleModeMask,
  ) async {
    final ids = setIds.toList();
    if (ids.isEmpty) return;
    await _db.batch((b) {
      b.update(
        _db.transitSets,
        TransitSetsCompanion(visibleModeMask: Value(visibleModeMask)),
        where: (t) => t.id.isIn(ids),
      );
    });
  }

  Future<void> deleteTransitSet(String id) {
    return (_db.delete(_db.transitSets)..where((s) => s.id.equals(id))).go();
  }

  // --- Border sets ----------------------------------------------------------

  Stream<List<BorderSet>> watchAllBorderSets() {
    return _db.select(_db.borderSets).watch();
  }

  Stream<List<BorderArea>> watchAllBorderAreas() {
    return _db.select(_db.borderAreas).watch();
  }

  /// Writes one finished border import: the set row plus its areas, then
  /// recolours the whole layer.
  ///
  /// Unlike a transit import there is no pending row — a border import that
  /// fails leaves nothing behind, because re-running it is two taps and a
  /// half-written set would have to remember the query to be worth keeping.
  ///
  /// One transaction, one batch: a city import is 54 areas but a country one is
  /// a handful of very large blobs, and either way this must not be a loop of
  /// awaited inserts.
  Future<({String setId, ImportTally tally})> addBorderSet({
    required String layerId,
    required double south,
    required double west,
    required double north,
    required double east,
    required String adminLevel,
    required List<({
      int osmId,
      String? name,
      double south,
      double west,
      double north,
      double east,
      double labelLat,
      double labelLng,
      int pointCount,
      String rings,
      List<int> wayIds,
    })> areas,
    String? label,
  }) async {
    final setId = _uuid.v4();
    late final ImportTally tally;
    await _db.transaction(() async {
      // Areas this layer already holds. Overpass returns whole relations, so an
      // overlapping box re-delivers every municipality it touched last time —
      // the case that drew each suburb twice, at full point cost.
      final seen = await _borderOsmIdsInLayer(layerId);
      final keep = [
        for (final a in areas)
          if (_isNew(seen, osmKey('relation', a.osmId))) a,
      ];
      tally =
          ImportTally(added: keep.length, skipped: areas.length - keep.length);
      // The set is written even when nothing survived: it records the box that
      // was fetched, and an empty one is invisible (Elements lists *areas*).
      await _db.into(_db.borderSets).insert(
            BorderSetsCompanion.insert(
              id: setId,
              layerId: layerId,
              south: south,
              west: west,
              north: north,
              east: east,
              adminLevel: adminLevel,
              fetchedAt: DateTime.now(),
              areaCount: Value(keep.length),
              pointCount: Value(keep.fold(0, (a, x) => a + x.pointCount)),
              label: Value(label),
            ),
          );
      await _db.batch((b) {
        for (final a in keep) {
          b.insert(
            _db.borderAreas,
            BorderAreasCompanion.insert(
              id: _uuid.v4(),
              setId: setId,
              osmId: a.osmId,
              name: Value(a.name),
              south: a.south,
              west: a.west,
              north: a.north,
              east: a.east,
              labelLat: a.labelLat,
              labelLng: a.labelLng,
              pointCount: a.pointCount,
              rings: a.rings,
              wayIds: jsonEncode(a.wayIds),
            ),
          );
        }
      });
    });
    await recolourBorderLayer(layerId);
    return (setId: setId, tally: tally);
  }

  /// Relation ids already stored on [layerId].
  Future<Set<String>> _borderOsmIdsInLayer(String layerId) async {
    final rows = await (_db.selectOnly(_db.borderAreas)
          ..addColumns([_db.borderAreas.osmId])
          ..join([
            innerJoin(
              _db.borderSets,
              _db.borderSets.id.equalsExp(_db.borderAreas.setId),
            ),
          ])
          ..where(_db.borderSets.layerId.equals(layerId)))
        .get();
    return {
      for (final r in rows)
        ?osmKey('relation', r.read(_db.borderAreas.osmId)),
    };
  }

  /// Recomputes every area colour in [layerId] so no two areas sharing a border
  /// match.
  ///
  /// Runs over the **whole layer**, not one import, which is what keeps two
  /// overlapping imports from clashing along their seam — and why it has to run
  /// again after a set is deleted, when a constraint has gone away.
  Future<void> recolourBorderLayer(String layerId) async {
    final setIds = await (_db.selectOnly(_db.borderSets)
          ..addColumns([_db.borderSets.id])
          ..where(_db.borderSets.layerId.equals(layerId)))
        .map((r) => r.read(_db.borderSets.id)!)
        .get();
    if (setIds.isEmpty) return;
    final areas = await (_db.select(_db.borderAreas)
          ..where((a) => a.setId.isIn(setIds)))
        .get();
    if (areas.isEmpty) return;

    final colors = assignAreaColors([
      for (final a in areas)
        AreaAdjacencyInput(osmId: a.osmId, wayIds: _decodeWayIds(a.wayIds)),
    ]);
    await _db.batch((b) {
      for (final a in areas) {
        final c = colors[a.osmId] ?? 0;
        if (c == a.colorIndex) continue;
        b.update(
          _db.borderAreas,
          BorderAreasCompanion(colorIndex: Value(c)),
          where: (t) => t.id.equals(a.id),
        );
      }
    });
  }

  /// The member way ids stored on an area. Never throws — a corrupt row simply
  /// has no neighbours, which costs a colour, not the map.
  static List<int> _decodeWayIds(String json) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];
    return [
      for (final v in decoded)
        if (v is num) v.toInt(),
    ];
  }

  /// Renames one imported area. This overwrites the OSM `name`, which is the
  /// point: the Elements list shows areas, so renaming a row renames the thing
  /// the row is.
  Future<void> updateBorderArea(
    String id, {
    Value<String?> name = const Value.absent(),
  }) async {
    await (_db.update(_db.borderAreas)..where((a) => a.id.equals(id)))
        .write(BorderAreasCompanion(name: name));
  }

  /// Deletes one imported area, then recolours what is left of its layer.
  Future<void> deleteBorderArea(String id) async {
    final area = await (_db.select(_db.borderAreas)
          ..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    if (area == null) return;
    final set = await (_db.select(_db.borderSets)
          ..where((s) => s.id.equals(area.setId)))
        .getSingleOrNull();
    await (_db.delete(_db.borderAreas)..where((a) => a.id.equals(id))).go();
    if (set != null) await recolourBorderLayer(set.layerId);
  }

  /// The decoded rings of one area, or empty when it is gone. Used by the
  /// "convert to freehand area" action, which needs the geometry rather than
  /// the summary row.
  Future<List<List<LatLng>>> borderAreaRings(String id) async {
    final area = await (_db.select(_db.borderAreas)
          ..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    return area == null ? const [] : decodeRings(area.rings);
  }

  /// Renames an import (or moves it to another `borders` layer). The imported
  /// area and level are immutable — a different area means a new import.
  Future<void> updateBorderSet(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) async {
    await (_db.update(_db.borderSets)..where((s) => s.id.equals(id))).write(
      BorderSetsCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        label: label,
      ),
    );
  }

  /// Deletes an import and recolours what is left: removing a set removes
  /// adjacency constraints, and leaving the old colours would keep an
  /// unnecessary clash on screen.
  Future<void> deleteBorderSet(String id) async {
    final set = await (_db.select(_db.borderSets)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    await (_db.delete(_db.borderSets)..where((s) => s.id.equals(id))).go();
    if (set != null) await recolourBorderLayer(set.layerId);
  }

  /// The per-layer borders display toggles (both default off).
  Future<void> updateBorderLayerOptions(
    String layerId, {
    bool? fillAreas,
    bool? showNames,
  }) {
    return (_db.update(_db.layers)..where((l) => l.id.equals(layerId))).write(
      LayersCompanion(
        borderFillAreas:
            fillAreas == null ? const Value.absent() : Value(fillAreas),
        borderShowNames:
            showNames == null ? const Value.absent() : Value(showNames),
      ),
    );
  }

  // --- Settings -------------------------------------------------------------

  /// Watches the single settings row, emitting defaults when it doesn't exist
  /// yet (so callers never have to seed it before reading).
  Stream<AppSetting> watchSettings() {
    return (_db.select(_db.appSettings)..where((s) => s.id.equals(1)))
        .watch()
        .map(
          (rows) => rows.isEmpty
              ? const AppSetting(
                  id: 1,
                  uncertaintyMeters: 500,
                  transportOverlay: false,
                  poiCategories: 0,
                  borderLevels: 0,
                  toolsExpanded: true,
                  basemapVisible: true,
                  basemapOpacity: 1.0,
                )
              : rows.first,
        );
  }

  /// Upserts the global uncertainty (metres) into the single settings row.
  Future<void> updateUncertainty(double meters) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            uncertaintyMeters: Value(meters),
          ),
        );
  }

  /// Remembers which Overpass instance last served an import (transit or
  /// borders), so the next one starts with the one that was actually up rather
  /// than at whichever is currently swamped.
  Future<void> updateTransitEndpoint(String endpoint) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            transitEndpoint: Value(endpoint),
          ),
        );
  }

  /// Upserts the utility-FAB expand/collapse choice into the settings row.
  Future<void> updateToolsExpanded(bool expanded) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            toolsExpanded: Value(expanded),
          ),
        );
  }

  /// Upserts the base-map visibility toggle into the single settings row.
  Future<void> updateBasemapVisible(bool visible) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            basemapVisible: Value(visible),
          ),
        );
  }

  /// Upserts the base-map opacity (0–1) into the single settings row.
  Future<void> updateBasemapOpacity(double opacity) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            basemapOpacity: Value(opacity),
          ),
        );
  }

  /// Persists the last map camera so the app reopens on the same view.
  Future<void> saveCamera(double lat, double lng, double zoom) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            lastLat: Value(lat),
            lastLng: Value(lng),
            lastZoom: Value(zoom),
          ),
        );
  }

  // --- Tile cache -----------------------------------------------------------

  /// Returns the cached bytes for [url] (bumping its last-used time so eviction
  /// keeps it), or null if the tile isn't cached.
  Future<Uint8List?> getTile(String url) async {
    final row = await (_db.select(_db.tileCache)
          ..where((t) => t.url.equals(url)))
        .getSingleOrNull();
    if (row == null) return null;
    await (_db.update(_db.tileCache)..where((t) => t.url.equals(url))).write(
      TileCacheCompanion(lastUsedAt: Value(DateTime.now().millisecondsSinceEpoch)),
    );
    return row.bytes;
  }

  /// Inserts/updates the cached bytes for [url].
  Future<void> putTile(String url, Uint8List bytes, {String? etag}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.into(_db.tileCache).insertOnConflictUpdate(
          TileCacheCompanion.insert(
            url: url,
            bytes: bytes,
            etag: Value(etag),
            sizeBytes: bytes.length,
            fetchedAt: now,
            lastUsedAt: now,
          ),
        );
  }

  /// True if [url] is already cached (used by prefetch to avoid refetching).
  Future<bool> hasTile(String url) async {
    final row = await (_db.selectOnly(_db.tileCache)
          ..addColumns([_db.tileCache.url])
          ..where(_db.tileCache.url.equals(url))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Total bytes currently held in the tile cache (for the Settings readout).
  Future<int> tileCacheBytes() async {
    final sum = _db.tileCache.sizeBytes.sum();
    final row = await (_db.selectOnly(_db.tileCache)..addColumns([sum]))
        .getSingle();
    return row.read(sum) ?? 0;
  }

  /// Evicts least-recently-used tiles until the cache total is at or below
  /// [maxBytes]. Cheap no-op when already under the cap.
  Future<void> evictTilesDownTo(int maxBytes) async {
    var total = await tileCacheBytes();
    if (total <= maxBytes) return;
    // Walk oldest-first in batches, deleting until under the cap.
    while (total > maxBytes) {
      final batch = await (_db.select(_db.tileCache)
            ..orderBy([(t) => OrderingTerm(expression: t.lastUsedAt)])
            ..limit(64))
          .get();
      if (batch.isEmpty) break;
      final urls = <String>[];
      for (final row in batch) {
        urls.add(row.url);
        total -= row.sizeBytes;
        if (total <= maxBytes) break;
      }
      await (_db.delete(_db.tileCache)..where((t) => t.url.isIn(urls))).go();
    }
  }

  /// Empties the tile cache (the Settings "Clear cached map tiles" button).
  Future<void> clearTileCache() => _db.delete(_db.tileCache).go();

  // --- Overpass overlay cache ----------------------------------------------
  //
  // **Gone.** Both viewport-following overlays this cached are gone: map POIs
  // became the `poi` layer type, administrative borders the `borders` one, and
  // both store their imports in their own tables instead. The read/write
  // accessors were deleted with them; the `OverpassCache` **table** stays,
  // because migrations here are append-only and dropping it would mean a table
  // rebuild for no benefit — the same treatment the dead `AppSettings` columns
  // (`transportOverlay`, `borderLevels`, `poiCategories`) get.

  // --- Clear ----------------------------------------------------------------

  /// Wipes all user data: deletes every layer (cascading to circles/planes),
  /// resets settings to defaults (uncertainty 500, camera null) by dropping the
  /// settings row, then re-seeds an empty default layer. Used by the Settings
  /// "Clear all data" button. Returns the id of the freshly seeded layer. The
  /// tile cache is left intact (it's not user data — it has its own button).
  Future<String> clearAll() async {
    await _db.delete(_db.layers).go(); // cascades to circles/planes
    await _db.delete(_db.appSettings).go(); // reverts to column defaults on read
    await _db.delete(_db.overpassCache).go(); // persisted POI/border overlays
    return ensureDefaultLayer();
  }

  // --- Import / export ------------------------------------------------------

  /// Snapshots layers and their objects into a drift-free [ExportData] for
  /// GeoJSON/KML serialisation. Layers come out in draw order; child points keep
  /// their stored order. With [onlyLayerId] set, exports just that one layer
  /// (used by the per-layer "Export layer" action).
  Future<ExportData> exportData({String? onlyLayerId}) async {
    final layersQuery = _db.select(_db.layers)
      ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)]);
    if (onlyLayerId != null) {
      layersQuery.where((l) => l.id.equals(onlyLayerId));
    }
    final layers = await layersQuery.get();
    final circles = await _db.select(_db.circles).get();
    final planes = await _db.select(_db.planes).get();
    final subspaces = await _db.select(_db.subspaces).get();
    final subPoints = await (_db.select(_db.subspacePoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .get();
    final freeLines = await _db.select(_db.freeLines).get();
    final flPoints = await (_db.select(_db.freeLinePoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .get();
    final freeAreas = await _db.select(_db.freeAreas).get();
    final faPoints = await (_db.select(_db.freeAreaPoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .get();
    final heightRegions = await _db.select(_db.heightRegions).get();
    final transitSets = await _db.select(_db.transitSets).get();
    final transitStops = await _db.select(_db.transitStops).get();
    final poiSets = await _db.select(_db.poiSets).get();
    final poiPoints = await (_db.select(_db.poiPoints)
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .get();

    final out = <ExportLayer>[];
    for (final layer in layers) {
      final objects = <ExportObject>[];
      switch (layer.type) {
        case 'circles':
          for (final c in circles.where((c) => c.layerId == layer.id)) {
            objects.add(ExportObject(
              kind: 'circle',
              coords: [LatLng(c.centerLat, c.centerLng)],
              radiusMeters: c.radiusMeters,
              label: c.label,
              colorArgb: c.colorArgb,
            ));
          }
        case 'planes':
          for (final p in planes.where((p) => p.layerId == layer.id)) {
            objects.add(ExportObject(
              kind: 'plane',
              coords: [LatLng(p.aLat, p.aLng), LatLng(p.bLat, p.bLng)],
              nearA: p.nearA,
              label: p.label,
              colorArgb: p.colorArgb,
            ));
          }
        case 'subspace':
          for (final s in subspaces.where((s) => s.layerId == layer.id)) {
            final pts = subPoints.where((p) => p.subspaceId == s.id).toList();
            if (pts.isEmpty) continue;
            var mainIndex = pts.indexWhere((p) => p.isMain);
            if (mainIndex < 0) mainIndex = 0;
            objects.add(ExportObject(
              kind: 'subspace',
              coords: [for (final p in pts) LatLng(p.lat, p.lng)],
              mainIndex: mainIndex,
              label: s.label,
              colorArgb: s.colorArgb,
            ));
          }
        case 'freeline':
          for (final l in freeLines.where((l) => l.layerId == layer.id)) {
            final pts = flPoints.where((p) => p.freeLineId == l.id).toList();
            objects.add(ExportObject(
              kind: 'freeline',
              coords: [for (final p in pts) LatLng(p.lat, p.lng)],
              offsetMeters: l.offsetMeters,
              inclusionLat: l.inclusionLat,
              inclusionLng: l.inclusionLng,
              inclusionRadiusMeters: l.inclusionRadiusMeters,
              label: l.label,
              colorArgb: l.colorArgb,
            ));
          }
        case 'freearea':
          for (final a in freeAreas.where((a) => a.layerId == layer.id)) {
            final pts = faPoints.where((p) => p.freeAreaId == a.id).toList();
            objects.add(ExportObject(
              kind: 'freearea',
              coords: [for (final p in pts) LatLng(p.lat, p.lng)],
              offsetMeters: a.offsetMeters,
              label: a.label,
              colorArgb: a.colorArgb,
            ));
          }
        case 'height':
          for (final r in heightRegions.where((r) => r.layerId == layer.id)) {
            objects.add(ExportObject(
              kind: 'height',
              coords: [LatLng(r.centerLat, r.centerLng)],
              radiusMeters: r.radiusMeters,
              thresholdMeters: r.thresholdMeters,
              aboveThreshold: r.aboveThreshold,
              sampleZoom: r.sampleZoom,
              label: r.label,
              colorArgb: r.colorArgb,
            ));
          }
        case 'poi':
          // coords[0] is the set's search centre; coords[1..] are the POIs
          // themselves, with their names in [ExportObject.pointLabels].
          for (final s in poiSets.where((s) => s.layerId == layer.id)) {
            final pts = poiPoints.where((p) => p.poiSetId == s.id).toList();
            objects.add(ExportObject(
              kind: 'poi',
              coords: [
                LatLng(s.centerLat, s.centerLng),
                for (final p in pts) LatLng(p.lat, p.lng),
              ],
              radiusMeters: s.radiusMeters,
              categoryKey: s.categoryKey,
              pointLabels: [for (final p in pts) p.name],
              label: s.label,
              colorArgb: s.colorArgb,
            ));
          }
        case 'transit':
          // Stations export as named points for other tools, but do **not**
          // re-import: this is derived, re-fetchable OSM data keyed to a
          // snapshot, and re-importing an area is one dialog away.
          for (final t in transitSets.where((t) => t.layerId == layer.id)) {
            final stops =
                transitStops.where((x) => x.setId == t.id).toList();
            if (stops.isEmpty) continue;
            objects.add(ExportObject(
              kind: 'transitstop',
              coords: [for (final x in stops) LatLng(x.lat, x.lng)],
              pointLabels: [for (final x in stops) x.name],
              label: t.label,
              colorArgb: t.colorArgb,
            ));
          }
        case 'borders':
          // Nothing. Border areas are derived OSM snapshots keyed to an
          // imported box — the same call transit's stops make, taken further
          // because the geometry is a blob, not points: exporting it would
          // produce a file no other tool wants and this app would not re-read.
          // Re-importing an area is one dialog away.
          break;
      }
      out.add(ExportLayer(
        name: layer.name,
        colorArgb: layer.colorArgb,
        type: layer.type,
        isInverted: layer.isInverted,
        objects: objects,
      ));
    }
    return ExportData(out);
  }

  /// Writes [data] into **new** layers (never merges), preserving order, colour,
  /// type, invert and per-object attributes. Returns the number of objects
  /// created. Objects with unusable geometry (e.g. a non-positive circle radius)
  /// are skipped.
  Future<int> importData(ExportData data) async {
    var imported = 0;
    for (final layer in data.layers) {
      final layerId = await createLayer(
        name: layer.name,
        colorArgb: layer.colorArgb,
        type: layer.type,
      );
      if (layer.isInverted) await updateLayer(layerId, isInverted: true);

      for (final o in layer.objects) {
        if (await _insertObject(layerId, o)) imported++;
      }
    }
    return imported;
  }

  /// Adds [layer]'s objects into the existing [layerId] (must be the same
  /// type), without creating a new layer. Returns the number of objects
  /// inserted. Throws [ArgumentError] on a missing layer or a type mismatch so
  /// the caller can show a friendly message.
  Future<int> mergeIntoLayer(String layerId, ExportLayer layer) async {
    final target = await (_db.select(_db.layers)
          ..where((l) => l.id.equals(layerId)))
        .getSingleOrNull();
    if (target == null) throw ArgumentError('Layer no longer exists');
    if (target.type != layer.type) {
      throw ArgumentError(
          'That file holds ${layer.type} objects, but the layer is '
          '${target.type}');
    }
    var imported = 0;
    for (final o in layer.objects) {
      if (await _insertObject(layerId, o)) imported++;
    }
    return imported;
  }

  /// Applies an imported element's colour override, if the file carried one.
  /// A file without it leaves the element following its new layer, which is
  /// what an import into a differently-coloured layer should do.
  Future<void> _applyImportedColor(
      ColoredElement kind, String id, int? argb) async {
    if (argb != null) await setElementColor(kind, id, argb);
  }

  /// Inserts one exported object into [layerId]. Returns true when it created an
  /// object, false when the geometry was unusable. Shared by [importData] (into
  /// fresh layers) and [mergeIntoLayer] (into an existing one).
  Future<bool> _insertObject(String layerId, ExportObject o) async {
    switch (o.kind) {
      case 'circle':
        final r = o.radiusMeters;
        if (o.coords.isEmpty || r == null || !r.isFinite || r <= 0) {
          return false;
        }
        final cid = await createCircle(
          layerId: layerId,
          centerLat: o.coords.first.latitude,
          centerLng: o.coords.first.longitude,
          radiusMeters: r,
          label: o.label,
        );
        await _applyImportedColor(ColoredElement.circle, cid, o.colorArgb);
      case 'plane':
        if (o.coords.length < 2) return false;
        final pid = await createPlane(
          layerId: layerId,
          aLat: o.coords[0].latitude,
          aLng: o.coords[0].longitude,
          bLat: o.coords[1].latitude,
          bLng: o.coords[1].longitude,
          nearA: o.nearA ?? true,
          label: o.label,
        );
        await _applyImportedColor(ColoredElement.plane, pid, o.colorArgb);
      case 'subspace':
        if (o.coords.isEmpty) return false;
        final sid = await createSubspace(layerId: layerId, label: o.label);
        final main = (o.mainIndex ?? 0).clamp(0, o.coords.length - 1);
        for (var i = 0; i < o.coords.length; i++) {
          await addSubspacePoint(
            subspaceId: sid,
            lat: o.coords[i].latitude,
            lng: o.coords[i].longitude,
            isMain: i == main,
          );
        }
        await _applyImportedColor(ColoredElement.subspace, sid, o.colorArgb);
      case 'freeline':
        if (o.coords.length < 2) return false;
        final lid = await createFreeLine(
          layerId: layerId,
          label: o.label,
          inclusionLat: o.inclusionLat,
          inclusionLng: o.inclusionLng,
          inclusionRadiusMeters: o.inclusionRadiusMeters,
        );
        if ((o.offsetMeters ?? 0) != 0) {
          await updateFreeLine(lid, offsetMeters: o.offsetMeters);
        }
        // Thin heavy imported tracks/borders (GPS jitter, thousand-point
        // city lines) — RDP keeps the endpoints and overall shape.
        await addFreeLinePoints(
            lid, simplifyLine(o.coords, kImportSimplifyMeters));
        await _applyImportedColor(ColoredElement.freeLine, lid, o.colorArgb);
      case 'freearea':
        if (o.coords.length < 3) return false;
        final aid = await createFreeArea(layerId: layerId, label: o.label);
        if ((o.offsetMeters ?? 0) != 0) {
          await updateFreeArea(aid, offsetMeters: o.offsetMeters);
        }
        await addFreeAreaPoints(
            aid, simplifyRing(o.coords, kImportSimplifyMeters, minPoints: 3));
        await _applyImportedColor(ColoredElement.freeArea, aid, o.colorArgb);
      case 'height':
        final r = o.radiusMeters;
        if (o.coords.isEmpty || r == null || !r.isFinite || r <= 0) {
          return false;
        }
        // The generated polygons are derived, not imported — the region comes
        // in un-generated and the user taps Generate.
        final hid = await createHeightRegion(
          layerId: layerId,
          centerLat: o.coords.first.latitude,
          centerLng: o.coords.first.longitude,
          radiusMeters: r,
          thresholdMeters: o.thresholdMeters ?? 0,
          aboveThreshold: o.aboveThreshold ?? true,
          sampleZoom: o.sampleZoom ?? 13,
          label: o.label,
        );
        await _applyImportedColor(ColoredElement.heightRegion, hid, o.colorArgb);
      case 'poi':
        final r = o.radiusMeters;
        if (o.coords.isEmpty || r == null || !r.isFinite || r <= 0) {
          return false;
        }
        final sid = await createPoiSet(
          layerId: layerId,
          categoryKey: o.categoryKey ?? 'place',
          centerLat: o.coords.first.latitude,
          centerLng: o.coords.first.longitude,
          radiusMeters: r,
          label: o.label,
        );
        final labels = o.pointLabels ?? const <String?>[];
        // No OSM identity: the export format doesn't carry it, so an imported
        // file's POIs stay outside the dedup check rather than being given a
        // made-up one.
        await addPoiPoints(sid, [
          for (var i = 1; i < o.coords.length; i++)
            PoiResult(
              lat: o.coords[i].latitude,
              lng: o.coords[i].longitude,
              categoryKey: o.categoryKey ?? 'place',
              name: i - 1 < labels.length ? labels[i - 1] : null,
            ),
        ]);
        await _applyImportedColor(ColoredElement.poiSet, sid, o.colorArgb);
      case 'transitstop':
        // Derived, re-fetchable OSM data — see the 'transit' case in
        // exportData. Re-import an area by fetching it again, not from a file.
        return false;
      default:
        return false;
    }
    return true;
  }

  // --- Seed -----------------------------------------------------------------

  /// Ensures at least one layer exists so the user can place circles right away.
  /// Also removes any circles with non-finite coordinates/radius left over from
  /// older builds (which would crash map projection). Returns the id of an
  /// existing or freshly created layer.
  Future<String> ensureDefaultLayer() async {
    await deleteInvalidCircles();
    final existing = await (_db.select(_db.layers)
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return createLayer(name: 'Layer 1', colorArgb: 0xFF2196F3);
  }

  /// Deletes circles whose centre or radius is NULL or non-finite (NaN/∞).
  /// Read via a raw query so a bad value can't throw during row mapping; NaN is
  /// detected in Dart (SQL comparisons against NaN are all false).
  Future<void> deleteInvalidCircles() async {
    final rows = await _db
        .customSelect(
          'SELECT id, center_lat, center_lng, radius_meters FROM circles',
        )
        .get();
    final badIds = <String>[
      for (final r in rows)
        if (!_isFinite(r.read<double?>('center_lat')) ||
            !_isFinite(r.read<double?>('center_lng')) ||
            !_isFinite(r.read<double?>('radius_meters')) ||
            (r.read<double?>('radius_meters') ?? 0) <= 0)
          r.read<String>('id'),
    ];
    if (badIds.isNotEmpty) {
      await (_db.delete(_db.circles)..where((c) => c.id.isIn(badIds))).go();
    }
  }

  static bool _isFinite(double? v) => v != null && v.isFinite;
}

/// The element tables that carry a per-element colour (schema v22).
///
/// A data-layer twin of the UI's `ObjectKind`: the repository can't reach into
/// `state/providers.dart`, and only these nine kinds have a colour to set.
enum ColoredElement {
  circle('circles', 'circles'),
  plane('planes', 'planes'),
  subspace('subspaces', 'subspace'),
  freeLine('free_lines', 'freeline'),
  freeArea('free_areas', 'freearea'),
  heightRegion('height_regions', 'height'),
  poiSet('poi_sets', 'poi'),
  transitSet('transit_sets', 'transit'),
  borderArea('border_areas', 'borders');

  const ColoredElement(this.table, this.layerType);

  /// The SQL table the elements live in.
  final String table;

  /// The `Layers.type` string whose elements these are.
  final String layerType;

  static ColoredElement? forLayerType(String type) {
    for (final k in ColoredElement.values) {
      if (k.layerType == type) return k;
    }
    return null;
  }
}
