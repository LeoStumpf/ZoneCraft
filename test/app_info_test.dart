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
