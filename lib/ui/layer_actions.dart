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

/// The one definition of what can be done to a layer.
///
/// A layer's actions used to live inline in the drawer's ⋮ menu — the only
/// place they were offered. Now the map's layer sheet offers the same set, so
/// the set is defined **once**, here, and both surfaces render it: the pure
/// half ([visibleLayerActions]) decides *which* actions a layer gets, in menu
/// order, and is unit-tested against every type; the widget half
/// ([layerActionsFor]) attaches the icon, the label and the `run` body.
///
/// Actions that need the map — an import that draws its preview in the map's
/// sheet slot, a mode that arms a banner — post a [MapRequest] and are marked
/// [LayerAction.needsMap], so whichever surface offers them knows to get out
/// of the way first.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/borders.dart';
import '../data/database.dart';
import '../data/layer_types.dart';
import '../data/poi_sets.dart';
import '../data/repository.dart';
import '../geo/coords.dart';
import '../state/providers.dart';
import 'editor_sheet.dart';
import 'import_actions.dart';
import 'object_summary.dart';
import 'transit_modes_sheet.dart';

/// Everything a layer's menu can offer, in the order it is offered.
enum LayerActionId {
  toTop,
  up,
  down,
  toBottom,
  rename,
  color,
  opacity,
  invert,
  stations,
  fillAreas,
  showNames,
  importPois,
  importStations,
  importBordersVisible,
  importFeature,
  importTrack,
  export,
  combine,
  makeMixed,
  delete,
}

/// The facts [visibleLayerActions] decides on — nothing else, so the decision
/// can be tested without a database.
class LayerActionContext {
  const LayerActionContext({
    required this.type,
    this.isInverted = false,
    this.hasStations = false,
    this.canCombine = false,
    this.isTop = false,
    this.isBottom = false,
    this.fillAreas = false,
    this.showNames = false,
  });

  /// `Layers.type`.
  final String type;
  final bool isInverted;

  /// Whether the layer holds at least one station import — the "Stations…"
  /// filter is over imported stations, and offering it on a layer of cafés
  /// would open an empty sheet.
  final bool hasStations;

  /// Whether another layer exists that could absorb this one.
  final bool canCombine;
  final bool isTop;
  final bool isBottom;
  final bool fillAreas;
  final bool showNames;
}

/// Which actions [c] gets, in menu order.
///
/// The predicates are the drawer's original ones, moved verbatim:
/// - 'height' layers use an above/below toggle, not viewport invert; 'poi' is
///   markers with nothing to invert; 'borders' draws many separate areas, so
///   there is no single region to take the complement of. A combined layer
///   offers it and inverts the **region half** only.
/// - "Import map feature…" fetches a *named place*, so it belongs to the
///   freehand types; "Import track…" is one entry, not one per matching type,
///   because a combined layer holds both freehand types and the same item
///   listed twice is a menu bug.
/// - Converting to a combined layer is one-way on purpose: going *back* is
///   only well defined while the layer holds at most one type.
List<LayerActionId> visibleLayerActions(LayerActionContext c) {
  final t = c.type;
  final freehand = layerTypeHolds(t, kFreeLine) || layerTypeHolds(t, kFreeArea);
  return [
    if (!c.isTop) ...[LayerActionId.toTop, LayerActionId.up],
    if (!c.isBottom) ...[LayerActionId.down, LayerActionId.toBottom],
    LayerActionId.rename,
    LayerActionId.color,
    LayerActionId.opacity,
    if (t == kMixedType || (t != kHeight && t != kPoi && t != kBorders))
      LayerActionId.invert,
    if (c.hasStations) LayerActionId.stations,
    if (t == kBorders) ...[LayerActionId.fillAreas, LayerActionId.showNames],
    if (layerTypeHolds(t, kPoi)) ...[
      LayerActionId.importPois,
      LayerActionId.importStations,
    ],
    if (t == kBorders) LayerActionId.importBordersVisible,
    if (freehand) ...[LayerActionId.importFeature, LayerActionId.importTrack],
    LayerActionId.export,
    if (c.canCombine) LayerActionId.combine,
    if (canBecomeMixed(t)) LayerActionId.makeMixed,
    LayerActionId.delete,
  ];
}

