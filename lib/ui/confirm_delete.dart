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

/// Asks before anything is deleted. The one rule, everywhere.
///
/// A move can be abandoned half-way — Cancel on the banner, Reset in the
/// editor — but a delete used to land on the first press, and the first press
/// is often the one that missed the button beside it. Undo could bring the
/// thing back, but only for someone who knew to look for it. So every delete
/// in the app goes through this dialog: an element, a point of one, a layer,
/// a folder, a report. Not counted by `UiHints` and never switched off —
/// a confirmation that goes quiet after three showings would stop protecting
/// exactly the people who have started to press quickly.
///
/// Returns true only for an explicit **Delete**; a dismissal is a no.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String body = 'Undo will bring it back.',
  String action = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}
