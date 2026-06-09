import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  test('v2 schema: layer carries type and isInverted with defaults', () async {
    final id = await repo.createLayer(name: 'L', colorArgb: 0xFF0000FF);
    final layer = await (db.select(db.layers)..where((l) => l.id.equals(id)))
        .getSingle();
    expect(layer.type, 'circles');
    expect(layer.isInverted, isFalse);

    await repo.updateLayer(id, isInverted: true);
    final updated = await (db.select(db.layers)..where((l) => l.id.equals(id)))
        .getSingle();
    expect(updated.isInverted, isTrue);
  });

  test('planes table CRUD works', () async {
    final layerId =
        await repo.createLayer(name: 'P', colorArgb: 0xFF00FF00, type: 'planes');
    final planeId = await repo.createPlane(
      layerId: layerId,
      aLat: 48.1,
      aLng: 11.5,
      bLat: 48.2,
      bLng: 11.6,
    );
    var planes = await repo.watchAllPlanes().first;
    expect(planes, hasLength(1));
    expect(planes.single.nearA, isTrue);

    await repo.updatePlane(planeId, nearA: false);
    planes = await repo.watchAllPlanes().first;
    expect(planes.single.nearA, isFalse);

    // Deleting the layer cascades to its planes.
    await repo.deleteLayer(layerId);
    expect(await repo.watchAllPlanes().first, isEmpty);
  });

  test('settings default to 0 and persist updates', () async {
    expect((await repo.watchSettings().first).uncertaintyMeters, 0);
    await repo.updateUncertainty(500);
    expect((await repo.watchSettings().first).uncertaintyMeters, 500);
  });
}
