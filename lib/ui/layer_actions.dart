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
import 'theme.dart';
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
  moveToFolder,
  moveOutOfFolder,
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
    this.inFolder = false,
    this.anyFolder = false,
    this.isTop = false,
    this.isBottom = false,
    this.fillAreas = false,
    this.showNames = false,
    this.holdsAnything = true,
    this.holdsInvertible = true,
    this.holdsRegionFill = true,
    this.holdsBorderAreas = true,
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

  /// Whether this layer is in a folder — "Move out of folder" is about a fact,
  /// not a possibility, so it is hidden rather than greyed when it is not.
  final bool inFolder;

  /// Whether any folder exists to move into.
  final bool anyFolder;
  final bool isTop;
  final bool isBottom;
  final bool fillAreas;
  final bool showNames;

  // --- What the layer actually holds ----------------------------------------
  //
  // [visibleLayerActions] never reads these: *which* actions a layer offers is
  // a fact about its type, and an option that came and went as rows were added
  // would be unfindable. They answer the second question,
  // [layerActionUnavailable] — whether the option offered can do anything yet.
  // Each defaults to true (assume it can act), so a context built for a
  // which-actions test is unaffected; `layerActionsFor` always passes them.

  /// Whether the layer holds at least one element of any kind.
  final bool holdsAnything;

  /// Whether it holds a [kInvertibleTypes] element — what "Fill outside" needs.
  final bool holdsInvertible;

  /// Whether it holds anything drawn as a **fill**, which is all that layer
  /// transparency acts on: the invertible types plus `height`.
  final bool holdsRegionFill;

  /// Whether a borders layer holds at least one area — a set whose import came
  /// back empty holds none, and then there is nothing to colour or to name.
  final bool holdsBorderAreas;
}

/// Which actions [c] gets, in menu order.
///
/// The predicates are the drawer's original ones, moved verbatim:
/// - 'height' layers use an above/below toggle, not viewport invert; 'poi' is
///   markers with nothing to invert; 'borders' draws many separate areas, so
///   there is no single region to take the complement of.
/// - "Import map feature…" fetches a *named place*, so it belongs to the
///   freehand types; "Import track…" is one entry, not one per matching type,
///   because the same item listed twice is a menu bug.
/// - Moving into a folder is always offered and greyed when there are no
///   folders; moving *out* only appears when the layer is in one, because
///   there is no "not yet" about it.
List<LayerActionId> visibleLayerActions(LayerActionContext c) {
  final t = c.type;
  final freehand = layerTypeHolds(t, kFreeLine) || layerTypeHolds(t, kFreeArea);
  return [
    if (!c.isTop) ...[LayerActionId.toTop, LayerActionId.up],
    if (!c.isBottom) ...[LayerActionId.down, LayerActionId.toBottom],
    LayerActionId.rename,
    LayerActionId.color,
    LayerActionId.opacity,
    // [kInvertibleTypes] is the same list the greying reads, so the menu item
    // and "can it do anything?" cannot disagree about what invert needs.
    if (kInvertibleTypes.contains(t)) LayerActionId.invert,
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
    // Always offered, greyed with a reason when there is no folder yet — the
    // remedy is one tap away in the same menu, which is what makes it a "not
    // yet" rather than a "never".
    LayerActionId.moveToFolder,
    if (c.inFolder) LayerActionId.moveOutOfFolder,
    LayerActionId.delete,
  ];
}

