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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/layer_types.dart';
import '../data/poi_sets.dart';
import '../data/shared_point.dart';
import '../data/transit.dart';
import '../state/import_preview.dart';
import '../state/providers.dart';
import 'border_area_editor.dart';
import 'circle_editor.dart';
import 'collapsible_sheet.dart';
import 'freearea_editor.dart';
import 'freeline_editor.dart';
import 'height_editor.dart';
import 'imported_point_editor.dart';
import 'pending_import_sheet.dart';
import 'poi_icons.dart';
import 'poi_set_editor.dart';
import 'share_place.dart';
import 'subspace_editor.dart';

/// Whether anything is in the map's sheet slot.
///
/// **The FAB column must be hidden by this and by nothing else.** That is not
/// style, it is the fix for a bug: the FABs used to be hidden by a *second*
/// list of the things that raise a sheet, the import form was added to the
/// slot and never to that list, and its buttons landed on top of the form's
/// own corner fields and its close button. One predicate, read by both.
///
/// Watched, not read, so the map rebuilds when a selection appears.
bool watchHasMapSheet(WidgetRef ref, {required Widget? importSheet}) =>
    importSheet != null ||
    ref.watch(pendingImportProvider) != null ||
    watchSelectedIds(ref).isNotEmpty ||
    ref.watch(receivedPointProvider) != null;

/// Whatever owns the map Scaffold's single sheet slot.
///
/// Five different things compete for that one slot — a pending import's
/// Keep/Discard bar, an import's options form, a received place, the selected
/// element's editor, and nothing at all — and the FAB column is hidden by
/// **the same expression** that decides between them. That coupling is the
/// point: the FABs used to be hidden by a second, separate list of the things
/// that raise a sheet, the import form was added to one list and not the
/// other, and its buttons landed on top of the form's own fields. One source
/// of truth, one slot.
///
/// This watches its own state rather than being handed twenty-two values.
/// Everything here is derived from providers the map already watches, so the
/// duplication costs nothing at runtime — Riverpod serves one element per
/// provider — and it buys a widget that can be pumped on its own.
///
/// Only four things cannot be watched, and they are the constructor:
/// [importSheet], which is the map's own transient form, and three callbacks
/// that need the map's camera centre to place a new point.
class EditorSheetHost extends ConsumerWidget {
  const EditorSheetHost({
    super.key,
    required this.importSheet,
    required this.onKeepSharedPlace,
    required this.onAddSubspacePoint,
    required this.onAddFreeLinePoint,
    required this.onAddFreeAreaPoint,
  });

  /// An import's options form, while one is up. Owned by the map because it is
  /// answered by a `Completer` the map is awaiting.
  final Widget? importSheet;

  final void Function(SharedPoint point) onKeepSharedPlace;

  /// Each appends a point to the selected object at the map's centre. The
  /// lookup of *which* object happens on the map side, at call time, so this
  /// widget never needs the camera.
  final VoidCallback onAddSubspacePoint;
  final VoidCallback onAddFreeLinePoint;
  final VoidCallback onAddFreeAreaPoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(layersProvider).asData?.value ?? const <Layer>[];
    final circles =
        ref.watch(circlesProvider).asData?.value ?? const <Circle>[];
    final subspaces =
        ref.watch(subspacesProvider).asData?.value ?? const <Subspace>[];
    final subspacePoints = ref.watch(subspacePointsBySubspaceProvider);
    final freeLines =
        ref.watch(freeLinesProvider).asData?.value ?? const <FreeLine>[];
    final freeLinePoints = ref.watch(freeLinePointsByLineProvider);
    final freeAreas =
        ref.watch(freeAreasProvider).asData?.value ?? const <FreeArea>[];
    final freeAreaPoints = ref.watch(freeAreaPointsByAreaProvider);
    final heightRegions =
        ref.watch(heightRegionsProvider).asData?.value ??
        const <HeightRegion>[];
    final heightPolygons = ref.watch(heightPolygonsByRegionProvider);
    final poiSets =
        ref.watch(poiSetsProvider).asData?.value ?? const <PoiSet>[];
    final poiPoints =
        ref.watch(poiPointsProvider).asData?.value ?? const <PoiPoint>[];
    final borderSets =
        ref.watch(borderSetsProvider).asData?.value ?? const <BorderSet>[];
    final borderAreaRows =
        ref.watch(borderAreasProvider).asData?.value ?? const <BorderArea>[];

