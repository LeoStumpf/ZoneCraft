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

/// Resolves the effective active layer id given the current layer list,
/// falling back to the top-most layer when nothing is explicitly selected.
String? effectiveActiveLayerId(List<Layer> layers, String? selected) {
  if (layers.isEmpty) return null;
  if (selected != null && layers.any((l) => l.id == selected)) return selected;
  return layers.last.id; // last == top of stack
}
