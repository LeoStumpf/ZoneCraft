import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repository.dart';

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

/// App-wide settings (currently the global uncertainty radius).
final settingsProvider = StreamProvider<AppSetting>((ref) {
  return ref.watch(repositoryProvider).watchSettings();
});

/// Runs once at startup to guarantee a layer exists.
final seedProvider = FutureProvider<String>((ref) {
  return ref.watch(repositoryProvider).ensureDefaultLayer();
});

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

/// Resolves the effective active layer id given the current layer list:
/// [noActiveLayer] ⇒ none; a still-present selection ⇒ itself; otherwise (nothing
/// chosen yet, or the selection was deleted) falls back to the top-most layer.
String? effectiveActiveLayerId(List<Layer> layers, String? selected) {
  if (selected == noActiveLayer) return null; // explicitly none
  if (layers.isEmpty) return null;
  if (selected != null && layers.any((l) => l.id == selected)) return selected;
  return layers.last.id; // last == top of stack
}
