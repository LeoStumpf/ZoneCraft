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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database_recovery.dart';
import 'data/error_log.dart';
import 'state/providers.dart';
import 'ui/error_screen.dart';
import 'ui/map_screen.dart';
import 'ui/theme.dart';

/// ZoneCraft sends **no** telemetry of any kind: no crash reporting, no
/// analytics, no advertising identifier. Nothing leaves the device except the
/// map, import and geocoding requests the user's own actions trigger, which are
/// listed in `PRIVACY.md`.
///
/// Crash reporting (Sentry) was wired in here and removed deliberately. Anything
/// added back has to be reflected in `PRIVACY.md` and in the Play Data safety
/// form, which are currently able to say "none" — the simplest true answer there
/// is worth more than the diagnostics were.
///
/// [ErrorLog] is **not** a walk-back of that. It keeps the last few errors in
/// memory, shows them to the user, and lets them press Copy; it never touches
/// the disk and never opens a socket. The decision it reverses is a different
/// one — that a failure should be *silent*. In release, an exception inside a
/// `build()` painted Flutter's default grey rectangle and a throw outside the
/// widget tree went to a `stderr` no phone user can read, so a crash was
/// invisible to the author (by choice) *and* to the person it happened to (by
/// accident). Only the second half was ever intended.
Future<void> main() async {
  // `openDatabaseSafely` reaches path_provider, which needs the binding.
  WidgetsFlutterBinding.ensureInitialized();

  // Both hooks, because they catch different things: `FlutterError.onError` is
  // the framework's own reporting path (build/layout/paint), and
  // `PlatformDispatcher.onError` is everything else that reaches the root zone
  // — an unawaited Future rejecting, a platform-channel callback throwing.
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    ErrorLog.instance.record(details.exception, details.stack);
    priorOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.instance.record(error, stack);
    // False would mark it handled and silence the console in debug, which is
    // where it is genuinely useful.
    return false;
  };
  ErrorWidget.builder = AppErrorWidget.new;
  // So a write that fails deep in an editor can say so, from a callback that
  // has no BuildContext of its own by the time it runs.
  failureNotifier = (message) => appMessengerKey.currentState
      ?.showSnackBar(SnackBar(content: Text(message)));

  // Opened here, before the first frame, so a migration failure is caught where
  // something can be done about it instead of surfacing lazily under whichever
  // widget happens to read a provider first.
  final opened = await openDatabaseSafely();

  runApp(
    ProviderScope(
      observers: [ErrorLogObserver()],
      overrides: [
        databaseProvider.overrideWithValue(opened.database),
      ],
      child: ZoneCraftApp(recovery: opened),
    ),
  );
}

/// Records provider failures, which otherwise reach nothing at all.
///
/// Every one of the ~20 `StreamProvider`s is read as
/// `ref.watch(x).asData?.value ?? const []`, and `asData` is null for
/// `AsyncError` exactly as it is for `AsyncLoading`. So a failed migration, a
/// corrupt database or a full disk rendered as a **normal, empty map** — no
/// error, no retry, nothing to distinguish "your data could not be read" from
/// "you have not made anything yet". The rational response to that screen is to
/// reinstall, or to press "Clear all data" — destroying data that was still
/// there.
///
/// Fixing it at the ~40 read sites would be forty chances to miss one. The
/// error arrives here instead, once, and `MapScreen` asks [firstFailure]
/// before it draws.
final class ErrorLogObserver extends ProviderObserver {
  /// The first provider error of the run, or null. First rather than latest:
  /// one root cause (the database not opening) makes every dependent provider
  /// fail after it, and the first is the one worth showing.
  static final ValueNotifier<Object?> firstFailure =
      ValueNotifier<Object?>(null);

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    ErrorLog.instance.record(
      error,
      stackTrace,
      context: context.provider.name ?? 'Loading data',
    );
    firstFailure.value ??= error;
  }
}

/// The root messenger, so a failure with no context of its own can still
/// reach the user. The drawer keeps its own — a Scaffold draws its drawer
/// above its snackbars — and that is unaffected.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class ZoneCraftApp extends StatelessWidget {
  const ZoneCraftApp({required this.recovery, super.key});

  final DatabaseOpenResult recovery;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoneCraft',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      // One theme, written out rather than seeded, and grounded in the map's
      // own palette — see `ui/theme.dart` for why seeding cannot express it.
      theme: zoneCraftLightTheme(),
      home: _Root(recovery: recovery),
    );
  }
}

/// Shows the map, unless the data layer failed — in which case it says so
/// rather than letting an empty map imply the data is gone.
class _Root extends StatefulWidget {
  const _Root({required this.recovery});

  final DatabaseOpenResult recovery;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool _recoveryAcknowledged = !widget.recovery.recovered;

  @override
  Widget build(BuildContext context) {
    // Rare and serious enough to interrupt for: the user's map is not on
    // screen and they need to know why before they start drawing a new one
    // over the top of it.
    if (!_recoveryAcknowledged) {
      return DatabaseRecoveredScreen(
        quarantinedPath: widget.recovery.quarantinedPath,
        error: widget.recovery.error,
        onContinue: () => setState(() => _recoveryAcknowledged = true),
      );
    }
    return ValueListenableBuilder<Object?>(
      valueListenable: ErrorLogObserver.firstFailure,
      builder: (context, failure, child) {
        if (failure != null) {
          return DataUnavailableScreen(
            error: failure,
            onRetry: () => ErrorLogObserver.firstFailure.value = null,
          );
        }
        return child!;
      },
      child: const MapScreen(),
    );
  }
}
