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
import 'package:zonecraft/data/overpass_client.dart' show overpassUserAgent;
import 'package:zonecraft/data/tile_source.dart' show tileUserAgent;

/// The About screen states a version, and a stated version that lags the build
/// is worse than none — it is the first thing a bug report quotes. This is the
/// guard that lets [kAppVersion] be a plain constant instead of a dependency
/// that reads it back from the platform at runtime.
void main() {
  test('kAppVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');

    // `1.1.0+2` — the build number is Play's, not the user's.
    final declared = match!.group(1)!.split('+').first;
    expect(
      kAppVersion,
      declared,
      reason: 'lib/app_info.dart and pubspec.yaml have drifted — update both',
    );
  });

  group('the User-Agent', () {
    // OSMF, Overpass and Nominatim all require a string that identifies this
    // app, all forbid a library default, and all *block* by exactly this
    // string: it is the app's identity to the people whose servers it uses.
    test('identifies the app, as every policy requires', () {
      expect(zoneCraftUserAgent, startsWith('ZoneCraft/'));
      expect(zoneCraftUserAgent, contains('github.com'));
      expect(zoneCraftUserAgent, isNot(contains('flutter')));
      expect(zoneCraftUserAgent, isNot(contains('com.example')));
    });

    test('carries the real version', () {
      // It lived as four hand-kept copies and every one of them still said
      // 1.0 at app version 1.3.0 — which is how an operator ends up unable to
      // tell which release is misbehaving.
      expect(zoneCraftUserAgent, contains(kAppVersion));
    });

    test('is the same string for every service', () {
      expect(tileUserAgent, zoneCraftUserAgent);
      expect(overpassUserAgent, zoneCraftUserAgent);
    });
  });
}