/// The menu group an action belongs to; a divider goes between groups.
/// 0 = stacking, 1 = properties, 2 = imports, 3 = export / structure,
/// 4 = destructive.
int layerActionGroup(LayerActionId id) => switch (id) {
  LayerActionId.toTop ||
  LayerActionId.up ||
  LayerActionId.down ||
  LayerActionId.toBottom => 0,
  LayerActionId.rename ||
  LayerActionId.color ||
  LayerActionId.opacity ||
  LayerActionId.invert ||
  LayerActionId.stations ||
  LayerActionId.fillAreas ||
  LayerActionId.showNames => 1,
  LayerActionId.importPois ||
  LayerActionId.importStations ||
  LayerActionId.importBordersVisible ||
  LayerActionId.importFeature ||
  LayerActionId.importTrack => 2,
  LayerActionId.export || LayerActionId.combine || LayerActionId.makeMixed => 3,
  LayerActionId.delete => 4,
};

/// What the map's active-layer chip reads.
String layerChipLabel(Layer? layer) => layer?.name ?? 'No layer';

/// One button an empty Elements list offers.
typedef EmptyStateAction = ({MapRequestKind kind, IconData icon, String label});

/// What an empty layer of [type] can be filled with, as the map-owned actions
/// its Elements list offers instead of a hint naming buttons elsewhere.
List<EmptyStateAction> emptyStateActions(String type) => [
  if (layerTypeHolds(type, kPoi)) ...[
    (
      kind: MapRequestKind.importPois,
      icon: Icons.travel_explore,
      label: 'Import POIs',
    ),
    (
      kind: MapRequestKind.importStations,
      icon: Icons.directions_transit,
      label: 'Import stations',
    ),
  ],
  if (type == kBorders)
    (
      kind: MapRequestKind.importBordersVisible,
      icon: Icons.public,
      label: 'Import borders in view',
    ),
  if (layerTypeHolds(type, kFreeLine) || layerTypeHolds(type, kFreeArea))
    (
      kind: MapRequestKind.importFeature,
      icon: Icons.search,
      label: 'Import map feature',
    ),
  if (type != kBorders)
    (
      kind: MapRequestKind.enterAdd,
      icon: Icons.add,
      label: type == kPoi ? 'Add POI' : 'Add',
    ),
];

/// One offered action, ready to render as a menu item, a list tile or a
/// switch.
class LayerAction {
  const LayerAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
    this.checked,
    this.needsMap = false,
  });

  final LayerActionId id;
  final IconData icon;
  final String label;

  /// Non-null for a toggle: render as a checked item / switch.
  final bool? checked;

  /// True when [run] only posts a [MapRequest] — the surface offering it must
  /// dismiss itself so the map can answer (a preview, a form, a banner).
  final bool needsMap;
  final Future<void> Function() run;
}

