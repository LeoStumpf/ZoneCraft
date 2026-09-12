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

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../data/repository.dart';
import '../data/shared_point.dart';
import '../data/undo_journal.dart';
import 'map_mode.dart';

/// Single long-lived database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<Repository>((ref) {
  return Repository(ref.watch(databaseProvider));
});

/// The undo journal, which lives on the database because its triggers do.
final undoJournalProvider = Provider<UndoJournal>((ref) {
  final journal = ref.watch(repositoryProvider).undo;
  // Here rather than in `install()`: see [UndoJournal.startWatching].
  journal.startWatching();
  return journal;
});

/// What the back/forward buttons render from.
final undoStateProvider = StreamProvider<UndoState>((ref) async* {
  final journal = ref.watch(undoJournalProvider);
  yield journal.state;
  yield* journal.changes;
});

/// Bumped by every undo and redo.
///
/// Editors mirror their row into `TextEditingController`s and deliberately skip
/// re-syncing a field that has focus — so after an undo the map would revert
/// while the text box still showed the old value, and the next keystroke would
/// write that stale value straight back. Folding this into the editor sheet's
/// key discards the sheet subtree on undo, which re-seeds every controller in
/// every editor from the restored row. It changes only on undo, so ordinary
/// live editing never fights the keyboard.
class UndoRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final undoRevisionProvider = NotifierProvider<UndoRevisionNotifier, int>(
  UndoRevisionNotifier.new,
);

/// Steps back (or, with [forward], returns) one action.
///
/// The order matters: drop the keyboard first so no focused field can write its
/// stale value back, disarm anything that would commit remembered geometry over
/// what is about to be restored, then replay.
Future<void> applyUndo(WidgetRef ref, {bool forward = false}) =>
    applyUndoIn(ProviderScope.containerOf(ref.context), forward: forward);

