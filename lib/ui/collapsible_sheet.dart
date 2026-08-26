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

/// Wraps a docked editor sheet with a grip bar that collapses it to just that
/// bar — so the map (and any point handles) hidden behind the sheet become
/// reachable without deselecting. The wrapped [child] keeps its state while
/// collapsed (edits still apply live), and re-expands on tap.
class CollapsibleSheet extends StatefulWidget {
  const CollapsibleSheet({super.key, required this.child});

  final Widget child;

  @override
  State<CollapsibleSheet> createState() => _CollapsibleSheetState();
}

class _CollapsibleSheetState extends State<CollapsibleSheet> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The grip shares the editor's raised surface so the two read as one
        // sheet; tapping it toggles the body.
        Material(
          elevation: 8,
          color: scheme.surface,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: SizedBox(
              height: 22,
              width: double.infinity,
              child: Center(
                child: _expanded
                    ? Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    : Icon(Icons.keyboard_arrow_up,
                        size: 20, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        // Kept in the tree while collapsed (maintainState) so controllers and
        // focus survive; takes zero space when hidden.
        Visibility(
          visible: _expanded,
          maintainState: true,
          child: widget.child,
        ),
      ],
    );
  }
}
