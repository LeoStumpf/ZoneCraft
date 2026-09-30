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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/borders.dart';
import '../data/database.dart';
import '../data/layer_types.dart';
import '../state/providers.dart';
import 'editor_sheet.dart' show scaledPx, textScaleFactorOf;
import 'import_actions.dart';
import 'layer_actions.dart';
import 'layer_tree.dart';
import 'layer_objects_sheet.dart';
import 'map_controls_screen.dart';
import 'object_summary.dart';
import 'osm_reports_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

/// Left-hand drawer for managing layers: list, choose active, visibility,
/// reorder, colour, rename, inverse, delete, and add. Replaces the old bottom
/// sheet so the map stays usable alongside it.
class LayersDrawer extends ConsumerStatefulWidget {
  const LayersDrawer({super.key});

  @override
  ConsumerState<LayersDrawer> createState() => _LayersDrawerState();
}

class _LayersDrawerState extends ConsumerState<LayersDrawer> {
  /// Whether a row is being dragged — while one is, every open folder's end
  /// row grows into a labelled drop slot. At rest it is a 6 dp line (or one
  /// line of text in an empty folder), and hitting a target that thin with a
  /// finger-sized row took pixel aiming: the drop kept landing above the
  /// folder or past it.
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final layersAsync = ref.watch(layersProvider);
    final poiSets =
        ref.watch(poiSetsProvider).asData?.value ?? const <PoiSet>[];
    final poiPoints =
        ref.watch(poiPointsProvider).asData?.value ?? const <PoiPoint>[];
    final circles =
        ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
    final subspaces =
        ref.watch(subspacesProvider).asData?.value ?? const <Subspace>[];
    final subspacePoints =
        ref.watch(subspacePointsProvider).asData?.value ??
        const <SubspacePoint>[];
    final freeLines =
        ref.watch(freeLinesProvider).asData?.value ?? const <FreeLine>[];
    final freeLinePoints =
        ref.watch(freeLinePointsProvider).asData?.value ??
        const <FreeLinePoint>[];
    final freeAreas =
        ref.watch(freeAreasProvider).asData?.value ?? const <FreeArea>[];
    final freeAreaPoints =
        ref.watch(freeAreaPointsProvider).asData?.value ??
        const <FreeAreaPoint>[];
    final heightRegions =
        ref.watch(heightRegionsProvider).asData?.value ??
        const <HeightRegion>[];
    final borderSets =
        ref.watch(borderSetsProvider).asData?.value ?? const <BorderSet>[];
    final borderAreas =
        ref.watch(borderAreasProvider).asData?.value ?? const <BorderArea>[];
    final selected = ref.watch(activeLayerProvider);
    final folders =
        ref.watch(foldersProvider).asData?.value ?? const <Folder>[];
    final repo = ref.read(repositoryProvider);