/// [applyUndo] for a caller with no live widget — a snackbar's UNDO button,
/// which outlives the tile whose action raised it (a deleted layer's tile is
/// gone by the time the button is pressed, and its `ref` with it).
Future<void> applyUndoIn(
  ProviderContainer container, {
  bool forward = false,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  clearTransientModesIn(container);
  final journal = container.read(undoJournalProvider);
  await (forward ? journal.redo() : journal.undo());
  container.read(undoRevisionProvider.notifier).bump();
}

/// Reactive list of layers, ordered bottom-to-top (draw order).
final layersProvider = StreamProvider<List<Layer>>((ref) {
  return ref.watch(repositoryProvider).watchLayers();
});

/// Reactive list of every circle across all layers.
final circlesProvider = StreamProvider<List<Circle>>((ref) {
  return ref.watch(repositoryProvider).watchAllCircles();
});

/// Reactive list of every subspace object across all layers.
final subspacesProvider = StreamProvider<List<Subspace>>((ref) {
  return ref.watch(repositoryProvider).watchAllSubspaces();
});

/// Reactive list of every subspace point (across all subspaces), ordered.
final subspacePointsProvider = StreamProvider<List<SubspacePoint>>((ref) {
  return ref.watch(repositoryProvider).watchAllSubspacePoints();
});

/// Reactive list of every freehand line across all layers.
final freeLinesProvider = StreamProvider<List<FreeLine>>((ref) {
  return ref.watch(repositoryProvider).watchAllFreeLines();
});

/// Reactive list of every freehand-line point (across all lines), ordered.
final freeLinePointsProvider = StreamProvider<List<FreeLinePoint>>((ref) {
  return ref.watch(repositoryProvider).watchAllFreeLinePoints();
});

/// Reactive list of every freehand area across all layers.
final freeAreasProvider = StreamProvider<List<FreeArea>>((ref) {
  return ref.watch(repositoryProvider).watchAllFreeAreas();
});

/// Reactive list of every freehand-area point (across all areas), ordered.
final freeAreaPointsProvider = StreamProvider<List<FreeAreaPoint>>((ref) {
  return ref.watch(repositoryProvider).watchAllFreeAreaPoints();
});

/// Reactive list of every height region across all layers.
final heightRegionsProvider = StreamProvider<List<HeightRegion>>((ref) {
  return ref.watch(repositoryProvider).watchAllHeightRegions();
});

/// Reactive list of every generated height polygon (across all regions), ordered.
final heightPolygonsProvider = StreamProvider<List<HeightPolygon>>((ref) {
  return ref.watch(repositoryProvider).watchAllHeightPolygons();
});

/// Reactive list of every height-polygon ring point (across all polygons),
/// ordered.
final heightPolygonPointsProvider = StreamProvider<List<HeightPolygonPoint>>((
  ref,
) {
  return ref.watch(repositoryProvider).watchAllHeightPolygonPoints();
});

/// Reactive list of every POI set across all layers.
final poiSetsProvider = StreamProvider<List<PoiSet>>((ref) {
  return ref.watch(repositoryProvider).watchAllPoiSets();
});

/// Reactive list of every stored POI (across all sets), ordered.
final poiPointsProvider = StreamProvider<List<PoiPoint>>((ref) {
  return ref.watch(repositoryProvider).watchAllPoiPoints();
});

/// Reactive list of every administrative-border import across all layers.
final borderSetsProvider = StreamProvider<List<BorderSet>>((ref) {
  return ref.watch(repositoryProvider).watchAllBorderSets();
});

/// Reactive list of every imported border area (across all sets), geometry
/// still encoded — decoding happens once per emission in [borderShapesProvider].
final borderAreasProvider = StreamProvider<List<BorderArea>>((ref) {
  return ref.watch(repositoryProvider).watchAllBorderAreas();
});

// --- Point lookups ----------------------------------------------------------
//
// The `watchAll*` point streams are flat lists across *every* object of *every*
// layer, because that is the shape a single query returns. The renderer wants
// "the points of this one object", and it asks once per object per frame:
// `RegionLayer.build` reads `MapCamera.of(context)`, so it re-runs on every
// camera tick of a pan, and a linear `.where(...)` scan inside a loop over the
// layer's objects is O(objects x all points of that type). Small hand-drawn
// layers never noticed; a borders-to-freehand conversion (97 areas, 13 629
// points) is ~1.3M comparisons and a fresh list allocation *per frame*.
//
// So group once per stream emission instead — the same trick
// [borderShapesProvider] uses to decode ring geometry once rather than per
// frame. Lookups become O(1), the lists keep their identity between frames, and
// the cost stops depending on layers you aren't looking at.

/// Groups [rows] by [keyOf], preserving each group's incoming order (the
/// queries already order by `sortOrder`, and the renderers depend on that).
Map<String, List<T>> _groupBy<T>(List<T> rows, String Function(T row) keyOf) {
  final out = <String, List<T>>{};
  for (final row in rows) {
    (out[keyOf(row)] ??= <T>[]).add(row);
  }
  return out;
}

/// Subspace points keyed by their subspace id.
final subspacePointsBySubspaceProvider =
    Provider<Map<String, List<SubspacePoint>>>((ref) {
      final rows = ref.watch(subspacePointsProvider).asData?.value ?? const [];
      return _groupBy(rows, (p) => p.subspaceId);
    });

/// Freehand-line vertices keyed by their line id.
final freeLinePointsByLineProvider = Provider<Map<String, List<FreeLinePoint>>>(
  (ref) {
    final rows = ref.watch(freeLinePointsProvider).asData?.value ?? const [];
    return _groupBy(rows, (p) => p.freeLineId);
  },
);

/// Freehand-area vertices keyed by their area id.
final freeAreaPointsByAreaProvider = Provider<Map<String, List<FreeAreaPoint>>>(
  (ref) {
    final rows = ref.watch(freeAreaPointsProvider).asData?.value ?? const [];
    return _groupBy(rows, (p) => p.freeAreaId);
  },
);

/// Stored POIs keyed by their set id. A city of stations is thousands of
/// rows, so the marker painter must not scan the flat list per set per frame.
final poiPointsBySetProvider = Provider<Map<String, List<PoiPoint>>>((ref) {
  final rows = ref.watch(poiPointsProvider).asData?.value ?? const [];
  return _groupBy(rows, (p) => p.poiSetId);
});

/// Generated height polygons keyed by their height-region id.
final heightPolygonsByRegionProvider =
    Provider<Map<String, List<HeightPolygon>>>((ref) {
      final rows = ref.watch(heightPolygonsProvider).asData?.value ?? const [];
      return _groupBy(rows, (p) => p.heightRegionId);
    });

/// Height-polygon ring points keyed by their polygon id.
final heightPolygonPointsByPolygonProvider =
    Provider<Map<String, List<HeightPolygonPoint>>>((ref) {
      final rows =
          ref.watch(heightPolygonPointsProvider).asData?.value ?? const [];
      return _groupBy(rows, (p) => p.polygonId);
    });

/// App-wide settings (currently the global uncertainty radius).
final settingsProvider = StreamProvider<AppSetting>((ref) {
  return ref.watch(repositoryProvider).watchSettings();
});

/// Runs once at startup to guarantee a layer exists.
final seedProvider = FutureProvider<String>((ref) {
  return ref.watch(repositoryProvider).ensureDefaultLayer();
});

/// Everything selectable, in one closed enum — the type tag the parallel
/// `selectedXProvider`s don't carry themselves.
///
/// Seven of these are a layer's **elements**, one kind per layer type, and are
/// what the Elements list shows. The last — [poiPoint] — is one level *below*
/// an element: an imported POI or station inside its set. It is selectable on
/// the map but deliberately never listed, because a city import is thousands
/// of them and the list is a place to find an import, not to scroll past
/// 2 672 bus stops.
///
/// Every kind opens an editor when selected (the imported ones get a sheet
/// scoped to what a snapshot can honestly offer), so there is no per-kind
/// "has editor" flag any more: `track`, the one exception, is gone.
enum ObjectKind {
  circle,
  subspace,
  freeLine,
  freeArea,
  heightRegion,
  poiSet,
  borderArea,
  poiPoint;

  /// The `Layers.type` string that holds this kind of object.
  String get layerType => switch (this) {
    ObjectKind.circle => 'circles',
    ObjectKind.subspace => 'subspace',
    ObjectKind.freeLine => 'freeline',
    ObjectKind.freeArea => 'freearea',
    ObjectKind.heightRegion => 'height',
    ObjectKind.poiSet || ObjectKind.poiPoint => 'poi',
    ObjectKind.borderArea => 'borders',
  };

  /// Whether this is a layer *element* (a row of the Elements list) rather than
  /// a point inside one.
  bool get isElement => this != ObjectKind.poiPoint;

  /// The kind a layer of [layerType] holds, or null for an unknown type.
  static ObjectKind? forLayerType(String layerType) => switch (layerType) {
    'circles' => ObjectKind.circle,
    'subspace' => ObjectKind.subspace,
    'freeline' => ObjectKind.freeLine,
    'freearea' => ObjectKind.freeArea,
    'height' => ObjectKind.heightRegion,
    'poi' => ObjectKind.poiSet,
    'borders' => ObjectKind.borderArea,
    _ => null,
  };
}

/// Sentinel [activeLayerProvider] value meaning "the user explicitly chose to
/// have no active layer" — distinct from `null`, which means "nothing chosen
/// yet, fall back to the top layer".
const String noActiveLayer = '__none__';

/// Id of the active layer (new objects are added to it, and only its objects
/// can be selected). `null` = nothing chosen yet (defaults to the top layer);
/// [noActiveLayer] = explicitly none.
class ActiveLayerNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;

  /// Toggle a layer active: tapping the already-active layer deselects to
  /// [noActiveLayer]; otherwise the layer becomes active.
  void toggle(String id, {required bool isActive}) =>
      state = isActive ? noActiveLayer : id;
}

