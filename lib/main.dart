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
