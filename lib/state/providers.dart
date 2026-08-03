import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../data/repository.dart';
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

/// Reactive list of layers, ordered bottom-to-top (draw order).
final layersProvider = StreamProvider<List<Layer>>((ref) {
  return ref.watch(repositoryProvider).watchLayers();
});

/// Reactive list of every circle across all layers.
final circlesProvider = StreamProvider<List<Circle>>((ref) {
  return ref.watch(repositoryProvider).watchAllCircles();
});

/// Reactive list of every plane across all layers.
final planesProvider = StreamProvider<List<Plane>>((ref) {
  return ref.watch(repositoryProvider).watchAllPlanes();
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
final heightPolygonPointsProvider =
    StreamProvider<List<HeightPolygonPoint>>((ref) {
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

/// Reactive list of every public-transport import across all layers.
final transitSetsProvider = StreamProvider<List<TransitSet>>((ref) {
  return ref.watch(repositoryProvider).watchAllTransitSets();
});

/// Reactive list of every imported transit station (across all sets).
final transitStopsProvider = StreamProvider<List<TransitStop>>((ref) {
  return ref.watch(repositoryProvider).watchAllTransitStops();
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
Map<String, List<T>> _groupBy<T>(
  List<T> rows,
  String Function(T row) keyOf,
) {
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
final freeLinePointsByLineProvider =
    Provider<Map<String, List<FreeLinePoint>>>((ref) {
  final rows = ref.watch(freeLinePointsProvider).asData?.value ?? const [];
  return _groupBy(rows, (p) => p.freeLineId);
});

/// Freehand-area vertices keyed by their area id.
final freeAreaPointsByAreaProvider =
    Provider<Map<String, List<FreeAreaPoint>>>((ref) {
  final rows = ref.watch(freeAreaPointsProvider).asData?.value ?? const [];
  return _groupBy(rows, (p) => p.freeAreaId);
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
  final rows = ref.watch(heightPolygonPointsProvider).asData?.value ?? const [];
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

/// The nine object types a layer can hold, in one closed enum — the type tag
/// the six parallel `selectedXProvider`s don't carry themselves.
enum ObjectKind {
  circle,
  plane,
  subspace,
  freeLine,
  freeArea,
  heightRegion,
  poiSet,
  transitSet,
  borderArea;

  /// The `Layers.type` string that holds this kind of object.
  String get layerType => switch (this) {
        ObjectKind.circle => 'circles',
        ObjectKind.plane => 'planes',
        ObjectKind.subspace => 'subspace',
        ObjectKind.freeLine => 'freeline',
        ObjectKind.freeArea => 'freearea',
        ObjectKind.heightRegion => 'height',
        ObjectKind.poiSet => 'poi',
        ObjectKind.transitSet => 'transit',
        ObjectKind.borderArea => 'borders',
      };

  /// The kind a layer of [layerType] holds, or null for an unknown type.
  static ObjectKind? forLayerType(String layerType) => switch (layerType) {
        'circles' => ObjectKind.circle,
        'planes' => ObjectKind.plane,
        'subspace' => ObjectKind.subspace,
        'freeline' => ObjectKind.freeLine,
        'freearea' => ObjectKind.freeArea,
        'height' => ObjectKind.heightRegion,
        'poi' => ObjectKind.poiSet,
        'transit' => ObjectKind.transitSet,
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

final activeLayerProvider =
    NotifierProvider<ActiveLayerNotifier, String?>(ActiveLayerNotifier.new);

/// Id of the currently selected circle, or null. Drives the docked editor sheet
/// and the remove button.
class SelectedCircleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedCircleProvider =
    NotifierProvider<SelectedCircleNotifier, String?>(
        SelectedCircleNotifier.new);

/// While a circle is selected, whether the next map tap relocates its centre.
/// (Mirrors [heightPlacementProvider].)
class CirclePlacementNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm(bool on) => state = on;
}

final circlePlacementProvider =
    NotifierProvider<CirclePlacementNotifier, bool>(
        CirclePlacementNotifier.new);

/// Id of the currently selected plane, or null. Mutually exclusive with
/// [selectedCircleProvider] (an object of one type is selected at a time).
class SelectedPlaneNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedPlaneProvider =
    NotifierProvider<SelectedPlaneNotifier, String?>(SelectedPlaneNotifier.new);

/// While a plane is selected, which endpoint the next map tap relocates —
/// `'A'`, `'B'`, or null for "no placement armed".
class PlanePlacementNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String? point) => state = point;
}

final planePlacementProvider =
    NotifierProvider<PlanePlacementNotifier, String?>(
        PlanePlacementNotifier.new);

/// Id of the currently selected subspace, or null. Mutually exclusive with the
/// circle/plane selections (one object of one type is selected at a time).
class SelectedSubspaceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedSubspaceProvider =
    NotifierProvider<SelectedSubspaceNotifier, String?>(
        SelectedSubspaceNotifier.new);

/// While a subspace is selected, the id of the point the next map tap relocates,
/// or null for "no placement armed".
class SubspacePlacementNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String? pointId) => state = pointId;
}

final subspacePlacementProvider =
    NotifierProvider<SubspacePlacementNotifier, String?>(
        SubspacePlacementNotifier.new);

/// Id of the currently selected freehand line, or null. Mutually exclusive with
/// the other object selections (one object of one type is selected at a time).
class SelectedFreeLineNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedFreeLineProvider =
    NotifierProvider<SelectedFreeLineNotifier, String?>(
        SelectedFreeLineNotifier.new);

/// While a freehand line is selected, the id of the point the next map tap
/// relocates, or null for "no placement armed".
class FreeLinePlacementNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String? pointId) => state = pointId;
}

final freeLinePlacementProvider =
    NotifierProvider<FreeLinePlacementNotifier, String?>(
        FreeLinePlacementNotifier.new);

/// While a freehand line is selected, whether the next map tap relocates its
/// inclusion-circle centre. (Mirrors [heightPlacementProvider] for the height
/// region centre.)
class FreeLineCenterPlacementNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm(bool on) => state = on;
}

final freeLineCenterPlacementProvider =
    NotifierProvider<FreeLineCenterPlacementNotifier, bool>(
        FreeLineCenterPlacementNotifier.new);

/// Id of the currently selected freehand area, or null. Mutually exclusive with
/// the other object selections.
class SelectedFreeAreaNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedFreeAreaProvider =
    NotifierProvider<SelectedFreeAreaNotifier, String?>(
        SelectedFreeAreaNotifier.new);

/// While a freehand area is selected, the id of the point the next map tap
/// relocates, or null for "no placement armed".
class FreeAreaPlacementNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void arm(String? pointId) => state = pointId;
}

final freeAreaPlacementProvider =
    NotifierProvider<FreeAreaPlacementNotifier, String?>(
        FreeAreaPlacementNotifier.new);

/// Id of the currently selected height region, or null. Mutually exclusive with
/// the other object selections.
class SelectedHeightRegionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedHeightRegionProvider =
    NotifierProvider<SelectedHeightRegionNotifier, String?>(
        SelectedHeightRegionNotifier.new);

/// While a height region is selected, whether the next map tap relocates its
/// centre (true) or not (null/false).
class HeightPlacementNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void arm(bool armed) => state = armed;
}

final heightPlacementProvider =
    NotifierProvider<HeightPlacementNotifier, bool>(HeightPlacementNotifier.new);

/// Clears every object selection and disarms every "the next map tap places
/// this point" flag.
///
/// The six `selectedXProvider`s are mutually exclusive **by convention only**
/// (nothing in the providers enforces it), so this is the single place that
/// convention is implemented. Callers outside the map screen (the layers
/// drawer's Elements list) rely on it too — keep it here, not in a widget.
void clearSelection(WidgetRef ref) {
  ref.read(selectedCircleProvider.notifier).select(null);
  ref.read(circlePlacementProvider.notifier).arm(false);
  ref.read(selectedPlaneProvider.notifier).select(null);
  ref.read(planePlacementProvider.notifier).arm(null);
  ref.read(selectedSubspaceProvider.notifier).select(null);
  ref.read(subspacePlacementProvider.notifier).arm(null);
  ref.read(selectedFreeLineProvider.notifier).select(null);
  ref.read(freeLinePlacementProvider.notifier).arm(null);
  ref.read(freeLineCenterPlacementProvider.notifier).arm(false);
  ref.read(selectedFreeAreaProvider.notifier).select(null);
  ref.read(freeAreaPlacementProvider.notifier).arm(null);
  ref.read(selectedHeightRegionProvider.notifier).select(null);
  ref.read(heightPlacementProvider.notifier).arm(false);
}

/// Whether any object is currently selected.
bool hasAnySelection(WidgetRef ref) =>
    ref.read(selectedCircleProvider) != null ||
    ref.read(selectedPlaneProvider) != null ||
    ref.read(selectedSubspaceProvider) != null ||
    ref.read(selectedFreeLineProvider) != null ||
    ref.read(selectedFreeAreaProvider) != null ||
    ref.read(selectedHeightRegionProvider) != null;

/// Selects exactly one object, clearing the others (and any armed placement),
/// and leaves whatever map mode was armed — editing the object is now the job.
///
/// The imported kinds ([ObjectKind.poiSet], [ObjectKind.transitSet],
/// [ObjectKind.borderArea]) are a no-op: imported objects have no editor, so
/// there is no selection provider for them.
void selectObject(WidgetRef ref, ObjectKind kind, String id) {
  clearSelection(ref);
  if (ref.read(mapModeProvider) != MapMode.edit) {
    ref.read(mapModeProvider.notifier).set(MapMode.view);
  }
  switch (kind) {
    case ObjectKind.circle:
      ref.read(selectedCircleProvider.notifier).select(id);
    case ObjectKind.plane:
      ref.read(selectedPlaneProvider.notifier).select(id);
    case ObjectKind.subspace:
      ref.read(selectedSubspaceProvider.notifier).select(id);
    case ObjectKind.freeLine:
      ref.read(selectedFreeLineProvider.notifier).select(id);
    case ObjectKind.freeArea:
      ref.read(selectedFreeAreaProvider.notifier).select(id);
    case ObjectKind.heightRegion:
      ref.read(selectedHeightRegionProvider.notifier).select(id);
    case ObjectKind.poiSet:
    case ObjectKind.transitSet:
    case ObjectKind.borderArea:
      break; // no editor sheet — nothing to select
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
        PendingFocusNotifier.new);

/// A one-shot request to re-run a transit import that didn't finish.
///
/// The Elements list lives in the drawer and has no access to the map screen's
/// import machinery, so it posts the set id here — the same shape
/// [pendingFocusProvider] uses, and for the same reason. No `operator ==`, so
/// asking twice for the same set re-fires.
class TransitRetryRequest {
  const TransitRetryRequest(this.setId);
  final String setId;
}

class PendingTransitRetryNotifier extends Notifier<TransitRetryRequest?> {
  @override
  TransitRetryRequest? build() => null;

  void request(String setId) => state = TransitRetryRequest(setId);
  void clear() => state = null;
}

final pendingTransitRetryProvider =
    NotifierProvider<PendingTransitRetryNotifier, TransitRetryRequest?>(
        PendingTransitRetryNotifier.new);

/// Resolves the effective active layer id given the current layer list:
/// [noActiveLayer] ⇒ none; a still-present selection ⇒ itself; otherwise (nothing
/// chosen yet, or the selection was deleted) falls back to the top-most layer.
String? effectiveActiveLayerId(List<Layer> layers, String? selected) {
  if (selected == noActiveLayer) return null; // explicitly none
  if (layers.isEmpty) return null;
  if (selected != null && layers.any((l) => l.id == selected)) return selected;
  return layers.last.id; // last == top of stack
}