/// Why [id] would do nothing on a layer with these facts, or null when it
/// works.
///
/// The second half of the promise [visibleLayerActions] starts. *Which* options
/// a layer has follows from its type, so the list is stable and learnable; that
/// leaves the options that are offered but, right now, cannot do anything — and
/// those used to report success and change nothing. "Fill outside" on a layer
/// of nothing but POI markers wrote `isInverted` and left the map
/// byte-identical, because markers have no outside.
///
/// The answer names a remedy rather than a fault, and it is written **once**,
/// here: `map_screen` shows it when the quick-toggle FAB is pressed, and the
/// layer sheet and the drawer menu — which have room — print it under the
/// option and disable the row. A control with nowhere to put the text stays
/// live and answers the press; a control with room says it before the press.
String? layerActionUnavailable(LayerActionId id, LayerActionContext c) {
  switch (id) {
    case LayerActionId.invert:
      // Switching a state **off** is always worth doing, whatever the layer
      // holds: the flag is stored, and a layer left inverted with nothing to
      // invert would fill the whole viewport the moment a shape was merged
      // into it — with the one control that could undo that greyed out. Only
      // turning it *on* can be pointless.
      if (c.isInverted) return null;
      if (!c.holdsAnything) {
        return 'This layer is empty — ${fillLayerWith(c.type)}.';
      }
      if (!c.holdsInvertible) {
        // Unreachable while every type that offers invert holds nothing *but*
        // invertible elements — kept because that is a fact about the type
        // list, not about this function.
        return 'Fill outside needs a shape to take the outside of — add a '
            'circle, line or area first.';
      }
      return null;

    case LayerActionId.fillAreas:
      if (c.fillAreas) return null; // see the note on invert above
      if (!c.holdsBorderAreas) {
        return 'There are no areas here yet — import some borders first.';
      }
      return null;

    case LayerActionId.showNames:
      if (c.showNames) return null;
      if (!c.holdsBorderAreas) {
        return 'There are no areas here yet — import some borders first.';
      }
      return null;

    // Everything else acts whenever it is offered: the stacking items are
    // hidden at the ends, "Combine…" needs a target to appear at all,
    // "Stations…" needs a station import, and an import, a rename, a colour,
    // an export or a delete always does something.
    case LayerActionId.toTop:
    case LayerActionId.up:
    case LayerActionId.down:
    case LayerActionId.toBottom:
    case LayerActionId.rename:
    case LayerActionId.color:
    case LayerActionId.opacity:
    case LayerActionId.stations:
    case LayerActionId.importPois:
    case LayerActionId.importStations:
    case LayerActionId.importBordersVisible:
    case LayerActionId.importFeature:
    case LayerActionId.importTrack:
    case LayerActionId.moveToFolder:
      if (!c.anyFolder) {
        return 'There are no folders yet — make one from the layers menu '
            'first.';
      }
      return null;

    case LayerActionId.export:
    case LayerActionId.combine:
    case LayerActionId.moveOutOfFolder:
    case LayerActionId.delete:
      return null;
  }
}

/// Why the transparency you set is not visible on this layer *yet*, or null.
///
/// Deliberately **not** part of [layerActionUnavailable]: transparency is a
/// value, not a command. It is stored and takes effect the moment the layer has
/// a fill, so disabling the slider would refuse a setting that is perfectly
/// valid to make in advance — the surface shows this line beside a live
/// control instead.
///
/// Only the two surprising cases are worth a line. An *empty* layer fading
/// nothing is self-evident; a layer full of markers, or a borders layer drawn
/// as outlines, is not.
String? layerOpacityNote(LayerActionContext c) {
  if (!c.holdsAnything) return null;
  if (c.type == kBorders && !c.fillAreas) {
    return 'Transparency fades the area fill — turn on “Colour areas” to see '
        'it.';
  }
  return null;
}

/// A line worth saying beside [id] even though it works, or null.
///
/// The counterpart to [layerActionUnavailable]: that one disables, this one
/// only explains. Today it is transparency alone — see [layerOpacityNote].
String? layerActionNote(LayerActionId id, LayerActionContext c) =>
    id == LayerActionId.opacity ? layerOpacityNote(c) : null;

/// The remedy for an empty layer, in its own noun: what would fill it.
String fillLayerWith(String type) => switch (type) {
  kCircles => 'add a circle first',
  kSubspace => 'add a subspace first',
  kFreeLine => 'draw or add a line first',
  kFreeArea => 'draw or add an area first',
  kHeight => 'add a height area first',
  kPoi => 'import or place some POIs first',
  kBorders => 'import some borders first',
  _ => 'add something to it first',
};

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
  LayerActionId.export ||
  LayerActionId.combine ||
  LayerActionId.moveToFolder ||
  LayerActionId.moveOutOfFolder => 3,
  LayerActionId.delete => 4,
};

/// What the map's active-layer chip reads.
String layerChipLabel(Layer? layer) => layer?.name ?? 'No layer';

/// One button an empty Elements list offers.
typedef EmptyStateAction = ({MapRequestKind kind, IconData icon, String label});

/// What an empty layer of [type] can be filled with, as the map-owned actions
/// its Elements list offers instead of a hint naming buttons elsewhere.
List<EmptyStateAction> emptyStateActions(String type) => [
  ...[
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
  ],
];