    final pendingImport = ref.watch(pendingImportProvider);
    final receivedPoint = ref.watch(receivedPointProvider);

    final selectedCircle = circles
        .where((c) => c.id == ref.watch(selectedCircleProvider))
        .firstOrNull;
    final selectedSubspace = subspaces
        .where((s) => s.id == ref.watch(selectedSubspaceProvider))
        .firstOrNull;
    final selectedSubspacePoints = selectedSubspace == null
        ? const <SubspacePoint>[]
        : subspacePoints[selectedSubspace.id] ?? const <SubspacePoint>[];
    final selectedFreeLine = freeLines
        .where((l) => l.id == ref.watch(selectedFreeLineProvider))
        .firstOrNull;
    final selectedFreeLinePoints = selectedFreeLine == null
        ? const <FreeLinePoint>[]
        : freeLinePoints[selectedFreeLine.id] ?? const <FreeLinePoint>[];
    final selectedFreeArea = freeAreas
        .where((a) => a.id == ref.watch(selectedFreeAreaProvider))
        .firstOrNull;
    final selectedFreeAreaPoints = selectedFreeArea == null
        ? const <FreeAreaPoint>[]
        : freeAreaPoints[selectedFreeArea.id] ?? const <FreeAreaPoint>[];
    final selectedHeightRegion = heightRegions
        .where((r) => r.id == ref.watch(selectedHeightRegionProvider))
        .firstOrNull;
    final selectedPoiSet = poiSets
        .where((s) => s.id == ref.watch(selectedPoiSetProvider))
        .firstOrNull;
    final selectedPoiPoint = poiPoints
        .where((p) => p.id == ref.watch(selectedPoiPointProvider))
        .firstOrNull;
    final selectedBorderArea = borderAreaRows
        .where((a) => a.id == ref.watch(selectedBorderAreaProvider))
        .firstOrNull;
    // The layer behind the selected area, reached through its import — areas
    // belong to a set, and the editor needs the layer's admin level.
    final selectedBorderLayer = selectedBorderArea == null
        ? null
        : () {
            final set = borderSets
                .where((x) => x.id == selectedBorderArea.setId)
                .firstOrNull;
            if (set == null) return null;
            return layers.where((l) => l.id == set.layerId).firstOrNull;
          }();

    final hasSelection =
        selectedCircle != null ||
        selectedSubspace != null ||
        selectedFreeLine != null ||
        selectedFreeArea != null ||
        selectedHeightRegion != null ||
        selectedPoiSet != null ||
        selectedPoiPoint != null ||
        selectedBorderArea != null;

