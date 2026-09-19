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

/// The app id is written down in five places that no compiler compares:
/// Gradle's `namespace` + `applicationId`, the Kotlin `package` (and the
/// directory it must live in), the `MethodChannel` name on both sides of the
/// platform channel, the tile client's `userAgentPackageName`, and `APP_ID` in
/// the two scripts that drive `adb`.
///
/// The Kotlin↔Dart channel pair is the dangerous one: a mismatch analyzes,
/// compiles and launches clean, and only shows up when a file is shared into
/// the app or an export is saved out of it — on a device, by hand. It was
/// briefly wrong once already (`userAgentPackageName` said
/// `com.zonecraft.zonecraft`), so this reads the files instead of trusting a
/// search-and-replace.
void main() {
  const appId = 'io.github.leostumpf.zonecraft';

  String read(String path) => File(path).readAsStringSync();

  String? capture(String path, RegExp pattern) =>
      pattern.firstMatch(read(path))?.group(1);

  test('Gradle declares the app id as its namespace and applicationId', () {
    const gradle = 'android/app/build.gradle.kts';
    expect(capture(gradle, RegExp(r'namespace\s*=\s*"([^"]+)"')), appId);
    expect(capture(gradle, RegExp(r'applicationId\s*=\s*"([^"]+)"')), appId);
  });

  test(
    'MainActivity.kt declares the app id, and sits where it says it does',
    () {
      // A Kotlin file whose package and directory disagree still compiles, and
      // the mismatch surfaces as a ClassNotFoundException at launch.
      final dir = appId.split('.').join('/');
      final path = 'android/app/src/main/kotlin/$dir/MainActivity.kt';
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'MainActivity.kt must live at the path its package spells out',
      );
      expect(
        capture(path, RegExp(r'^package\s+(\S+)', multiLine: true)),
        appId,
      );
    },
  );

  test('both halves of the file channel name the same channel', () {
    final dir = appId.split('.').join('/');
    final kotlin = capture(
      'android/app/src/main/kotlin/$dir/MainActivity.kt',
      RegExp(r'const val CHANNEL = "([^"]+)"'),
    );
    final dart = capture(
      'lib/data/platform_files.dart',
      RegExp(r"MethodChannel\(\s*'([^']+)'"),
    );
    expect(kotlin, '$appId/files');
    expect(dart, kotlin);
  });

  test('the tile client identifies itself with the app id', () {
    expect(
      capture(
        'lib/ui/map_screen.dart',
        RegExp(r"userAgentPackageName:\s*'([^']+)'"),
      ),
      appId,
    );
  });

  test('the adb scripts target the app id', () {
    for (final script in ['scripts/build.sh', 'scripts/screenshots.sh']) {
      expect(
        capture(script, RegExp(r'^APP_ID="([^"]+)"', multiLine: true)),
        appId,
        reason: '$script drives adb against the installed package',
      );
    }
  });

  test('nothing still carries the pre-rename id', () {
    // The id moved to io.github.* (the reverse of leostumpf.github.io, a name
    // that is provably ours) before the first Play upload, which is the last
    // moment it can move at all.
    for (final path in const [
      'android/app/build.gradle.kts',
      'android/app/src/main/AndroidManifest.xml',
      'lib/data/platform_files.dart',
      'lib/ui/map_screen.dart',
      'ios/Runner/Info.plist',
      'ios/Runner.xcodeproj/project.pbxproj',
      'scripts/build.sh',
      'scripts/screenshots.sh',
    ]) {
      expect(read(path), isNot(contains('com.leostumpf')), reason: path);
    }
  });

  test('the iOS bundle id matches, tests included', () {
    final pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
    final ids = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
    ).allMatches(pbxproj).map((m) => m.group(1)).toSet();
    expect(ids, {appId, '$appId.RunnerTests'});
  });
}