/// One offered action, ready to render as a menu item, a list tile or a
/// switch.
class LayerAction {
  const LayerAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.description,
    required this.run,
    this.checked,
    this.needsMap = false,
    this.unavailable,
    this.note,
  });

  final LayerActionId id;
  final IconData icon;
  final String label;

  /// One line saying what the option *does* — for a toggle, what is true once
  /// it is on.
  ///
  /// The label alone is not enough anywhere it is read. On the map the action
  /// is a bare icon whose tooltip was the menu label, ellipsis and all, so
  /// "Invert" had to answer "invert what, into what?" on its own. This is the
  /// text the layer sheet shows as a subtitle, the map says in a one-line tip
  /// after the button is pressed, and the button guide lists — written once
  /// here, like the label beside it.
  final String description;

  /// Non-null for a toggle: render as a checked item / switch.
  final bool? checked;

  /// True when [run] only posts a [MapRequest] — the surface offering it must
  /// dismiss itself so the map can answer (a preview, a form, a banner).
  final bool needsMap;
  final Future<void> Function() run;

  /// Why pressing this would do nothing right now, or null when it works —
  /// [layerActionUnavailable], attached centrally so no action body can forget
  /// it. A surface with room prints it and disables the row; the map's bare
  /// icon button stays live and says it on the press.
  final String? unavailable;

  /// Something worth saying about this action while it still works —
  /// [layerActionNote]. Printed where the option is, never disabling it.
  final String? note;

  /// This action with its two explanations attached. Only [layerActionsFor]
  /// calls it, which is what keeps them off the twenty action bodies.
  LayerAction withReasons({String? unavailable, String? note}) => LayerAction(
    id: id,
    icon: icon,
    label: label,
    description: description,
    run: run,
    checked: checked,
    needsMap: needsMap,
    unavailable: unavailable,
    note: note,
  );
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
  // What the layer holds, per content type — read once here and asked of
  // [layerActionUnavailable], so "is this option greyed?" is decided in one
  // pure place rather than by each surface.
  bool holds(String type) {
    if (!layerTypeHolds(layer.type, type)) return false;
    bool anyIn<T>(List<T> rows, String Function(T) layerIdOf) =>
        rows.any((r) => layerIdOf(r) == layer.id);
    return switch (type) {
      kCircles => anyIn(
        ref.read(circlesProvider).asData?.value ?? const <Circle>[],
        (c) => c.layerId,
      ),
      kSubspace => anyIn(
        ref.read(subspacesProvider).asData?.value ?? const <Subspace>[],
        (s) => s.layerId,
      ),
      kFreeLine => anyIn(
        ref.read(freeLinesProvider).asData?.value ?? const <FreeLine>[],
        (l) => l.layerId,
      ),
      kFreeArea => anyIn(
        ref.read(freeAreasProvider).asData?.value ?? const <FreeArea>[],
        (a) => a.layerId,
      ),
      kHeight => anyIn(
        ref.read(heightRegionsProvider).asData?.value ?? const <HeightRegion>[],
        (r) => r.layerId,
      ),
      kPoi => anyIn(
        ref.read(poiSetsProvider).asData?.value ?? const <PoiSet>[],
        (s) => s.layerId,
      ),
      kBorders => anyIn(
        ref.read(borderSetsProvider).asData?.value ?? const <BorderSet>[],
        (s) => s.layerId,
      ),
      _ => false,
    };
  }

  // A set can exist with no areas in it — an import that came back empty — so
  // the areas are counted rather than the sets.
  bool holdsBorderAreas() {
    if (!layerTypeHolds(layer.type, kBorders)) return false;
    final sets =
        (ref.read(borderSetsProvider).asData?.value ?? const <BorderSet>[])
            .where((s) => s.layerId == layer.id)
            .map((s) => s.id)
            .toSet();
    if (sets.isEmpty) return false;
    return (ref.read(borderAreasProvider).asData?.value ?? const <BorderArea>[])
        .any((a) => sets.contains(a.setId));
  }

  final contentTypes = layerContentTypes(layer);
  final ctx = LayerActionContext(
    type: layer.type,
    isInverted: layer.isInverted,
    hasStations: hasStations,
    canCombine: layers.any((l) => canCombineLayers(layer, l)),
    inFolder: layer.folderId != null,
    anyFolder: (ref.read(foldersProvider).asData?.value ?? const <Folder>[])
        .isNotEmpty,
    isTop: layers.isEmpty || layers.last.id == layer.id,
    isBottom: layers.isEmpty || layers.first.id == layer.id,
    fillAreas: layer.borderFillAreas,
    showNames: layer.borderShowNames,
    holdsAnything: contentTypes.any(holds),
    holdsInvertible: kInvertibleTypes.any(holds),
    // The invertible types plus `height`: everything `region_layer` draws as a
    // fill, and so everything the layer's opacity acts on.
    holdsRegionFill: [...kInvertibleTypes, kHeight].any(holds),
    holdsBorderAreas: holdsBorderAreas(),
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
      description: 'Draw this layer above every other one.',
      run: () => move(LayerMove.toTop),
    ),
    LayerActionId.up => LayerAction(
      id: id,
      icon: Icons.arrow_upward,
      label: 'Move up',
      description: 'Draw this layer one place higher.',
      run: () => move(LayerMove.up),
    ),
    LayerActionId.down => LayerAction(
      id: id,
      icon: Icons.arrow_downward,
      label: 'Move down',
      description: 'Draw this layer one place lower.',
      run: () => move(LayerMove.down),
    ),
    LayerActionId.toBottom => LayerAction(
      id: id,
      icon: Icons.vertical_align_bottom,
      label: 'Move to bottom',
      description: 'Draw this layer below every other one.',
      run: () => move(LayerMove.toBottom),
    ),
    LayerActionId.rename => LayerAction(
      id: id,
      icon: Icons.edit_outlined,
      label: 'Rename',
      description: 'Give this layer a different name.',
      run: () => renameLayerFlow(context, repo, layer),
    ),
    LayerActionId.color => LayerAction(
      id: id,
      icon: Icons.palette_outlined,
      label: 'Colour',
      description: "Pick the colour this layer's elements are drawn in.",
      run: () => pickLayerColor(context, ref, layer),
    ),
    LayerActionId.opacity => LayerAction(
      id: id,
      icon: Icons.opacity,
      label: 'Transparency…',
      description: 'Make the whole layer more or less see-through.',
      run: () => showOpacityDialog(
        context,
        title: 'Layer transparency',
        value: layer.opacity,
        onChanged: (v) => repo.updateLayer(layer.id, opacity: v),
      ),
    ),
    LayerActionId.invert => LayerAction(
      id: id,
      // Not `flip`, which reads as "mirror". This is about inside versus
      // outside, not left versus right.
      icon: Icons.select_all,
      // Named by its result, not its operation: "Invert" made the user ask
      // invert *what*, into what.
      label: layer.isInverted ? 'Fill inside' : 'Fill outside',
      description: layer.isInverted
          ? 'Colour this layer’s shapes, rather than everything around them.'
          : 'Colour everything except this layer’s shapes.',
      checked: layer.isInverted,
      run: () => repo.updateLayer(layer.id, isInverted: !layer.isInverted),
    ),
    LayerActionId.stations => LayerAction(
      id: id,
      icon: Icons.directions_transit,
      label: 'Stations…',
      description: 'Choose which kinds of station are shown on the map.',
      run: () => showTransitModes(context, layer),
    ),
    LayerActionId.fillAreas => LayerAction(
      id: id,
      icon: Icons.format_color_fill,
      label: 'Colour areas',
      description:
          'Give each area a colour, chosen so no two neighbours match.',
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
      description: "Print each area's name across it.",
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
      description:
          'Fetch places of one kind — cafés, benches — around a point.',
      needsMap: true,
      run: () async => request(MapRequestKind.importPois),
    ),
    LayerActionId.importStations => LayerAction(
      id: id,
      icon: Icons.directions_transit,
      label: 'Import transit stations…',
      description: 'Fetch public-transport stops inside a box you draw.',
      needsMap: true,
      run: () async => request(MapRequestKind.importStations),
    ),
    LayerActionId.importBordersVisible => LayerAction(
      id: id,
      icon: Icons.public,
      label: 'Import borders in view…',
      description: 'Fetch administrative areas covering the current view.',
      needsMap: true,
      run: () async => request(MapRequestKind.importBordersVisible),
    ),
    LayerActionId.importFeature => LayerAction(
      id: id,
      icon: Icons.search,
      label: 'Import map feature…',
      description:
          'Search OpenStreetMap by name and import the shape it finds.',
      needsMap: true,
      run: () async => request(MapRequestKind.importFeature),
    ),
    LayerActionId.importTrack => LayerAction(
      id: id,
      icon: Icons.route_outlined,
      label: 'Import track…',
      description: 'Read a GPX, KML or GeoJSON file into this layer.',
      needsMap: true,
      run: () async => request(MapRequestKind.importTrack),
    ),
    LayerActionId.export => LayerAction(
      id: id,
      icon: Icons.ios_share,
      label: 'Export layer…',
      description: 'Save this one layer to a file, or share it.',
      run: () => exportSingleLayer(context, repo, layer),
    ),
    LayerActionId.combine => LayerAction(
      id: id,
      icon: Icons.merge,
      label: 'Combine…',
      description: 'Move everything from this layer into another one.',
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
    LayerActionId.moveToFolder => LayerAction(
      id: id,
      icon: Icons.drive_file_move_outlined,
      label: 'Move to folder…',
      description: 'Put this layer in a folder, to hide or invert as a group.',
      run: () async {
        final folders =
            ref.read(foldersProvider).asData?.value ?? const <Folder>[];
        final target = await showFolderPicker(context, folders);
        if (target == null) return;
        await repo.moveLayerToFolder(layer.id, target);
      },
    ),
    LayerActionId.moveOutOfFolder => LayerAction(
      id: id,
      icon: Icons.drive_file_move_outline,
      label: 'Move out of folder',
      description: 'Take this layer back out on its own, unchanged.',
      run: () => repo.moveLayerToFolder(layer.id, null),
    ),
    LayerActionId.delete => LayerAction(
      id: id,
      icon: Icons.delete_outline,
      label: 'Delete',
      description: 'Remove the layer and everything on it.',
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

  return [
    for (final id in visibleLayerActions(ctx))
      build(id).withReasons(
        unavailable: layerActionUnavailable(id, ctx),
        note: layerActionNote(id, ctx),
      ),
  ];
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
/// hold everything the source does, and — for borders — the same admin level,
/// since one layer holds
/// one level. Mirrors [Repository.combineLayers]'s guard, so the menu never
/// offers a target the repository would refuse.
bool canCombineLayers(Layer source, Layer target) =>
    target.id != source.id &&
    layerContentTypes(source).every((t) => layerTypeHolds(target.type, t)) &&
    (source.type != 'borders' || target.borderLevel == source.borderLevel);

/// Which folder to put a layer in. Null when the sheet is dismissed.
Future<String?> showFolderPicker(BuildContext context, List<Folder> folders) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Move to folder')),
          const Divider(height: 1),
          for (final f in folders.reversed)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f.name),
              onTap: () => Navigator.pop(ctx, f.id),
            ),
        ],
      ),
    ),
  );
}

