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

/// Layers grouped into folders: the shape, and every piece of arithmetic that
/// shape needs — all of it pure, none of it in a widget.
///
/// The same rule `movedLayerOrder` is written under, for the same reason: the
/// drawer renders the stack upside down (top of the map first), so anything
/// computed against what is on screen is computed backwards. Everything here
/// takes and returns **bottom-to-top** order — what `watchLayers` hands out —
/// except [drawerRows], which is explicitly the display list and is the one
/// place the reversal happens.
///
/// A folder paints nothing of its own. It offers three things: hide the group,
/// invert the group (which **flips each member's own invert**, rather than
/// compositing them into one region — a folder has no colour to paint a
/// complement in), and fold the group away. [resolveLayers] is where those
/// first two become facts about the layers themselves, so the map, the painter
/// and the hit test never learn that folders exist.
library;

import '../data/database.dart';

/// One item at the root of the stack: a folder with its members, or a layer
/// that belongs to no folder.
sealed class LayerNode {
  const LayerNode();
}

/// A folder and the layers in it, **bottom-to-top**.
final class FolderNode extends LayerNode {
  const FolderNode(this.folder, this.layers);

  final Folder folder;
  final List<Layer> layers;
}

/// A layer sitting at the root, in no folder.
final class LayerNodeLeaf extends LayerNode {
  const LayerNodeLeaf(this.layer);

  final Layer layer;
}

/// The stack as a tree, bottom-to-top.
///
/// Folders and root layers share one ordering space — a folder's `sortOrder` is
/// its position *among root items*, and a member layer's is its position
/// *within its folder*. Ties break on id so the order is total: two rows with
/// the same `sortOrder` is a state only a bug can produce, and one that renders
/// differently on each read would hide it.
///
/// A layer whose `folderId` names a folder that is not there is treated as a
/// root layer rather than dropped — losing a layer is worse than showing it in
/// the wrong place, and `setNull` on the FK means it should never happen.
List<LayerNode> buildLayerTree(List<Folder> folders, List<Layer> layers) {
  final byFolder = <String, List<Layer>>{};
  final roots = <Layer>[];
  final folderIds = {for (final f in folders) f.id};
  for (final l in layers) {
    final fid = l.folderId;
    if (fid == null || !folderIds.contains(fid)) {
      roots.add(l);
    } else {
      (byFolder[fid] ??= <Layer>[]).add(l);
    }
  }
  int byOrder(int aOrder, String aId, int bOrder, String bId) =>
      aOrder != bOrder ? aOrder.compareTo(bOrder) : aId.compareTo(bId);

  final nodes = <LayerNode>[
    for (final f in folders)
      FolderNode(
        f,
        (byFolder[f.id] ?? const <Layer>[]).toList()
          ..sort((a, b) => byOrder(a.sortOrder, a.id, b.sortOrder, b.id)),
      ),
    for (final l in roots) LayerNodeLeaf(l),
  ];
  nodes.sort((a, b) {
    final (ao, ai) = _rootKey(a);
    final (bo, bi) = _rootKey(b);
    return byOrder(ao, ai, bo, bi);
  });
  return nodes;
}

(int, String) _rootKey(LayerNode n) => switch (n) {
  FolderNode(:final folder) => (folder.sortOrder, folder.id),
  LayerNodeLeaf(:final layer) => (layer.sortOrder, layer.id),
};

/// The flat, bottom-to-top list of layers **as the map should draw them**, with
/// each folder folded into its members.
///
/// This is the whole of the rendering change folders needed. Every consumer of
/// layer order — the band sweep, the fill loop, the hit test's `layerZ` — takes
/// this list and goes on knowing nothing about folders:
///
/// * a hidden folder hides its members, because a group you have put away
///   should go away whole;
/// * an inverted folder **flips** each member rather than overriding it, so a
///   member that was already inverted goes back to normal — inverting twice is
///   the identity, which is what makes the folder's switch a switch rather than
///   a setting that silently wins.
///
/// Nothing else is folded in: a member keeps its own colour and its own
/// opacity, because the point of a folder over the old combined layer is that
/// what you put in comes out again unchanged.
List<Layer> resolveLayers(List<LayerNode> tree) => [
  for (final node in tree)
    ...switch (node) {
      LayerNodeLeaf(:final layer) => [layer],
      FolderNode(:final folder, :final layers) => [
        for (final l in layers)
          l.copyWith(
            isVisible: l.isVisible && folder.isVisible,
            isInverted: l.isInverted != folder.isInverted,
          ),
      ],
    },
];

/// Every layer in [tree] in draw order, with its stored settings untouched —
/// what the drawer, the layer sheet and the editors read. [resolveLayers] is
/// for the map alone.
List<Layer> treeLayers(List<LayerNode> tree) => [
  for (final node in tree)
    ...switch (node) {
      LayerNodeLeaf(:final layer) => [layer],
      FolderNode(:final layers) => layers,
    },
];

// --- The drawer's list ------------------------------------------------------

/// One row of the drawer, which renders the stack **top first**.
sealed class LayerRow {
  const LayerRow();

  /// The id of the thing on this row — a folder's or a layer's.
  String get id;
}

/// A folder's own row: the header that hides, inverts and folds it.
final class FolderRow extends LayerRow {
  const FolderRow(this.folder, {required this.layers});

  final Folder folder;

