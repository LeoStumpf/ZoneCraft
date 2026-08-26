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
import 'package:zonecraft/app_info.dart';

/// The About screen states a version, and a stated version that lags the build
/// is worse than none — it is the first thing a bug report quotes. This is the
/// guard that lets [kAppVersion] be a plain constant instead of a dependency
/// that reads it back from the platform at runtime.
void main() {
  test('kAppVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');

    // `1.1.0+2` — the build number is Play's, not the user's.
    final declared = match!.group(1)!.split('+').first;
    expect(
      kAppVersion,
      declared,
      reason: 'lib/app_info.dart and pubspec.yaml have drifted — update both',
    );
  });
}
