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

import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../data/layer_types.dart';
import '../data/repository.dart' show ColoredElement;
import '../state/providers.dart';
import 'object_summary.dart';
import 'poi_groups.dart';

/// The Elements list as a flat sequence of rows, computed from what the
/// providers say plus the sheet's own state (sort, search, what is expanded).
///
/// Pure so it is unit-testable, and flat so the sheet can render it with a
/// `ListView.builder`: a city's station import is thousands of rows, and a
/// `Column` of tiles built eagerly is a visible stall on opening the sheet.

/// How the rows of one kind are ordered.
enum ElementSort {
  /// Bottom of the map first — the order the map is stacked, and the one the
  /// "Bring to front" / "Send to back" wording assumes.
  stack,

  /// By the name the user gave; unnamed elements keep stack order after them.
  name,

  /// Largest first by [ObjectSummary.sizeMeasure]; kinds without a size fall
  /// back to name.
  size,
}

sealed class ListRow {
  const ListRow();
}

/// "Circles · 3" — only on a combined layer, where rows of several kinds
/// follow each other and a divider alone would not say where one kind ends.
class KindHeaderRow extends ListRow {
  const KindHeaderRow(this.kind, this.count);
  final ObjectKind kind;
  final int count;
}

/// A collapsible heading over the POI layer's imports.
class SectionRow extends ListRow {
  const SectionRow({
    required this.title,
    required this.blurb,
    required this.trailing,
    required this.expanded,
  });
  final String title;
  final String blurb;
  final String trailing;
  final bool expanded;
}

/// The "Rail only / Show all / Hide all" shortcuts above the station groups.
class StationToolsRow extends ListRow {
  const StationToolsRow();
}

/// One POI type's heading; its points follow only while [expanded].
class GroupHeaderRow extends ListRow {
  const GroupHeaderRow(this.group, {required this.expanded, required this.shown});
  final PoiTypeGroup group;
  final bool expanded;

  /// How many of the group's points the current search leaves — the count
  /// the heading shows, so "Bus · 3" while searching means three matches.
  final int shown;
}

/// One element, or one POI inside a group ([inGroup]).
class ElementRow extends ListRow {
  const ElementRow(
    this.summary, {
    this.inGroup = false,
    this.canMoveBack = false,
    this.canMoveForward = false,
  });
  final ObjectSummary summary;
  final bool inGroup;

  /// Whether the z-order menu offers "Send backward" / "Bring forward".
  /// **Computed from stack order, not display order**: sorting the list by
  /// name must not change what "front" means on the map.
  final bool canMoveBack;
  final bool canMoveForward;
}

/// Shown instead of rows when a search matches nothing — distinct from an
/// empty layer, which offers import buttons instead.
class NoMatchesRow extends ListRow {
  const NoMatchesRow(this.query);
  final String query;
}

@immutable
class ElementRows {
  const ElementRows({required this.rows, required this.poiCount});

  final List<ListRow> rows;

  /// Every POI on the layer (before search), for the header count.
  final int poiCount;

  bool get isEmpty => rows.isEmpty;
}

/// Whether [sort] is even a choice for these rows.
bool canSortByStack(List<ObjectSummary> summaries) =>
    summaries.any((s) => _stackable(s.ref.kind));

bool canSortBySize(List<ObjectSummary> summaries) =>
    summaries.any((s) => s.sizeMeasure != null);

/// Stacking is per (layer, table), so only kinds with a z column take part;
/// border areas are listed by name and their z is not editable from a list
/// that is not in that order.
bool _stackable(ObjectKind kind) {
  final c = ColoredElement.forObjectKindName(kind.name);
  return c != null && c != ColoredElement.borderArea;
}