/// The actions [layer] gets, with their bodies.
///
/// [context] is the surface's own context — used for the dialogs the action
/// itself opens (rename, colour, transparency, export, combine) — and must be
/// the *map's* when the caller is a sheet that closes first. Layer deletion and
/// conversion are the two irreversible-looking writes, so each ends with a
/// snackbar carrying UNDO: the undo journal already recorded them, the snackbar
/// only says so.
List<LayerAction> layerActionsFor(
  BuildContext context,
  WidgetRef ref,
  Layer layer,
  List<Layer> layers,
) {
  final repo = ref.read(repositoryProvider);
  final hasStations =
      layerHolds(layer, kPoi) &&
      (ref.read(poiSetsProvider).asData?.value ?? const <PoiSet>[]).any(
        (s) => s.layerId == layer.id && s.isStationImport,
      );
  final ctx = LayerActionContext(
    type: layer.type,
    isInverted: layer.isInverted,
    hasStations: hasStations,
    canCombine: layers.any((l) => canCombineLayers(layer, l)),
    isTop: layers.isEmpty || layers.last.id == layer.id,
    isBottom: layers.isEmpty || layers.first.id == layer.id,
    fillAreas: layer.borderFillAreas,
    showNames: layer.borderShowNames,
  );

  Future<void> move(LayerMove m) async {
    final ids = layers.map((l) => l.id).toList();
    final moved = movedLayerOrder(ids, layer.id, m);
    if (identical(moved, ids)) return;
    await repo.reorderLayers(moved);
  }

  void request(MapRequestKind kind) => ref
      .read(mapRequestProvider.notifier)
      .post(MapRequest(kind, layerId: layer.id));

  LayerAction build(LayerActionId id) => switch (id) {
    LayerActionId.toTop => LayerAction(
      id: id,
      icon: Icons.vertical_align_top,
      label: 'Move to top',
      run: () => move(LayerMove.toTop),
    ),
    LayerActionId.up => LayerAction(
      id: id,
      icon: Icons.arrow_upward,
      label: 'Move up',
      run: () => move(LayerMove.up),
    ),
    LayerActionId.down => LayerAction(
      id: id,
      icon: Icons.arrow_downward,
      label: 'Move down',
      run: () => move(LayerMove.down),
    ),
    LayerActionId.toBottom => LayerAction(
      id: id,
      icon: Icons.vertical_align_bottom,
      label: 'Move to bottom',
      run: () => move(LayerMove.toBottom),
    ),
    LayerActionId.rename => LayerAction(
      id: id,
      icon: Icons.edit_outlined,
      label: 'Rename',
      run: () => renameLayerFlow(context, repo, layer),
    ),
    LayerActionId.color => LayerAction(
      id: id,
      icon: Icons.palette_outlined,
      label: 'Colour',
      run: () => pickLayerColor(context, ref, layer),
    ),
    LayerActionId.opacity => LayerAction(
      id: id,
      icon: Icons.opacity,
      label: 'Transparency…',
      run: () => showOpacityDialog(
        context,
        title: 'Layer transparency',
        value: layer.opacity,
        onChanged: (v) => repo.updateLayer(layer.id, opacity: v),
      ),
    ),
    LayerActionId.invert => LayerAction(
      id: id,
      icon: Icons.flip,
      label: layer.isInverted ? 'Un-invert' : 'Invert',
      checked: layer.isInverted,
      run: () => repo.updateLayer(layer.id, isInverted: !layer.isInverted),
    ),
    LayerActionId.stations => LayerAction(
      id: id,
      icon: Icons.directions_transit,
      label: 'Stations…',
      run: () => showTransitModes(context, layer),
    ),
    LayerActionId.fillAreas => LayerAction(
      id: id,
      icon: Icons.format_color_fill,
      label: 'Colour areas',
      checked: layer.borderFillAreas,
      run: () => repo.updateBorderLayerOptions(
        layer.id,
        fillAreas: !layer.borderFillAreas,
      ),
    ),
    LayerActionId.showNames => LayerAction(
      id: id,
      icon: Icons.label_outline,
      label: 'Show names',
      checked: layer.borderShowNames,
      run: () => repo.updateBorderLayerOptions(
        layer.id,
        showNames: !layer.borderShowNames,
      ),
    ),
    LayerActionId.importPois => LayerAction(
      id: id,
      icon: Icons.travel_explore,
      label: 'Import nearby POIs…',
      needsMap: true,
      run: () async => request(MapRequestKind.importPois),
    ),
    LayerActionId.importStations => LayerAction(
      id: id,
      icon: Icons.directions_transit,
      label: 'Import transit stations…',
      needsMap: true,
      run: () async => request(MapRequestKind.importStations),
    ),
    LayerActionId.importBordersVisible => LayerAction(
      id: id,
      icon: Icons.public,
      label: 'Import borders in view…',
      needsMap: true,
      run: () async => request(MapRequestKind.importBordersVisible),
    ),
    LayerActionId.importFeature => LayerAction(
      id: id,
      icon: Icons.search,
      label: 'Import map feature…',
      needsMap: true,
      run: () async => request(MapRequestKind.importFeature),
    ),
    LayerActionId.importTrack => LayerAction(
      id: id,
      icon: Icons.route_outlined,
      label: 'Import track…',
      needsMap: true,
      run: () async => request(MapRequestKind.importTrack),
    ),
    LayerActionId.export => LayerAction(
      id: id,
      icon: Icons.ios_share,
      label: 'Export layer…',
      run: () => exportSingleLayer(context, repo, layer),
    ),
    LayerActionId.combine => LayerAction(
      id: id,
      icon: Icons.merge,
      label: 'Combine…',
      run: () async {
        final targets = layers
            .where((l) => canCombineLayers(layer, l))
            .toList();
        final mergedInto = await combineLayerFlow(
          context,
          repo,
          layer,
          targets,
        );
        // If the combined-away layer was active, follow to the target.
        if (mergedInto != null && ref.read(activeLayerProvider) == layer.id) {
          ref.read(activeLayerProvider.notifier).select(mergedInto);
        }
      },
    ),
    LayerActionId.makeMixed => LayerAction(
      id: id,
      icon: Icons.layers_outlined,
      label: 'Make combined layer',
      run: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        final container = ProviderScope.containerOf(context);
        await repo.convertLayerToMixed(layer.id);
        await _offerUndo(
          container,
          messenger,
          label: 'Make combined layer',
          message: '“${layer.name}” is now a combined layer',
        );
      },
    ),
    LayerActionId.delete => LayerAction(
      id: id,
      icon: Icons.delete_outline,
      label: 'Delete',
      run: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        final container = ProviderScope.containerOf(context);
        await repo.deleteLayer(layer.id);
        await _offerUndo(
          container,
          messenger,
          label: 'Delete layer',
          message: 'Deleted “${layer.name}”',
        );
      },
    ),
  };

  return [for (final id in visibleLayerActions(ctx)) build(id)];
}

