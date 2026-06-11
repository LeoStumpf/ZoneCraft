import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

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
  }) {
    return (_db.update(_db.layers)..where((l) => l.id.equals(id))).write(
      LayersCompanion(
        name: name == null ? const Value.absent() : Value(name),
        colorArgb: colorArgb == null ? const Value.absent() : Value(colorArgb),
        isVisible:
            isVisible == null ? const Value.absent() : Value(isVisible),
        isInverted:
            isInverted == null ? const Value.absent() : Value(isInverted),
      ),
    );
  }

  Future<void> deleteLayer(String id) {
    return (_db.delete(_db.layers)..where((l) => l.id.equals(id))).go();
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
          ),
        );
    return id;
  }

  Future<void> updateSubspacePoint(String id, {double? lat, double? lng}) {
    return (_db.update(_db.subspacePoints)..where((p) => p.id.equals(id))).write(
      SubspacePointsCompanion(
        lat: lat == null ? const Value.absent() : Value(lat),
        lng: lng == null ? const Value.absent() : Value(lng),
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

  Future<String> createFreeLine({required String layerId, String? label}) async {
    final id = _uuid.v4();
    await _db.into(_db.freeLines).insert(
          FreeLinesCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
          ),
        );
    return id;
  }

  Future<void> updateFreeLine(
    String id, {
    String? layerId,
    double? offsetMeters,
    Value<String?> label = const Value.absent(),
  }) {
    return (_db.update(_db.freeLines)..where((l) => l.id.equals(id))).write(
      FreeLinesCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        offsetMeters:
            offsetMeters == null ? const Value.absent() : Value(offsetMeters),
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

  Future<int> _maxFreeAreaPointOrder(String freeAreaId) async {
    final max = _db.freeAreaPoints.sortOrder.max();
    final row = await (_db.selectOnly(_db.freeAreaPoints)
          ..addColumns([max])
          ..where(_db.freeAreaPoints.freeAreaId.equals(freeAreaId)))
        .getSingleOrNull();
    return row?.read(max) ?? -1;
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
