import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/database.dart';
import '../state/providers.dart';
import 'object_summary.dart' show typeIcon;
import 'transit_lines.dart';

/// What the sheet asks the caller to do afterwards. Only framing needs the map;
/// visibility is written in place.
class TransitLinesResult {
  const TransitLinesResult(this.fitPoints);

  /// Points to frame — the caller owns `pendingFocusProvider` and the drawer's
  /// navigator, so there stays exactly one place that pops routes.
  final List<LatLng> fitPoints;
}

/// The per-layer "which lines are shown" menu: mode groups with a tri-state
/// master checkbox, each expanding to the individual lines.
///
/// A *line* is a distinct `ref` within a mode, so U6's two direction relations
/// collapse to one row and hiding it is one tap.
Future<TransitLinesResult?> showTransitLines(BuildContext context, Layer layer) {
  return showModalBottomSheet<TransitLinesResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, controller) =>
          _TransitLinesSheet(layer: layer, scrollController: controller),
    ),
  );
}

/// Adapts a drift row to the pure grouping helper.
class _RouteRow implements TransitRouteLike {
  _RouteRow(this.row);
  final TransitRoute row;

  @override
  String get id => row.id;
  @override
  String get modeKey => row.modeKey;
  @override
  String? get ref => row.ref;
  @override
  String? get name => row.name;
  @override
  String? get operatorName => row.operatorName;
  @override
  bool get isVisible => row.isVisible;
  @override
  int? get colorArgb => row.colorArgb;
}

class _TransitLinesSheet extends ConsumerStatefulWidget {
  const _TransitLinesSheet({required this.layer, required this.scrollController});

  final Layer layer;
  final ScrollController scrollController;

  @override
  ConsumerState<_TransitLinesSheet> createState() => _TransitLinesSheetState();
}

class _TransitLinesSheetState extends ConsumerState<_TransitLinesSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _setVisible(Iterable<String> routeIds, bool visible) {
    // One batch — a 200-route group toggle must not be 200 writes.
    return ref
        .read(repositoryProvider)
        .setTransitRouteVisibility(routeIds, visible);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sets = (ref.watch(transitSetsProvider).asData?.value ?? const [])
        .where((s) => s.layerId == widget.layer.id)
        .map((s) => s.id)
        .toSet();
    final allRoutes = (ref.watch(transitRoutesProvider).asData?.value ?? const [])
        .where((r) => sets.contains(r.setId))
        .map(_RouteRow.new)
        .toList();
    final parts =
        ref.watch(transitRoutePartsProvider).asData?.value ?? const [];

    final groups = groupTransitLines(allRoutes, query: _search.text);
    final total = allRoutes.length;
    final shown = allRoutes.where((r) => r.isVisible).length;
    final everyId = [for (final r in allRoutes) r.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Icon(typeIcon('transit'), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.layer.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text('$shown / $total shown', style: theme.textTheme.bodySmall),
              PopupMenuButton<String>(
                iconSize: 20,
                onSelected: (v) => _setVisible(everyId, v == 'all'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'all', child: Text('Show all')),
                  PopupMenuItem(value: 'none', child: Text('Hide all')),
                ],
              ),
            ],
          ),
        ),
        if (total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Search line, name or operator',
                border: const OutlineInputBorder(),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: groups.isEmpty
              ? ListView(
                  controller: widget.scrollController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Text(
                        total == 0
                            ? 'No lines imported yet — tap Import transit, then '
                                'tap two corners of an area.'
                            : 'No line matches that search.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: groups.length,
                  itemBuilder: (context, i) =>
                      _groupTile(theme, groups[i], parts),
                ),
        ),
      ],
    );
  }

  Widget _groupTile(
    ThemeData theme,
    TransitLineGroup group,
    List<TransitRoutePart> parts,
  ) {
    return ExpansionTile(
      // A search narrows to what you asked for, so open the results.
      initiallyExpanded: _search.text.trim().isNotEmpty,
      leading: Checkbox(
        tristate: true,
        value: groupCheckboxValue(group.state),
        // Mixed resolves to "show everything" — the useful direction.
        onChanged: (_) => _setVisible(
            group.routeIds, group.state != GroupState.all),
      ),
      title: Row(
        children: [
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: Color(group.mode.colorArgb),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(group.mode.label),
        ],
      ),
      subtitle: Text('${group.lines.length} line'
          '${group.lines.length == 1 ? '' : 's'} · '
          '${group.visibleRouteCount} / ${group.routeCount} shown'),
      children: [
        for (final line in group.lines)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: groupCheckboxValue(line.state),
            tristate: true,
            onChanged: (_) =>
                _setVisible(line.routeIds, line.state != GroupState.all),
            title: Row(
              children: [
                Container(
                  width: 14,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(line.colorArgb ?? group.mode.colorArgb),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(line.label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            subtitle: line.subtitle == null
                ? null
                : Text(line.subtitle!, overflow: TextOverflow.ellipsis),
            secondary: IconButton(
              tooltip: 'Zoom to this line',
              icon: const Icon(Icons.my_location, size: 18),
              onPressed: () => _zoomTo(line, parts),
            ),
          ),
      ],
    );
  }

  /// Frames a line from its parts' **stored bboxes** — no geometry decode.
  void _zoomTo(TransitLine line, List<TransitRoutePart> parts) {
    final ids = line.routeIds.toSet();
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    var any = false;
    for (final p in parts) {
      if (!ids.contains(p.routeId)) continue;
      any = true;
      if (p.south < s) s = p.south;
      if (p.north > n) n = p.north;
      if (p.west < w) w = p.west;
      if (p.east > e) e = p.east;
    }
    if (!any) return;
    Navigator.pop(
      context,
      TransitLinesResult([LatLng(s, w), LatLng(n, e)]),
    );
  }
}