/// Seals the step just written under [label] and offers to take it back.
///
/// The UNDO button performs the *same* undo the chrome button does — never an
/// inverse write, which would land on the stack as a further step. It is
/// guarded on the top of the stack still being this step, so a later edit is
/// never the thing undone. A delete too large for the journal clears the
/// history; then the snackbar simply has no button.
///
/// Takes the container, not a `WidgetRef`: the tile that raised the snackbar
/// is unmounted by the time UNDO is pressed (its layer is gone), and a
/// disposed ref throws.
Future<void> _offerUndo(
  ProviderContainer container,
  ScaffoldMessengerState? messenger, {
  required String label,
  required String message,
}) async {
  final journal = container.read(undoJournalProvider);
  await journal.sealStep(label: label);
  if (messenger == null) return;
  final canUndo = journal.state.undoLabel == label;
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: canUndo
          ? SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                if (journal.state.undoLabel != label) return;
                unawaited(applyUndoIn(container));
              },
            )
          : null,
    ),
  );
}

// --- Stacking ---------------------------------------------------------------

/// Where a "move layer" menu item sends the layer, in map-stack terms:
/// `toTop` is drawn last, over everything else.
enum LayerMove { toTop, up, down, toBottom }

/// [ids] — a layer stack **bottom-to-top** — with [id] moved by [move].
///
/// Pure, because this is the one place the feature can be wrong: the drawer
/// renders the stack upside down (top layer first), so an ordering computed
/// against what is on screen would be reversed. Taking and returning the
/// bottom-to-top order — the order [Repository.watchLayers] hands out and
/// [Repository.reorderLayers] expects back — means the reversal never enters
/// the arithmetic at all.
///
/// Returns [ids] unchanged when [id] is absent or already where it is going,
/// so a caller can use identity to decide whether a write is needed.
List<String> movedLayerOrder(List<String> ids, String id, LayerMove move) {
  final i = ids.indexOf(id);
  if (i < 0) return ids;
  final j = switch (move) {
    LayerMove.toBottom => 0,
    LayerMove.down => i - 1,
    LayerMove.up => i + 1,
    LayerMove.toTop => ids.length - 1,
  }.clamp(0, ids.length - 1);
  if (j == i) return ids;
  return [...ids]
    ..removeAt(i)
    ..insert(j, id);
}

/// Whether [source] may be merged into [target]: a different layer that can
/// hold everything the source does — which a combined layer does for all but
/// `borders` — and, for borders, the same admin level, since one layer holds
/// one level. Mirrors [Repository.combineLayers]'s guard, so the menu never
/// offers a target the repository would refuse.
bool canCombineLayers(Layer source, Layer target) =>
    target.id != source.id &&
    layerContentTypes(source).every((t) => layerTypeHolds(target.type, t)) &&
    (source.type != 'borders' || target.borderLevel == source.borderLevel);

// --- Creating a layer -------------------------------------------------------

/// One entry of the "Add layer" menu.
typedef LayerTypeChoice = ({
  String type,
  IconData icon,
  String label,
  String? subtitle,
});