    // The drawer gets its own messenger: a Scaffold draws its drawer *above*
    // its snackbars, so "Deleted … UNDO" raised from here would otherwise be
    // hidden behind the very drawer it was raised from.
    // Wider at a large font. Material's drawer is a fixed 304 dp, and with
    // the eye, swatch and three trailing controls a layer's name got ~80 dp
    // at 2.0 — "Circl / es 1", broken mid-word. It grows with the text (up to
    // 1.4x) but always leaves a 48 dp strip of map to tap back to.
    final width = MediaQuery.sizeOf(context).width;
    final grow = textScaleFactorOf(context).clamp(1.0, 1.4);
    return Drawer(
      width: math.min(304 * grow, width - 48),
      child: ScaffoldMessenger(
        child: Scaffold(
          body: SafeArea(
            child: layersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (layers) {
                // The drawer renders the tree, top of stack first — see
                // `layer_tree.dart`, which owns every bit of the arithmetic.
                final rows = drawerRows(ref.watch(layerTreeProvider));
                final activeId = effectiveActiveLayerId(layers, selected);

                // What a layer of each type is counted in — the unit you can
                // see on the map, not the rows the table happens to hold: a
                // subspace's points, a borders layer's *areas* rather than its
                // imports (which would read 1). A folder's row sums these.
                int countOf(Layer layer) => switch (layer.type) {
                  'subspace' => () {
                    final ids = subspaces
                        .where((s) => s.layerId == layer.id)
                        .map((s) => s.id)
                        .toSet();
                    return subspacePoints
                        .where((p) => ids.contains(p.subspaceId))
                        .length;
                  }(),
                  'freeline' => () {
                    final ids = freeLines
                        .where((l) => l.layerId == layer.id)
                        .map((l) => l.id)
                        .toSet();
                    return freeLinePoints
                        .where((p) => ids.contains(p.freeLineId))
                        .length;
                  }(),
                  'freearea' => () {
                    final ids = freeAreas
                        .where((a) => a.layerId == layer.id)
                        .map((a) => a.id)
                        .toSet();
                    return freeAreaPoints
                        .where((p) => ids.contains(p.freeAreaId))
                        .length;
                  }(),
                  'height' =>
                    heightRegions.where((r) => r.layerId == layer.id).length,
                  'borders' => () {
                    final ids = borderSets
                        .where((s) => s.layerId == layer.id)
                        .map((s) => s.id)
                        .toSet();
                    return borderAreas
                        .where((a) => ids.contains(a.setId))
                        .length;
                  }(),
                  'poi' => () {
                    final ids = poiSets
                        .where((s) => s.layerId == layer.id)
                        .map((s) => s.id)
                        .toSet();
                    return poiPoints
                        .where((p) => ids.contains(p.poiSetId))
                        .length;
                  }(),
                  _ => circles.where((c) => c.layerId == layer.id).length,
                };

                // The rows under the list: the base map, the guide, the
                // outbox and Settings. Pinned below the list while there is
                // room; on a short drawer (landscape, or a large font) they
                // took all of it — the list got negative height and the
                // Column overflowed — so there they scroll as the list's
                // footer instead, still one flick away.
                final shortDrawer =
                    MediaQuery.sizeOf(context).height < scaledPx(context, 560);
                final footer = <Widget>[
                  const Divider(height: 1),
                  // The base map, pinned as the bottom-most layer: hideable and
                  // opacity-adjustable like any layer, but never reorderable or
                  // deletable.
                  const _BasemapTile(),
                  const Divider(height: 1),
                  // Above Settings: someone who cannot read the map's
                  // buttons opens the drawer looking for words, and this is
                  // the first place they land.
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('What the buttons do'),
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MapControlsScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  // Only once there is something in it. An outbox nobody
                  // has written to is a row explaining a feature, and the
                  // drawer is not where features are explained — the editor
                  // that offers the report is.
                  if (ref.watch(osmReportsProvider).asData?.value.isNotEmpty ??
                      false)
                    ListTile(
                      leading: Badge(
                        isLabelVisible:
                            ref.watch(pendingOsmReportsProvider) > 0,
                        label: Text('${ref.watch(pendingOsmReportsProvider)}'),
                        child: const Icon(Icons.volunteer_activism_outlined),
                      ),
                      title: const Text('OpenStreetMap outbox'),
                      onTap: () {
                        Navigator.pop(context); // close the drawer
                        unawaited(
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OsmReportsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          // Expanded, not Text + Spacer: at a large font the
                          // title alone pushed the four buttons off the edge.
                          Expanded(
                            child: Text(
                              'Layers',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Import layer from file',
                            icon: const Icon(Icons.file_open_outlined),
                            onPressed: () => importLayerFlow(
                              context,
                              repo,
                              layers,
                              ref: ref,
                            ),
                          ),
                          // Export lives here too, not only in Settings: it is an
                          // action on the map, and this is where the map's layers
                          // are.
                          IconButton(
                            tooltip: 'Export all layers',
                            icon: const Icon(Icons.ios_share),
                            onPressed: () => exportAllFlow(context, repo),
                          ),
                          // (Importing a named map feature is not here any more: it
                          // always produces freehand geometry, so it lives on the
                          // freehand layers themselves, next to "Import track…".)
                          PopupMenuButton<String>(
                            tooltip: 'Add layer',
                            onSelected: (type) => type == _kNewFolder
                                ? unawaited(addFolderFlow(ref, folders))
                                : addLayerFlow(context, ref, layers, type),
                            itemBuilder: (_) => [
                              for (final c in kLayerTypeChoices)
                                PopupMenuItem(
                                  value: c.type,
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(c.icon),
                                    title: Text(c.label),
                                    subtitle: c.subtitle == null
                                        ? null
                                        : Text(c.subtitle!),
                                  ),
                                ),
                              // A folder sits apart: it is not an eighth kind of
                              // content but a way to hold the other seven.
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: _kNewFolder,
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.create_new_folder_outlined,
                                  ),
                                  title: Text('Folder'),
                                  subtitle: Text(
                                    'Group layers to hide or invert together',
                                  ),
                                ),
                              ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add),
                                  SizedBox(width: 4),
                                  Text('Add'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // What is active, in words — and, when nothing is, that
                    // this is a state and not an oversight, with the one
                    // gesture that changes it.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        switch (layers
                            .where((l) => l.id == activeId)
                            .firstOrNull) {
                          null =>
                            'No active layer — tap a layer to make it active',
                          final l =>
                            'Active: ${l.name} · tap it again for none',
                        },
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: rows.length,
                        footer: shortDrawer
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: footer,
                              )
                            : null,
                        // Drag starts are placed by hand: an end-of-folder row
                        // is a boundary, and the default would make it a thing
                        // you can pick up.
                        buildDefaultDragHandles: false,
                        onReorderStart: (_) => setState(() => _dragging = true),
                        onReorderEnd: (_) => setState(() => _dragging = false),
                        // `moveDrawerRows` works out the new parent as well as
                        // the new order — a drop joins whatever the row above
                        // it belongs to — and returns the list unchanged when
                        // nothing moved, which is the signal to skip the write.
                        onReorderItem: (oldIndex, newIndex) {
                          final moved = moveDrawerRows(
                            rows,
                            oldIndex,
                            newIndex,
                          );
                          if (identical(moved, rows)) return;
                          unawaited(repo.reorderTree(treeWrites(moved)));
                        },
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          switch (row) {
                            case FolderRow():
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(row.folder.id),
                                index: index,
                                child: _FolderBand(
                                  folder: row.folder,
                                  header: true,
                                  child: _FolderTile(
                                    index: index,
                                    folder: row.folder,
                                    layers: row.layers,
                                    elementCount: row.layers
                                        .map(countOf)
                                        .fold(0, (a, b) => a + b),
                                    canInvert: row.layers.any(
                                      (l) =>
                                          kInvertibleTypes.contains(l.type) &&
                                          countOf(l) > 0,
                                    ),
                                  ),
                                ),
                              );
                            case LayerLineRow():
                              final tile = _LayerTile(
                                index: index,
                                layer: row.layer,
                                layers: layers,
                                objectCount: countOf(row.layer),
                                isActive: row.layer.id == activeId,
                                folder: row.folder,
                              );
                              final inFolder = row.folder;
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(row.layer.id),
                                index: index,
                                child: inFolder == null
                                    ? tile
                                    : _FolderBand(
                                        folder: inFolder,
                                        child: tile,
                                      ),
                              );
                            case FolderEndRow():
                              return _FolderBand(
                                key: ValueKey(row.id),
                                folder: row.folder,
                                end: true,
                                child: _dragging
                                    ? SizedBox(
                                        height: 56,
                                        child: Center(
                                          child: Text(
                                            'Drop here to put it in '
                                            '“${row.folder.name}”',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontStyle: FontStyle.italic,
                                                ),
                                          ),
                                        ),
                                      )
                                    : row.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          6,
                                          8,
                                          8,
                                        ),
                                        child: Text(
                                          'Empty — drag a layer here',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontStyle: FontStyle.italic,
                                              ),
                                        ),
                                      )
                                    : const SizedBox(height: 6),
                              );
                          }
                        },
                      ),
                    ),
                    if (!shortDrawer) ...footer,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The value the Add menu uses for "Folder" — not a layer type, and the one
