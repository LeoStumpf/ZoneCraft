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

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/database.dart';
import '../data/layer_types.dart';
import '../data/poi_sets.dart';
import '../data/transit.dart';
import '../state/providers.dart';
import 'object_summary.dart';
import 'poi_icons.dart';
import 'poi_layer.dart' show poiIconFor;

/// A POI layer's points, grouped by **type** for the Elements list.
///
/// The list used to show one row per *import* — "Station import 2 · 400
/// stations · imported 3 Jan" — which describes how the points arrived, not
/// what they are. What a person wants from "everything on this layer" is the
/// cafés, the bus stops, the pins they placed: so the rows are the points,
/// filed under the kind of thing they are. Two imports of the same category
/// land in **one** group (the repository already de-duplicates a re-import
/// against the layer, so a merged group holds each place once) — and so does a
/// hand-made category that *is* that category (a "Bench" set beside a bench
/// import: they are all benches, see [poiSetCatalogueCategory]). How a point
/// arrived is deliberately not a heading anywhere: the list has no Imports
/// section, only kinds of thing. A station
/// served by several modes is filed under its [primaryTransitMode] — the same
/// pick its marker icon makes.
///
/// Pure (no providers, no database) so it is unit-testable; the provider at
/// the bottom is the only thing that touches Riverpod.

enum PoiGroupKind {
  /// One transit mode's stations across every station import of the layer —
  /// or, for `station:none`, the stations OSM gave no mode.
  station,

  /// One catalogue category ("Benches") across every radius import of it and
  /// every hand-made category that is the same thing.
  category,

  /// A hand-made category that is none of the catalogue's — every set of that
  /// name, since two "Swimming spots" are one kind of place.
  manual,
}

/// One expandable section of a POI layer's Elements list.
@immutable
class PoiTypeGroup {
  const PoiTypeGroup({
    required this.key,
    required this.kind,
    required this.label,
    required this.icon,
    required this.setIds,
    required this.points,
    this.manualSetIds = const {},
    this.mode,
  });

  /// Stable across rebuilds — what the sheet remembers as expanded.
  /// `station:<mode>` / `station:none` / `category:<key>` / `manual:<name>`.
  final String key;
  final PoiGroupKind kind;
  final String label;
  final IconData icon;

  /// The mode a station group stands for; null for `station:none` and for the
  /// other kinds. Its presence is what puts a visibility tick box on the row.
  final TransitMode? mode;

  /// Every set that contributed a point — a category group merges imports
  /// and hand-made sets.
  final Set<String> setIds;

  /// The hand-made sets among [setIds] — what the heading's "Edit category"
  /// edits. Empty for a group of nothing but imports.
  final Set<String> manualSetIds;

  /// The rows under the heading, `ObjectKind.poiPoint`, sorted by name.
  final List<ObjectSummary> points;

  List<LatLng> get fitPoints => [for (final p in points) p.center];
}

const String _noneKey = 'station:none';