  /// Its members, bottom-to-top — carried even while collapsed, because the
  /// header still has to say how many there are and act on all of them.
  final List<Layer> layers;

  @override
  String get id => folder.id;
}

/// A layer's own row. [folder] is the folder it is in, or null at the root — the
/// row carries it so a drop can read the parent off the row above it without
/// walking back up the list.
final class LayerLineRow extends LayerRow {
  const LayerLineRow(this.layer, {this.folder});

  final Layer layer;
  final Folder? folder;

  @override
  String get id => layer.id;
}

/// The drawer's list, top of stack first: each root item, and under a folder
/// its members — unless it is collapsed, which is the point of collapsing.
List<LayerRow> drawerRows(List<LayerNode> tree) => [
  for (final node in tree.reversed)
    ...switch (node) {
      LayerNodeLeaf(:final layer) => [LayerLineRow(layer)],
      FolderNode(:final folder, :final layers) => [
        FolderRow(folder, layers: layers),
        if (!folder.isCollapsed)
          for (final l in layers.reversed) LayerLineRow(l, folder: folder),
      ],
    },
];

/// [rows] with the row at [from] dropped at [to], and every layer's folder
/// re-derived from where it landed.
///
/// **A dropped layer joins whatever the row above it belongs to.** That is the
/// only rule, and it is the one a drag can express: dropped under a folder's
/// header or among its members it joins that folder, dropped under a root row
/// it stays at the root, dropped at the very top it is at the root. The case
/// the rule cannot express is a folder's *last* member leaving downwards —
/// there is no row below it that means "outside" — which is why the menu keeps
/// "Move out of folder", and why this is a tested function rather than
/// something inferred inside a widget.
///
/// A **collapsed** folder is opaque: a row dropped under it goes to the root,
/// not into a group the user cannot see. Dragging a folder moves its whole
/// block, members and all; a folder never lands inside another folder, because
/// there is only one level.
///
/// Returns [rows] itself when nothing moved, so the caller can use identity to
/// skip the write — the same contract [movedLayerOrder] has.
List<LayerRow> moveDrawerRows(List<LayerRow> rows, int from, int to) {
  if (from < 0 || from >= rows.length || from == to) return rows;
  final moved = rows[from];
  final List<LayerRow> block;
  final rest = [...rows];
  if (moved is FolderRow) {
    // The header and whatever of its members are on screen travel together.
    var end = from + 1;
    while (end < rest.length &&
        rest[end] is LayerLineRow &&
        (rest[end] as LayerLineRow).folder?.id == moved.folder.id) {
      end++;
    }
    block = rest.sublist(from, end);
    rest.removeRange(from, end);
  } else {
    block = [rest.removeAt(from)];
  }
  // `to` indexes the list the user saw; taking the block out shifts everything
  // after it up by its length.
  var at = to > from ? to - (block.length - 1) : to;
  at = at.clamp(0, rest.length);
  // A folder cannot land between another folder's members: it would nest.
  if (moved is FolderRow) {
    while (at > 0 &&
        at < rest.length &&
        rest[at] is LayerLineRow &&
        (rest[at] as LayerLineRow).folder != null) {
      at++;
    }
  }
  rest.insertAll(at, block);
  // A folder brings its own members and takes nobody else's; only a dropped
  // *layer* changes hands.
  if (moved is! LayerLineRow) return rest;
  return [
    for (var i = 0; i < rest.length; i++)
      if (i != at)
        rest[i]
      else
        LayerLineRow(moved.layer, folder: _parentAt(rest, at)),
  ];
}

/// The folder a row dropped at [at] joins: the one the row above it belongs to.
///
/// A **collapsed** folder adopts nothing — a row dropped under it goes to the
/// root rather than into a group the user cannot see.
Folder? _parentAt(List<LayerRow> rows, int at) {
  if (at == 0) return null;
  return switch (rows[at - 1]) {
    FolderRow(:final folder) => folder.isCollapsed ? null : folder,
    LayerLineRow(:final folder) => folder,
  };
}

// --- Writing it back --------------------------------------------------------

/// Where one row ends up: its parent (null at the root) and its order within
/// that parent. A folder's [folderId] is always null and its [sortOrder] is its
/// place among the root items.
typedef TreeWrite = ({
  String id,
  bool isFolder,
  String? folderId,
  int sortOrder,
});

/// The dense ordering [drawerRows] describes, ready for one batch.
///
/// Takes the **display** list (top first) and reverses once, here, so the
/// reversal never enters the arithmetic anywhere else. Orders are re-packed
/// from 0 per parent, the same discipline `reorderLayers` has always had.
List<TreeWrite> treeWrites(List<LayerRow> rows) {
  final out = <TreeWrite>[];
  var root = 0;
  final within = <String, int>{};
  for (final row in rows.reversed) {
    switch (row) {
      case FolderRow():
        out.add((
          id: row.folder.id,
          isFolder: true,
          folderId: null,
          sortOrder: root++,
        ));
      case LayerLineRow(:final layer, :final folder):
        if (folder == null) {
          out.add((
            id: layer.id,
            isFolder: false,
            folderId: null,
            sortOrder: root++,
          ));
        } else {
          final n = within[folder.id] ?? 0;
          within[folder.id] = n + 1;
          out.add((
            id: layer.id,
            isFolder: false,
            folderId: folder.id,
            sortOrder: n,
          ));
        }
    }
  }
  return out;
}
