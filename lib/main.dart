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

import 'ui/map_screen.dart';

/// ZoneCraft sends **no** telemetry of any kind: no crash reporting, no
/// analytics, no advertising identifier. Nothing leaves the device except the
/// map, import and geocoding requests the user's own actions trigger, which are
/// listed in `PRIVACY.md`.
///
/// Crash reporting (Sentry) was wired in here and removed deliberately. Anything
/// added back has to be reflected in `PRIVACY.md` and in the Play Data safety
/// form, which are currently able to say "none" — the simplest true answer there
/// is worth more than the diagnostics were.
void main() {
  runApp(const ProviderScope(child: ZoneCraftApp()));
}

class ZoneCraftApp extends StatelessWidget {
  const ZoneCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoneCraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
