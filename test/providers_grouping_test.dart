import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/state/providers.dart';

/// The grouping providers are what stop the renderer re-scanning every point of
/// every object on every camera frame, so two properties matter and both are
/// easy to break silently:
///
/// * points land under the **right owner** (a mis-keyed group draws one
///   object's outline onto another), and
/// * each group keeps its **query order** — `sortOrder` *is* the ring/polyline
///   vertex order, so a reshuffle turns a polygon into a star.
void main() {
  late AppDatabase db;
  late Repository repo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('freehand-area vertices group under their own area, in order', () async {
    final layerId = await repo.createLayer(
      name: 'A',
      colorArgb: 0xFF0000FF,
      type: 'freearea',
    );
    final a1 = await repo.createFreeArea(layerId: layerId);
    final a2 = await repo.createFreeArea(layerId: layerId);
    await repo.addFreeAreaPoints(a1, const [
      LatLng(1, 1),
      LatLng(2, 2),
      LatLng(3, 3),
    ]);
    await repo.addFreeAreaPoints(a2, const [LatLng(9, 9)]);

    // Let the stream deliver before reading the derived (synchronous) view.
    final byArea = await _settle(
      container,
      freeAreaPointsByAreaProvider,
      freeAreaPointsProvider,
    );

    expect(byArea.keys.toSet(), {a1, a2});
    expect(byArea[a1], hasLength(3));
    expect(byArea[a2], hasLength(1));
    // Vertex order is the ring order — it must survive grouping untouched.
    expect([for (final p in byArea[a1]!) p.lat], [1, 2, 3]);
    expect(byArea[a2]!.single.lat, 9);
  });

  test('an object with no points simply has no group', () async {
    final layerId = await repo.createLayer(
      name: 'A',
      colorArgb: 0xFF0000FF,
      type: 'freearea',
    );
    final empty = await repo.createFreeArea(layerId: layerId);

    final byArea = await _settle(
      container,
      freeAreaPointsByAreaProvider,
      freeAreaPointsProvider,
    );

    // The renderer reads `map[id] ?? const []`, so absence is the contract —
    // not an empty list entry.
    expect(byArea.containsKey(empty), isFalse);
  });

  test('subspace points group per subspace, keeping the main point', () async {
    final layerId = await repo.createLayer(
      name: 'S',
      colorArgb: 0xFF00FF00,
      type: 'subspace',
    );
    final s1 = await repo.createSubspace(layerId: layerId);
    final s2 = await repo.createSubspace(layerId: layerId);
    await repo.addSubspacePoint(subspaceId: s1, lat: 1, lng: 1, isMain: true);
    await repo.addSubspacePoint(subspaceId: s1, lat: 2, lng: 2);
    await repo.addSubspacePoint(subspaceId: s2, lat: 3, lng: 3, isMain: true);

    final bySubspace = await _settle(
      container,
      subspacePointsBySubspaceProvider,
      subspacePointsProvider,
    );

    expect(bySubspace[s1], hasLength(2));
    expect(bySubspace[s2], hasLength(1));
    // Exactly one main per subspace, and it stays with its own subspace.
    expect(bySubspace[s1]!.where((p) => p.isMain).single.lat, 1);
    expect(bySubspace[s2]!.where((p) => p.isMain).single.lat, 3);
  });
}

/// Reads [grouped] once its backing [source] stream has delivered.
///
/// Riverpod disposes a provider nobody listens to, so the subscription has to
/// be held open across the await — reading `.future` on an unlistened
/// StreamProvider tears it down mid-flight.
Future<Map<String, List<T>>> _settle<T, S>(
  ProviderContainer container,
  Provider<Map<String, List<T>>> grouped,
  StreamProvider<List<S>> source,
) async {
  final sub = container.listen(source, (_, _) {});
  final groupedSub = container.listen(grouped, (_, _) {});
  try {
    await container.read(source.future);
    return container.read(grouped);
  } finally {
    sub.close();
    groupedSub.close();
  }
}