/// Makes a folder and leaves it where it was made — on top, empty, waiting for
/// something to be dragged in.
Future<void> addFolderFlow(WidgetRef ref, List<Folder> folders) async {
  await ref
      .read(repositoryProvider)
      .createFolder(name: 'Folder ${folders.length + 1}');
}

Future<void> renameFolderFlow(
  BuildContext context,
  Repository repo,
  Folder folder,
) async {
  final name = await _askName(context, 'Rename folder', folder.name);
  if (name == null || name.isEmpty) return;
  await repo.updateFolder(folder.id, name: name);
}

/// Deletes the folder. **Its layers stay** — back at the root, unchanged —
/// which is the whole difference between a folder and the combined layer it
/// replaced, and worth saying in the snackbar rather than leaving to be
/// discovered.
Future<void> deleteFolderFlow(
  BuildContext context,
  WidgetRef ref,
  Folder folder, {
  required int layerCount,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final container = ProviderScope.containerOf(context);
  await ref.read(repositoryProvider).deleteFolder(folder.id);
  await _offerUndo(
    container,
    messenger,
    label: 'Delete folder',
    message: layerCount == 0
        ? 'Deleted “${folder.name}”'
        : 'Deleted “${folder.name}” · its '
              '${layerCount == 1 ? 'layer' : '$layerCount layers'} moved out',
  );
}

// --- Creating a layer -------------------------------------------------------

/// One entry of the "Add layer" menu.
typedef LayerTypeChoice = ({
  String type,
  IconData icon,
  String label,
  String? subtitle,
});

/// The seven types, in the order the menu offers them.
///
/// Every subtitle says what the layer *is for*, never how it is built. This is
/// the one menu a beginner cannot avoid — you need a layer before you can draw
/// anything — and every entry used to be a bare noun with `subtitle: null`.
/// Several of those nouns are jargon: "subspace" is a Voronoi cell, a word that
/// appears six times in this codebase and not once in the UI; "height" reads as
/// z-order in a list of layers, which is exactly what it is not.
///
/// The app already writes these explanations well — `subspace_editor` says
/// "everywhere closer to the main point than to any other point" — but only
/// *after* you have created one and can see it. Saying it at the moment of
/// choosing is the same sentence, one step earlier.
///
/// The precedent is this project's own best naming decision: "Invert" became
/// "Fill outside", named by result rather than operation. Same rule here.
const kLayerTypeChoices = <LayerTypeChoice>[
  (
    type: kCircles,
    icon: Icons.circle_outlined,
    label: 'Circles layer',
    subtitle:
        'Everything within a distance of a point — "within 2 km of '
        'the town hall".',
  ),
  (
    type: kSubspace,
    icon: Icons.scatter_plot_outlined,
    label: 'Nearest-point layer',
    subtitle:
        'Everywhere closer to one point than to any of the others. Two '
        'points split the map in half.',
  ),
  (
    type: kFreeLine,
    icon: Icons.polyline,
    label: 'Freehand line layer',
    subtitle: 'Draw a line to cut an area in two, and keep one side.',
  ),
  (
    type: kFreeArea,
    icon: Icons.hexagon_outlined,
    label: 'Freehand area layer',
    subtitle: 'Draw any shape by hand and fill it.',
  ),
  (
    type: kHeight,
    icon: Icons.terrain,
    label: 'Ground-height layer',
    subtitle:
        'Ground above or below an elevation you choose. Needs the '
        'network once, then works offline.',
  ),
  (
    type: kPoi,
    icon: Icons.place_outlined,
    label: 'Places layer',
    subtitle:
        'Import cafés, benches or stations from OpenStreetMap, or place '
        'your own markers.',
  ),
  (
    type: kBorders,
    icon: Icons.public,
    label: 'Borders layer',
    subtitle:
        'Download real district, city or country outlines once and keep '
        'them offline.',
  ),
];

/// What a new layer is coloured, in creation order.
///
/// These are osm-carto's own **icon inks** — the saturated half of the style,
/// where it keeps its transport blue, its health red, its leisure green. Layer
/// colours are this app's foreground and have to stay apart from each other and
/// from the map, so they are drawn from the style's ink and never from its land
/// tones: muted into `#C8D7AB` territory a zone would vanish into the farmland
/// under it. Their lightnesses spread 0.28–0.58, which keeps the per-element
/// shade ladder (`element_color.dart`, ±0.28 L) inside its legible band.
///
/// Only new layers are affected: the colour is fixed as an ARGB at creation.
const _palette = <Color>[
  Color(kDefaultLayerColor), // transport blue
  OsmPalette.health, // #BF0000
  OsmPalette.leisureGreen, // #0D8216
  OsmPalette.gastronomy, // #C77400
  OsmPalette.shop, // #AC39AC
  OsmPalette.airTransport, // #8461C4
];

/// What a layer of [type] is called before anyone renames it.
///
/// "Layer 4" said only that it was the fourth thing made, which is the one fact
/// about it the drawer already shows — its position — and none of the fact that
/// matters, which is what is in it. The number counts layers of **this type**,
/// so the second height layer is "Height 2" whatever else exists. Names are not
/// unique and are not made unique: this is a starting point, not an identity,
/// and deleting the first "Height 1" must not renumber the second.
String defaultLayerName(String type, List<Layer> existing) {
  final n = existing.where((l) => l.type == type).length + 1;
  return '${layerTypeNoun(type)} $n';
}

/// Creates a layer of [type] named after what it holds and makes it active.
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
        name: defaultLayerName(type, layers),
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
  final name = await _askName(context, 'Rename layer', layer.name);
  if (name != null && name.isNotEmpty) {
    await repo.updateLayer(layer.id, name: name);
  }
}

/// One rename dialog, for a layer and for a folder. Returns null on cancel.
Future<String?> _askName(BuildContext context, String title, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
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
/// layer's type: the overrides live in one table per kind, so there is
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
                      border: Border.all(color: kSwatchRing),
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
