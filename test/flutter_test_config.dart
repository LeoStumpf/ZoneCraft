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

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Lays text out with the font a device uses, so an overflow here is real.
///
/// `flutter_test` renders every family it has not been given in a
/// placeholder whose glyphs are square boxes, wider than Roboto's. A `Row`
/// that fits on the Pixel could overflow in a test for no reason but the
/// font, so the overflow errors were filtered out — and with them the only
/// automated look at "does this fit at this width and text scale". Loading
/// Roboto and the icon font from the Flutter SDK's own cache (the same files
/// in CI, which uses the same SDK) makes the measurements a device's, and the
/// filter unnecessary.
///
/// If the cache is missing the tests still run, in the placeholder font; the
/// layout sweep (`visual_robustness_test.dart`) is then the only thing that
/// may report an overflow that is the font's fault.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await _loadSdkFonts();
  await testMain();
}

Future<void> _loadSdkFonts() async {
  final dir = _materialFontsDir();
  if (dir == null) return;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final file = File('${dir.path}/$name');
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      any = true;
    }
    if (any) await loader.load();
  }

  await load('Roboto', const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
    'Roboto-Light.ttf',
  ]);
  await load('MaterialIcons', const ['MaterialIcons-Regular.otf']);
}

/// `<flutter>/bin/cache/artifacts/material_fonts`, from `FLUTTER_ROOT` when
/// the tool sets it, else found by walking up from the executable running
/// the tests (`flutter_tester`, which lives under the same `bin/cache`).
Directory? _materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) return dir;
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final fonts = Directory('${dir.path}/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    dir = dir.parent;
  }
  return null;
}
