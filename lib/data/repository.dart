import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:uuid/uuid.dart';

import '../geo/simplify.dart';
import 'database.dart';
import 'serialization.dart';

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
  Future<String> createLayer({
    required String name,
    required int colorArgb,
    String type = 'circles',
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
        default:
          await (_db.update(_db.circles)
                ..where((t) => t.layerId.equals(sourceId)))
              .write(CirclesCompanion(layerId: Value(targetId)));
      }
      // The source now holds no objects, so deleting it won't cascade the
      // re-pointed rows away.
      await (_db.delete(_db.layers)..where((l) => l.id.equals(sourceId))).go();
    });
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

  Future<String> createCircle({
    required String layerId,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    String? label,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.circles).insert(
          CirclesCompanion.insert(
            id: id,
            layerId: layerId,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            label: Value(label),
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
    await _db.into(_db.subspaces).insert(
          SubspacesCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
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
    await _db.into(_db.freeLines).insert(
          FreeLinesCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
            inclusionLat: Value(inclusionLat),
            inclusionLng: Value(inclusionLng),
            inclusionRadiusMeters: Value(inclusionRadiusMeters),
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
    await _db.into(_db.freeAreas).insert(
          FreeAreasCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
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
    await _db.into(_db.poiSets).insert(
          PoiSetsCompanion.insert(
            id: id,
            layerId: layerId,
            categoryKey: categoryKey,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            label: Value(label),
          ),
        );
    return id;
  }

  /// Appends the fetched POIs to [poiSetId] in one batch.
  Future<void> addPoiPoints(
    String poiSetId,
    List<({double lat, double lng, String? name})> pts,
  ) async {
    if (pts.isEmpty) return;
    await _db.batch((b) {
      for (var i = 0; i < pts.length; i++) {
        b.insert(
          _db.poiPoints,
          PoiPointsCompanion.insert(
            id: _uuid.v4(),
            poiSetId: poiSetId,
            lat: pts[i].lat,
            lng: pts[i].lng,
            name: Value(pts[i].name),
            sortOrder: i,
          ),
        );
      }
    });
  }

  Future<void> deletePoiSet(String id) {
    return (_db.delete(_db.poiSets)..where((s) => s.id.equals(id))).go();
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

  /// Upserts the public-transport overlay toggle into the single settings row.
  Future<void> updateTransportOverlay(bool enabled) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            transportOverlay: Value(enabled),
          ),
        );
  }

  /// Upserts the enabled-POI-category bitmask into the single settings row.
  Future<void> updatePoiCategories(int mask) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            poiCategories: Value(mask),
          ),
        );
  }

  /// Upserts the enabled-border-levels bitmask into the single settings row.
  Future<void> updateBorderLevels(int mask) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            borderLevels: Value(mask),
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

  /// Persists the last successful Overpass result for [kind] ('poi'|'border').
  Future<void> saveOverpassCache(
    String kind,
    String payload, {
    required double south,
    required double west,
    required double north,
    required double east,
    required int maskBits,
  }) {
    return _db.into(_db.overpassCache).insertOnConflictUpdate(
          OverpassCacheCompanion.insert(
            kind: kind,
            payload: payload,
            south: south,
            west: west,
            north: north,
            east: east,
            maskBits: maskBits,
            fetchedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// Loads the persisted Overpass result for [kind], or null if none.
  Future<OverpassCacheData?> loadOverpassCache(String kind) {
    return (_db.select(_db.overpassCache)..where((c) => c.kind.equals(kind)))
        .getSingleOrNull();
  }

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
            ));
          }
        case 'planes':
          for (final p in planes.where((p) => p.layerId == layer.id)) {
            objects.add(ExportObject(
              kind: 'plane',
              coords: [LatLng(p.aLat, p.aLng), LatLng(p.bLat, p.bLng)],
              nearA: p.nearA,
              label: p.label,
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
            ));
          }
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
        await createCircle(
          layerId: layerId,
          centerLat: o.coords.first.latitude,
          centerLng: o.coords.first.longitude,
          radiusMeters: r,
          label: o.label,
        );
      case 'plane':
        if (o.coords.length < 2) return false;
        await createPlane(
          layerId: layerId,
          aLat: o.coords[0].latitude,
          aLng: o.coords[0].longitude,
          bLat: o.coords[1].latitude,
          bLng: o.coords[1].longitude,
          nearA: o.nearA ?? true,
          label: o.label,
        );
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
      case 'freearea':
        if (o.coords.length < 3) return false;
        final aid = await createFreeArea(layerId: layerId, label: o.label);
        if ((o.offsetMeters ?? 0) != 0) {
          await updateFreeArea(aid, offsetMeters: o.offsetMeters);
        }
        await addFreeAreaPoints(
            aid, simplifyRing(o.coords, kImportSimplifyMeters, minPoints: 3));
      case 'height':
        final r = o.radiusMeters;
        if (o.coords.isEmpty || r == null || !r.isFinite || r <= 0) {
          return false;
        }
        // The generated polygons are derived, not imported — the region comes
        // in un-generated and the user taps Generate.
        await createHeightRegion(
          layerId: layerId,
          centerLat: o.coords.first.latitude,
          centerLng: o.coords.first.longitude,
          radiusMeters: r,
          thresholdMeters: o.thresholdMeters ?? 0,
          aboveThreshold: o.aboveThreshold ?? true,
          sampleZoom: o.sampleZoom ?? 13,
          label: o.label,
        );
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
        await addPoiPoints(sid, [
          for (var i = 1; i < o.coords.length; i++)
            (
              lat: o.coords[i].latitude,
              lng: o.coords[i].longitude,
              name: i - 1 < labels.length ? labels[i - 1] : null,
            ),
        ]);
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
