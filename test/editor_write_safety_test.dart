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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A source-level test, because the thing being guarded is a *habit*.
///
/// The editors fire repository writes without awaiting them: the UI is
/// optimistic and a slider tick must not wait on SQLite. The cost is that a
/// rejected write — a full disk, `SQLITE_BUSY`, a constraint violation —
/// becomes an unhandled async error, and on screen an edit that looked saved
/// until the next stream emission quietly takes it away. `logAsyncFailure`
/// exists to make that visible.
///
/// It was applied to five editors and missed three, because the fix was
/// applied to a list rather than to the pattern. A list can be incomplete
/// twice; a grep cannot.
void main() {
  final editors =
      Directory('lib/ui')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_editor.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('there are editors to check', () {
    expect(editors.length, greaterThanOrEqualTo(8));
  });

  for (final file in editors) {
    final name = file.path.split('/').last;

    test('$name reports its failed writes', () {
      final offenders = <String>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // `unawaited(` on its own, or wrapping a repository call directly.
        // Navigation and animation futures are legitimately dropped; a write
        // to the user's map is not.
        if (!line.contains('unawaited(')) continue;
        final tail = lines.skip(i).take(3).join(' ');
        if (tail.contains('_repo.') || tail.contains('repo.')) {
          offenders.add('  ${i + 1}: ${line.trim()}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These repository writes drop their failure silently. Use '
            'logAsyncFailure(future, "What the user was doing") so a lost '
            'edit says so:\n${offenders.join('\n')}',
      );
    });
  }
}