final activeLayerProvider = NotifierProvider<ActiveLayerNotifier, String?>(
  ActiveLayerNotifier.new,
);

/// Id of the currently selected circle, or null. Drives the docked editor sheet
/// and the remove button.
class SelectedCircleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedCircleProvider =
    NotifierProvider<SelectedCircleNotifier, String?>(
      SelectedCircleNotifier.new,
    );

/// While a circle is selected, whether the next map tap relocates its centre.
/// (Mirrors [heightPlacementProvider].)
class CirclePlacementNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm({required bool on}) => state = on;
}

final circlePlacementProvider = NotifierProvider<CirclePlacementNotifier, bool>(
  CirclePlacementNotifier.new,
);

/// Id of the currently selected subspace, or null. Mutually exclusive with the
/// other selections (one object of one type is selected at a time).
class SelectedSubspaceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedSubspaceProvider =
    NotifierProvider<SelectedSubspaceNotifier, String?>(
      SelectedSubspaceNotifier.new,
    );

/// While a subspace is selected, the id of the point the next map tap relocates,
/// or null for "no placement armed".
class SubspacePlacementNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String? pointId) => state = pointId;
}

final subspacePlacementProvider =
    NotifierProvider<SubspacePlacementNotifier, String?>(
      SubspacePlacementNotifier.new,
    );

/// Id of the currently selected freehand line, or null. Mutually exclusive with
/// the other object selections (one object of one type is selected at a time).
class SelectedFreeLineNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedFreeLineProvider =
    NotifierProvider<SelectedFreeLineNotifier, String?>(
      SelectedFreeLineNotifier.new,
    );

