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

import '../state/import_preview.dart';
import 'editor_sheet.dart';

/// The Keep / Discard bar under a file that has been read but not written.
///
/// Deliberately the same shape as `ReceivedPlaceSheet`: both are an *offer*
/// drawn on the map with nothing saved behind it, and both say so in as many
/// words, because the whole value of the step is knowing that backing out costs
/// nothing.
class PendingImportSheet extends StatelessWidget {
  const PendingImportSheet({
    super.key,
    required this.pending,
    required this.onKeep,
    required this.onDiscard,
  });

  final PendingImport pending;
  final VoidCallback onKeep;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.file_open_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Import this?',
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Discard',
              icon: const Icon(Icons.close),
              onPressed: onDiscard,
            ),
          ],
        ),
        Text(pending.summary, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Shown on the map above. Nothing has been saved yet.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        // Wrap rather than Row: at a large system font a pair of labelled
        // buttons is exactly the thing a bottom sheet clips away silently.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onKeep,
              icon: const Icon(Icons.check),
              label: const Text('Keep'),
            ),
            TextButton(onPressed: onDiscard, child: const Text('Discard')),
          ],
        ),
      ],
    );
  }
}