/// Groups [layer]'s POIs by type. Pending imports hold no points and yield no
/// group — a failed café import must not produce an empty "Cafés" heading —
/// but a hand-made category with nothing placed yet keeps its group, because
/// its heading is where that category is renamed or deleted.
///
/// Order: station modes in catalogue order with the mode-less stations last,
/// then every other group by label — a hand-made category is a kind of place
/// like any other, not an appendix.
List<PoiTypeGroup> poiTypeGroups({
  required Layer layer,
  required List<PoiSet> sets,
  required Map<String, List<PoiPoint>> pointsBySet,
  Map<String, OsmReport> reportByPoint = const {},
}) {
  if (!layerHolds(layer, kPoi)) return const [];
  // Only a hand-placed point or a correction has anything to publish, so the
  // subject (a few lookups) is built for those few and never for an import's
  // thousands of untouched rows.
  PoiPublishState publishState(PoiPoint p, PoiSet s) {
    if (!s.isManual && p.editedAt == null) return PoiPublishState.none;
    final report = reportByPoint[p.id];
    if (report != null) {
      return report.sentAt != null
          ? PoiPublishState.sent
          : PoiPublishState.listed;
    }
    return osmSubjectFor(p, sets).canPublish
        ? PoiPublishState.unpublished
        : PoiPublishState.none;
  }

  final mine = [
    for (final s in sets)
      if (s.layerId == layer.id) s,
  ];
  if (mine.isEmpty) return const [];

  final stationRows = <String, List<ObjectSummary>>{};
  final stationSets = <String, Set<String>>{};
  final kinds = <String, _Pending>{};

  for (final s in mine) {
    final pts = pointsBySet[s.id] ?? const <PoiPoint>[];
    if (s.isPending) continue;
    if (s.isStationImport) {
      for (final p in pts) {
        final mode = primaryTransitMode(p.modeMask);
        final key = mode == null ? _noneKey : 'station:${mode.key}';
        (stationRows[key] ??= []).add(
          _pointSummary(
            p,
            layer.id,
            p.modeMask == 0 ? 'No type given' : transitModeLabels(p.modeMask),
            'Station',
          ),
        );
        (stationSets[key] ??= {}).add(s.id);
      }
      continue;
    }
    final category = poiSetCatalogueCategory(s);
    final _Pending group;
    if (category != null) {
      group = kinds.putIfAbsent(
        'category:${category.key}',
        () => _Pending(
          PoiGroupKind.category,
          category.label,
          poiIconFor(category.key),
        ),
      );
    } else {
      // Only a hand-made set can land here: an import's key is always a
      // catalogue key, bar an old one whose category has since been renamed —
      // which keeps its own group under its raw key, as it always did.
      final label = s.isManual ? _manualLabel(s) : s.categoryKey;
      group = kinds.putIfAbsent(
        s.isManual
            ? 'manual:${singularName(label)}'
            : 'category:${s.categoryKey}',
        () => _Pending(
          s.isManual ? PoiGroupKind.manual : PoiGroupKind.category,
          label,
          poiSetIcon(s),
        ),
      );
    }
    group.setIds.add(s.id);
    if (s.isManual) group.manualSetIds.add(s.id);
    group.points.addAll([
      for (final p in pts)
        _pointSummary(
          p,
          layer.id,
          group.label,
          'Unnamed POI',
          publishState: publishState(p, s),
        ),
    ]);
  }

  final stations = <PoiTypeGroup>[
    for (final m in transitModes)
      if (stationRows.containsKey('station:${m.key}'))
        PoiTypeGroup(
          key: 'station:${m.key}',
          kind: PoiGroupKind.station,
          label: m.label,
          icon: transitIconFor(m.bit),
          mode: m,
          setIds: stationSets['station:${m.key}']!,
          points: _sorted(stationRows['station:${m.key}']!),
        ),
    if (stationRows.containsKey(_noneKey))
      PoiTypeGroup(
        key: _noneKey,
        kind: PoiGroupKind.station,
        label: 'No type given',
        icon: Icons.help_outline,
        setIds: stationSets[_noneKey]!,
        points: _sorted(stationRows[_noneKey]!),
      ),
  ];

  final others = [
    for (final e in kinds.entries)
      PoiTypeGroup(
        key: e.key,
        kind: e.value.kind,
        label: e.value.label,
        icon: e.value.icon,
        setIds: e.value.setIds,
        manualSetIds: e.value.manualSetIds,
        points: _sorted(e.value.points),
      ),
  ]..sort((a, b) => compareNamed(a.label, b.label, a.key, b.key));

  return [...stations, ...others];
}

/// A category or hand-made group while its sets are still being collected.
class _Pending {
  _Pending(this.kind, this.label, this.icon);
  final PoiGroupKind kind;
  final String label;
  final IconData icon;
  final setIds = <String>{};
  final manualSetIds = <String>{};
  final points = <ObjectSummary>[];
}

/// A hand-made category has no OSM tag behind it, so its own name is the only
/// thing that describes it.
String _manualLabel(PoiSet s) {
  final l = s.label?.trim();
  return (l == null || l.isEmpty) ? 'Category' : l;
}

ObjectSummary _pointSummary(
  PoiPoint p,
  String layerId,
  String subtitle,
  String unnamed, {
  PoiPublishState publishState = PoiPublishState.none,
}) {
  final at = LatLng(p.lat, p.lng);
  final name = p.name?.trim();
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.poiPoint, id: p.id, layerId: layerId),
    title: (name == null || name.isEmpty) ? unnamed : name,
    subtitle: subtitle,
    center: at,
    fitPoints: [at],
    sortName: name ?? '',
    isEdited: p.editedAt != null,
    publishState: publishState,
  );
}

List<ObjectSummary> _sorted(List<ObjectSummary> rows) => rows
  ..sort((a, b) => compareNamed(a.sortName, b.sortName, a.ref.id, b.ref.id));

/// One layer's POI type groups, from the global row providers.
final poiTypeGroupsProvider = Provider.family<List<PoiTypeGroup>, String>((
  ref,
  layerId,
) {
  final layer = (ref.watch(layersProvider).asData?.value ?? const <Layer>[])
      .where((l) => l.id == layerId)
      .firstOrNull;
  if (layer == null) return const [];
  return poiTypeGroups(
    layer: layer,
    sets: ref.watch(poiSetsProvider).asData?.value ?? const [],
    pointsBySet: ref.watch(poiPointsBySetProvider),
    // Newest first, so the first per point is its latest.
    reportByPoint: {
      for (final r
          in (ref.watch(osmReportsProvider).asData?.value ??
                  const <OsmReport>[])
              .reversed)
        if (r.poiPointId != null) r.poiPointId!: r,
    },
  );
}, isAutoDispose: true);
