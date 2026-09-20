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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/layer_types.dart';
import '../state/providers.dart';
import 'map_controls.dart';

/// What every button on the map does, in one list.
///
/// The map is icon buttons with no labels, and a tooltip only appears on a long
/// press that nobody thinks to try. The one-line tip the map gives after a
/// button is pressed answers "what did that do?"; this answers the other
/// question, "what *is* that?", for all of them at once and before anything is
/// pressed.
///
/// It reads [mapControls], the same list the buttons take their tooltips from,
/// so a renamed button cannot leave this page describing the old one.
class MapControlsScreen extends ConsumerWidget {
  const MapControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('What the buttons do')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'The map keeps its buttons small and unlabelled so the map itself '
            'has the room. Here is what each of them is.',
            style: theme.textTheme.bodyMedium,
          ),
          for (final area in MapControlArea.values) ...[
            _Heading(area.title),
            for (final c in mapControls.where((c) => c.area == area))
              _ControlRow(c),
          ],
          _Heading('The layer’s own switch, in full'),
          Text(
            'One button in the bottom row changes with the kind of layer you '
            'are on. It is whichever of these the layer has:',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          // Written out from the same descriptions the button and the layer
          // sheet use, so the three cannot drift apart.
          for (final v in _quickToggleVariants) _ControlRow(v),
          _Heading('Tips'),
          Text(
            'After you press one of those switches the map says, in a line, '
            'what is now true. Each tip shows a few times and then stops. You '
            'can stop them sooner, or start them over, in Settings.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(_resetTips(context, ref)),
              icon: const Icon(Icons.refresh),
              label: const Text('Show all tips again'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetTips(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(repositoryProvider).resetHints();
    // The effect is invisible until the next button press, so say it happened.
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Tips will be shown again')));
  }
}

/// The three things the per-layer switch can be, described where the guide can
/// show them all at once — on the map you only ever see one.
const List<MapControl> _quickToggleVariants = [
  MapControl(
    id: MapControlId.quickToggle,
    area: MapControlArea.bottom,
    icon: Icons.select_all,
    name: 'Fill outside',
    what:
        'Colours everything except this layer’s shapes, instead of the '
        'shapes themselves.',
    sometimes:
        'On layers that draw regions — circles, subspaces, lines, '
        'areas.',
  ),
  MapControl(
    id: MapControlId.quickToggle,
    area: MapControlArea.bottom,
    icon: Icons.directions_transit,
    name: 'Stations',
    what: 'Chooses which kinds of station are shown.',
    sometimes: 'On a layer holding an imported set of transit stations.',
  ),
  MapControl(
    id: MapControlId.quickToggle,
    area: MapControlArea.bottom,
    icon: Icons.format_color_fill,
    name: 'Colour areas',
    what: 'Gives each area a colour, chosen so no two neighbours match.',
    sometimes: 'On a $kBorders layer.',
  ),
];

/// A section heading, with the rule above it.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 40),
      Text(text, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
    ],
  );
}

/// One button: the icon exactly as it appears on the map, then its name, what
/// it does, and — where it applies — why it is sometimes not there.
class _ControlRow extends StatelessWidget {
  const _ControlRow(this.control);

  final MapControl control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drawn as the round button it is on the map, so the eye can match
          // the two without reading anything.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              control.icon,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(control.name, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(control.what, style: theme.textTheme.bodySmall),
                if (control.sometimes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    control.sometimes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
