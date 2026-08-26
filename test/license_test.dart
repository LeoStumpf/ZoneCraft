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

/// Guards the licence the way `tile_source_test` guards prefetching: what is
/// being protected is a decision, and the way it erodes is a new file added
/// without thinking about it.
void main() {
  const notice = 'GNU Affero General Public License';

  test('LICENSE is the AGPL, verbatim and complete', () {
    final text = File('LICENSE').readAsStringSync();
    expect(text, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
    expect(text, contains('Version 3, 19 November 2007'));
    // The section that distinguishes the AGPL from the GPL. Its absence would
    // mean the plain GPL text had been dropped in by mistake.
    expect(text, contains('Remote Network Interaction'));
    expect(text, contains('END OF TERMS AND CONDITIONS'));
  });

  test('every source file carries the licence header', () {
    final offenders = <String>[];
    for (final dir in ['lib', 'test', 'tool']) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final f in root.listSync(recursive: true).whereType<File>()) {
        final path = f.path;
        if (!path.endsWith('.dart')) continue;
        // Generated code is rewritten wholesale by build_runner and drift, so
        // a header there would not survive the next regeneration.
        if (path.endsWith('.g.dart')) continue;
        if (path.contains('generated_migrations')) continue;
        final head = f.readAsStringSync();
        if (!head.substring(0, head.length.clamp(0, 1200)).contains(notice)) {
          offenders.add(path);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'These files are missing the AGPL header:\n${offenders.join('\n')}',
    );
  });

  test('the docs do not still claim the old licence', () {
    for (final doc in ['README.md', 'THIRD_PARTY_NOTICES.md', 'LICENSE']) {
      final text = File(doc).readAsStringSync().toLowerCase();
      expect(text, isNot(contains('beer-ware')), reason: '$doc is stale');
    }
    expect(File('README.md').readAsStringSync(), contains(notice));
  });
}
