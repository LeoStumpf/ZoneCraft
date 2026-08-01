import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/transit.dart';
import '../state/providers.dart';
import 'object_summary.dart' show typeIcon;
import 'transit_layer.dart' show transitIconFor;

/// The per-layer "which stations are shown" filter.
///
/// A station carries the modes that serve it, so this is one checkbox per
/// transit type. **A station shows iff at least one of its types is enabled** —
/// unticking Bus leaves Pasing Bahnhof standing, because a train stops there.
/// That union rule is what makes "only stations where a railway stops" a single
/// tap ("Rail only"), which on a Munich import goes from ~2 670 markers to ~350.
Future<void> showTransitModes(BuildContext context, Layer layer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, controller) =>
          _TransitModesSheet(layer: layer, scrollController: controller),
    ),
  );
}

class _TransitModesSheet extends ConsumerWidget {
  const _TransitModesSheet({
    required this.layer,
    required this.scrollController,
  });

  final Layer layer;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tally = ref.watch(transitTallyProvider(layer.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Icon(typeIcon('transit'), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  layer.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text('${tally.shown} / ${tally.total} shown',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            children: [TransitModeFilter(layer: layer)],
          ),
        ),
      ],
    );
  }
}

/// The station-type tick boxes themselves, without a sheet around them.
///
/// Lives in its own widget because it is offered from two places: this sheet
/// (reached from the layer's overflow menu) and inline at the top of the layer's
/// **Elements** list — which is where people look first, having gone there to
/// "see what's in this layer". Elements lists *imports*, which are deletable
/// snapshots; the types are a filter. Showing both, each under its own heading,
/// is what stops the two being confused.
class TransitModeFilter extends ConsumerWidget {
  const TransitModeFilter({super.key, required this.layer});

  final Layer layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tally = ref.watch(transitTallyProvider(layer.id));

    if (tally.total == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Text(
          'No stations imported yet — tap Import transit, then tap two '
          'corners of an area.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    Future<void> write(int mask) =>
        ref.read(repositoryProvider).setTransitVisibleModes(tally.setIds, mask);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            'A station is shown when at least one ticked type stops there.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Wrap(
            spacing: 8,
            children: [
              // The stated use case, in one tap.
              OutlinedButton.icon(
                icon: const Icon(Icons.train, size: 16),
                label: const Text('Rail only'),
                onPressed: () => write(transitRailMask),
              ),
              TextButton(
                onPressed: () => write(transitAllModesMask),
                child: const Text('Show all'),
              ),
              TextButton(
                onPressed: () => write(0),
                child: const Text('Hide all'),
              ),
            ],
          ),
        ),
        for (final m in tally.present)
          CheckboxListTile(
            value: tally.visible & m.bit != 0,
            onChanged: (v) =>
                write(transitMaskWith(tally.visible, m, v ?? false)),
            secondary: Icon(transitIconFor(m.bit)),
            title: Row(
              children: [
                Container(
                  width: 14,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(m.colorArgb),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(m.label)),
                Text('${tally.counts[m.key]}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            subtitle: Text(m.blurb),
          ),
        if (tally.untyped > 0)
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('No type given'),
            subtitle:
                const Text('Shown whenever anything is — never orphaned'),
            trailing:
                Text('${tally.untyped}', style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// Everything both views need about one transit layer's stations: which types
/// are present, how many of each, what is ticked, and what that shows.
class TransitTally {
  const TransitTally({
    required this.setIds,
    required this.present,
    required this.counts,
    required this.untyped,
    required this.visible,
    required this.shown,
    required this.total,
  });

  final Set<String> setIds;

  /// Types that actually occur in this layer — never offer a tick box for a
  /// type no imported station has.
  final List<TransitMode> present;
  final Map<String, int> counts;
  final int untyped;

  /// Union of the imports' visible masks: several imports in one layer could in
  /// principle disagree, and the filter edits them together.
  final int visible;
  final int shown;
  final int total;
}

TransitTally transitTally({
  required String layerId,
  required List<TransitSet> sets,
  required List<TransitStop> allStations,
}) {
  final mine = sets.where((s) => s.layerId == layerId).toList();
  final setIds = {for (final s in mine) s.id};
  final stations = allStations.where((s) => setIds.contains(s.setId)).toList();

  final counts = <String, int>{};
  var untyped = 0;
  for (final s in stations) {
    if (s.modeMask == 0) {
      untyped++;
      continue;
    }
    for (final m in transitModesFromMask(s.modeMask)) {
      counts[m.key] = (counts[m.key] ?? 0) + 1;
    }
  }
  final visible = mine.fold(0, (int a, s) => a | s.visibleModeMask);

  return TransitTally(
    setIds: setIds,
    present: transitModes.where((m) => (counts[m.key] ?? 0) > 0).toList(),
    counts: counts,
    untyped: untyped,
    visible: visible,
    shown: visibleTransitStationCount(stations, visible),
    total: stations.length,
  );
}

final transitTallyProvider = Provider.family<TransitTally, String>(
  (ref, layerId) => transitTally(
    layerId: layerId,
    sets: ref.watch(transitSetsProvider).asData?.value ?? const [],
    allStations: ref.watch(transitStopsProvider).asData?.value ?? const [],
  ),
);

/// How many of [stations] a mask would show. Pure, so the header count and the
/// map can't disagree.
int visibleTransitStationCount(Iterable<TransitStop> stations, int visible) {
  if (visible == 0) return 0;
  var n = 0;
  for (final s in stations) {
    if (s.modeMask == 0 || s.modeMask & visible != 0) n++;
  }
  return n;
}