/// While a freehand line is selected, the id of the point the next map tap
/// relocates, or null for "no placement armed".
class FreeLinePlacementNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String? pointId) => state = pointId;
}

final freeLinePlacementProvider =
    NotifierProvider<FreeLinePlacementNotifier, String?>(
      FreeLinePlacementNotifier.new,
    );

/// While a freehand line is selected, whether the next map tap relocates its
/// inclusion-circle centre. (Mirrors [heightPlacementProvider] for the height
/// region centre.)
class FreeLineCenterPlacementNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm({required bool on}) => state = on;
}

final freeLineCenterPlacementProvider =
    NotifierProvider<FreeLineCenterPlacementNotifier, bool>(
      FreeLineCenterPlacementNotifier.new,
    );

/// Id of the currently selected freehand area, or null. Mutually exclusive with
/// the other object selections.
class SelectedFreeAreaNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedFreeAreaProvider =
    NotifierProvider<SelectedFreeAreaNotifier, String?>(
      SelectedFreeAreaNotifier.new,
    );

/// While a freehand area is selected, the id of the point the next map tap
/// relocates, or null for "no placement armed".
class FreeAreaPlacementNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String? pointId) => state = pointId;
}

final freeAreaPlacementProvider =
    NotifierProvider<FreeAreaPlacementNotifier, String?>(
      FreeAreaPlacementNotifier.new,
    );

/// Id of the currently selected height region, or null. Mutually exclusive with
/// the other object selections.
class SelectedHeightRegionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedHeightRegionProvider =
    NotifierProvider<SelectedHeightRegionNotifier, String?>(
      SelectedHeightRegionNotifier.new,
    );

/// While a height region is selected, whether the next map tap relocates its
/// centre (true) or not (null/false).
class HeightPlacementNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm({required bool on}) => state = on;
}

final heightPlacementProvider = NotifierProvider<HeightPlacementNotifier, bool>(
  HeightPlacementNotifier.new,
);

/// Id of the selected border area, or null.
///
/// Unlike the six geometry kinds this one selects a **read-only OSM snapshot**,
/// so the editor it opens is mostly presentation — with one exception, the
/// outline, which can be reshaped and is flagged when it has been (see
/// `BorderAreas.editedAt`).
class SelectedBorderAreaNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedBorderAreaProvider =
    NotifierProvider<SelectedBorderAreaNotifier, String?>(
      SelectedBorderAreaNotifier.new,
    );

/// While a border area is selected, whether its outline shows vertex handles.
///
/// Off by default, and deliberately a mode rather than always-on: an
/// administrative boundary carries hundreds of vertices where a hand-drawn area
/// carries eight, so handles everywhere would bury the map under dots and make
/// a stray drag — a silent fork from OSM — far too easy.
class BorderReshapeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm({required bool on}) => state = on;
}

final borderReshapeProvider = NotifierProvider<BorderReshapeNotifier, bool>(
  BorderReshapeNotifier.new,
);

/// Id of the selected POI import, or null.
class SelectedPoiSetNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedPoiSetProvider =
    NotifierProvider<SelectedPoiSetNotifier, String?>(
      SelectedPoiSetNotifier.new,
    );

/// Id of the selected individual POI, or null — one level below a set.
class SelectedPoiPointNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedPoiPointProvider =
    NotifierProvider<SelectedPoiPointNotifier, String?>(
      SelectedPoiPointNotifier.new,
    );

/// Clears every object selection and disarms every "the next map tap places
/// this point" flag.
///
/// The `selectedXProvider`s are mutually exclusive **by convention only**
/// (nothing in the providers enforces it), so this is the single place that
/// convention is implemented. Callers outside the map screen (the layers
/// drawer's Elements list) rely on it too — keep it here, not in a widget.
void clearSelection(WidgetRef ref) {
  ref.read(selectedCircleProvider.notifier).select(null);
  ref.read(selectedSubspaceProvider.notifier).select(null);
  ref.read(selectedFreeLineProvider.notifier).select(null);
  ref.read(selectedFreeAreaProvider.notifier).select(null);
  ref.read(selectedHeightRegionProvider.notifier).select(null);
  ref.read(selectedPoiSetProvider.notifier).select(null);
  ref.read(selectedPoiPointProvider.notifier).select(null);
  ref.read(selectedBorderAreaProvider.notifier).select(null);
  clearTransientModes(ref);
}

