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

import 'map_controls_screen.dart';

/// The key [Repository.noteHintShown] counts this against. Shown **once**.
///
/// One, not the usual three: a tip that teaches a button earns repeating,
/// because the user meets that button again and may not have read it. A
/// statement of what the app is for is read or dismissed, and showing it again
/// on the second launch reads as the app not trusting you.
const String kWelcomeHintKey = 'hint.firstRun';

/// What ZoneCraft is for, said once, on the map.
///
/// The app never said it. The one sentence that explains it — "turns a map into
/// a deduction board… watch the possible area shrink to where it has to be" —
/// lived in README.md, where no user is. In the app, every explanation answered
/// "what does this button do" (the guide) or "which servers does it contact"
/// (About); nothing answered "why would I open this?". A first-time user got a
/// map of somewhere they do not live and twelve unlabelled icons.
///
/// So: the idea, one worked example of the loop, and a door to the guide. It is
/// a bottom sheet rather than a full-screen tour because the map stays visible
/// behind it — the thing being explained is right there.
Future<void> showWelcomeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _WelcomeSheet(),
  );
}

class _WelcomeSheet extends StatelessWidget {
  const _WelcomeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        // The same 60 % cap the editors use: the map has to stay visible.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Welcome to ZoneCraft', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'ZoneCraft turns a map into a deduction board. Each thing you '
                'learn about where something is becomes a zone; stack the '
                'zones, and the area it could be in shrinks to where it has '
                'to be.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text('For example', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              const _Step(
                icon: Icons.circle_outlined,
                text: '“They are within 2 km of the station.” Add a circle '
                    'there and set its radius.',
              ),
              const _Step(
                icon: Icons.flip_to_back,
                text: '“No, they are not.” Press Fill outside — now the zone '
                    'is everywhere except that circle.',
              ),
              const _Step(
                icon: Icons.layers_outlined,
                text: 'Add a layer per answer. Where the colours overlap is '
                    'what is left.',
              ),
              const SizedBox(height: 20),
              Text(
                'Everything stays on this phone. There is no account, and '
                'nothing is uploaded.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        unawaited(
                          nav.push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MapControlsScreen(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text('What the buttons do'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You can read this again from Settings → Show all tips '
                'again.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
