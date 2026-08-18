import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/data/serialization.dart';

/// The storage half of per-element colours (schema v22). The colour *maths*
/// lives in `test/element_color_test.dart`.
void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  Future<String> circle(String layerId, {double lat = 48.1}) => repo.createCircle(
    layerId: layerId,
    centerLat: lat,
    centerLng: 11.5,
    radiusMeters: 500,
  );

  test('shades are handed out in creation order, per layer', () async {
    final a = await repo.createLayer(name: 'A', colorArgb: 0xFF43A047);
    final b = await repo.createLayer(name: 'B', colorArgb: 0xFF2196F3);
    final ids = [for (var i = 0; i < 3; i++) await circle(a)];
    final other = await circle(b);

    final rows = await db.select(db.circles).get();
    Circle byId(String id) => rows.firstWhere((c) => c.id == id);
    expect([for (final id in ids) byId(id).colorShade], [0, 1, 2]);
    // The counter is per layer: a new layer starts again at the layer colour.
    expect(byId(other).colorShade, 0);
    expect(rows.every((c) => c.colorArgb == null), isTrue);
  });

  test('deleting an element never re-shades the others', () async {
    // The alternative — numbering by position in the list — would repaint the
    // whole layer in different colours over a single delete.
    final layer = await repo.createLayer(name: 'L', colorArgb: 0xFF43A047);
    final ids = [for (var i = 0; i < 3; i++) await circle(layer)];
    await repo.deleteCircle(ids[1]);
    final rows = await db.select(db.circles).get();
    expect(
      {for (final c in rows) c.id: c.colorShade},
      {ids[0]: 0, ids[2]: 2},
    );
    // …and the next element still gets a slot of its own.
    final fourth = await circle(layer);
    final after = await db.select(db.circles).get();
    expect(after.firstWhere((c) => c.id == fourth).colorShade, 3);
  });

  test('an override can be set, listed and cleared', () async {
    final layer = await repo.createLayer(name: 'L', colorArgb: 0xFF43A047);
    final one = await circle(layer);
    final two = await circle(layer, lat: 48.2);

    expect(await repo.elementsWithColorOverride(layer, 'circles'), isEmpty);

    await repo.setElementColor(ColoredElement.circle, one, 0xFFFF0000);
    expect(await repo.elementsWithColorOverride(layer, 'circles'), [one]);

    // Clearing hands it back to the layer, which is what makes a later layer
    // recolour reach it again.
    await repo.clearElementColors(ColoredElement.circle, [one]);
    expect(await repo.elementsWithColorOverride(layer, 'circles'), isEmpty);
    final rows = await db.select(db.circles).get();
    expect(rows.firstWhere((c) => c.id == two).colorArgb, isNull);
  });

  test('border areas report through their set, not a layer id', () async {
    // BorderAreas hang off an import set, so the override lookup has to join.
    final layer = await repo.createLayer(
      name: 'B',
      colorArgb: 0xFF43A047,
      type: 'borders',
      borderLevel: '8',
    );
    await repo.addBorderSet(
      layerId: layer,
      adminLevel: '8',
      south: 48.0,
      west: 11.4,
      north: 48.2,
      east: 11.7,
      areas: [
        (
          osmId: 1,
          name: 'Maxvorstadt',
          south: 48.1,
          west: 11.5,
          north: 48.2,
          east: 11.6,
          labelLat: 48.15,
          labelLng: 11.55,
          pointCount: 3,
          rings: '[[[48.1,11.5],[48.2,11.5],[48.2,11.6]]]',
          wayIds: <int>[7],
        ),
      ],
    );
    final area = (await db.select(db.borderAreas).get()).single;
    await repo.setElementColor(ColoredElement.borderArea, area.id, 0xFF00FF00);
    expect(await repo.elementsWithColorOverride(layer, 'borders'), [area.id]);
  });

  test('an override survives an export/import round trip', () async {
    final layer = await repo.createLayer(name: 'L', colorArgb: 0xFF43A047);
    final id = await circle(layer);
    await repo.setElementColor(ColoredElement.circle, id, 0xFFFF00FF);

    final json = exportToGeoJson(await repo.exportData());
    await repo.clearAll();
    await repo.importData(importFromGeoJson(json)!);

    final rows = await db.select(db.circles).get();
    expect(rows.single.colorArgb, 0xFFFF00FF);
    // A file *without* a colour leaves the element following its new layer —
    // the auto shade is derived from the layer, so it is not a thing to carry.
    expect(rows.single.colorShade, 0);
  });
}
