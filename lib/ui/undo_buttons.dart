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

import '../state/providers.dart';

/// The back/forward pair, as map chrome rather than as FABs.
///
/// The FAB column is hidden whenever a selection or an editor sheet is up —
/// which is exactly when a wrong radius or a mis-tapped icon wants taking back
/// — so these live beside the menu button instead, for the same reason the
/// compass does. Both stay visible and simply grey out when their stack is
/// empty, so their place on screen never moves.
class UndoButtons extends ConsumerWidget {
  const UndoButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(undoStateProvider).asData?.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Button(
          icon: Icons.undo,
          // The label names the step, so you can tell what a press will take
          // back before you press it.
          tooltip: state?.undoLabel == null
              ? 'Nothing to undo'
              : 'Undo ${_lower(state!.undoLabel!)}',
          onPressed: state?.canUndo ?? false
              ? () => applyUndo(ref)
              : null,
        ),
        const SizedBox(width: 8),
        _Button(
          icon: Icons.redo,
          tooltip: state?.redoLabel == null
              ? 'Nothing to redo'
              : 'Redo ${_lower(state!.redoLabel!)}',
          onPressed: state?.canRedo ?? false
              ? () => applyUndo(ref, forward: true)
              : null,
        ),
      ],
    );
  }

  /// "Delete layer" -> "delete layer", so the tooltip reads as one sentence.
  /// Acronyms keep their case ("POI"), which is why this only touches the first
  /// character.
  static String _lower(String label) =>
      label.isEmpty ? label : label[0].toLowerCase() + label.substring(1);
}

/// One circular chrome button, in the shape the menu button and the compass
/// already use.
class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