/// The seven types plus the combined one, in the order the menu offers them.
const kLayerTypeChoices = <LayerTypeChoice>[
  (
    type: kCircles,
    icon: Icons.circle_outlined,
    label: 'Circles layer',
    subtitle: null,
  ),
  (
    type: kSubspace,
    icon: Icons.scatter_plot_outlined,
    label: 'Subspace layer',
    subtitle: null,
  ),
  (
    type: kFreeLine,
    icon: Icons.polyline,
    label: 'Freehand line layer',
    subtitle: null,
  ),
  (
    type: kFreeArea,
    icon: Icons.hexagon_outlined,
    label: 'Freehand area layer',
    subtitle: null,
  ),
  (type: kHeight, icon: Icons.terrain, label: 'Height layer', subtitle: null),
  (type: kPoi, icon: Icons.travel_explore, label: 'POI layer', subtitle: null),
  (type: kBorders, icon: Icons.public, label: 'Borders layer', subtitle: null),
  (
    type: kMixedType,
    icon: Icons.layers_outlined,
    label: 'Combined layer',
    subtitle: 'Holds any mix except borders',
  ),
];

const _palette = <Color>[
  Color(0xFF2196F3),
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];

/// Creates a layer of [type] named after its position and makes it active.
///
/// Borders is the one type with a creation-time sub-choice: a layer holds
/// exactly one admin level, which is what makes its colouring well defined, so
/// the level has to be settled before the layer exists.
Future<void> addLayerFlow(
  BuildContext context,
  WidgetRef ref,
  List<Layer> layers,
  String type,
) async {
  String? level;
  if (type == kBorders) {
    final picked = await showBorderLevelPicker(context);
    if (picked == null) return;
    level = picked.adminLevel;
  }
  final count = layers.length;
  final id = await ref
      .read(repositoryProvider)
      .createLayer(
        name: 'Layer ${count + 1}',
        colorArgb: _palette[count % _palette.length].toARGB32(),
        type: type,
        borderLevel: level,
      );
  ref.read(activeLayerProvider.notifier).select(id);
}

/// Picks the admin level for a new borders layer.
///
/// This is the only creation-time sub-choice any layer type has, and it is
/// deliberate: one layer holds one level, which is what makes "no two
/// neighbours share a colour" mean anything (levels nest, they don't tile).
Future<BorderLevel?> showBorderLevelPicker(BuildContext context) {
  return showDialog<BorderLevel>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Which borders?'),
      children: [
        for (final l in borderLevels)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, l),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text(l.label),
              subtitle: Text(l.blurb),
              isThreeLine: true,
            ),
          ),
      ],
    ),
  );
}

// --- Properties -------------------------------------------------------------

Future<void> renameLayerFlow(
  BuildContext context,
  Repository repo,
  Layer layer,
) async {
  final controller = TextEditingController(text: layer.name);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename layer'),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (s) => Navigator.pop(ctx, s.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name != null && name.isNotEmpty) {
    await repo.updateLayer(layer.id, name: name);
  }
}

/// Recolours [layer], then settles what to do with the elements that carry
/// their own colour and therefore did *not* follow it.
Future<void> pickLayerColor(
  BuildContext context,
  WidgetRef ref,
  Layer layer,
) async {
  Color picked = Color(layer.colorArgb);
  final result = await showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Layer colour'),
      content: SingleChildScrollView(
        child: BlockPicker(
          pickerColor: picked,
          onColorChanged: (c) => picked = c,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, picked),
          child: const Text('Select'),
        ),
      ],
    ),
  );
  if (result == null) return;
  final repo = ref.read(repositoryProvider);
  // Elements that follow the layer re-shade themselves the moment it changes
  // — that is the point of deriving the shade rather than storing it. The
  // ones that were given their own colour are the only open question, and
  // silently overwriting them would throw away deliberate work.
  final overridden = await repo.elementsWithColorOverride(layer.id, layer.type);
  await repo.updateLayer(layer.id, colorArgb: result.toARGB32());
  if (overridden.isEmpty || !context.mounted) return;
  await _askAboutOverrides(context, ref, layer, overridden);
}

/// After a layer recolour: what to do with the elements that carry their own
/// colour and therefore did *not* follow it.
Future<void> _askAboutOverrides(
  BuildContext context,
  WidgetRef ref,
  Layer layer,
  List<String> overridden,
) async {
  final n = overridden.length;
  final answer = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Elements with their own colour'),
      content: Text(
        n == 1
            ? '1 element has a colour of its own, so it kept it. '
                  'Everything else followed the layer.'
            : '$n elements have colours of their own, so they kept them. '
                  'Everything else followed the layer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'keep'),
          child: const Text('Keep them'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'some'),
          child: const Text('Choose…'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'all'),
          child: Text(n == 1 ? 'Reset it' : 'Reset all'),
        ),
      ],
    ),
  );
  if (answer == null || answer == 'keep') return;
  if (answer == 'all') {
    await _clearOverrides(ref, layer, overridden);
    return;
  }
  if (!context.mounted) return;
  final chosen = await _chooseOverrides(context, ref, layer, overridden);
  if (chosen != null && chosen.isNotEmpty) {
    await _clearOverrides(ref, layer, chosen);
  }
}

