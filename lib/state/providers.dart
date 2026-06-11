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

/// App-wide settings (currently the global uncertainty radius).
final settingsProvider = StreamProvider<AppSetting>((ref) {
  return ref.watch(repositoryProvider).watchSettings();
});

/// Runs once at startup to guarantee a layer exists.
final seedProvider = FutureProvider<String>((ref) {
  return ref.watch(repositoryProvider).ensureDefaultLayer();
});

/// Id of the layer that new circles are added to. `null` means "first layer".
class ActiveLayerNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
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

/// Resolves the effective active layer id given the current layer list,
/// falling back to the top-most layer when nothing is explicitly selected.
String? effectiveActiveLayerId(List<Layer> layers, String? selected) {
  if (layers.isEmpty) return null;
  if (selected != null && layers.any((l) => l.id == selected)) return selected;
  return layers.last.id; // last == top of stack
}