    final sheet =
        (pendingImport == null
            ? null
            : PendingImportSheet(
                pending: pendingImport,
                onKeep: () => pendingImport.answer(keep: true),
                onDiscard: () => pendingImport.answer(keep: false),
              )) ??
        importSheet ??
        (!hasSelection
            // A shared position. An arriving one clears the selection (see the
            // listener above), so in practice these two never compete; the order
            // here only decides what happens if something is selected *after*.
            ? (receivedPoint == null
                  ? null
                  : ReceivedPlaceSheet(
                      point: receivedPoint,
                      onKeep: () => onKeepSharedPlace(receivedPoint),
                      onDismiss: () =>
                          ref.read(receivedPointProvider.notifier).clear(),
                    ))
            : CollapsibleSheet(
                // Reset to expanded whenever the selected object changes —
                // and rebuild from scratch on an undo. Editors mirror their
                // row into controllers and skip re-syncing a focused field,
                // so without the revision an undone value would still be sat
                // in the text box, ready for the next keystroke to write it
                // back. Discarding the subtree re-seeds every editor at once.
                key: ValueKey(
                  'sheet-${ref.watch(undoRevisionProvider)}-'
                  '${selectedCircle?.id ?? selectedSubspace?.id ?? selectedFreeLine?.id ?? selectedFreeArea?.id ?? selectedHeightRegion?.id ?? selectedPoiSet?.id ?? selectedPoiPoint?.id ?? selectedBorderArea?.id}',
                ),
                child: selectedCircle != null
                    ? CircleEditorSheet(
                        key: ValueKey(selectedCircle.id),
                        circle: selectedCircle,
                        layers: layers,
                      )
                    : selectedSubspace != null
                    ? SubspaceEditorSheet(
                        key: ValueKey(selectedSubspace.id),
                        subspace: selectedSubspace,
                        points: selectedSubspacePoints,
                        layers: layers,
                        onAddPoint: onAddSubspacePoint,
                      )
                    : selectedFreeLine != null
                    ? FreeLineEditorSheet(
                        key: ValueKey(selectedFreeLine.id),
                        freeLine: selectedFreeLine,
                        points: selectedFreeLinePoints,
                        layers: layers,
                        onAddPoint: onAddFreeLinePoint,
                      )
                    : selectedFreeArea != null
                    ? FreeAreaEditorSheet(
                        key: ValueKey(selectedFreeArea.id),
                        freeArea: selectedFreeArea,
                        points: selectedFreeAreaPoints,
                        layers: layers,
                        onAddPoint: onAddFreeAreaPoint,
                      )
                    : selectedHeightRegion != null
                    ? HeightEditorSheet(
                        key: ValueKey(selectedHeightRegion.id),
                        region: selectedHeightRegion,
                        polygonCount:
                            heightPolygons[selectedHeightRegion.id]?.length ??
                            0,
                        layers: layers,
                      )
                    : selectedPoiPoint != null
                    ? () {
                        // A station and a POI are the same row; the set
                        // says which it is, and that decides the sheet's
                        // icon, wording and whether the point may move.
                        final set = poiSetOf(
                          poiSets,
                          selectedPoiPoint.poiSetId,
                        );
                        final station = set != null && set.isStationImport;
                        return ImportedPointEditorSheet(
                          key: ValueKey(selectedPoiPoint.id),
                          id: selectedPoiPoint.id,
                          name: selectedPoiPoint.name,
                          lat: selectedPoiPoint.lat,
                          lng: selectedPoiPoint.lng,
                          icon: set == null
                              ? Icons.place_outlined
                              : poiPointIcon(selectedPoiPoint, set),
                          title: station ? 'Edit station' : 'Edit POI',
                          subtitle: station
                              ? transitModeLabels(selectedPoiPoint.modeMask)
                              : poiCategoryLabel(
                                  poiSets,
                                  selectedPoiPoint.poiSetId,
                                ),
                          // Both kinds can be moved; this says which one it
                          // is, and therefore what the move means.
                          movable: set?.isManual ?? false,
                          editedAt: selectedPoiPoint.editedAt,
                          origLat: selectedPoiPoint.origLat,
                          origLng: selectedPoiPoint.origLng,
                          origName: selectedPoiPoint.origName,
                          osmType: selectedPoiPoint.osmType,
                          osmId: selectedPoiPoint.osmId,
                          // The OSM tag behind the category, when there is
                          // one — it is what makes a report actionable, and a
                          // hand-made category built from a bare icon has
                          // none to offer.
                          tagKey: poiCategoryTag(
                            poiSets,
                            selectedPoiPoint.poiSetId,
                          )?.tagKey,
                          tagValue: poiCategoryTag(
                            poiSets,
                            selectedPoiPoint.poiSetId,
                          )?.tagValue,
                        );
                      }()
                    : selectedPoiSet != null
                    ? PoiSetEditorSheet(
                        key: ValueKey(selectedPoiSet.id),
                        set: selectedPoiSet,
                        pointCount: poiPoints
                            .where((p) => p.poiSetId == selectedPoiSet.id)
                            .length,
                        layers: [
                          for (final l in layers)
                            if (layerHolds(l, kPoi)) l,
                        ],
                      )
                    : selectedBorderArea != null && selectedBorderLayer != null
                    ? BorderAreaEditorSheet(
                        key: ValueKey(selectedBorderArea.id),
                        area: selectedBorderArea,
                        layer: selectedBorderLayer,
                      )
                    : const SizedBox.shrink(),
              ));

    // `watchHasMapSheet` gates this widget, so `sheet` is non-null in
    // practice; the fallback keeps a race between the two harmless.
    return sheet ?? const SizedBox.shrink();
  }
}
