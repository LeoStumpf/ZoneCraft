import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'ui/map_screen.dart';

/// Sentry DSN, baked in at build time via `--dart-define=SENTRY_DSN=...`. Empty
/// for local/debug builds, in which case crash reporting is skipped entirely.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() {
  if (_sentryDsn.isEmpty) {
    // No DSN (dev build): start normally, no telemetry.
    runApp(const ProviderScope(child: ZoneCraftApp()));
    return;
  }
  SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      // Crash/error reporting only — no performance tracing.
      options.tracesSampleRate = 0;
    },
    appRunner: () => runApp(const ProviderScope(child: ZoneCraftApp())),
  );
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