/// Puts [ids] back on their auto shades.
///
/// Each id's kind comes from its own summary row rather than from the
/// layer's type: a mixed layer's overrides span several tables, so there is
/// no single [ColoredElement] the whole list belongs to.
Future<void> _clearOverrides(
  WidgetRef ref,
  Layer layer,
  List<String> ids,
) async {
  final repo = ref.read(repositoryProvider);
  final kindById = {
    for (final s in ref.read(layerSummariesProvider(layer.id)))
      s.ref.id: s.ref.kind,
  };
  for (final id in ids) {
    final name = kindById[id]?.name;
    final kind = name == null ? null : ColoredElement.forObjectKindName(name);
    if (kind != null) await repo.setElementColor(kind, id, null);
  }
}

/// Ticks off which of the overridden elements should go back to following the
/// layer. Named from the Elements-list summaries, because "3 elements" is not
/// something anyone can act on.
Future<List<String>?> _chooseOverrides(
  BuildContext context,
  WidgetRef ref,
  Layer layer,
  List<String> overridden,
) {
  final ids = overridden.toSet();
  final rows = [
    for (final s in ref.read(layerSummariesProvider(layer.id)))
      if (ids.contains(s.ref.id)) s,
  ];
  final picked = <String>{};
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Follow the layer again'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in rows)
                CheckboxListTile(
                  dense: true,
                  value: picked.contains(s.ref.id),
                  secondary: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(s.colorArgb ?? layer.colorArgb),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  title: Text(s.title, overflow: TextOverflow.ellipsis),
                  onChanged: (on) => setState(() {
                    if (on ?? false) {
                      picked.add(s.ref.id);
                    } else {
                      picked.remove(s.ref.id);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, picked.toList()),
            child: const Text('Reset'),
          ),
        ],
      ),
    ),
  );
}

/// A 0–100 % opacity control: a slider for a quick sweep plus a per-cent
/// field for an exact value (the slider's 5 % steps cannot express 33 %).
/// [onChanged] fires **live** from either so the map updates immediately.
///
/// Used inline by the layer sheet and wrapped in a dialog by
/// [showOpacityDialog]; one widget, so the two cannot disagree on clamping.
class OpacityControl extends StatefulWidget {
  const OpacityControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.inline = false,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Slider and field side by side on one row (the layer sheet), rather than
  /// stacked (the dialog, which is narrow).
  final bool inline;

  @override
  State<OpacityControl> createState() => _OpacityControlState();
}

class _OpacityControlState extends State<OpacityControl> {
  late double _current = widget.value.clamp(0.0, 1.0);
  late final TextEditingController _field = TextEditingController(
    text: (_current * 100).round().toString(),
  );
  final _focus = FocusNode();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = SizedBox(
      width: scaledPx(context, 90),
      child: TextField(
        controller: _field,
        focusNode: _focus,
        decoration: const InputDecoration(
          labelText: 'Opaque',
          suffixText: '%',
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (s) {
          final n = parseDecimal(s);
          if (n == null || !n.isFinite) return;
          final v = (n / 100).clamp(0.0, 1.0);
          setState(() => _current = v);
          widget.onChanged(v);
        },
      ),
    );
    final slider = Slider(
      min: 0,
      max: 1,
      divisions: 20,
      value: _current,
      label: '${(_current * 100).round()}%',
      onChanged: (v) {
        setState(() => _current = v);
        // Mirrored even while the field has focus: the keyboard stays
        // up during a drag, and a stale number there would contradict
        // the slider.
        final t = (v * 100).round().toString();
        _field.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
        widget.onChanged(v);
      },
    );
    if (widget.inline) {
      return Row(
        children: [
          Expanded(child: slider),
          field,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [field]),
        slider,
      ],
    );
  }
}

/// [OpacityControl] in a modal, shared by the drawer's layer tiles and its
/// base-map tile. There is no Save button — the change is already applied.
Future<void> showOpacityDialog(
  BuildContext context, {
  required String title,
  required double value,
  required ValueChanged<double> onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: OpacityControl(value: value, onChanged: onChanged),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
