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
import '../data/overpass.dart' show poiCategories;
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
/// against the layer, so a merged group holds each place once), and a station
/// served by several modes is filed under its [primaryTransitMode] — the same
/// pick its marker icon makes.
///
/// Pure (no providers, no database) so it is unit-testable; the provider at
/// the bottom is the only thing that touches Riverpod.

enum PoiGroupKind {
  /// One transit mode's stations across every station import of the layer —
  /// or, for `station:none`, the stations OSM gave no mode.
  station,

  /// One Overpass category ("Cafés") across every radius import of it.
  category,

  /// One hand-made category: that set *is* the type.
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
    this.mode,
  });

  /// Stable across rebuilds — what the sheet remembers as expanded.
  /// `station:<mode>` / `station:none` / `category:<key>` / `manual:<setId>`.
  final String key;
  final PoiGroupKind kind;
  final String label;
  final IconData icon;

  /// The mode a station group stands for; null for `station:none` and for the
  /// other kinds. Its presence is what puts a visibility tick box on the row.
  final TransitMode? mode;

  /// Every set that contributed a point — a category group merges imports.
  final Set<String> setIds;

  /// The rows under the heading, `ObjectKind.poiPoint`, sorted by name.
  final List<ObjectSummary> points;

  /// The one set behind a hand-made category (its Edit / Delete target).
  String? get manualSetId => kind == PoiGroupKind.manual ? setIds.single : null;

  List<LatLng> get fitPoints => [for (final p in points) p.center];
}

const String _noneKey = 'station:none';

/// Groups [layer]'s POIs by type. Pending imports hold no points and yield no
/// group — a failed café import must not produce an empty "Cafés" heading —
/// but a hand-made category with nothing placed yet keeps its group, because
/// its heading is where that category is renamed or deleted.
///
/// Order: station modes in catalogue order with the mode-less stations last,
/// then categories by label, then hand-made categories by label (then id).
List<PoiTypeGroup> poiTypeGroups({
  required Layer layer,
  required List<PoiSet> sets,
  required Map<String, List<PoiPoint>> pointsBySet,
}) {
  if (!layerHolds(layer, kPoi)) return const [];
  final mine = [
    for (final s in sets)
      if (s.layerId == layer.id) s,
  ];
  if (mine.isEmpty) return const [];

  final stationRows = <String, List<ObjectSummary>>{};
  final stationSets = <String, Set<String>>{};
  final categoryRows = <String, List<ObjectSummary>>{};
  final categorySets = <String, Set<String>>{};
  final manual = <PoiTypeGroup>[];

  for (final s in mine) {
    final pts = pointsBySet[s.id] ?? const <PoiPoint>[];
    if (s.isManual) {
      final label = _manualLabel(s);
      manual.add(
        PoiTypeGroup(
          key: 'manual:${s.id}',
          kind: PoiGroupKind.manual,
          label: label,
          icon: poiSetIcon(s),
          setIds: {s.id},
          points: _sorted([
            for (final p in pts) _pointSummary(p, layer.id, label, 'Unnamed POI'),
          ]),
        ),
      );
      continue;
    }
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
    final label = _categoryLabel(s.categoryKey);
    final key = 'category:${s.categoryKey}';
    (categoryRows[key] ??= []).addAll([
      for (final p in pts) _pointSummary(p, layer.id, label, 'Unnamed POI'),
    ]);
    (categorySets[key] ??= {}).add(s.id);
  }

  final groups = <PoiTypeGroup>[
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

  final categories = [
    for (final e in categoryRows.entries)
      PoiTypeGroup(
        key: e.key,
        kind: PoiGroupKind.category,
        label: _categoryLabel(e.key.substring('category:'.length)),
        icon: poiIconFor(e.key.substring('category:'.length)),
        setIds: categorySets[e.key]!,
        points: _sorted(e.value),
      ),
  ]..sort((a, b) => compareNamed(a.label, b.label, a.key, b.key));
  manual.sort((a, b) => compareNamed(a.label, b.label, a.key, b.key));

  return [...groups, ...categories, ...manual];
}

/// The human name of an Overpass category ("Cafés"), falling back to the raw
/// key so an old set whose category has since been renamed still says
/// something.
String _categoryLabel(String categoryKey) =>
    poiCategories.where((c) => c.key == categoryKey).firstOrNull?.label ??
    categoryKey;

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
  String unnamed,
) {
  final at = LatLng(p.lat, p.lng);
  final name = p.name?.trim();
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.poiPoint, id: p.id, layerId: layerId),
    title: (name == null || name.isEmpty) ? unnamed : name,
    subtitle: subtitle,
    center: at,
    fitPoints: [at],
    sortName: name ?? '',
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
  );
});