/// Disarms every "the next map tap places this" flag and the border reshape
/// mode, without touching the selections.
///
/// Undo needs exactly this half and not the other: a selection whose row has
/// gone resolves to null and closes its own sheet (and a redo re-opens it), but
/// an armed placement or a live reshape draft would survive and write stale
/// geometry back over what was just restored.
void clearTransientModes(WidgetRef ref) =>
    clearTransientModesIn(ProviderScope.containerOf(ref.context));

/// [clearTransientModes] against the container itself — see [applyUndoIn].
void clearTransientModesIn(ProviderContainer c) {
  c.read(circlePlacementProvider.notifier).arm(on: false);
  c.read(subspacePlacementProvider.notifier).arm(null);
  c.read(freeLinePlacementProvider.notifier).arm(null);
  c.read(freeLineCenterPlacementProvider.notifier).arm(on: false);
  c.read(freeAreaPlacementProvider.notifier).arm(null);
  c.read(heightPlacementProvider.notifier).arm(on: false);
  c.read(poiPointPlacementProvider.notifier).arm(on: false);
  c.read(borderReshapeProvider.notifier).arm(on: false);
}

/// Whether any object is currently selected.
bool hasAnySelection(WidgetRef ref) =>
    ref.read(selectedCircleProvider) != null ||
    ref.read(selectedSubspaceProvider) != null ||
    ref.read(selectedFreeLineProvider) != null ||
    ref.read(selectedFreeAreaProvider) != null ||
    ref.read(selectedHeightRegionProvider) != null ||
    ref.read(selectedPoiSetProvider) != null ||
    ref.read(selectedPoiPointProvider) != null ||
    ref.read(selectedBorderAreaProvider) != null;

/// The ids of every selected object, *watched* — for a list that wants to
/// mark its selected row and follow the selection as it changes.
Set<String> watchSelectedIds(WidgetRef ref) => {
  for (final p in [
    selectedCircleProvider,
    selectedSubspaceProvider,
    selectedFreeLineProvider,
    selectedFreeAreaProvider,
    selectedHeightRegionProvider,
    selectedPoiSetProvider,
    selectedPoiPointProvider,
    selectedBorderAreaProvider,
  ])
    ?ref.watch(p),
};

/// Selects exactly one object, clearing the others (and any armed placement),
/// and leaves whatever map mode was armed — editing the object is now the job.
///
/// Every kind has an editor, including the imported ones — theirs is scoped to
/// what a snapshot can honestly offer (name, colour, curation, and for a
/// border area its outline), rather than pretending the geometry is yours.
void selectObject(WidgetRef ref, ObjectKind kind, String id) {
  clearSelection(ref);
  if (ref.read(mapModeProvider) != MapMode.edit) {
    ref.read(mapModeProvider.notifier).set(MapMode.view);
  }
  switch (kind) {
    case ObjectKind.circle:
      ref.read(selectedCircleProvider.notifier).select(id);
    case ObjectKind.subspace:
      ref.read(selectedSubspaceProvider.notifier).select(id);
    case ObjectKind.freeLine:
      ref.read(selectedFreeLineProvider.notifier).select(id);
    case ObjectKind.freeArea:
      ref.read(selectedFreeAreaProvider.notifier).select(id);
    case ObjectKind.heightRegion:
      ref.read(selectedHeightRegionProvider.notifier).select(id);
    case ObjectKind.poiSet:
      ref.read(selectedPoiSetProvider.notifier).select(id);
    case ObjectKind.poiPoint:
      ref.read(selectedPoiPointProvider.notifier).select(id);
    case ObjectKind.borderArea:
      ref.read(selectedBorderAreaProvider.notifier).select(id);
  }
}

/// A one-shot request for the map to frame something (the layers drawer's
/// "Zoom to" / "Edit" actions, which have no access to the [MapController]).
///
/// Deliberately has **no** `operator ==`: asking twice for the same object must
/// re-fire the listener rather than be swallowed as an unchanged state.
class MapFocusRequest {
  const MapFocusRequest(this.points);

  /// One or more lat/lng points to bring into view. A single point means
  /// "centre here" — a camera fit on a degenerate box zooms to the maximum.
  final List<LatLng> points;
}

class PendingFocusNotifier extends Notifier<MapFocusRequest?> {
  @override
  MapFocusRequest? build() => null;

  void request(List<LatLng> points) {
    if (points.isEmpty) return;
    state = MapFocusRequest(points);
  }

  void clear() => state = null;
}

final pendingFocusProvider =
    NotifierProvider<PendingFocusNotifier, MapFocusRequest?>(
      PendingFocusNotifier.new,
    );

