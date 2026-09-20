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

import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart'
    show Distance, Haversine, LatLng, LengthUnit;
import 'package:uuid/uuid.dart';

import '../geo/border_areas.dart';
import '../geo/simplify.dart';
import 'database.dart';
import 'layer_types.dart';
import 'overpass.dart' show PoiResult;
import 'poi_sets.dart';
import 'serialization.dart';
import 'service_overrides.dart';
import 'undo_journal.dart';

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

const Distance _geo = Distance(calculator: Haversine());

/// `type/id` — the only safe identity for an OSM element, because ids are
/// unique only *within* a type: node 240109189 and way 240109189 are different
/// things. Null when either half is missing.
///
/// **Zero counts as missing.** It is not a valid OSM id for any element type;
/// it is the placeholder an id-less imported row is stored with (see
/// `BorderAreas.osmId`, which is NOT NULL). Treating it as a real identity made
/// every id-less area look like the same relation, so a re-import kept one and
/// silently dropped the rest.
String? osmKey(String? type, int? id) =>
    (type == null || id == null || id == 0) ? null : '$type/$id';

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

  /// Row-level undo/redo. It belongs to the database — its triggers live on
  /// that connection — but every caller reaches it through the repository,
  /// which is the one thing the whole app already resolves writes through. Going
  /// via the database instead would make anything that only wants to seal a step
  /// construct a real, file-backed database, which is wrong in tests and wrong
  /// anywhere the repository has been substituted.
  UndoJournal get undo => _db.undo;

  // --- Layers ---------------------------------------------------------------

  /// All layers ordered by draw order (ascending; last item is drawn on top).
  Stream<List<Layer>> watchLayers() {
    return (_db.select(
      _db.layers,
    )..orderBy([(l) => OrderingTerm(expression: l.sortOrder)])).watch();
  }

  /// Creates a layer placed on top of all existing ones. Returns its id.
  /// [type] is the object kind the layer holds (see `layer_types.dart`).
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
    await _db
        .into(_db.layers)
        .insert(
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
    String? type,
  }) {
    return (_db.update(_db.layers)..where((l) => l.id.equals(id))).write(
      LayersCompanion(
        name: name == null ? const Value.absent() : Value(name),
        colorArgb: colorArgb == null ? const Value.absent() : Value(colorArgb),
        isVisible: isVisible == null ? const Value.absent() : Value(isVisible),
        isInverted: isInverted == null
            ? const Value.absent()
            : Value(isInverted),
        opacity: opacity == null ? const Value.absent() : Value(opacity),
        type: type == null ? const Value.absent() : Value(type),
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
    final src = await (_db.select(
      _db.layers,
    )..where((l) => l.id.equals(sourceId))).getSingleOrNull();
    final tgt = await (_db.select(
      _db.layers,
    )..where((l) => l.id.equals(targetId))).getSingleOrNull();
    if (src == null || tgt == null) {
      throw ArgumentError('Layer no longer exists');
    }
    // The target has to be able to *hold* everything the source does — which a
    // mixed target does for all but `borders`, and a single-type target only
    // for its own type.
    final moving = layerContentTypes(src);
    final unheld = moving.where((t) => !layerTypeHolds(tgt.type, t)).toList();
    if (unheld.isNotEmpty) {
      throw ArgumentError('Layers must be the same type');
    }
    // One borders layer holds one admin level: the "no two neighbours share a
    // colour" rule is only meaningful within a level, since areas of different
    // levels nest rather than tile.
    if (src.type == kBorders && src.borderLevel != tgt.borderLevel) {
      throw ArgumentError('Border layers must hold the same level');
    }
    await _db.transaction(() async {
      // Re-point every table the source can hold. Driven by
      // [layerContentTypes] rather than a switch with a `default:` arm: the old
      // shape silently sent an unknown type down the `circles` branch, which
      // re-pointed nothing and then lost every row to the cascade when the
      // source layer was deleted below. An unknown type now throws instead.
      for (final type in moving) {
        await _repointLayerRows(type, sourceId, targetId);
      }
      // The source now holds no objects, so deleting it won't cascade the
      // re-pointed rows away.
      await (_db.delete(_db.layers)..where((l) => l.id.equals(sourceId))).go();
    });
    // The target now holds areas from two imports that were coloured
    // independently, so its seam has to be resolved.
    if (layerTypeHolds(tgt.type, kBorders) && moving.contains(kBorders)) {
      await recolourBorderLayer(targetId);
    }
  }

  /// Moves every row of one object [type] from [sourceId] to [targetId].
  ///
  /// Exhaustive by construction: a type with no branch here throws rather than
  /// quietly doing nothing, which is the failure the old `default:` arm made
  /// invisible until a layer had already lost its contents.
  Future<void> _repointLayerRows(
    String type,
    String sourceId,
    String targetId,
  ) async {
    final to = Value(targetId);
    // Stack the incoming elements **above** the target's, rather than letting
    // the two layers' independent z numbering interleave into an order neither
    // of them had. One statement per table, O(1), and it preserves each side's
    // internal order — which is what "combine this into that" means.
    await _liftZAbove(type, sourceId, targetId);
    switch (type) {
      case kCircles:
        await (_db.update(_db.circles)
              ..where((t) => t.layerId.equals(sourceId)))
            .write(CirclesCompanion(layerId: to));
      case kSubspace:
        await (_db.update(_db.subspaces)
              ..where((t) => t.layerId.equals(sourceId)))
            .write(SubspacesCompanion(layerId: to));
      case kFreeLine:
        await (_db.update(_db.freeLines)
              ..where((t) => t.layerId.equals(sourceId)))
            .write(FreeLinesCompanion(layerId: to));
      case kFreeArea:
        await (_db.update(_db.freeAreas)
              ..where((t) => t.layerId.equals(sourceId)))
            .write(FreeAreasCompanion(layerId: to));
      case kHeight:
        await (_db.update(_db.heightRegions)
              ..where((t) => t.layerId.equals(sourceId)))
            .write(HeightRegionsCompanion(layerId: to));
      case kPoi:
        await (_db.update(_db.poiSets)
              ..where((t) => t.layerId.equals(sourceId)))
            .write(PoiSetsCompanion(layerId: to));
      case kBorders:
        await (_db.update(_db.borderSets)
              ..where((t) => t.layerId.equals(sourceId)))
            .write(BorderSetsCompanion(layerId: to));
      default:
        throw ArgumentError('No table is registered for layer type "$type"');
    }
  }

  // --- Folders --------------------------------------------------------------

  /// All folders, ordered by their place among the root items.
  Stream<List<Folder>> watchFolders() {
    return (_db.select(
      _db.folders,
    )..orderBy([(f) => OrderingTerm(expression: f.sortOrder)])).watch();
  }

  /// A new, empty folder on top of the stack.
  Future<String> createFolder({required String name}) async {
    final id = _uuid.v4();
    // One ordering space at the root: a folder sits among the layers that are
    // not in one, so it has to start above both.
    final maxLayer = await _maxSortOrder();
    final maxFolder = _db.folders.sortOrder.max();
    final row = await (_db.selectOnly(
      _db.folders,
    )..addColumns([maxFolder])).getSingleOrNull();
    final top = math.max(maxLayer, row?.read(maxFolder) ?? -1);
    await _db
        .into(_db.folders)
        .insert(
          FoldersCompanion.insert(id: id, name: name, sortOrder: top + 1),
        );
    return id;
  }

  Future<void> updateFolder(
    String id, {
    String? name,
    bool? isVisible,
    bool? isInverted,
    bool? isCollapsed,
  }) {
    return (_db.update(_db.folders)..where((f) => f.id.equals(id))).write(
      FoldersCompanion(
        name: name == null ? const Value.absent() : Value(name),
        isVisible: isVisible == null ? const Value.absent() : Value(isVisible),
        isInverted: isInverted == null
            ? const Value.absent()
            : Value(isInverted),
        isCollapsed: isCollapsed == null
            ? const Value.absent()
            : Value(isCollapsed),
      ),
    );
  }

  /// Deletes the folder. **Its layers survive**, back at the root where they
  /// were — the `folderId` FK is `setNull`. Getting layers back out again is
  /// the thing the `mixed` layer could never do, so deleting the group must
  /// never be a way to delete its contents by accident.
  Future<void> deleteFolder(String id) {
    return (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
  }

  /// Moves [layerId] into [folderId] (null = out to the root), on top of
  /// whatever is already there.
  Future<void> moveLayerToFolder(String layerId, String? folderId) async {
    final scope = folderId == null
        ? (_db.select(_db.layers)..where((l) => l.folderId.isNull()))
        : (_db.select(_db.layers)..where((l) => l.folderId.equals(folderId)));
    final siblings = await scope.get();
    var top = -1;
    for (final s in siblings) {
      if (s.id != layerId && s.sortOrder > top) top = s.sortOrder;
    }
    if (folderId == null) {
      // At the root a layer shares its ordering with the folders.
      final maxFolder = _db.folders.sortOrder.max();
      final row = await (_db.selectOnly(
        _db.folders,
      )..addColumns([maxFolder])).getSingleOrNull();
      top = math.max(top, row?.read(maxFolder) ?? -1);
    }
    await (_db.update(_db.layers)..where((l) => l.id.equals(layerId))).write(
      LayersCompanion(folderId: Value(folderId), sortOrder: Value(top + 1)),
    );
  }

  /// Persists a whole tree's ordering and membership in one batch.
  ///
  /// The shape is `ui/layer_tree.dart`'s `TreeWrite`, spelled out structurally
  /// rather than imported: records are structural in Dart, so the two agree
  /// without the data layer depending on the UI that computes them.
  Future<void> reorderTree(
    List<({String id, bool isFolder, String? folderId, int sortOrder})> writes,
  ) async {
    await _db.batch((b) {
      for (final w in writes) {
        if (w.isFolder) {
          b.update(
            _db.folders,
            FoldersCompanion(sortOrder: Value(w.sortOrder)),
            where: (f) => f.id.equals(w.id),
          );
        } else {
          b.update(
            _db.layers,
            LayersCompanion(
              folderId: Value(w.folderId),
              sortOrder: Value(w.sortOrder),
            ),
            where: (l) => l.id.equals(w.id),
          );
        }
      }
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
    final row = await (_db.selectOnly(
      _db.layers,
    )..addColumns([max])).getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Circles --------------------------------------------------------------

  Stream<List<Circle>> watchAllCircles() {
    return (_db.select(_db.circles)..orderBy([
          (t) => OrderingTerm(expression: t.zOrder),
          (t) => OrderingTerm(expression: t.createdAt),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  // --- Per-element colour (v22) ---------------------------------------------

  /// Sets — or with null clears — one element's colour override. Clearing puts
  /// the element back on its auto shade of the layer colour, so it follows
  /// later layer recolours again.
  Future<void> setElementColor(ColoredElement kind, String id, int? argb) {
    final v = Value<int?>(argb);
    return switch (kind) {
      ColoredElement.circle => (_db.update(
        _db.circles,
      )..where((t) => t.id.equals(id))).write(CirclesCompanion(colorArgb: v)),
      ColoredElement.subspace => (_db.update(
        _db.subspaces,
      )..where((t) => t.id.equals(id))).write(SubspacesCompanion(colorArgb: v)),
      ColoredElement.freeLine => (_db.update(
        _db.freeLines,
      )..where((t) => t.id.equals(id))).write(FreeLinesCompanion(colorArgb: v)),
      ColoredElement.freeArea => (_db.update(
        _db.freeAreas,
      )..where((t) => t.id.equals(id))).write(FreeAreasCompanion(colorArgb: v)),
      ColoredElement.heightRegion =>
        (_db.update(_db.heightRegions)..where((t) => t.id.equals(id))).write(
          HeightRegionsCompanion(colorArgb: v),
        ),
      ColoredElement.poiSet => (_db.update(
        _db.poiSets,
      )..where((t) => t.id.equals(id))).write(PoiSetsCompanion(colorArgb: v)),
      ColoredElement.borderArea =>
        (_db.update(_db.borderAreas)..where((t) => t.id.equals(id))).write(
          BorderAreasCompanion(colorArgb: v),
        ),
    };
  }

  /// The ids of [layerId]'s elements that carry an explicit colour — what the
  /// layer-recolour dialog needs to know, since those are exactly the elements
  /// a recolour would *not* reach on its own.
  Future<List<String>> elementsWithColorOverride(
    String layerId,
    String layerType,
  ) async {
    // The overrides live in one table per kind, so this asks each
    // of the types it holds rather than one.
    final kinds = [
      for (final type in layerContentTypesOf(layerType))
        if (ColoredElement.forLayerType(type) != null)
          ColoredElement.forLayerType(type)!,
    ];
    if (kinds.isEmpty) return const [];
    final out = <String>[];
    for (final kind in kinds) {
      // Border areas hang off their import set, not off the layer directly.
      final sql = kind == ColoredElement.borderArea
          ? 'SELECT a.id AS id FROM border_areas a '
                'JOIN border_sets s ON a.set_id = s.id '
                'WHERE s.layer_id = ? AND a.color_argb IS NOT NULL'
          : 'SELECT id FROM ${kind.table} '
                'WHERE layer_id = ? AND color_argb IS NOT NULL';
      final rows = await _db
          .customSelect(sql, variables: [Variable<String>(layerId)])
          .get();
      out.addAll([for (final r in rows) r.read<String>('id')]);
    }
    return out;
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
  ///
  /// One layer holds one kind since v30, so one table is the whole answer —
  /// the cross-table maximum a `mixed` layer needed went with it.
  Future<int> _nextColorShade(String table, String layerId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(color_shade), -1) + 1 AS next '
          'FROM $table WHERE layer_id = ?',
          variables: [Variable<String>(layerId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  /// Shifts [sourceId]'s elements of [type] past the top of [targetId]'s, so
  /// the two stacks concatenate when the rows are re-pointed.
  ///
  /// Silently does nothing for a type with no `z_order` (`borders`, whose areas
  /// do not overlap at one admin level, and the point tables): the caller is
  /// exhaustive over types, this is only about the ones that stack.
  Future<void> _liftZAbove(
    String type,
    String sourceId,
    String targetId,
  ) async {
    final kind = ColoredElement.forLayerType(type);
    if (kind == null || kind == ColoredElement.borderArea) return;
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(z_order), -1) + 1 AS next '
          'FROM ${kind.table} WHERE layer_id = ?',
          variables: [Variable<String>(targetId)],
        )
        .getSingle();
    final offset = row.read<int>('next');
    if (offset == 0) return;
    await _db.customUpdate(
      'UPDATE ${kind.table} SET z_order = z_order + ? WHERE layer_id = ?',
      variables: [Variable<int>(offset), Variable<String>(sourceId)],
      updates: {_tableOf(kind)},
    );
  }

  /// The stack slot a new element of [table] takes in [layerId]: one past the
  /// highest already used, so a new element lands **in front**.
  ///
  /// The scope of a `z_order` is one layer *and one table*: each kind is drawn
  /// by its own painter in its own pass, so no number stored here could make a
  /// marker go behind a circle. Sharing a counter across tables would only
  /// invent an ordering nothing honours.
  ///
  /// Deliberately **not** gapless from zero: a delete must never restack the
  /// layer. [reorderElements] is what collapses the gaps, and only when the
  /// user actually moves something.
  Future<int> _nextZOrder(String table, String layerId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(z_order), -1) + 1 AS next '
          'FROM $table WHERE layer_id = ?',
          variables: [Variable<String>(layerId)],
        )
        .getSingle();
    return row.read<int>('next');
  }

  /// The ids of [layerId]'s elements of [kind], back-to-front.
  Future<List<String>> _stackedIds(ColoredElement kind, String layerId) async {
    final rows = await _db
        .customSelect(
          'SELECT id FROM ${kind.table} WHERE layer_id = ? '
          'ORDER BY z_order, created_at, id',
          variables: [Variable<String>(layerId)],
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// The layer an element belongs to, or null if there is no such row.
  Future<String?> _layerOfElement(ColoredElement kind, String id) async {
    final row = await _db
        .customSelect(
          'SELECT layer_id FROM ${kind.table} WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    return row?.read<String?>('layer_id');
  }

  /// Moves one element within its layer's stack.
  ///
  /// Renumbers the whole layer **gaplessly**, exactly as [reorderLayers] does
  /// for layers — one batch, one transaction, one mental model — and that is
  /// also what heals the ties an import or a [combineLayers] can leave behind.
  /// A move that changes nothing writes nothing.
  Future<void> moveElementZ(ColoredElement kind, String id, ZMove move) async {
    final layerId = await _layerOfElement(kind, id);
    if (layerId == null) return;
    final ids = await _stackedIds(kind, layerId);
    final i = ids.indexOf(id);
    if (i < 0) return;
    final j = switch (move) {
      ZMove.toBack => 0,
      ZMove.backward => i - 1,
      ZMove.forward => i + 1,
      ZMove.toFront => ids.length - 1,
    }.clamp(0, ids.length - 1);
    if (j == i) return;
    ids
      ..removeAt(i)
      ..insert(j, id);
    await reorderElements(kind, ids);
  }

  /// The drift table behind a [ColoredElement], for telling the stream layer
  /// which one a raw statement touched.
  ///
  /// A raw `customStatement` writes the row and says nothing, so every open
  /// query stream keeps serving its cached snapshot: the map and the Elements
  /// list would show the old stack until something else happened to dirty the
  /// table. [customUpdate]'s `updates:` is how drift is told, and this is what
  /// it needs to be told *with*.
  TableInfo<Table, dynamic> _tableOf(ColoredElement kind) => switch (kind) {
    ColoredElement.circle => _db.circles,
    ColoredElement.subspace => _db.subspaces,
    ColoredElement.freeLine => _db.freeLines,
    ColoredElement.freeArea => _db.freeAreas,
    ColoredElement.heightRegion => _db.heightRegions,
    ColoredElement.poiSet => _db.poiSets,
    ColoredElement.borderArea => _db.borderAreas,
  };

  /// Persists a whole stack. [orderedIds] is back-to-front, the same direction
  /// [reorderLayers] takes.
  ///
  /// One transaction, so a half-renumbered layer is never observable.
  Future<void> reorderElements(
    ColoredElement kind,
    List<String> orderedIds,
  ) async {
    final table = {_tableOf(kind)};
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await _db.customUpdate(
          'UPDATE ${kind.table} SET z_order = ? WHERE id = ?',
          variables: [Variable<int>(i), Variable<String>(orderedIds[i])],
          updates: table,
        );
      }
    });
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
    final z = await _nextZOrder('circles', layerId);
    await _db
        .into(_db.circles)
        .insert(
          CirclesCompanion.insert(
            id: id,
            layerId: layerId,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            label: Value(label),
            colorShade: Value(shade),
            zOrder: Value(z),
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
  }) async {
    // Moving an element to another layer: the z it carried means nothing
    // there, so it takes a fresh slot on top — which is what moving something
    // into a layer means. Carrying the old number across would bury it under
    // whatever the target already held.
    final z = layerId == null ? null : await _nextZOrder('circles', layerId);
    await (_db.update(_db.circles)..where((c) => c.id.equals(id))).write(
      CirclesCompanion(
        centerLat: centerLat == null ? const Value.absent() : Value(centerLat),
        centerLng: centerLng == null ? const Value.absent() : Value(centerLng),
        radiusMeters: radiusMeters == null
            ? const Value.absent()
            : Value(radiusMeters),
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        zOrder: z == null ? const Value.absent() : Value(z),
        label: label,
      ),
    );
  }

  Future<void> deleteCircle(String id) {
    return (_db.delete(_db.circles)..where((c) => c.id.equals(id))).go();
  }

  // --- Subspaces ------------------------------------------------------------

  Stream<List<Subspace>> watchAllSubspaces() {
    return (_db.select(_db.subspaces)..orderBy([
          (t) => OrderingTerm(expression: t.zOrder),
          (t) => OrderingTerm(expression: t.createdAt),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  /// All points across every subspace, ordered by their [SubspacePoints.sortOrder].
  Stream<List<SubspacePoint>> watchAllSubspacePoints() {
    return (_db.select(
      _db.subspacePoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).watch();
  }

  Future<String> createSubspace({
    required String layerId,
    String? label,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('subspaces', layerId);
    final z = await _nextZOrder('subspaces', layerId);
    await _db
        .into(_db.subspaces)
        .insert(
          SubspacesCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
            colorShade: Value(shade),
            zOrder: Value(z),
          ),
        );
    return id;
  }

  Future<void> updateSubspace(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
  }) async {
    // Moving an element to another layer: the z it carried means nothing
    // there, so it takes a fresh slot on top — which is what moving something
    // into a layer means. Carrying the old number across would bury it under
    // whatever the target already held.
    final z = layerId == null ? null : await _nextZOrder('subspaces', layerId);
    await (_db.update(_db.subspaces)..where((s) => s.id.equals(id))).write(
      SubspacesCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        zOrder: z == null ? const Value.absent() : Value(z),
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
    await _db
        .into(_db.subspacePoints)
        .insert(
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
    return (_db.update(
      _db.subspacePoints,
    )..where((p) => p.id.equals(id))).write(
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
    final row =
        await (_db.selectOnly(_db.subspacePoints)
              ..addColumns([max])
              ..where(_db.subspacePoints.subspaceId.equals(subspaceId)))
            .getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Freehand lines -------------------------------------------------------

  Stream<List<FreeLine>> watchAllFreeLines() {
    return (_db.select(_db.freeLines)..orderBy([
          (t) => OrderingTerm(expression: t.zOrder),
          (t) => OrderingTerm(expression: t.createdAt),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  /// All points across every freehand line, ordered by [FreeLinePoints.sortOrder].
  Stream<List<FreeLinePoint>> watchAllFreeLinePoints() {
    return (_db.select(
      _db.freeLinePoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).watch();
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
    final z = await _nextZOrder('free_lines', layerId);
    await _db
        .into(_db.freeLines)
        .insert(
          FreeLinesCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
            inclusionLat: Value(inclusionLat),
            inclusionLng: Value(inclusionLng),
            inclusionRadiusMeters: Value(inclusionRadiusMeters),
            colorShade: Value(shade),
            zOrder: Value(z),
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
  }) async {
    // Moving an element to another layer: the z it carried means nothing
    // there, so it takes a fresh slot on top — which is what moving something
    // into a layer means. Carrying the old number across would bury it under
    // whatever the target already held.
    final z = layerId == null ? null : await _nextZOrder('free_lines', layerId);
    await (_db.update(_db.freeLines)..where((l) => l.id.equals(id))).write(
      FreeLinesCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        zOrder: z == null ? const Value.absent() : Value(z),
        offsetMeters: offsetMeters == null
            ? const Value.absent()
            : Value(offsetMeters),
        inclusionLat: inclusionLat == null
            ? const Value.absent()
            : Value(inclusionLat),
        inclusionLng: inclusionLng == null
            ? const Value.absent()
            : Value(inclusionLng),
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
    await _db
        .into(_db.freeLinePoints)
        .insert(
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
      await _db
          .into(_db.freeLinePoints)
          .insert(
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

  /// Appends many points to [freeLineId] in one batch (used by GPX import,
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
    return (_db.update(
      _db.freeLinePoints,
    )..where((p) => p.id.equals(id))).write(
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
      final a = await (_db.select(
        _db.freeLinePoints,
      )..where((p) => p.id.equals(idA))).getSingle();
      final b = await (_db.select(
        _db.freeLinePoints,
      )..where((p) => p.id.equals(idB))).getSingle();
      await (_db.update(_db.freeLinePoints)..where((p) => p.id.equals(idA)))
          .write(FreeLinePointsCompanion(sortOrder: Value(b.sortOrder)));
      await (_db.update(_db.freeLinePoints)..where((p) => p.id.equals(idB)))
          .write(FreeLinePointsCompanion(sortOrder: Value(a.sortOrder)));
    });
  }

  Future<int> _maxFreeLinePointOrder(String freeLineId) async {
    final max = _db.freeLinePoints.sortOrder.max();
    final row =
        await (_db.selectOnly(_db.freeLinePoints)
              ..addColumns([max])
              ..where(_db.freeLinePoints.freeLineId.equals(freeLineId)))
            .getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Freehand areas -------------------------------------------------------

  Stream<List<FreeArea>> watchAllFreeAreas() {
    return (_db.select(_db.freeAreas)..orderBy([
          (t) => OrderingTerm(expression: t.zOrder),
          (t) => OrderingTerm(expression: t.createdAt),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  /// All points across every freehand area, ordered by [FreeAreaPoints.sortOrder].
  Stream<List<FreeAreaPoint>> watchAllFreeAreaPoints() {
    return (_db.select(
      _db.freeAreaPoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).watch();
  }

  Future<String> createFreeArea({
    required String layerId,
    String? label,
  }) async {
    final id = _uuid.v4();
    final shade = await _nextColorShade('free_areas', layerId);
    final z = await _nextZOrder('free_areas', layerId);
    await _db
        .into(_db.freeAreas)
        .insert(
          FreeAreasCompanion.insert(
            id: id,
            layerId: layerId,
            label: Value(label),
            colorShade: Value(shade),
            zOrder: Value(z),
          ),
        );
    return id;
  }

  Future<void> updateFreeArea(
    String id, {
    String? layerId,
    double? offsetMeters,
    Value<String?> label = const Value.absent(),
  }) async {
    // Moving an element to another layer: the z it carried means nothing
    // there, so it takes a fresh slot on top — which is what moving something
    // into a layer means. Carrying the old number across would bury it under
    // whatever the target already held.
    final z = layerId == null ? null : await _nextZOrder('free_areas', layerId);
    await (_db.update(_db.freeAreas)..where((a) => a.id.equals(id))).write(
      FreeAreasCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        zOrder: z == null ? const Value.absent() : Value(z),
        offsetMeters: offsetMeters == null
            ? const Value.absent()
            : Value(offsetMeters),
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
    await _db
        .into(_db.freeAreaPoints)
        .insert(
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
      await _db
          .into(_db.freeAreaPoints)
          .insert(
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
    return (_db.update(
      _db.freeAreaPoints,
    )..where((p) => p.id.equals(id))).write(
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
      final a = await (_db.select(
        _db.freeAreaPoints,
      )..where((p) => p.id.equals(idA))).getSingle();
      final b = await (_db.select(
        _db.freeAreaPoints,
      )..where((p) => p.id.equals(idB))).getSingle();
      await (_db.update(_db.freeAreaPoints)..where((p) => p.id.equals(idA)))
          .write(FreeAreaPointsCompanion(sortOrder: Value(b.sortOrder)));
      await (_db.update(_db.freeAreaPoints)..where((p) => p.id.equals(idB)))
          .write(FreeAreaPointsCompanion(sortOrder: Value(a.sortOrder)));
    });
  }

  Future<int> _maxFreeAreaPointOrder(String freeAreaId) async {
    final max = _db.freeAreaPoints.sortOrder.max();
    final row =
        await (_db.selectOnly(_db.freeAreaPoints)
              ..addColumns([max])
              ..where(_db.freeAreaPoints.freeAreaId.equals(freeAreaId)))
            .getSingleOrNull();
    return row?.read(max) ?? -1;
  }

  // --- Height regions -------------------------------------------------------

  Stream<List<HeightRegion>> watchAllHeightRegions() {
    return (_db.select(_db.heightRegions)..orderBy([
          (t) => OrderingTerm(expression: t.zOrder),
          (t) => OrderingTerm(expression: t.createdAt),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  /// All generated height polygons across every region, ordered.
  Stream<List<HeightPolygon>> watchAllHeightPolygons() {
    return (_db.select(
      _db.heightPolygons,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).watch();
  }

  /// All height-polygon ring points across every polygon, ordered.
  Stream<List<HeightPolygonPoint>> watchAllHeightPolygonPoints() {
    return (_db.select(
      _db.heightPolygonPoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).watch();
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
    final z = await _nextZOrder('height_regions', layerId);
    await _db
        .into(_db.heightRegions)
        .insert(
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
            zOrder: Value(z),
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
  }) async {
    final geometryChanged =
        centerLat != null ||
        centerLng != null ||
        radiusMeters != null ||
        thresholdMeters != null ||
        aboveThreshold != null ||
        sampleZoom != null;
    // Moving an element to another layer: the z it carried means nothing
    // there, so it takes a fresh slot on top — which is what moving something
    // into a layer means. Carrying the old number across would bury it under
    // whatever the target already held.
    final z = layerId == null
        ? null
        : await _nextZOrder('height_regions', layerId);
    await (_db.update(_db.heightRegions)..where((r) => r.id.equals(id))).write(
      HeightRegionsCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        zOrder: z == null ? const Value.absent() : Value(z),
        centerLat: centerLat == null ? const Value.absent() : Value(centerLat),
        centerLng: centerLng == null ? const Value.absent() : Value(centerLng),
        radiusMeters: radiusMeters == null
            ? const Value.absent()
            : Value(radiusMeters),
        thresholdMeters: thresholdMeters == null
            ? const Value.absent()
            : Value(thresholdMeters),
        aboveThreshold: aboveThreshold == null
            ? const Value.absent()
            : Value(aboveThreshold),
        sampleZoom: sampleZoom == null
            ? const Value.absent()
            : Value(sampleZoom),
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
    String regionId,
    List<List<LatLng>> rings,
  ) async {
    await (_db.delete(
      _db.heightPolygons,
    )..where((p) => p.heightRegionId.equals(regionId))).go();
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

  /// The generated fill rings of one region, in stored order — the inverse of
  /// [replaceHeightPolygons]. Empty until the region has been generated (or
  /// when it is gone). Used by "Convert to freehand area", which needs the
  /// geometry rather than the summary row; the painter reads the grouped
  /// providers instead.
  Future<List<List<LatLng>>> heightRegionRings(String id) async {
    final polys =
        await (_db.select(_db.heightPolygons)
              ..where((p) => p.heightRegionId.equals(id))
              ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
            .get();
    if (polys.isEmpty) return const [];
    final pts =
        await (_db.select(_db.heightPolygonPoints)
              ..where((q) => q.polygonId.isIn([for (final p in polys) p.id]))
              ..orderBy([(q) => OrderingTerm(expression: q.sortOrder)]))
            .get();
    final byPoly = <String, List<LatLng>>{for (final p in polys) p.id: []};
    for (final q in pts) {
      byPoly[q.polygonId]!.add(LatLng(q.lat, q.lng));
    }
    return [for (final p in polys) byPoly[p.id]!];
  }

  // --- POI sets -------------------------------------------------------------

  Stream<List<PoiSet>> watchAllPoiSets() {
    return (_db.select(_db.poiSets)..orderBy([
          (t) => OrderingTerm(expression: t.zOrder),
          (t) => OrderingTerm(expression: t.createdAt),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  /// All stored POIs across every set, ordered by [PoiPoints.sortOrder].
  Stream<List<PoiPoint>> watchAllPoiPoints() {
    return (_db.select(
      _db.poiPoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).watch();
  }

  /// Creates a POI set of the given [source] on a `poi` layer and returns its
  /// id. What the set then holds depends on the kind (see [PoiSets.source]):
  ///
  /// * [kPoiSourceRadius] — [categoryKey] within [radiusMeters] of the centre;
  ///   the points go in via [fillPoiSet].
  /// * [kPoiSourceBox] — stations within [bbox] (`[south, west, north, east]`,
  ///   required) of the modes in [modeMask], shown per [visibleModeMask]; the
  ///   centre and radius passed are **ignored** and derived from the box, so a
  ///   caller cannot make the two disagree. Points via [fillPoiSet].
  /// * [kPoiSourceManual] — a hand-made category; pass the map centre and 0
  ///   for the three query columns (NOT NULL, meaningless here) and add points
  ///   with [addManualPoiPoint].
  ///
  /// **Every import is born pending** (`fetchedAt` null) — recorded *before*
  /// fetching, so a failure leaves something the user can come back to rather
  /// than a snackbar they missed. [fillPoiSet] marks it done.
  Future<String> createPoiSet({
    required String layerId,
    required String source,
    required String categoryKey,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    String? label,
    String? iconKey,
    List<double>? bbox,
    int modeMask = 0,
    int visibleModeMask = -1,
  }) async {
    if (source == kPoiSourceBox) {
      if (bbox == null || bbox.length != 4) {
        throw ArgumentError('A box import needs its box');
      }
      centerLat = (bbox[0] + bbox[2]) / 2;
      centerLng = (bbox[1] + bbox[3]) / 2;
      radiusMeters = boxCoveringRadiusMeters(
        south: bbox[0],
        west: bbox[1],
        north: bbox[2],
        east: bbox[3],
      );
    } else if (bbox != null) {
      throw ArgumentError('Only a box import has a box');
    }
    final id = _uuid.v4();
    final shade = await _nextColorShade('poi_sets', layerId);
    final z = await _nextZOrder('poi_sets', layerId);
    await _db
        .into(_db.poiSets)
        .insert(
          PoiSetsCompanion.insert(
            id: id,
            layerId: layerId,
            categoryKey: categoryKey,
            centerLat: centerLat,
            centerLng: centerLng,
            radiusMeters: radiusMeters,
            label: Value(label),
            colorShade: Value(shade),
            zOrder: Value(z),
            source: Value(source),
            iconKey: Value(iconKey),
            south: Value(bbox?[0]),
            west: Value(bbox?[1]),
            north: Value(bbox?[2]),
            east: Value(bbox?[3]),
            modeMask: Value(modeMask),
            visibleModeMask: Value(visibleModeMask),
          ),
        );
    return id;
  }

  /// Adds one hand-placed POI to a **manual** set, at the end of its order.
  ///
  /// Deliberately refuses an import: a fetched set is a record of what OSM
  /// returned over a given box, and a point someone dropped into it would make
  /// that record a lie — with no column able to say which rows were which.
  /// Hand-placed points carry no `osmType`/`osmId`, so they never take part in
  /// re-import dedup, which is the correct answer for geometry that has no
  /// upstream.
  Future<String> addManualPoiPoint({
    required String poiSetId,
    required double lat,
    required double lng,
    String? label,
  }) async {
    final set = await (_db.select(
      _db.poiSets,
    )..where((s) => s.id.equals(poiSetId))).getSingleOrNull();
    if (set == null) throw ArgumentError('That POI category no longer exists');
    if (!set.isManual) {
      throw ArgumentError(
        'That is an Overpass import — it records what OSM returned, so '
        'points cannot be added to it by hand',
      );
    }
    final next = await _db
        .customSelect(
          'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next '
          'FROM poi_points WHERE poi_set_id = ?',
          variables: [Variable<String>(poiSetId)],
        )
        .getSingle();
    final id = _uuid.v4();
    await _db
        .into(_db.poiPoints)
        .insert(
          PoiPointsCompanion.insert(
            id: id,
            poiSetId: poiSetId,
            lat: lat,
            lng: lng,
            name: Value(label),
            sortOrder: next.read<int>('next'),
          ),
        );
    return id;
  }

  /// Moves a POI — hand-placed or imported.
  ///
  /// An imported point's position used to be immutable: it is the fetched fact
  /// the layer exists to record, and moving one silently turned a record of
  /// where things are into a drawing of where you think they are. What makes
  /// it safe now is that the move is no longer silent. The first edit captures
  /// what the import returned ([PoiPoints.origLat]/[origLng]/[origName]) and
  /// stamps [PoiPoints.editedAt], so the row says out loud that it has forked
  /// from upstream — the same contract a reshaped border area lives under, and
  /// it matters for the same reason: the row keeps its `osmId`, so a later
  /// import over the same ground skips it and the edit wins over whatever OSM
  /// now says.
  ///
  /// The capture happens **once**. A second move does not overwrite the
  /// original with the first correction, or Revert would only ever walk back
  /// one step and the report would misstate what OSM has.
  ///
  /// A move that changes nothing does not fork — the same guard
  /// [reshapeBorderArea] uses, so a drag that ends where it started is not an
  /// edit.
  Future<void> movePoiPoint({
    required String id,
    required double lat,
    required double lng,
  }) async {
    final row = await _db
        .customSelect(
          'SELECT s.source AS source, p.lat AS lat, p.lng AS lng, '
          'p.name AS name, p.edited_at AS edited_at FROM poi_points p '
          'JOIN poi_sets s ON p.poi_set_id = s.id WHERE p.id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (row == null) return;
    if (row.read<double>('lat') == lat && row.read<double>('lng') == lng) {
      return;
    }
    final isManual = row.read<String>('source') == kPoiSourceManual;
    final forking = !isManual && row.read<DateTime?>('edited_at') == null;
    await (_db.update(_db.poiPoints)..where((p) => p.id.equals(id))).write(
      PoiPointsCompanion(
        lat: Value(lat),
        lng: Value(lng),
        editedAt: forking ? Value(DateTime.now()) : const Value.absent(),
        origLat: forking
            ? Value(row.read<double>('lat'))
            : const Value.absent(),
        origLng: forking
            ? Value(row.read<double>('lng'))
            : const Value.absent(),
        origName: forking
            ? Value(row.read<String?>('name'))
            : const Value.absent(),
      ),
    );
  }

  /// Puts an edited POI back to exactly what the import returned, and clears
  /// the fork.
  ///
  /// The counterpart to the capture in [movePoiPoint]: because a POI is three
  /// scalars rather than a 119 238-point ring, keeping the original costs
  /// nothing and an imported point — unlike a reshaped boundary — can simply
  /// be handed back. A no-op on a point that was never edited.
  Future<void> revertPoiPoint(String id) async {
    final row = await (_db.select(
      _db.poiPoints,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (row == null || row.editedAt == null) return;
    await (_db.update(_db.poiPoints)..where((p) => p.id.equals(id))).write(
      PoiPointsCompanion(
        lat: Value(row.origLat ?? row.lat),
        lng: Value(row.origLng ?? row.lng),
        name: Value(row.origName),
        editedAt: const Value(null),
        origLat: const Value(null),
        origLng: const Value(null),
        origName: const Value(null),
      ),
    );
  }

  /// Writes the fetched points into [poiSetId] and marks the import done.
  ///
  /// **Replaces** whatever the set held, so a retry after a failure is
  /// idempotent — and **skips any point this layer's *other* sets already
  /// hold** (see [ImportTally]). Scoped to the layer, not the set: overlapping
  /// imports land in *different* sets, which is exactly the case that used to
  /// draw the same café (or Pasing Bahnhof) twice. Two layers deliberately
  /// holding the same POIs is a legitimate thing to want, so it stays
  /// possible. The set's own previous rows are excluded from the check so a
  /// retry of the same box doesn't dedup against its own earlier attempt.
  ///
  /// One transaction, one batch — a city of stations is thousands of rows and
  /// must not be a loop of awaited inserts. Takes [PoiResult]s rather than a
  /// bare record: it is exactly what the importer already holds, and it keeps
  /// the OSM identity from having to be spelled out at every call site.
  Future<ImportTally> fillPoiSet(String poiSetId, List<PoiResult> pts) async {
    return _db.transaction(() async {
      await (_db.delete(
        _db.poiPoints,
      )..where((p) => p.poiSetId.equals(poiSetId))).go();
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
              modeMask: Value(keep[i].modeMask),
              // Only ever set when restoring a ZoneCraft file: a point that
              // was corrected by hand comes back still saying so, rather than
              // arriving as though OSM had always had it there. The timestamp
              // is new — the *fact* of the fork travels, not when it happened.
              editedAt: keep[i].origLat != null
                  ? Value(DateTime.now())
                  : const Value.absent(),
              origLat: Value(keep[i].origLat),
              origLng: Value(keep[i].origLng),
              origName: Value(keep[i].origName),
            ),
          );
        }
      });
      await (_db.update(
        _db.poiSets,
      )..where((t) => t.id.equals(poiSetId))).write(
        PoiSetsCompanion(
          fetchedAt: Value(DateTime.now()),
          lastError: const Value(null),
        ),
      );
      return ImportTally(added: keep.length, skipped: pts.length - keep.length);
    });
  }

  /// Every `type/id` held by the *other* sets of the layer owning [poiSetId].
  Future<Set<String>> _poiOsmKeysInLayerOf(String poiSetId) async {
    final layerId =
        await (_db.selectOnly(_db.poiSets)
              ..addColumns([_db.poiSets.layerId])
              ..where(_db.poiSets.id.equals(poiSetId)))
            .map((r) => r.read(_db.poiSets.layerId))
            .getSingleOrNull();
    if (layerId == null) return <String>{};
    final rows =
        await (_db.selectOnly(_db.poiPoints)
              ..addColumns([_db.poiPoints.osmType, _db.poiPoints.osmId])
              ..join([
                innerJoin(
                  _db.poiSets,
                  _db.poiSets.id.equalsExp(_db.poiPoints.poiSetId),
                ),
              ])
              ..where(
                _db.poiSets.layerId.equals(layerId) &
                    _db.poiSets.id.equals(poiSetId).not() &
                    _db.poiPoints.osmId.isNotNull(),
              ))
            .get();
    return {
      for (final r in rows)
        ?osmKey(r.read(_db.poiPoints.osmType), r.read(_db.poiPoints.osmId)),
    };
  }

  /// Records why an import didn't finish. The set stays, so the layer can offer
  /// a retry for exactly that query.
  Future<void> markPoiImportFailed(String setId, String message) {
    return (_db.update(_db.poiSets)..where((t) => t.id.equals(setId))).write(
      PoiSetsCompanion(lastError: Value(message)),
    );
  }

  /// Renames a POI set (or moves it to another `poi` layer). An import's query
  /// and its stored points are immutable — a different area means a new
  /// import.
  /// [categoryKey] and [iconKey] are only meaningful on a **manual** set — an
  /// import's category describes the query that ran — but this does not police
  /// that, because the only caller that passes them is the manual half of the
  /// editor, and a repository refusing a write it was asked to make is worse
  /// than a UI that never asks.
  Future<void> updatePoiSet(
    String id, {
    String? layerId,
    Value<String?> label = const Value.absent(),
    String? categoryKey,
    Value<String?> iconKey = const Value.absent(),
  }) async {
    // Moving an element to another layer: the z it carried means nothing
    // there, so it takes a fresh slot on top — which is what moving something
    // into a layer means. Carrying the old number across would bury it under
    // whatever the target already held.
    final z = layerId == null ? null : await _nextZOrder('poi_sets', layerId);
    await (_db.update(_db.poiSets)..where((s) => s.id.equals(id))).write(
      PoiSetsCompanion(
        layerId: layerId == null ? const Value.absent() : Value(layerId),
        zOrder: z == null ? const Value.absent() : Value(z),
        label: label,
        categoryKey: categoryKey == null
            ? const Value.absent()
            : Value(categoryKey),
        iconKey: iconKey,
      ),
    );
  }

  /// Which transit modes a station import shows — what the filter sheet
  /// writes. One batch, so toggling a mode is a single write and a single
  /// stream emission.
  Future<void> setPoiVisibleModes(
    Iterable<String> setIds,
    int visibleModeMask,
  ) async {
    final ids = setIds.toList();
    if (ids.isEmpty) return;
    await _db.batch((b) {
      b.update(
        _db.poiSets,
        PoiSetsCompanion(visibleModeMask: Value(visibleModeMask)),
        where: (t) => t.id.isIn(ids),
      );
    });
  }

  Future<void> deletePoiSet(String id) {
    return (_db.delete(_db.poiSets)..where((s) => s.id.equals(id))).go();
  }

  /// Renames one stored POI.
  ///
  /// Renaming an imported point forks it from upstream exactly as moving one
  /// does, and is recorded the same way — see [movePoiPoint] for why. It was
  /// possible long before [PoiPoints.editedAt] existed and was simply never
  /// recorded, which is the case this closes: a locally renamed POI keeps its
  /// `osmId`, so nothing downstream could tell the new name from OSM's.
  ///
  /// A station's **mode bits** remain untouchable. They are a lossy
  /// re-encoding of tags this app never stored, so there is no correction to
  /// be made here that could be stated honestly to anyone.
  Future<void> updatePoiPoint(String id, {required Value<String?> name}) async {
    final row = await (_db.select(
      _db.poiPoints,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final next = name.present ? name.value : row.name;
    if (next == row.name) return;
    final set = await (_db.select(
      _db.poiSets,
    )..where((s) => s.id.equals(row.poiSetId))).getSingleOrNull();
    final forking = set != null && !set.isManual && row.editedAt == null;
    await (_db.update(_db.poiPoints)..where((p) => p.id.equals(id))).write(
      PoiPointsCompanion(
        name: name,
        editedAt: forking ? Value(DateTime.now()) : const Value.absent(),
        origLat: forking ? Value(row.lat) : const Value.absent(),
        origLng: forking ? Value(row.lng) : const Value.absent(),
        origName: forking ? Value(row.name) : const Value.absent(),
      ),
    );
  }

  /// Removes one stored POI — curating an import down to what you want, without
  /// throwing away the whole set. Its `sort_order` gap is harmless: the order
  /// only has to be *stable*, and the remaining rows keep theirs.
  ///
  /// The POI keeps its OSM identity right up to the delete, so re-importing the
  /// same ground brings it back. That is the honest behaviour — the row was a
  /// copy of something upstream, and the upstream copy is still there.
  Future<void> deletePoiPoint(String id) {
    return (_db.delete(_db.poiPoints)..where((p) => p.id.equals(id))).go();
  }

  // --- OSM reports (the outbox) ---------------------------------------------

  /// Every report, newest first — the outbox screen's whole data source.
  Stream<List<OsmReport>> watchOsmReports() {
    return (_db.select(
      _db.osmReports,
    )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).watch();
  }

  /// Stores a composed report. **Storing is not sending**: the row starts with
  /// [OsmReports.sentAt] null and stays that way until somebody presses Send.
  Future<String> createOsmReport({
    required double lat,
    required double lng,
    required String kind,
    required String body,
    String? osmType,
    int? osmId,
    String? poiPointId,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.osmReports)
        .insert(
          OsmReportsCompanion.insert(
            id: id,
            lat: lat,
            lng: lng,
            kind: kind,
            body: body,
            osmType: Value(osmType),
            osmId: Value(osmId),
            poiPointId: Value(poiPointId),
          ),
        );
    return id;
  }

  /// Lets a draft be corrected before it is sent. Refuses to touch a report
  /// that has already gone: the note on OSM would no longer match, and the row
  /// is a record of what was said, not a place to keep revising it.
  Future<void> updateOsmReport(String id, {required String body}) async {
    await (_db.update(_db.osmReports)
          ..where((r) => r.id.equals(id) & r.sentAt.isNull()))
        .write(OsmReportsCompanion(body: Value(body)));
  }

  /// Records that OSM accepted the note, clearing any earlier failure.
  Future<void> markOsmReportSent(String id, int noteId) {
    return (_db.update(_db.osmReports)..where((r) => r.id.equals(id))).write(
      OsmReportsCompanion(
        sentAt: Value(DateTime.now()),
        noteId: Value(noteId),
        lastError: const Value(null),
      ),
    );
  }

  /// Leaves the row in the outbox with the reason attached, so it can present
  /// itself as a retry — the same shape a failed import's row has.
  Future<void> markOsmReportFailed(String id, String message) {
    return (_db.update(_db.osmReports)..where((r) => r.id.equals(id))).write(
      OsmReportsCompanion(lastError: Value(message)),
    );
  }

  Future<void> deleteOsmReport(String id) {
    return (_db.delete(_db.osmReports)..where((r) => r.id.equals(id))).go();
  }

  /// How many notes have actually reached OSM in the last [window].
  ///
  /// Read by the report sheet to hold itself back: osm.org's own form warns
  /// after five anonymous notes in a day and stops offering itself after ten,
  /// and an app that ignored that would earn the blanket block the API usage
  /// policy promises. Counts **sent** rows only — drafts sitting in the outbox
  /// have cost nobody anything.
  Future<int> osmReportsSentSince(Duration window) async {
    final since = DateTime.now().subtract(window);
    final rows = await (_db.select(
      _db.osmReports,
    )..where((r) => r.sentAt.isBiggerThanValue(since))).get();
    return rows.length;
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
  /// Unlike a POI import there is no pending row — a border import that
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
    required List<
      ({
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
      })
    >
    areas,
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
      tally = ImportTally(
        added: keep.length,
        skipped: areas.length - keep.length,
      );
      // The set is written even when nothing survived: it records the box that
      // was fetched, and an empty one is invisible (Elements lists *areas*).
      await _db
          .into(_db.borderSets)
          .insert(
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
    final rows =
        await (_db.selectOnly(_db.borderAreas)
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
      for (final r in rows) ?osmKey('relation', r.read(_db.borderAreas.osmId)),
    };
  }

  /// Recomputes every area colour in [layerId] so no two areas sharing a border
  /// match.
  ///
  /// Runs over the **whole layer**, not one import, which is what keeps two
  /// overlapping imports from clashing along their seam — and why it has to run
  /// again after a set is deleted, when a constraint has gone away.
  Future<void> recolourBorderLayer(String layerId) async {
    final setIds =
        await (_db.selectOnly(_db.borderSets)
              ..addColumns([_db.borderSets.id])
              ..where(_db.borderSets.layerId.equals(layerId)))
            .map((r) => r.read(_db.borderSets.id)!)
            .get();
    if (setIds.isEmpty) return;
    final areas = await (_db.select(
      _db.borderAreas,
    )..where((a) => a.setId.isIn(setIds))).get();
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
      // A corrupt row costs a colour, not the map, however it is corrupt.
      // ignore: avoid_catches_without_on_clauses
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
    double? labelLat,
    double? labelLng,
  }) async {
    await (_db.update(_db.borderAreas)..where((a) => a.id.equals(id))).write(
      BorderAreasCompanion(
        name: name,
        labelLat: labelLat == null ? const Value.absent() : Value(labelLat),
        labelLng: labelLng == null ? const Value.absent() : Value(labelLng),
      ),
    );
  }

  /// Replaces one area's outline with [rings] and marks it as **reshaped by
  /// hand** (v23).
  ///
  /// The denormalised bounds and point count are recomputed here rather than
  /// left to the caller: the painter culls on the bounds, so an outline dragged
  /// outside its stored box would vanish at exactly the zoom where you were
  /// working on it.
  ///
  /// Refuses geometry that has no fillable ring left — a reshape that empties
  /// an area is a slip, not an intention, and the row would then draw nothing
  /// with no way back.
  ///
  /// Moving the name plate is deliberately **not** routed through here: an
  /// anchor is presentation, and flagging it as a fork of OSM geometry would
  /// make the marker meaningless.
  ///
  /// An outline that comes back **identical** is not a reshape and is not
  /// stamped. Every completed drag commits, including one that ends where it
  /// started, and a snapshot wrongly labelled "no longer what OSM says" is the
  /// one thing this flag exists to get right.
  Future<bool> reshapeBorderArea(String id, List<List<LatLng>> rings) async {
    final usable = [
      for (final r in rings)
        if (r.length >= 3) r,
    ];
    if (usable.isEmpty) return false;
    var south = 90.0, west = 180.0, north = -90.0, east = -180.0;
    var points = 0;
    for (final r in usable) {
      points += r.length;
      for (final p in r) {
        if (!p.latitude.isFinite || !p.longitude.isFinite) return false;
        if (p.latitude < south) south = p.latitude;
        if (p.latitude > north) north = p.latitude;
        if (p.longitude < west) west = p.longitude;
        if (p.longitude > east) east = p.longitude;
      }
    }
    final area = await (_db.select(
      _db.borderAreas,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (area == null) return false;
    final encoded = encodeRings(usable);
    if (encoded == area.rings) return true; // nothing moved; stay untouched
    await (_db.update(_db.borderAreas)..where((a) => a.id.equals(id))).write(
      BorderAreasCompanion(
        rings: Value(encoded),
        south: Value(south),
        west: Value(west),
        north: Value(north),
        east: Value(east),
        pointCount: Value(points),
        editedAt: Value(DateTime.now()),
      ),
    );
    return true;
  }

  /// Deletes one imported area, then recolours what is left of its layer.
  Future<void> deleteBorderArea(String id) async {
    final area = await (_db.select(
      _db.borderAreas,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (area == null) return;
    final set = await (_db.select(
      _db.borderSets,
    )..where((s) => s.id.equals(area.setId))).getSingleOrNull();
    await (_db.delete(_db.borderAreas)..where((a) => a.id.equals(id))).go();
    if (set != null) await recolourBorderLayer(set.layerId);
  }

  /// The decoded rings of one area, or empty when it is gone. Used by the
  /// "convert to freehand area" action, which needs the geometry rather than
  /// the summary row.
  Future<List<List<LatLng>>> borderAreaRings(String id) async {
    final area = await (_db.select(
      _db.borderAreas,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    return area == null ? const [] : decodeRings(area.rings);
  }

  /// Deletes an import and recolours what is left: removing a set removes
  /// adjacency constraints, and leaving the old colours would keep an
  /// unnecessary clash on screen.
  Future<void> deleteBorderSet(String id) async {
    final set = await (_db.select(
      _db.borderSets,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
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
        borderFillAreas: fillAreas == null
            ? const Value.absent()
            : Value(fillAreas),
        borderShowNames: showNames == null
            ? const Value.absent()
            : Value(showNames),
      ),
    );
  }

  // --- Settings -------------------------------------------------------------

  /// Watches the single settings row, emitting defaults when it doesn't exist
  /// yet (so callers never have to seed it before reading).
  Stream<AppSetting> watchSettings() {
    return (_db.select(
      _db.appSettings,
    )..where((s) => s.id.equals(1))).watch().map(
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
              hintsEnabled: true,
            )
          : rows.first,
    );
  }

  /// Upserts the global uncertainty (metres) into the single settings row.
  Future<void> updateUncertainty(double meters) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            uncertaintyMeters: Value(meters),
          ),
        );
  }

  /// Remembers which Overpass instance last served an import (POI or
  /// borders), so the next one starts with the one that was actually up rather
  /// than at whichever is currently swamped.
  Future<void> updateTransitEndpoint(String endpoint) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            transitEndpoint: Value(endpoint),
          ),
        );
  }

  /// Upserts one of the three service overrides. A blank string clears it back
  /// to the built-in default, which is what an emptied text field means.
  ///
  /// `Value(null)` and "leave alone" are different companion states, so each
  /// setter names exactly the column it owns and nothing else moves.
  Future<void> updateServiceOverride(ServiceOverride which, String? value) {
    final v = Value(
      value == null || value.trim().isEmpty ? null : value.trim(),
    );
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            tileUrlOverride: which == ServiceOverride.tiles
                ? v
                : const Value.absent(),
            overpassEndpointOverride: which == ServiceOverride.overpass
                ? v
                : const Value.absent(),
            nominatimHostOverride: which == ServiceOverride.nominatim
                ? v
                : const Value.absent(),
          ),
        );
  }

  /// Records that the tip [key] was shown, and says whether it should be.
  ///
  /// Returns true at most [limit] times per key, and false for ever after. The
  /// count is only spent on a tip that was actually *shown*: when hints are
  /// switched off this answers false without touching it, so turning them back
  /// on resumes where the user left off rather than finding them silently used
  /// up by months of pressing the button.
  ///
  /// Read-modify-write in one transaction, because two taps in the same frame
  /// would otherwise both read the same count and show one tip too many.
  Future<bool> noteHintShown(String key, {int limit = 3}) {
    return _db.transaction(() async {
      final settings = await (_db.select(
        _db.appSettings,
      )..where((s) => s.id.equals(1))).getSingleOrNull();
      // No row yet means a fresh install, which is the case tips are *for*.
      if (settings != null && !settings.hintsEnabled) return false;

      final row = await (_db.select(
        _db.uiHints,
      )..where((h) => h.key.equals(key))).getSingleOrNull();
      final shown = row?.shownCount ?? 0;
      if (shown >= limit) return false;
      await _db
          .into(_db.uiHints)
          .insertOnConflictUpdate(
            UiHintsCompanion.insert(key: key, shownCount: Value(shown + 1)),
          );
      return true;
    });
  }

  /// Turns the button explanations on or off for good — the *stop now* answer,
  /// for someone who does not want to wait out the remaining showings.
  Future<void> updateHintsEnabled({required bool enabled}) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            hintsEnabled: Value(enabled),
          ),
        );
  }

  /// Forgets every tip and switches them back on: the app teaches from scratch.
  /// For a user coming back after a long time, or showing it to somebody else.
  Future<void> resetHints() async {
    await _db.delete(_db.uiHints).go();
    await updateHintsEnabled(enabled: true);
  }

  /// Upserts the utility-FAB expand/collapse choice into the settings row.
  Future<void> updateToolsExpanded({required bool expanded}) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            toolsExpanded: Value(expanded),
          ),
        );
  }

  /// Upserts the base-map visibility toggle into the single settings row.
  Future<void> updateBasemapVisible({required bool visible}) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            basemapVisible: Value(visible),
          ),
        );
  }

  /// Upserts the base-map opacity (0–1) into the single settings row.
  Future<void> updateBasemapOpacity(double opacity) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            basemapOpacity: Value(opacity),
          ),
        );
  }

  /// Persists the last map camera so the app reopens on the same view.
  Future<void> saveCamera(double lat, double lng, double zoom) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(1),
            lastLat: Value(lat),
            lastLng: Value(lng),
            lastZoom: Value(zoom),
          ),
        );
  }

  // --- Tile cache -----------------------------------------------------------

  /// How stale a tile's `lastUsedAt` has to be before serving it writes a new
  /// one.
  ///
  /// This is the whole fix for a read that wrote. `getTile` used to `UPDATE`
  /// on **every** tile it served, so a pan across the map — dozens of tiles a
  /// second, most of them re-served seconds apart — became dozens of write
  /// transactions a second, all on the single sqlite3 connection the whole app
  /// shares (`database.dart` explains why there is only one), competing with
  /// the queries that were drawing the map.
  ///
  /// Five minutes, and the number was argued down from an hour for a reason
  /// worth keeping. The write is what makes a tile survive eviction, so the
  /// interval is exactly how stale the recency order is allowed to be. At an
  /// hour, a user who looks at one city, then another, then comes back to the
  /// first is served those tiles from cache **without** re-stamping them — so
  /// when the cap is hit they are evicted as "old" while on screen, and
  /// re-downloaded. That is precisely the cost the cache exists to avoid.
  ///
  /// Five minutes keeps recency accurate enough that whatever is on screen is
  /// never the oldest thing in the table, and still collapses the case the
  /// amplification actually came from: panning back and forth over an area
  /// already cached, where every tile load is a hit and used to be a write.
  static const int tileTouchIntervalMs = 5 * 60 * 1000;

  /// Returns the cached bytes for [url], or null if the tile isn't cached.
  ///
  /// Bumps the tile's last-used time so eviction keeps it — but at most once
  /// per [tileTouchIntervalMs]. See there for why.
  Future<Uint8List?> getTile(String url) async {
    final row = await (_db.select(
      _db.tileCache,
    )..where((t) => t.url.equals(url))).getSingleOrNull();
    if (row == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - row.lastUsedAt >= tileTouchIntervalMs) {
      await (_db.update(_db.tileCache)..where((t) => t.url.equals(url))).write(
        TileCacheCompanion(lastUsedAt: Value(now)),
      );
    }
    return row.bytes;
  }

  /// Inserts/updates the cached bytes for [url].
  Future<void> putTile(String url, Uint8List bytes, {String? etag}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db
        .into(_db.tileCache)
        .insertOnConflictUpdate(
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
    final row =
        await (_db.selectOnly(_db.tileCache)
              ..addColumns([_db.tileCache.url])
              ..where(_db.tileCache.url.equals(url))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Total bytes currently held in the tile cache (for the Settings readout).
  Future<int> tileCacheBytes() async {
    final sum = _db.tileCache.sizeBytes.sum();
    final row = await (_db.selectOnly(
      _db.tileCache,
    )..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  /// The eviction currently running, if any. See [evictTilesDownTo].
  Future<void>? _evicting;

  /// Evicts least-recently-used tiles until the cache total is at or below
  /// [maxBytes]. Cheap no-op when already under the cap.
  ///
  /// **Coalesced**, because the caller is `CachedTileProvider`'s unawaited
  /// write-back: one per tile stored, so a pan on a cold cache starts dozens
  /// of these at once.
  ///
  /// Be accurate about what that fixes, because the audit note this answers
  /// overstated it. Concurrent runs did **not** over-evict in practice: they
  /// all read the same total, then all selected the same oldest rows, so the
  /// redundant `DELETE ... WHERE url IN (...)` statements hit rows that were
  /// already gone and did nothing. That is what "harmless and self-correcting"
  /// meant, and it was right.
  ///
  /// What they did do is the same full `SUM(size_bytes)` scan and the same
  /// delete, dozens of times over, on the single sqlite3 connection the whole
  /// app shares — during a pan, which is when that connection is also trying
  /// to draw the map. Callers arriving while a run is in flight now join it.
  ///
  /// The second change is the one that removes the *correctness* risk rather
  /// than the waste: the loop re-reads the total each pass instead of
  /// decrementing a number taken once at the start, so tiles written while an
  /// eviction runs are counted, and it stops at the cap rather than past it.
  ///
  /// **A joined caller inherits the running call's [maxBytes].** That is safe
  /// only because all three call sites pass the same
  /// `CachedTileProvider.maxCacheBytes` — the tile cache has one cap, not one
  /// per caller. A caller wanting a *stricter* cap would silently get the
  /// looser one; if that ever becomes a real case, this needs to remember the
  /// in-flight target and chain a second run rather than join.
  Future<void> evictTilesDownTo(int maxBytes) {
    return _evicting ??= _evictTilesDownTo(
      maxBytes,
    ).whenComplete(() => _evicting = null);
  }

  Future<void> _evictTilesDownTo(int maxBytes) async {
    // The total is re-read each pass rather than decremented locally: tiles
    // are still being written while this runs, so a number taken once at the
    // start is wrong by the end — in the direction that deletes too much.
    while (true) {
      final total = await tileCacheBytes();
      if (total <= maxBytes) return;

      // Oldest first, in batches, so a large eviction is not one enormous
      // statement.
      final batch =
          await (_db.select(_db.tileCache)
                ..orderBy([(t) => OrderingTerm(expression: t.lastUsedAt)])
                ..limit(64))
              .get();
      if (batch.isEmpty) return;

      var running = total;
      final urls = <String>[];
      for (final row in batch) {
        urls.add(row.url);
        running -= row.sizeBytes;
        if (running <= maxBytes) break;
      }
      await (_db.delete(_db.tileCache)..where((t) => t.url.isIn(urls))).go();
    }
  }

  /// Empties the tile cache (the Settings "Clear cached map tiles" button).
  ///
  /// The `VACUUM` is the point. Deleting the rows returns their pages to
  /// SQLite's own freelist and leaves the file exactly as large as it was — so
  /// the Settings readout (a `SUM(size_bytes)`) dropped to 0 B, the snackbar
  /// said the cache was cleared, and Android's Storage screen went on showing
  /// the same few hundred megabytes. A user low on space, who pressed the
  /// button *because* they were low on space, was told a thing that was not
  /// true. It runs on drift's background isolate like every other statement
  /// here, so a long vacuum does not block a frame.
  Future<void> clearTileCache() async {
    await _db.delete(_db.tileCache).go();
    await _db.customStatement('VACUUM');
  }

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

  /// Wipes all user data: deletes every layer (cascading to its elements),
  /// resets settings to defaults (uncertainty 500, camera null) by dropping the
  /// settings row, then re-seeds an empty default layer. Used by the Settings
  /// "Clear all data" button. Returns the id of the freshly seeded layer. The
  /// tile cache is left intact (it's not user data — it has its own button).
  Future<String> clearAll() async {
    // Deliberately not undoable, and deliberately journalled off while it runs:
    // a wipe is a wipe, and recording one would copy the entire database into
    // the in-memory log purely to throw it away a moment later.
    final id = await _db.undo.suspended(() async {
      await _db.delete(_db.layers).go(); // cascades to every element table
      await _db
          .delete(_db.appSettings)
          .go(); // reverts to column defaults on read
      await _db.delete(_db.overpassCache).go(); // persisted POI/border overlays
      // The outbox goes too. It holds free text the user typed, so leaving it
      // behind would make "clear all data" untrue in the one place that
      // matters most — and the dialog says so before it runs. Notes already
      // delivered are on OSM's servers and no local delete reaches them; what
      // goes is this device's record of them.
      await _db.delete(_db.osmReports).go();
      return ensureDefaultLayer();
    });
    await _db.undo.clear();
    return id;
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
    // Only the folders the exported layers actually name: a per-layer export
    // of a layer at the root carries none, and a map with no folders writes a
    // file identical to what it wrote before folders existed.
    final allFolders = await (_db.select(
      _db.folders,
    )..orderBy([(f) => OrderingTerm(expression: f.sortOrder)])).get();
    final namedFolders = {for (final l in layers) ?l.folderId};
    final folders = [
      for (final f in allFolders)
        if (namedFolders.contains(f.id))
          ExportFolder(
            name: f.name,
            isVisible: f.isVisible ? null : false,
            isInverted: f.isInverted ? true : null,
          ),
    ];
    final folderNames = {for (final f in allFolders) f.id: f.name};
    final circles =
        await (_db.select(_db.circles)..orderBy([
              (t) => OrderingTerm(expression: t.zOrder),
              (t) => OrderingTerm(expression: t.createdAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    final subspaces =
        await (_db.select(_db.subspaces)..orderBy([
              (t) => OrderingTerm(expression: t.zOrder),
              (t) => OrderingTerm(expression: t.createdAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    final subPoints = await (_db.select(
      _db.subspacePoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
    final freeLines =
        await (_db.select(_db.freeLines)..orderBy([
              (t) => OrderingTerm(expression: t.zOrder),
              (t) => OrderingTerm(expression: t.createdAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    final flPoints = await (_db.select(
      _db.freeLinePoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
    final freeAreas =
        await (_db.select(_db.freeAreas)..orderBy([
              (t) => OrderingTerm(expression: t.zOrder),
              (t) => OrderingTerm(expression: t.createdAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    final faPoints = await (_db.select(
      _db.freeAreaPoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
    final heightRegions =
        await (_db.select(_db.heightRegions)..orderBy([
              (t) => OrderingTerm(expression: t.zOrder),
              (t) => OrderingTerm(expression: t.createdAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    final heightPolygons = await (_db.select(
      _db.heightPolygons,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
    final heightPolygonPoints = await (_db.select(
      _db.heightPolygonPoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
    final poiSets =
        await (_db.select(_db.poiSets)..orderBy([
              (t) => OrderingTerm(expression: t.zOrder),
              (t) => OrderingTerm(expression: t.createdAt),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    final poiPoints = await (_db.select(
      _db.poiPoints,
    )..orderBy([(p) => OrderingTerm(expression: p.sortOrder)])).get();
    // Border geometry is scoped to the layers being exported, unlike every
    // table above: one state boundary is a ~3 MB ring blob, so pulling every
    // area in the database to export one layer would be the biggest read the
    // app makes, for nothing.
    final layerIds = [for (final l in layers) l.id];
    final borderSets = await (_db.select(
      _db.borderSets,
    )..where((s) => s.layerId.isIn(layerIds))).get();
    final borderAreas = borderSets.isEmpty
        ? <BorderArea>[]
        : await (_db.select(
                _db.borderAreas,
              )..where((a) => a.setId.isIn([for (final s in borderSets) s.id])))
              .get();

    // The generated height fills, grouped region -> rings in one pass each.
    // A scan per region inside the layer loop would be O(regions x vertices),
    // and a generated region carries thousands of them.
    final ringOfPolygon = <String, List<LatLng>>{};
    for (final p in heightPolygonPoints) {
      (ringOfPolygon[p.polygonId] ??= <LatLng>[]).add(LatLng(p.lat, p.lng));
    }
    final fillsOfRegion = <String, List<List<LatLng>>>{};
    for (final poly in heightPolygons) {
      final ring = ringOfPolygon[poly.id];
      if (ring == null || ring.length < 3) continue;
      (fillsOfRegion[poly.heightRegionId] ??= <List<LatLng>>[]).add(ring);
    }

    final out = <ExportLayer>[];
    for (final layer in layers) {
      final objects = <ExportObject>[];
      // Each of the layer's types is collected in turn; a
      // single-type layer runs exactly one pass, doing what it always did.
      // The bodies already filter by `layer.id`, so nothing else changes.
      for (final type in layerContentTypes(layer)) {
        switch (type) {
          case 'circles':
            for (final c in circles.where((c) => c.layerId == layer.id)) {
              objects.add(
                ExportObject(
                  kind: 'circle',
                  coords: [LatLng(c.centerLat, c.centerLng)],
                  radiusMeters: c.radiusMeters,
                  label: c.label,
                  colorArgb: c.colorArgb,
                ),
              );
            }
          case 'subspace':
            for (final s in subspaces.where((s) => s.layerId == layer.id)) {
              final pts = subPoints.where((p) => p.subspaceId == s.id).toList();
              if (pts.isEmpty) continue;
              var mainIndex = pts.indexWhere((p) => p.isMain);
              if (mainIndex < 0) mainIndex = 0;
              objects.add(
                ExportObject(
                  kind: 'subspace',
                  coords: [for (final p in pts) LatLng(p.lat, p.lng)],
                  mainIndex: mainIndex,
                  // Only when one is actually named — a list of nulls is bulk.
                  pointLabels: pts.any((p) => p.label != null)
                      ? [for (final p in pts) p.label]
                      : null,
                  label: s.label,
                  colorArgb: s.colorArgb,
                ),
              );
            }
          case 'freeline':
            for (final l in freeLines.where((l) => l.layerId == layer.id)) {
              final pts = flPoints.where((p) => p.freeLineId == l.id).toList();
              // A point-less row has no geometry to write, and the encoders read
              // `coords.first` — the same guard subspace already makes.
              if (pts.isEmpty) continue;
              objects.add(
                ExportObject(
                  kind: 'freeline',
                  coords: [for (final p in pts) LatLng(p.lat, p.lng)],
                  offsetMeters: l.offsetMeters,
                  inclusionLat: l.inclusionLat,
                  inclusionLng: l.inclusionLng,
                  inclusionRadiusMeters: l.inclusionRadiusMeters,
                  label: l.label,
                  colorArgb: l.colorArgb,
                ),
              );
            }
          case 'freearea':
            for (final a in freeAreas.where((a) => a.layerId == layer.id)) {
              final pts = faPoints.where((p) => p.freeAreaId == a.id).toList();
              if (pts.isEmpty) continue;
              objects.add(
                ExportObject(
                  kind: 'freearea',
                  coords: [for (final p in pts) LatLng(p.lat, p.lng)],
                  offsetMeters: a.offsetMeters,
                  label: a.label,
                  colorArgb: a.colorArgb,
                ),
              );
            }
          case 'height':
            for (final r in heightRegions.where((r) => r.layerId == layer.id)) {
              objects.add(
                ExportObject(
                  kind: 'height',
                  coords: [LatLng(r.centerLat, r.centerLng)],
                  radiusMeters: r.radiusMeters,
                  thresholdMeters: r.thresholdMeters,
                  aboveThreshold: r.aboveThreshold,
                  sampleZoom: r.sampleZoom,
                  // The fills are derived from terrain tiles, but regenerating
                  // them needs the network and can disagree with what the sender
                  // saw — so a generated region travels drawn. An ungenerated one
                  // carries neither key and still imports as ungenerated.
                  generated: r.generatedAt == null ? null : true,
                  heightRings: r.generatedAt == null
                      ? null
                      : (fillsOfRegion[r.id] ?? const <List<LatLng>>[]),
                  label: r.label,
                  colorArgb: r.colorArgb,
                ),
              );
            }
          case 'poi':
            // coords[0] is the set's centre (the box centre for a station
            // import); coords[1..] are the points themselves, with their names
            // in [ExportObject.pointLabels]. One object per *set*: an import
            // that never succeeded has no points but is still a row on the
            // layer — a retry the user can press — so it travels as an empty
            // one rather than vanishing.
            for (final s in poiSets.where((s) => s.layerId == layer.id)) {
              final pts = poiPoints.where((p) => p.poiSetId == s.id).toList();
              // The OSM identity of each POI travels too: it is what dedup
              // matches on, so without it a later import over the same ground
              // draws every one of them a second time. Written only when at
              // least one POI has it (rows from before v21 never did).
              final identified = pts.any((p) => p.osmId != null);
              final corrected = pts.any((p) => p.editedAt != null);
              final box = s.isStationImport;
              objects.add(
                ExportObject(
                  kind: 'poi',
                  coords: [
                    LatLng(s.centerLat, s.centerLng),
                    for (final p in pts) LatLng(p.lat, p.lng),
                  ],
                  // A box set's radius is derived from its box on the way back
                  // in; writing it would be a second formula to keep equal.
                  radiusMeters: box ? null : s.radiusMeters,
                  categoryKey: s.categoryKey,
                  pointLabels: [for (final p in pts) p.name],
                  pointOsmIds: identified
                      ? [for (final p in pts) p.osmId ?? 0]
                      : null,
                  pointOsmTypes: identified
                      ? [for (final p in pts) p.osmType]
                      : null,
                  // What OSM said, for the points somebody has since corrected.
                  // Written only when the set holds at least one — so an import
                  // nobody touched exports byte-for-byte as it did before v31,
                  // and a corrected one cannot arrive elsewhere pretending to be
                  // what OSM returned.
                  pointOrigLat: corrected
                      ? [for (final p in pts) p.origLat]
                      : null,
                  pointOrigLng: corrected
                      ? [for (final p in pts) p.origLng]
                      : null,
                  pointOrigNames: corrected
                      ? [for (final p in pts) p.origName]
                      : null,
                  // Only a station import carries mode bits; every other kind
                  // would write a list of zeros.
                  pointModeMasks: box && pts.isNotEmpty
                      ? [for (final p in pts) p.modeMask]
                      : null,
                  // Written only for a hand-made category, so an ordinary import's
                  // GeoJSON is byte-for-byte what it was before v25.
                  manual: s.isManual ? true : null,
                  iconKey: s.iconKey,
                  bbox: s.bbox,
                  modeMask: box ? s.modeMask : null,
                  visibleModeMask: box ? s.visibleModeMask : null,
                  pending: s.isPending ? true : null,
                  errorMessage: s.lastError,
                  label: s.label,
                  colorArgb: s.colorArgb,
                ),
              );
            }
          case 'borders':
            // One object per **area**, which is what the Elements list names and
            // what a person would say they are handing over. The import it came
            // from rides along as `adminLevel` + `bbox`, so the areas regroup
            // into the same sets on the far side instead of collapsing into one.
            for (final s in borderSets.where((s) => s.layerId == layer.id)) {
              for (final a in borderAreas.where((a) => a.setId == s.id)) {
                final rings = decodeRings(a.rings);
                if (rings.isEmpty) continue;
                objects.add(
                  ExportObject(
                    kind: 'borderarea',
                    coords: rings.first,
                    rings: rings,
                    label: a.name,
                    // 0 is the "no relation id" placeholder an id-less import was
                    // stored with; writing it out would make every such area look
                    // like the same OSM relation, and dedup would keep one.
                    osmId: a.osmId == 0 ? null : a.osmId,
                    adminLevel: s.adminLevel,
                    setLabel: s.label,
                    bbox: [s.south, s.west, s.north, s.east],
                    colorIndex: a.colorIndex,
                    labelLat: a.labelLat,
                    labelLng: a.labelLng,
                    wayIds: _decodeWayIds(a.wayIds),
                    edited: a.editedAt == null ? null : true,
                    colorArgb: a.colorArgb,
                  ),
                );
              }
            }
        }
      }
      out.add(
        ExportLayer(
          name: layer.name,
          colorArgb: layer.colorArgb,
          type: layer.type,
          isInverted: layer.isInverted,
          opacity: layer.opacity,
          // Only a borders layer has these; every other type carries the column
          // defaults, and writing them would put meaningless keys in the file.
          borderLevel: layer.borderLevel,
          borderFillAreas: layer.type == 'borders'
              ? layer.borderFillAreas
              : null,
          borderShowNames: layer.type == 'borders'
              ? layer.borderShowNames
              : null,
          // Only a hidden layer writes the key; shown is the default everywhere.
          isVisible: layer.isVisible ? null : false,
          folderName: folderNames[layer.folderId],
          objects: objects,
        ),
      );
    }
    return ExportData(out, folders: folders);
  }

  /// Writes [data] into **new** layers (never merges), preserving order, colour,
  /// type, invert and per-object attributes. Returns the number of objects
  /// created. Objects with unusable geometry (e.g. a non-positive circle radius)
  /// are skipped.
  ///
  /// [simplify] RDP-thins imported line and ring geometry at
  /// [kImportSimplifyMeters]. It belongs to *generic* files — a GPX full of GPS
  /// jitter, a thousand-point city outline — and must be **off** for our own
  /// GeoJSON: thinning what this app itself wrote changes the shape on every
  /// round-trip, so an export/import is not the identity it looks like. It
  /// defaults to on so every generic call site keeps its behaviour.
  Future<int> importData(ExportData data, {bool simplify = true}) {
    // One file, one undo step — however many hundreds of rows it lands, and
    // however long the layer-by-layer loop takes.
    return _db.undo.group('Import', () => _importData(data, simplify));
  }

  Future<int> _importData(ExportData data, bool simplify) async {
    var imported = 0;
    // The folders first, so a layer can name one as it is created. Matched by
    // name, which is all a file carries — and a name that clashes with a
    // folder already on the map joins it rather than making a second one with
    // the same name, which is what anyone reading the drawer would expect.
    final existing = {for (final f in await watchFolders().first) f.name: f.id};
    final folderIds = <String, String>{};
    for (final f in data.folders) {
      final id = existing[f.name] ?? await createFolder(name: f.name);
      folderIds[f.name] = id;
      if (existing[f.name] == null &&
          (f.isVisible == false || f.isInverted == true)) {
        await updateFolder(
          id,
          isVisible: f.isVisible == false ? false : null,
          isInverted: f.isInverted == true ? true : null,
        );
      }
    }
    for (final layer in data.layers) {
      final layerId = await createLayer(
        name: layer.name,
        colorArgb: layer.colorArgb,
        type: layer.type,
        // A borders layer's admin level is fixed at creation, so it has to be
        // known before any area is written.
        borderLevel: layer.type == 'borders' ? layer.borderLevel : null,
      );
      final folderId = folderIds[layer.folderName];
      if (folderId != null) await moveLayerToFolder(layerId, folderId);
      if (layer.isInverted ||
          layer.opacity != null ||
          layer.isVisible == false) {
        await updateLayer(
          layerId,
          isInverted: layer.isInverted ? true : null,
          opacity: layer.opacity,
          // Null means "shown", which is also `updateLayer`'s no-op — so only a
          // hidden layer writes anything here.
          isVisible: layer.isVisible == false ? false : null,
        );
      }
      if (layer.type == 'borders' &&
          (layer.borderFillAreas != null || layer.borderShowNames != null)) {
        await updateBorderLayerOptions(
          layerId,
          fillAreas: layer.borderFillAreas,
          showNames: layer.borderShowNames,
        );
      }
      imported += await _insertObjects(layerId, layer.objects, simplify);
    }
    return imported;
  }

  /// Adds [layer]'s objects into the existing [layerId] (must be the same
  /// type), without creating a new layer. Returns the number of objects
  /// inserted. Throws [ArgumentError] on a missing layer or a type mismatch so
  /// the caller can show a friendly message.
  Future<int> mergeIntoLayer(
    String layerId,
    ExportLayer layer, {
    bool simplify = true,
  }) {
    return _db.undo.group(
      'Import',
      () => _mergeIntoLayer(layerId, layer, simplify),
    );
  }

  Future<int> _mergeIntoLayer(
    String layerId,
    ExportLayer layer,
    bool simplify,
  ) async {
    final target = await (_db.select(
      _db.layers,
    )..where((l) => l.id.equals(layerId))).getSingleOrNull();
    if (target == null) throw ArgumentError('Layer no longer exists');
    // What matters is whether the target can *hold* what the file carries, not
    // whether the two layers are labelled the same. Checked against
    // the objects' own kinds rather than the file's layer type, since that is
    // what `_insertObject` will actually dispatch on.
    final kinds = <String>{
      for (final o in layer.objects)
        if (layerTypeForExportKind(o.kind) != null)
          layerTypeForExportKind(o.kind)!,
    };
    final unheld = kinds.where((t) => !layerTypeHolds(target.type, t)).toList()
      ..sort();
    if (unheld.isNotEmpty) {
      throw ArgumentError(
        'That file holds ${unheld.join(', ')} objects, but the layer is '
        '${target.type}',
      );
    }
    // Same rule [combineLayers] enforces: one borders layer holds one admin
    // level, because "no two neighbours share a colour" is only meaningful
    // within a level — areas of different levels nest rather than tile.
    if (target.type == kBorders &&
        layer.borderLevel != null &&
        layer.borderLevel != target.borderLevel) {
      throw ArgumentError(
        'That file holds admin level ${layer.borderLevel} areas, but '
        '“${target.name}” holds level ${target.borderLevel}',
      );
    }
    return _insertObjects(layerId, layer.objects, simplify);
  }

  /// Inserts [objects] into [layerId], returning how many were created.
  ///
  /// Border areas are pulled out and written as one batch rather than one at a
  /// time: each area otherwise costs a dedup scan of every area already in the
  /// layer, which is quadratic — and a country-level file is thousands of them.
  Future<int> _insertObjects(
    String layerId,
    List<ExportObject> objects,
    bool simplify,
  ) async {
    var imported = 0;
    final areas = <ExportObject>[];
    for (final o in objects) {
      if (o.kind == 'borderarea') {
        areas.add(o);
      } else if (await _insertObject(layerId, o, simplify)) {
        imported++;
      }
    }
    if (areas.isNotEmpty) imported += await _insertBorderAreas(layerId, areas);
    return imported;
  }

  /// Applies an imported element's colour override, if the file carried one.
  /// A file without it leaves the element following its new layer, which is
  /// what an import into a differently-coloured layer should do.
  Future<void> _applyImportedColor(
    ColoredElement kind,
    String id,
    int? argb,
  ) async {
    if (argb != null) await setElementColor(kind, id, argb);
  }

  /// Inserts one exported object into [layerId]. Returns true when it created an
  /// object, false when the geometry was unusable. Shared by [importData] (into
  /// fresh layers) and [mergeIntoLayer] (into an existing one).
  Future<bool> _insertObject(
    String layerId,
    ExportObject o,
    bool simplify,
  ) async {
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
      case 'subspace':
        if (o.coords.isEmpty) return false;
        final sid = await createSubspace(layerId: layerId, label: o.label);
        final main = (o.mainIndex ?? 0).clamp(0, o.coords.length - 1);
        final seedNames = o.pointLabels ?? const <String?>[];
        for (var i = 0; i < o.coords.length; i++) {
          await addSubspacePoint(
            subspaceId: sid,
            lat: o.coords[i].latitude,
            lng: o.coords[i].longitude,
            isMain: i == main,
            label: i < seedNames.length ? seedNames[i] : null,
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
        await addFreeLinePoints(lid, _importLine(o.coords, simplify));
        await _applyImportedColor(ColoredElement.freeLine, lid, o.colorArgb);
      case 'freearea':
        if (o.coords.length < 3) return false;
        final aid = await createFreeArea(layerId: layerId, label: o.label);
        if ((o.offsetMeters ?? 0) != 0) {
          await updateFreeArea(aid, offsetMeters: o.offsetMeters);
        }
        await addFreeAreaPoints(
          aid,
          simplify
              ? simplifyRing(o.coords, kImportSimplifyMeters, minPoints: 3)
              : o.coords,
        );
        await _applyImportedColor(ColoredElement.freeArea, aid, o.colorArgb);
      case 'height':
        final r = o.radiusMeters;
        if (o.coords.isEmpty || r == null || !r.isFinite || r <= 0) {
          return false;
        }
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
        // A generated region comes back drawn. Regenerating instead would need
        // the network and could disagree with what the sender saw — and until
        // someone tapped Generate the layer would show nothing at all.
        final fills = o.heightRings;
        if (fills != null || o.generated == true) {
          await replaceHeightPolygons(hid, fills ?? const <List<LatLng>>[]);
          await markHeightGenerated(hid);
        }
        await _applyImportedColor(
          ColoredElement.heightRegion,
          hid,
          o.colorArgb,
        );
      case 'poi':
        if (o.coords.isEmpty) return false;
        final r = o.radiusMeters;
        // Which kind of set this is follows from what the file carries: a
        // box means a station import, `manual` a hand-made category, and
        // anything else a radius import — so a v3 file needs no `source` key
        // and a v2 one (which never had it) reads the same way.
        final manual = o.manual ?? false;
        final box = o.bbox;
        final source = manual
            ? kPoiSourceManual
            : box != null
            ? kPoiSourceBox
            : kPoiSourceRadius;
        // A search radius is what the set was fetched with, not what its POIs
        // are — so when a file doesn't carry a usable one, derive it from how
        // far the POIs actually reach. Dropping the set (and every POI in it)
        // over a missing number loses far more than it protects.
        // A hand-made category never had a search radius — 0 *is* its value,
        // and deriving one from how far its points reach would both invent a
        // search that never ran and break the export fixed point. A box set
        // derives its own from the box inside [createPoiSet].
        final radius = manual
            ? (r ?? 0)
            : (r != null && r.isFinite && r > 0)
            ? r
            : _coveringRadius(o.coords);
        final sid = await createPoiSet(
          layerId: layerId,
          source: source,
          categoryKey: o.categoryKey ?? 'place',
          centerLat: o.coords.first.latitude,
          centerLng: o.coords.first.longitude,
          radiusMeters: radius,
          label: o.label,
          iconKey: o.iconKey,
          bbox: box,
          modeMask: o.modeMask ?? 0,
          visibleModeMask: o.visibleModeMask ?? -1,
        );
        await _applyImportedColor(ColoredElement.poiSet, sid, o.colorArgb);
        final labels = o.pointLabels ?? const <String?>[];
        if (manual) {
          // Hand-placed points go in the way they were placed: one by one,
          // through the guard that keeps imports and hand-made sets apart. A
          // manual set never gets a `fetchedAt` — nothing was fetched.
          for (var i = 1; i < o.coords.length; i++) {
            await addManualPoiPoint(
              poiSetId: sid,
              lat: o.coords[i].latitude,
              lng: o.coords[i].longitude,
              label: i - 1 < labels.length ? labels[i - 1] : null,
            );
          }
          return true;
        }
        if (o.pending ?? false) {
          // An import that never succeeded is still a row on the layer — the
          // retry the user can press. Restoring it as an empty *pending* set
          // keeps the layer looking exactly as it did, error text and all.
          if (o.errorMessage != null) {
            await markPoiImportFailed(sid, o.errorMessage!);
          }
          return true;
        }
        // The OSM identity travels with the file (v2), so a re-import over the
        // same ground recognises these POIs instead of drawing them twice. A
        // file without it — or a POI whose id is missing — simply stays outside
        // the dedup check, rather than being given a made-up one.
        final poiIds = o.pointOsmIds ?? const <int>[];
        final poiTypes = o.pointOsmTypes ?? const <String?>[];
        final masks = o.pointModeMasks ?? const <int>[];
        // A point somebody corrected by hand keeps saying so on the way in.
        // Absent in a v4 file, and absent per-slot for every point that was
        // never touched.
        final origLat = o.pointOrigLat ?? const <double?>[];
        final origLng = o.pointOrigLng ?? const <double?>[];
        final origNames = o.pointOrigNames ?? const <String?>[];
        await fillPoiSet(sid, [
          for (var i = 1; i < o.coords.length; i++)
            PoiResult(
              lat: o.coords[i].latitude,
              lng: o.coords[i].longitude,
              categoryKey: o.categoryKey ?? 'place',
              name: i - 1 < labels.length ? labels[i - 1] : null,
              osmType: i - 1 < poiTypes.length ? poiTypes[i - 1] : null,
              osmId: i - 1 < poiIds.length && poiIds[i - 1] != 0
                  ? poiIds[i - 1]
                  : null,
              modeMask: i - 1 < masks.length ? masks[i - 1] : 0,
              origLat: i - 1 < origLat.length ? origLat[i - 1] : null,
              origLng: i - 1 < origLng.length ? origLng[i - 1] : null,
              origName: i - 1 < origNames.length ? origNames[i - 1] : null,
            ),
        ]);
      case 'borderarea':
        // Never reached: [_insertObjects] batches these — see the comment
        // there. Refused rather than half-handled, so a new call site that
        // bypasses the batch fails loudly instead of writing quadratically.
        return false;
      default:
        return false;
    }
    return true;
  }

  /// Imported line geometry: RDP-thinned when [simplify], verbatim otherwise.
  /// Thinning belongs to *generic* files (GPS jitter, thousand-point city
  /// lines); our own GeoJSON has to come back exactly as it went out.
  static List<LatLng> _importLine(List<LatLng> pts, bool simplify) =>
      simplify ? simplifyLine(pts, kImportSimplifyMeters) : pts;

  /// Metres from `points.first` to the furthest of the rest — the fallback
  /// search radius for a POI set whose file didn't record one.
  static double _coveringRadius(List<LatLng> points) {
    var max = 0.0;
    for (var i = 1; i < points.length; i++) {
      final d = _geo.as(LengthUnit.Meter, points.first, points[i]);
      if (d > max) max = d;
    }
    return max > 0 ? max : 1;
  }

  /// `[south, west, north, east]` of [points] — the fallback box for a border
  /// import whose file didn't record the one it was fetched over.
  List<double> _extent(Iterable<LatLng> points) {
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in points) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    return s > n ? [0, 0, 0, 0] : [s, w, n, e];
  }

  /// Writes exported border areas into [layerId], regrouping them into the
  /// imports they came from, and recolours the layer once at the end.
  ///
  /// The set an area belongs to is recovered from the `adminLevel` + `bbox` it
  /// carries: areas fetched together share both, so the elements-to-imports
  /// structure survives the trip. An import whose box is already on the layer
  /// (the file came from here, or was imported once already) reuses that set
  /// rather than adding an identical second one.
  ///
  /// Areas already on the layer are skipped by relation id, the same check a
  /// re-fetch makes — so merging two overlapping files doesn't draw the shared
  /// municipalities twice.
  Future<int> _insertBorderAreas(
    String layerId,
    List<ExportObject> areas,
  ) async {
    final layer = await (_db.select(
      _db.layers,
    )..where((l) => l.id.equals(layerId))).getSingleOrNull();
    if (layer == null) return 0;
    var added = 0;
    await _db.transaction(() async {
      final seen = await _borderOsmIdsInLayer(layerId);
      final existing = await (_db.select(
        _db.borderSets,
      )..where((x) => x.layerId.equals(layerId))).get();
      // Set key -> (id, areas so far, points so far). The counts are
      // denormalised onto the set row, so a reused set has to be topped up
      // rather than overwritten.
      final sets = <String, ({String id, int areas, int points})>{
        for (final x in existing)
          _borderSetKey(x.adminLevel, x.south, x.west, x.north, x.east): (
            id: x.id,
            areas: x.areaCount,
            points: x.pointCount,
          ),
      };
      final rows = <BorderAreasCompanion>[];
      final overrides = <String, int>{}; // area id -> colour override
      for (final o in areas) {
        final rings = [
          for (final r in o.rings ?? [o.coords])
            if (r.length >= 3) r,
        ];
        if (rings.isEmpty) continue;
        final osmId = o.osmId;
        if (!_isNew(seen, osmKey('relation', osmId))) continue;
        final level = o.adminLevel ?? layer.borderLevel ?? '';
        final box = o.bbox ?? _extent(rings.expand((r) => r));
        final key = _borderSetKey(level, box[0], box[1], box[2], box[3]);
        var set = sets[key];
        if (set == null) {
          set = (id: _uuid.v4(), areas: 0, points: 0);
          await _db
              .into(_db.borderSets)
              .insert(
                BorderSetsCompanion.insert(
                  id: set.id,
                  layerId: layerId,
                  south: box[0],
                  west: box[1],
                  north: box[2],
                  east: box[3],
                  adminLevel: level,
                  label: Value(o.setLabel),
                  fetchedAt: DateTime.now(),
                ),
              );
        }
        final points = rings.fold(0, (a, r) => a + r.length);
        final id = _uuid.v4();
        final extent = _extent(rings.expand((r) => r));
        rows.add(
          BorderAreasCompanion.insert(
            id: id,
            setId: set.id,
            // A file without a relation id still imports; it simply sits outside
            // the dedup check, exactly as an unidentified POI does.
            osmId: osmId ?? 0,
            name: Value(o.label),
            colorIndex: Value(o.colorIndex ?? 0),
            south: extent[0],
            west: extent[1],
            north: extent[2],
            east: extent[3],
            labelLat: o.labelLat ?? (extent[0] + extent[2]) / 2,
            labelLng: o.labelLng ?? (extent[1] + extent[3]) / 2,
            pointCount: points,
            rings: encodeRings(rings),
            wayIds: jsonEncode(o.wayIds ?? const <int>[]),
            // An outline the sender reshaped stays flagged here: it is still not
            // what OSM says, and the receiver's own re-import dedup will keep it.
            editedAt: Value(o.edited == true ? DateTime.now() : null),
          ),
        );
        if (o.colorArgb != null) overrides[id] = o.colorArgb!;
        sets[key] = (
          id: set.id,
          areas: set.areas + 1,
          points: set.points + points,
        );
        added++;
      }
      await _db.batch((b) {
        for (final r in rows) {
          b.insert(_db.borderAreas, r);
        }
        for (final e in sets.entries) {
          b.update(
            _db.borderSets,
            BorderSetsCompanion(
              areaCount: Value(e.value.areas),
              pointCount: Value(e.value.points),
            ),
            where: (t) => t.id.equals(e.value.id),
          );
        }
        for (final e in overrides.entries) {
          b.update(
            _db.borderAreas,
            BorderAreasCompanion(colorArgb: Value(e.value)),
            where: (t) => t.id.equals(e.key),
          );
        }
      });
    });
    // The layer now holds areas that were coloured in another database (or in
    // two files), so its seams have to be resolved — the same step every
    // fetch, delete and combine ends with. Deterministic, so a whole layer
    // imported at once comes out looking exactly as it did on the sender's.
    if (added > 0) await recolourBorderLayer(layerId);
    return added;
  }

  /// Identity of the import an area belongs to: its admin level plus the box it
  /// was fetched over, rounded so a float round-trip through JSON still
  /// matches.
  String _borderSetKey(String level, double s, double w, double n, double e) =>
      '$level/${s.toStringAsFixed(6)}/${w.toStringAsFixed(6)}/'
      '${n.toStringAsFixed(6)}/${e.toStringAsFixed(6)}';

  // --- Seed -----------------------------------------------------------------

  /// Ensures at least one layer exists so the user can place circles right away.
  /// Also removes any circles with non-finite coordinates/radius left over from
  /// older builds (which would crash map projection). Returns the id of an
  /// existing or freshly created layer.
  Future<String> ensureDefaultLayer() {
    // None of this is a user action, so none of it belongs on the undo stack —
    // otherwise the app opens with "Add layer" already there, one press away
    // from deleting the layer it just seeded.
    return _db.undo.suspended(() async {
      await deleteInvalidCircles();
      // Seed the settings row while we are here. `clearAll` deletes it, and
      // `watchSettings` synthesises defaults when it is missing — so without
      // this the first uncertainty change after a wipe is an INSERT, which the
      // journal's `AFTER UPDATE OF` trigger never sees, and that one change
      // would silently not be undoable.
      await _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(const AppSettingsCompanion(id: Value(1)));
      final existing =
          await (_db.select(_db.layers)
                ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return existing.id;
      return createLayer(name: 'Circles 1', colorArgb: kDefaultLayerColor);
    });
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
/// Where a "move element" action sends an element within its layer's stack.
///
/// `toFront` is drawn last, so it wins an overlap. The Elements list reads
/// bottom-of-map first, so front is *down* the list — the menu wording names
/// the map rather than the list for that reason.
enum ZMove { toFront, forward, backward, toBack }

enum ColoredElement {
  circle('circles', 'circles'),
  subspace('subspaces', 'subspace'),
  freeLine('free_lines', 'freeline'),
  freeArea('free_areas', 'freearea'),
  heightRegion('height_regions', 'height'),
  poiSet('poi_sets', 'poi'),
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

  /// The kind for an [ObjectKind] name, which is what a *row* knows about
  /// itself.
  ///
  /// The layer-type lookup could not answer for the retired `mixed` type — six
  /// kinds — so anything acting on one element (the Elements-list colour menu,
  /// the editors' colour swatch) must come in this way instead. Takes the
  /// enum's `name` rather than the enum itself so `data/` need not import
  /// `state/`.
  static ColoredElement? forObjectKindName(String kindName) =>
      switch (kindName) {
        'circle' => ColoredElement.circle,
        'subspace' => ColoredElement.subspace,
        'freeLine' => ColoredElement.freeLine,
        'freeArea' => ColoredElement.freeArea,
        'heightRegion' => ColoredElement.heightRegion,
        'poiSet' => ColoredElement.poiSet,
        'borderArea' => ColoredElement.borderArea,
        _ => null,
      };
}
