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

/// The folder arithmetic, away from the widget that renders it.
///
/// Every list here is **bottom-to-top** — the order `watchLayers` emits and
/// `reorderTree` expects — except the drawer rows, which are explicitly the
/// display list. That split is the whole reason this is a pure library.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/layer_types.dart';
import 'package:zonecraft/ui/layer_tree.dart';

Layer _layer(
  String id, {
  String? folderId,
  int sortOrder = 0,
  bool isVisible = true,
  bool isInverted = false,
  String type = kCircles,
}) => Layer(
  id: id,
  name: id,
  colorArgb: 0xFF000000,
  isVisible: isVisible,
  sortOrder: sortOrder,
  type: type,
  isInverted: isInverted,
  opacity: 1,
  borderFillAreas: false,
  borderShowNames: false,
  folderId: folderId,
  createdAt: DateTime(2026),
);

Folder _folder(
  String id, {
  int sortOrder = 0,
  bool isVisible = true,
  bool isInverted = false,
  bool isCollapsed = false,
}) => Folder(
  id: id,
  name: id,
  sortOrder: sortOrder,
  isVisible: isVisible,
  isInverted: isInverted,
  isCollapsed: isCollapsed,
  createdAt: DateTime(2026),
);

void main() {
  group('buildLayerTree', () {
    test('folders and root layers share one ordering space', () {
      final tree = buildLayerTree(
        [_folder('f', sortOrder: 1)],
        [
          _layer('bottom', sortOrder: 0),
          _layer('top', sortOrder: 2),
          _layer('in2', folderId: 'f', sortOrder: 1),
          _layer('in1', folderId: 'f', sortOrder: 0),
        ],
      );
      expect(tree.map((n) => switch (n) {
            FolderNode(:final folder) => folder.id,
            LayerNodeLeaf(:final layer) => layer.id,
          }), ['bottom', 'f', 'top']);
      expect((tree[1] as FolderNode).layers.map((l) => l.id), ['in1', 'in2']);
    });

    test('a layer whose folder is gone shows at the root, never vanishes', () {
      // Losing a layer is worse than showing it in the wrong place.
      final tree = buildLayerTree([], [_layer('orphan', folderId: 'ghost')]);
      expect(tree.single, isA<LayerNodeLeaf>());
      expect(treeLayers(tree).single.id, 'orphan');
    });

    test('ties break on id, so the order is total', () {
      final a = buildLayerTree([], [_layer('b'), _layer('a')]);
      final b = buildLayerTree([], [_layer('a'), _layer('b')]);
      expect(treeLayers(a).map((l) => l.id), ['a', 'b']);
      expect(treeLayers(b).map((l) => l.id), treeLayers(a).map((l) => l.id));
    });
  });

  group('resolveLayers', () {
    test('a folder changes nothing while it is shown and not inverted', () {
      final tree = buildLayerTree(
        [_folder('f')],
        [_layer('a', folderId: 'f', isInverted: true), _layer('b', folderId: 'f',
            sortOrder: 1)],
      );
      final drawn = resolveLayers(tree);
      // What you put in comes out again unchanged — the whole point over the
      // combined layer it replaces.
      expect(drawn.map((l) => l.id), ['a', 'b']);
      expect(drawn[0].isInverted, isTrue);
      expect(drawn[1].isInverted, isFalse);
      expect(drawn.every((l) => l.isVisible), isTrue);
    });

    test('a hidden folder hides everything in it', () {
      final tree = buildLayerTree(
        [_folder('f', isVisible: false)],
        [_layer('a', folderId: 'f'), _layer('root', sortOrder: 1)],
      );
      final drawn = resolveLayers(tree);
      expect(drawn.firstWhere((l) => l.id == 'a').isVisible, isFalse);
      expect(drawn.firstWhere((l) => l.id == 'root').isVisible, isTrue);
    });

    test('an inverted folder flips each member, and un-flips an inverted one',
        () {
      // The switch is a switch: inverting twice is the identity, so a member
      // that was already inverted goes back to normal rather than being
      // silently overridden.
      final tree = buildLayerTree(
        [_folder('f', isInverted: true)],
        [
          _layer('plain', folderId: 'f'),
          _layer('already', folderId: 'f', sortOrder: 1, isInverted: true),
        ],
      );
      final drawn = resolveLayers(tree);
      expect(drawn.firstWhere((l) => l.id == 'plain').isInverted, isTrue);
      expect(drawn.firstWhere((l) => l.id == 'already').isInverted, isFalse);
    });

    test('colour and opacity are never folded in', () {
      final tree = buildLayerTree([_folder('f')], [_layer('a', folderId: 'f')]);
      final drawn = resolveLayers(tree).single;
      expect(drawn.colorArgb, 0xFF000000);
      expect(drawn.opacity, 1);
    });

    test('draw order survives the fold', () {
      final tree = buildLayerTree(
        [_folder('f', sortOrder: 1)],
        [
          _layer('below', sortOrder: 0),
          _layer('above', sortOrder: 2),
          _layer('mid1', folderId: 'f', sortOrder: 0),
          _layer('mid2', folderId: 'f', sortOrder: 1),
        ],
      );
      expect(resolveLayers(tree).map((l) => l.id),
          ['below', 'mid1', 'mid2', 'above']);
    });
  });

  group('drawerRows', () {
    List<LayerNode> sample({bool collapsed = false}) => buildLayerTree(
      [_folder('f', sortOrder: 1, isCollapsed: collapsed)],
      [
        _layer('bottom', sortOrder: 0),
        _layer('top', sortOrder: 2),
        _layer('in1', folderId: 'f', sortOrder: 0),
        _layer('in2', folderId: 'f', sortOrder: 1),
      ],
    );

    test('top of stack first, members under their folder', () {
      expect(drawerRows(sample()).map((r) => r.id),
          ['top', 'f', 'in2', 'in1', 'bottom']);
    });

    test('a collapsed folder shows as one row but still knows its members', () {
      final rows = drawerRows(sample(collapsed: true));
      expect(rows.map((r) => r.id), ['top', 'f', 'bottom']);
      expect((rows[1] as FolderRow).layers.map((l) => l.id), ['in1', 'in2']);
    });
  });

  group('moveDrawerRows', () {
    // top · f · in2 · in1 · bottom
    List<LayerRow> rows() => drawerRows(buildLayerTree(
      [_folder('f', sortOrder: 1)],
      [
        _layer('bottom', sortOrder: 0),
        _layer('top', sortOrder: 2),
        _layer('in1', folderId: 'f', sortOrder: 0),
        _layer('in2', folderId: 'f', sortOrder: 1),
      ],
    ));

    String? parentOf(List<LayerRow> rs, String id) =>
        (rs.firstWhere((r) => r.id == id) as LayerLineRow).folder?.id;

    test('a layer dropped among a folder\'s members joins it', () {
      // The index is the final one, as `onReorderItem` hands it over.
      final moved = moveDrawerRows(rows(), 0, 2); // 'top' among the members
      expect(moved.map((r) => r.id), ['f', 'in2', 'top', 'in1', 'bottom']);
      expect(parentOf(moved, 'top'), 'f');
    });

    test('a layer dropped under a root row stays at the root', () {
      final moved = moveDrawerRows(rows(), 3, 0); // 'in1' to the very top
      expect(moved.map((r) => r.id), ['in1', 'top', 'f', 'in2', 'bottom']);
      expect(parentOf(moved, 'in1'), isNull);
    });

    test('dragging the folder takes its members with it', () {
      final moved = moveDrawerRows(rows(), 1, 4); // 'f' down past 'bottom'
      expect(moved.map((r) => r.id), ['top', 'bottom', 'f', 'in2', 'in1']);
      expect(parentOf(moved, 'in1'), 'f');
      expect(parentOf(moved, 'in2'), 'f');
      expect(parentOf(moved, 'bottom'), isNull);
    });

    test('a folder never lands inside another folder', () {
      final base = drawerRows(buildLayerTree(
        [_folder('f', sortOrder: 0), _folder('g', sortOrder: 1)],
        [_layer('in', folderId: 'f', sortOrder: 0)],
      ));
      // g · f · in  ->  drop 'g' between 'f' and its member
      final moved = moveDrawerRows(base, 0, 2);
      expect(moved.map((r) => r.id), ['f', 'in', 'g']);
      expect(parentOf(moved, 'in'), 'f');
    });

    test('a collapsed folder is opaque: a drop under it goes to the root', () {
      final base = drawerRows(buildLayerTree(
        [_folder('f', sortOrder: 1, isCollapsed: true)],
        [
          _layer('in', folderId: 'f', sortOrder: 0),
          _layer('root', sortOrder: 0),
        ],
      ));
      // f · root  ->  drop 'root' under the collapsed header
      expect(base.map((r) => r.id), ['f', 'root']);
      final moved = moveDrawerRows(base, 1, 1);
      expect(parentOf(moved, 'root'), isNull);
    });

    test('a move that changes nothing returns the same list', () {
      final base = rows();
      expect(identical(moveDrawerRows(base, 2, 2), base), isTrue);
      expect(identical(moveDrawerRows(base, 9, 0), base), isTrue);
    });
  });

  group('treeWrites', () {
    test('re-packs each parent from 0, bottom-to-top', () {
      final writes = treeWrites(drawerRows(buildLayerTree(
        [_folder('f', sortOrder: 7)],
        [
          _layer('bottom', sortOrder: 3),
          _layer('top', sortOrder: 9),
          _layer('in1', folderId: 'f', sortOrder: 4),
          _layer('in2', folderId: 'f', sortOrder: 8),
        ],
      )));
      final by = {for (final w in writes) w.id: w};
      expect((by['bottom']!.sortOrder, by['bottom']!.folderId), (0, null));
      expect((by['f']!.sortOrder, by['f']!.isFolder), (1, true));
      expect((by['top']!.sortOrder, by['top']!.folderId), (2, null));
      expect((by['in1']!.sortOrder, by['in1']!.folderId), (0, 'f'));
      expect((by['in2']!.sortOrder, by['in2']!.folderId), (1, 'f'));
    });

    test('a drop writes the new parent', () {
      final rows = drawerRows(buildLayerTree(
        [_folder('f', sortOrder: 1)],
        [_layer('root', sortOrder: 0), _layer('in', folderId: 'f')],
      ));
      // f · in · root  ->  'root' dropped between the header and its member
      final writes = treeWrites(moveDrawerRows(rows, 2, 1));
      final root = writes.firstWhere((w) => w.id == 'root');
      expect((root.folderId, root.sortOrder), ('f', 1));
    });

    test('round-trips: writing an untouched tree changes nothing', () {
      final tree = buildLayerTree(
        [_folder('f', sortOrder: 1)],
        [
          _layer('bottom', sortOrder: 0),
          _layer('in1', folderId: 'f', sortOrder: 0),
          _layer('in2', folderId: 'f', sortOrder: 1),
        ],
      );
      for (final w in treeWrites(drawerRows(tree))) {
        if (w.isFolder) continue;
        final was = treeLayers(tree).firstWhere((l) => l.id == w.id);
        expect((w.folderId, w.sortOrder), (was.folderId, was.sortOrder),
            reason: w.id);
      }
    });
  });
}