/// A one-shot request to re-run a POI import (radius or box) that didn't
/// finish.
///
/// The Elements list lives in the drawer and has no access to the map screen's
/// import machinery, so it posts the set id here — the same shape
/// [pendingFocusProvider] uses, and for the same reason. No `operator ==`, so
/// asking twice for the same set re-fires.
class ImportRetryRequest {
  const ImportRetryRequest(this.setId);
  final String setId;
}

class PendingImportRetryNotifier extends Notifier<ImportRetryRequest?> {
  @override
  ImportRetryRequest? build() => null;

  void request(String setId) => state = ImportRetryRequest(setId);
  void clear() => state = null;
}

final pendingImportRetryProvider =
    NotifierProvider<PendingImportRetryNotifier, ImportRetryRequest?>(
      PendingImportRetryNotifier.new,
    );

/// What a map-owning action can be asked for from somewhere that is not the
/// map: the layers drawer, the layer sheet, an Elements list's empty state.
///
/// Each of these runs inside `map_screen`, because each needs the camera (a
/// border import takes the visible bounds), the map's `bottomSheet` slot (an
/// import form draws its preview live) or a mode (Add / Draw arm a banner) —
/// none of which a popped sheet's context can reach.
enum MapRequestKind {
  /// One category of POIs around the map centre (`_importPois`).
  importPois,

  /// Stations in a box marked by two corner taps (Add mode armed for it).
  importStations,

  /// Administrative areas inside the visible bounds — the Add-FAB long-press.
  importBordersVisible,

  /// A named map feature via Nominatim, merged into the layer.
  importFeature,

  /// A GPX/KML/GeoJSON track file, merged into the layer.
  importTrack,

  /// A whole file as new layers or merged, with the map preview.
  importFile,

  /// Arm Add mode for the layer.
  enterAdd,

  /// Arm Draw mode for the layer (freehand types only).
  enterDraw,
}

/// A one-shot request for the map to run [kind] on [layerId].
///
/// Same shape as [ImportRetryRequest] and for the same reason: the map screen
/// listens, clears, and acts once. No `operator ==`, so asking twice re-fires.
/// [layerId] is null only for [MapRequestKind.importFile], which makes layers
/// rather than filling one.
class MapRequest {
  const MapRequest(this.kind, {this.layerId});
  final MapRequestKind kind;
  final String? layerId;
}

class MapRequestNotifier extends Notifier<MapRequest?> {
  @override
  MapRequest? build() => null;

  void post(MapRequest request) => state = request;
  void clear() => state = null;
}

final mapRequestProvider = NotifierProvider<MapRequestNotifier, MapRequest?>(
  MapRequestNotifier.new,
);

/// While a hand-placed POI is selected, whether the next map tap moves it.
///
/// Only ever armed for a POI in a **manual** category: an imported POI's
/// position is the fetched fact its layer exists to record (see
/// `Repository.moveManualPoiPoint`, which refuses the write regardless).
class PoiPointPlacementNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm({required bool on}) => state = on;
}

final poiPointPlacementProvider =
    NotifierProvider<PoiPointPlacementNotifier, bool>(
      PoiPointPlacementNotifier.new,
    );

/// A position that arrived from outside the app — a `zonecraft://` link, or
/// text pasted into the "Paste coordinates" box.
///
/// Deliberately **not** written to the database on arrival. A link tapped by
/// accident must leave nothing behind, so what a share delivers is a camera
/// move and an offer; turning it into a circle or a POI is a separate,
/// explicit step. Same one-shot shape as [pendingFocusProvider], and for the
/// same reason: the sender is not the map screen.
class ReceivedPointNotifier extends Notifier<SharedPoint?> {
  @override
  SharedPoint? build() => null;

  void receive(SharedPoint p) => state = p;
  void clear() => state = null;
}

final receivedPointProvider =
    NotifierProvider<ReceivedPointNotifier, SharedPoint?>(
      ReceivedPointNotifier.new,
    );

/// Resolves the effective active layer id given the current layer list:
/// [noActiveLayer] ⇒ none; a still-present selection ⇒ itself; otherwise (nothing
/// chosen yet, or the selection was deleted) falls back to the top-most layer.
String? effectiveActiveLayerId(List<Layer> layers, String? selected) {
  if (selected == noActiveLayer) return null; // explicitly none
  if (layers.isEmpty) return null;
  if (selected != null && layers.any((l) => l.id == selected)) return selected;
  return layers.last.id; // last == top of stack
}