/// entry in that menu that is not one.
const _kNewFolder = '\u0000folder';

/// A folder's own row: collapse it, hide it, invert it, rename it, delete it.
///
/// It has no colour swatch and no opacity slider, because a folder paints
/// nothing — everything in it goes on drawing itself exactly as it did outside,
/// which is the whole difference between this and the combined layer it
/// replaced.
class _FolderTile extends ConsumerWidget {
  const _FolderTile({
    required this.index,
    required this.folder,
    required this.layers,
    required this.elementCount,
    required this.canInvert,
  });

  /// Position in the drawer's list (top of stack first) — what the drag
  /// handle needs.
  final int index;
  final Folder folder;

  /// Its members, bottom-to-top.
  final List<Layer> layers;
  final int elementCount;

  /// Whether anything in it could be inverted — "Fill outside" is greyed and
  /// says why otherwise, the same rule a layer's own toggle follows.
  final bool canInvert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final theme = Theme.of(context);
    final subtitle = StringBuffer(
      '${layers.length} layer${layers.length == 1 ? '' : 's'}',
    );
    if (elementCount > 0) {
      subtitle.write(' · $elementCount element${elementCount == 1 ? '' : 's'}');
    }
    if (folder.isInverted) subtitle.write(' · inverted');
    if (!folder.isVisible) subtitle.write(' · hidden');
    if (folder.overrideColor && folder.colorArgb != null) {
      subtitle.write(' · one colour');
    }
    if (folder.opacity < 0.995) {
      subtitle.write(' · ${(folder.opacity * 100).round()}% opacity');
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 4),
      horizontalTitleGap: 4,
      // Both leading buttons compact: at full size they took 96 dp before the
      // name, which left a phone about five characters — "Commute" broke as
      // "Commu / te".
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: folder.isCollapsed ? 'Show what is in it' : 'Fold away',
            icon: Icon(
              folder.isCollapsed ? Icons.chevron_right : Icons.expand_more,
            ),
            onPressed: () => unawaited(
              repo.updateFolder(folder.id, isCollapsed: !folder.isCollapsed),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: folder.isVisible ? 'Hide' : 'Show',
            icon: Icon(
              folder.isVisible
                  ? Icons.visibility
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => unawaited(
              repo.updateFolder(folder.id, isVisible: !folder.isVisible),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          // The folder's colour: the rail down its members, and — with "Use
          // folder colour" — the colour they are all drawn in.
          _SwatchButton(
            label: 'Folder colour',
            color: folder.colorArgb == null ? null : Color(folder.colorArgb!),
            onTap: () => unawaited(pickFolderColor(context, repo, folder)),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.folder_outlined, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
      subtitle: Text(subtitle.toString()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            iconSize: 20,
            padding: EdgeInsets.zero,
            onSelected: (choice) {
              switch (choice) {
                case 'rename':
                  unawaited(renameFolderFlow(context, repo, folder));
                case 'color':
                  unawaited(pickFolderColor(context, repo, folder));
                case 'opacity':
                  unawaited(
                    showOpacityDialog(
                      context,
                      title: 'Folder transparency',
                      value: folder.opacity,
                      onChanged: (v) =>
                          unawaited(repo.updateFolder(folder.id, opacity: v)),
                    ),
                  );
                case 'override':
                  unawaited(
                    repo.updateFolder(
                      folder.id,
                      overrideColor: !folder.overrideColor,
                    ),
                  );
                case 'export':
                  unawaited(exportFolder(context, repo, folder));
                case 'invert':
                  unawaited(
                    repo.updateFolder(
                      folder.id,
                      isInverted: !folder.isInverted,
                    ),
                  );
                case 'delete':
                  unawaited(
                    deleteFolderFlow(
                      context,
                      ref,
                      folder,
                      layerCount: layers.length,
                    ),
                  );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'color', child: Text('Colour…')),
              const PopupMenuItem(
                value: 'opacity',
                child: Text('Transparency…'),
              ),
              // The two tick boxes sit between dividers: a checked item is
              // indented for its tick, and next to plain items that read as
              // misalignment rather than as a group of switches.
              const PopupMenuDivider(),
              // A tick box, because it is a mode the folder is in: on, every
              // layer inside draws in the folder's colour; off, each draws in
              // its own again (nothing about the layers was changed).
              CheckedPopupMenuItem(
                value: 'override',
                checked: folder.overrideColor,
                enabled: folder.colorArgb != null || folder.overrideColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Use folder colour for all layers'),
                    Text(
                      folder.colorArgb == null
                          ? 'Pick the folder a colour first.'
                          : 'Off: each layer keeps its own colour.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              CheckedPopupMenuItem(
                value: 'invert',
                checked: folder.isInverted,
                // Greyed, not hidden: it is a "not yet", and the reason says
                // what would make it work.
                enabled: canInvert || folder.isInverted,
                child: canInvert || folder.isInverted
                    ? const Text('Fill outside')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Fill outside'),
                          Text(
                            'Nothing in here has a shape to take the outside '
                            'of yet.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'export',
                enabled: layers.isNotEmpty,
                child: const Text('Export folder…'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Delete folder'),
                  subtitle: Text('Its layers move out and stay'),
                ),
              ),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.drag_handle, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// What marks a folder's rows as one block in the drawer: a rail down the
/// left in the folder's colour and a faint wash of it behind — the header
/// strongest, the members lighter, and the [end] row closing the block with
/// a rounded foot. An indent alone (all a member used to get) was 16 px, and
/// the layer under a folder's last member looked exactly like one of them.
class _FolderBand extends StatelessWidget {
  const _FolderBand({
    super.key,
    required this.folder,
    required this.child,
    this.header = false,
    this.end = false,
  });

  final Folder folder;
  final Widget child;
  final bool header;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = folder.colorArgb == null
        ? scheme.outline
        : Color(folder.colorArgb!);
    return Container(
      margin: EdgeInsets.fromLTRB(4, header ? 4 : 0, 4, end ? 6 : 0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: header ? 0.16 : 0.07),
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: BorderRadius.only(
          topRight: header ? const Radius.circular(8) : Radius.zero,
          bottomRight: end ? const Radius.circular(8) : Radius.zero,
        ),
      ),
      child: child,
    );
  }
}

/// A menu item's text: the label, and under it the one line that says why it
/// can do nothing (or what it will not show yet). A disabled item cannot be
/// pressed to ask, so the answer has to be on it already — the same trade the
/// layer sheet makes, and the opposite of the map's bare icon buttons, which
/// have nowhere to put a sentence and so stay live instead.
Widget _itemLabel(BuildContext context, LayerAction a) {
  final aside = a.unavailable ?? a.note;
  if (aside == null) return Text(a.label);
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(a.label),
      Text(
        aside,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _LayerTile extends ConsumerWidget {
  const _LayerTile({
    required this.index,
    required this.layer,
    required this.layers,
    required this.objectCount,
    required this.isActive,
    this.folder,
  });

  /// Position in the drawer's list (top of stack first) — what the drag
  /// handle needs.
  final int index;
  final Layer layer;

  /// The whole stack, **bottom-to-top** — the order [Repository.watchLayers]
  /// hands out. Every stacking decision is computed against this, never
  /// against the drawer's reversed display list.
  final List<Layer> layers;
  final int objectCount;
  final bool isActive;

  /// The folder this layer is in, or null at the root. Only for how the row is
  /// *shown* — indented, and saying when the folder is overriding it. What the
  /// row's own controls write is always the layer's own setting.
  final Folder? folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final noun = switch (layer.type) {
      'subspace' => 'point',
      'freeline' => 'point',
      'freearea' => 'point',
      'height' => 'area',
      'poi' => 'POI',
      'borders' => 'area',
      _ => 'circle',
    };
    final subtitle = StringBuffer(
      '$objectCount $noun${objectCount == 1 ? '' : 's'}',
    );
    // The level is what a borders layer *is* — two layers reading "12 areas"
    // are otherwise indistinguishable.
    if (layer.type == 'borders') {
      final level = borderLevelByAdminLevel(layer.borderLevel);
      if (level != null) subtitle.write(' · ${level.label.toLowerCase()}');
    }
    // What is *drawn*, said the same way `resolveLayers` computes it — the row
    // shows the layer's own settings, so without this a layer reading "not
    // inverted" inside an inverted folder would be drawn inverted with nothing
    // on the row admitting it.
    final drawnInverted = layer.isInverted != (folder?.isInverted ?? false);
    if (drawnInverted) {
      subtitle.write(
        folder != null && folder!.isInverted
            ? ' · inverted (folder)'
            : ' · inverted',
      );
    }
    if (!layer.isVisible) {
      subtitle.write(' · hidden');
    } else if (folder != null && !folder!.isVisible) {
      subtitle.write(' · hidden (folder)');
    }
    // Show the opacity only when it isn't this type's default (region layers
    // default to a translucent fill, so the default value isn't 100%).
    final defaultOpacity = defaultLayerOpacity(layer.type);
    if ((layer.opacity - defaultOpacity).abs() > 0.005) {
      subtitle.write(' · ${(layer.opacity * 100).round()}% opacity');
    }
    // Watched so the menu re-evaluates "Stations…" when a station import
    // lands; the predicate itself lives in [layerActionsFor].
    ref.watch(poiSetsProvider);

    final scheme = Theme.of(context).colorScheme;
    final dimmed = Theme.of(context).disabledColor;
    final subtitleText = Text(
      isActive ? 'Active · $subtitle' : subtitle.toString(),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always present, for every layer type: the list of this layer's
        // objects. Deliberately not a popup-menu entry — reaching an element
        // must never depend on the layer's type or state.
        IconButton(
          tooltip: 'Elements',
          icon: const Icon(Icons.format_list_bulleted),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 36),
          onPressed: () => _openElements(context, ref),
        ),
        // NB: PopupMenuButton.constraints sizes the *menu*, not the button —
        // keep the button slim with iconSize/padding only.
        //
        // The items come from [layerActionsFor], the one definition the
        // map's layer sheet renders too. Explicit stacking items are there
        // because dragging a tile is fiddly on a phone and impossible to
        // aim at "all the way to the top" with twenty layers.
        Builder(
          builder: (context) {
            final actions = layerActionsFor(context, ref, layer, layers);
            return PopupMenuButton<LayerAction>(
              iconSize: 20,
              padding: EdgeInsets.zero,
              onSelected: (action) {
                // A map-owned action needs the drawer out of the way: the
                // map answers with a form, a preview or a banner, all of
                // which this drawer would cover.
                if (action.needsMap) Navigator.pop(context);
                unawaited(action.run());
              },
              itemBuilder: (_) => [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0 &&
                      layerActionGroup(actions[i].id) !=
                          layerActionGroup(actions[i - 1].id))
                    const PopupMenuDivider(),
                  if (actions[i].checked != null)
                    CheckedPopupMenuItem(
                      value: actions[i],
                      checked: actions[i].checked!,
                      enabled: actions[i].unavailable == null,
                      child: _itemLabel(context, actions[i]),
                    )
                  else
                    PopupMenuItem(
                      value: actions[i],
                      enabled: actions[i].unavailable == null,
                      child: _itemLabel(context, actions[i]),
                    ),
                ],
              ],
            );
          },
        ),
        // A real handle, not a hint of one: dragging anywhere on the tile
        // also reorders (after a long press), but a handle that looks like a
        // handle should grab at once.
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.drag_handle, size: 20),
          ),
        ),
      ],
    );
    // The three controls take ~120 dp at any font size. Beside the name they
    // left it ~90 dp in a narrow drawer at a large font ("PO / I…", "Cir /
    // cl…"), so when the name would get less than about eight characters'
    // room they drop to the subtitle line and the name has the full width.
    return LayoutBuilder(
      builder: (context, box) {
        final roomy = box.maxWidth - 200 >= scaledPx(context, 90);
        return ListTile(
          selected: isActive,
          // The active layer has to be visible at a glance — `selected` alone only
          // tints the text, which is nothing next to four other rows. So: a filled
          // tile, an accent bar on the left, a bold name and "Active" in the
          // subtitle. A hidden layer is dimmed, since it is *not* what is shown.
          selectedTileColor: scheme.primaryContainer,
          selectedColor: scheme.onPrimaryContainer,
          textColor: layer.isVisible ? null : dimmed,
          iconColor: layer.isVisible ? null : dimmed,
          shape: isActive
              ? Border(left: BorderSide(color: scheme.primary, width: 4))
              : null,
          // Three trailing controls (elements, menu, drag) leave little room for the
          // name, so claw back the default paddings and keep every control compact.
          // The folder band's rail already says a member is in a folder; the old
          // 16 dp indent on top of it only took room from the name.
          contentPadding: EdgeInsets.only(
            left: folder == null ? 4 : 8,
            right: 4,
          ),
          horizontalTitleGap: 4,
          minLeadingWidth: 36,
          // Tap to make active; tap the active layer again to have no active layer.
          onTap: () => ref
              .read(activeLayerProvider.notifier)
              .toggle(layer.id, isActive: isActive),
          leading: IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            tooltip: layer.isVisible ? 'Hide' : 'Show',
            icon: Icon(
              layer.isVisible
                  ? Icons.visibility
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () =>
                repo.updateLayer(layer.id, isVisible: !layer.isVisible),
          ),
          title: Row(
            children: [
              _SwatchButton(
                label: 'Layer colour',
                color: Color(layer.colorArgb),
                onTap: () => pickLayerColor(context, ref, layer),
              ),
              const SizedBox(width: 2),
              Icon(typeIcon(layer.type), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  layer.name,
                  // Two lines before an ellipsis: with three trailing controls the
                  // name gets ~80 dp at a large system font, and "Subspac…" does
                  // not say which layer it is.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: isActive
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
              ),
            ],
          ),
          subtitle: roomy
              ? subtitleText
              : Row(
                  children: [
                    Expanded(child: subtitleText),
                    controls,
                  ],
                ),
          trailing: roomy ? controls : null,
        );
      },
    );
  }

  /// Opens this layer's element list and applies whatever it asks for.
  ///
  /// The sheet handles rename/delete itself; what needs the map goes through
  /// [applyElementResult], which ends with the drawer closed so the result is
  /// visible. This is the single place that pops routes for the flow.
  Future<void> _openElements(BuildContext context, WidgetRef ref) async {
    final result = await showLayerObjects(context, layer);
    if (result == null || !context.mounted) return;
    applyElementResult(
      ref,
      layer,
      result,
      closeHost: () => Navigator.pop(context),
    );
  }
}

/// The base map as a pinned bottom "layer": a hide toggle and a transparency
/// control, mirroring a layer tile — but with no rename/colour/reorder/delete,
/// since the map can be hidden but never removed. Its state lives in
/// `AppSettings` (`basemapVisible` / `basemapOpacity`).
class _BasemapTile extends ConsumerWidget {
  const _BasemapTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final settings = ref.watch(settingsProvider).asData?.value;
    final visible = settings?.basemapVisible ?? true;
    final opacity = settings?.basemapOpacity ?? 1.0;
    final subtitle = StringBuffer('Base map');
    if (opacity < 0.999) {
      subtitle.write(' · ${(opacity * 100).round()}% opacity');
    }
    return ListTile(
      leading: IconButton(
        tooltip: visible ? 'Hide' : 'Show',
        icon: Icon(visible ? Icons.visibility : Icons.visibility_off_outlined),
        onPressed: settings == null
            ? null
            : () => repo.updateBasemapVisible(visible: !visible),
      ),
      title: Row(
        children: const [
          Icon(Icons.map_outlined, size: 16),
          SizedBox(width: 6),
          Expanded(child: Text('Map')),
        ],
      ),
      subtitle: Text(subtitle.toString()),
      trailing: IconButton(
        tooltip: 'Transparency',
        icon: const Icon(Icons.opacity),
        onPressed: settings == null
            ? null
            : () => showOpacityDialog(
                context,
                title: 'Map transparency',
                value: opacity,
                onChanged: (v) => repo.updateBasemapOpacity(v),
              ),
      ),
    );
  }
}

/// A row's colour dot, which is also the button that recolours it.
///
/// The dot stays 20 dp — the row is short of width for the name already — but
/// the tap area around it is 32 dp and opaque, and it is announced as a
/// button: a bare 20 dp `GestureDetector` was hard to hit and read as nothing
/// at all to a screen reader.
class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: kSwatchRing),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
