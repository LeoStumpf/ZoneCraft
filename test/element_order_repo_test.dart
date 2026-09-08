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

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';

/// The storage half of per-element draw order (schema v26). The *painting* half
/// — how a stack becomes passes — is `test/paint_order_test.dart`.
void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() async => db.close());

  Future<String> circle(String layerId) => repo.createCircle(
        layerId: layerId,
        centerLat: 48.1,
        centerLng: 11.5,
        radiusMeters: 500,
      );

  /// The layer's circles as the renderer sees them: back to front.
  Future<List<String>> stack(String layerId) async {
    final rows = await repo.watchAllCircles().first;
    return [
      for (final c in rows)
        if (c.layerId == layerId) c.id,
    ];
  }

  test('a new element lands on top', () async {
    final l = await repo.createLayer(name: 'L', colorArgb: 0xFF43A047);
    final a = await circle(l);
    final b = await circle(l);
    final c = await circle(l);
    expect(await stack(l), [a, b, c]);
  });

  test('z is per layer, so a second layer starts again at the bottom',
      () async {
    final l1 = await repo.createLayer(name: 'A', colorArgb: 0xFF43A047);
    final l2 = await repo.createLayer(name: 'B', colorArgb: 0xFF2196F3);
    await circle(l1);
    final only = await circle(l2);
    final rows = await repo.watchAllCircles().first;
    expect(rows.firstWhere((c) => c.id == only).zOrder, 0);
  });

  group('moveElementZ', () {
    late String l;
    late String a, b, c, d;

    setUp(() async {
      l = await repo.createLayer(name: 'L', colorArgb: 0xFF43A047);
      a = await circle(l);
      b = await circle(l);
      c = await circle(l);
      d = await circle(l);
    });

    test('toFront draws it over everything', () async {
      await repo.moveElementZ(ColoredElement.circle, a, ZMove.toFront);
      expect(await stack(l), [b, c, d, a]);
    });

    test('toBack puts it under everything', () async {
      await repo.moveElementZ(ColoredElement.circle, d, ZMove.toBack);
      expect(await stack(l), [d, a, b, c]);
    });

    test('forward and backward move one step', () async {
      await repo.moveElementZ(ColoredElement.circle, b, ZMove.forward);
      expect(await stack(l), [a, c, b, d]);
      await repo.moveElementZ(ColoredElement.circle, b, ZMove.backward);
      expect(await stack(l), [a, b, c, d]);
    });

    // The renumber is what heals ties left by an import or a combine, so it has
    // to actually be 0..n-1 rather than "some increasing sequence".
    test('a move renumbers the layer gaplessly', () async {
      await repo.moveElementZ(ColoredElement.circle, a, ZMove.toFront);
      final rows = (await repo.watchAllCircles().first)
          .where((r) => r.layerId == l)
          .toList();
      expect([for (final r in rows) r.zOrder], [0, 1, 2, 3]);
    });

    test('a move that changes nothing writes nothing', () async {
      final before = await repo.watchAllCircles().first;
      await repo.moveElementZ(ColoredElement.circle, d, ZMove.toFront);
      await repo.moveElementZ(ColoredElement.circle, d, ZMove.forward);
      await repo.moveElementZ(ColoredElement.circle, a, ZMove.toBack);
      await repo.moveElementZ(ColoredElement.circle, a, ZMove.backward);
      final after = await repo.watchAllCircles().first;
      expect([for (final r in after) r.zOrder],
          [for (final r in before) r.zOrder]);
    });

    test('an unknown id is ignored rather than restacking the layer', () async {
      await repo.moveElementZ(ColoredElement.circle, 'nope', ZMove.toFront);
      expect(await stack(l), [a, b, c, d]);
    });

    // A delete must never restack the survivors — the slots are deliberately
    // left with a gap in them until something is actually moved.
    test('deleting one leaves the others where they were', () async {
      await repo.deleteCircle(b);
      expect(await stack(l), [a, c, d]);
      final rows = (await repo.watchAllCircles().first)
          .where((r) => r.layerId == l)
          .toList();
      expect([for (final r in rows) r.zOrder], [0, 2, 3]);
    });
  });

  test('moving an element to another layer re-seats it on top there', () async {
    final l1 = await repo.createLayer(name: 'A', colorArgb: 0xFF43A047);
    final l2 = await repo.createLayer(name: 'B', colorArgb: 0xFF2196F3);
    await circle(l2);
    await circle(l2);
    final mover = await circle(l1); // z 0 in its own layer

    await repo.updateCircle(mover, layerId: l2);
    // Carrying z 0 across would have buried it under l2's existing pair.
    expect((await stack(l2)).last, mover);
  });

  test('combining stacks one layer above the other, not interleaved', () async {
    final target = await repo.createLayer(name: 'T', colorArgb: 0xFF43A047);
    final source = await repo.createLayer(name: 'S', colorArgb: 0xFF43A047);
    final t1 = await circle(target);
    final t2 = await circle(target);
    final s1 = await circle(source);
    final s2 = await circle(source);

    await repo.combineLayers(sourceId: source, targetId: target);

    // Both sides keep their internal order, and the source arrives on top —
    // which is what "combine this into that" means. Without the lift both
    // layers' independent 0,1 numbering would have shuffled them together.
    expect(await stack(target), [t1, t2, s1, s2]);
  });
}