/// Builds the rows.
///
/// [summaries] are the layer's elements in stack order, as
/// `layerSummariesProvider` yields them — including the POI *sets*, which land
/// in the Imports section; the POI *points* come as [poiGroups].
ElementRows buildElementRows({
  required Layer layer,
  required List<ObjectSummary> summaries,
  required List<PoiTypeGroup> poiGroups,
  required ElementSort sort,
  required String query,
  required Set<String> expandedGroups,
  required bool importsExpanded,
}) {
  final q = query.trim().toLowerCase();
  final searching = q.isNotEmpty;
  bool matches(ObjectSummary s) =>
      !searching ||
      s.title.toLowerCase().contains(q) ||
      s.subtitle.toLowerCase().contains(q);

  // Z-menu flags first, over the stack-ordered input, before anything is
  // re-sorted or filtered away.
  final zFlags = <ObjectRef, (bool, bool)>{};
  for (final kind in ObjectKind.values) {
    if (!_stackable(kind)) continue;
    final same = [
      for (final s in summaries)
        if (s.ref.kind == kind) s.ref,
    ];
    if (same.length < 2) continue;
    for (var i = 0; i < same.length; i++) {
      zFlags[same[i]] = (i > 0, i < same.length - 1);
    }
  }

  ElementRow row(ObjectSummary s, {bool inGroup = false}) {
    final f = zFlags[s.ref] ?? (false, false);
    return ElementRow(s, inGroup: inGroup, canMoveBack: f.$1, canMoveForward: f.$2);
  }

  List<ObjectSummary> sorted(List<ObjectSummary> rows, ObjectKind kind) {
    final effective = switch (sort) {
      ElementSort.stack => _stackable(kind) ? ElementSort.stack : ElementSort.name,
      ElementSort.size =>
        rows.any((s) => s.sizeMeasure != null) ? ElementSort.size : ElementSort.name,
      ElementSort.name => ElementSort.name,
    };
    switch (effective) {
      case ElementSort.stack:
        return rows;
      case ElementSort.name:
        return _stableSorted(
          rows,
          (a, b) => compareNamed(a.sortName, b.sortName, a.ref.id, b.ref.id),
        );
      case ElementSort.size:
        return _stableSorted(rows, (a, b) {
          final x = a.sizeMeasure, y = b.sizeMeasure;
          if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
          return y.compareTo(x); // largest first
        });
    }
  }

  // A failed import must surface: its retry row goes above everything, so a
  // collapsed Imports section can never hide it.
  final pending = [
    for (final s in summaries)
      if (s.isPending && matches(s)) row(s),
  ];

  final kinds = [
    for (final t in layerContentTypes(layer)) ?ObjectKind.forLayerType(t),
  ];
  final presentKinds = {for (final s in summaries) s.ref.kind};
  final poiCount = poiGroups.fold(0, (int n, g) => n + g.points.length);
  // Kind headings only where several kinds share the list.
  final headed = layer.type == kMixedType && presentKinds.length > 1;

  final rows = <ListRow>[...pending];
  for (final kind in kinds) {
    final mine = [
      for (final s in summaries)
        if (s.ref.kind == kind && !s.isPending) s,
    ];
    if (kind == ObjectKind.poiSet) {
      if (mine.isEmpty && poiGroups.isEmpty) continue;
      if (headed) rows.add(KindHeaderRow(kind, poiCount));
      // A hand-made category is not an import: its group heading is where it
      // is renamed or deleted, so it has no second row under "Imports".
      final manualSetIds = {
        for (final g in poiGroups) ?g.manualSetId,
      };
      rows.addAll(
        _poiRows(
          groups: poiGroups,
          sets: sorted(
            [for (final s in mine) if (!manualSetIds.contains(s.ref.id)) s],
            kind,
          ),
          searching: searching,
          matches: matches,
          expandedGroups: expandedGroups,
          importsExpanded: importsExpanded,
          row: row,
        ),
      );
      continue;
    }
    final shown = [
      for (final s in sorted(mine, kind))
        if (matches(s)) s,
    ];
    if (shown.isEmpty) continue;
    if (headed) rows.add(KindHeaderRow(kind, shown.length));
    rows.addAll([for (final s in shown) row(s)]);
  }

  if (rows.isEmpty && searching) {
    return ElementRows(rows: [NoMatchesRow(query.trim())], poiCount: poiCount);
  }
  return ElementRows(rows: rows, poiCount: poiCount);
}

List<ListRow> _poiRows({
  required List<PoiTypeGroup> groups,
  required List<ObjectSummary> sets,
  required bool searching,
  required bool Function(ObjectSummary) matches,
  required Set<String> expandedGroups,
  required bool importsExpanded,
  required ElementRow Function(ObjectSummary, {bool inGroup}) row,
}) {
  final rows = <ListRow>[];
  var toolsAdded = false;
  for (final g in groups) {
    final shown = [
      for (final p in g.points)
        if (matches(p)) p,
    ];
    // While searching a group is only its matches: an empty one is noise, and
    // a collapsed one would hide the very thing being looked for.
    if (searching && shown.isEmpty) continue;
    if (!toolsAdded && !searching && g.mode != null) {
      rows.add(const StationToolsRow());
      toolsAdded = true;
    }
    final expanded = searching || expandedGroups.contains(g.key);
    rows.add(GroupHeaderRow(g, expanded: expanded, shown: shown.length));
    if (expanded) rows.addAll([for (final p in shown) row(p, inGroup: true)]);
  }

  final shownSets = [
    for (final s in sets)
      if (matches(s)) s,
  ];
  if (shownSets.isEmpty) return rows;
  final expanded = searching || importsExpanded;
  rows.add(
    SectionRow(
      title: 'Imports',
      blurb: 'How the points above arrived — deleting an import removes its '
          'points',
      trailing: '${shownSets.length}',
      expanded: expanded,
    ),
  );
  if (expanded) rows.addAll([for (final s in shownSets) row(s)]);
  return rows;
}

List<T> _stableSorted<T>(List<T> rows, int Function(T, T) compare) {
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
