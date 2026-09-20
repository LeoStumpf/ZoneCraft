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
import 'package:flutter_localizations/flutter_localizations.dart';
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
  failureNotifier = (message) => appMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message)),
  );

  // Opened here, before the first frame, so a migration failure is caught where
  // something can be done about it instead of surfacing lazily under whichever
  // widget happens to read a provider first.
  //
  // **Everything from here to `runApp` is inside a catch, and that is the whole
  // point.** This work happens before there is a widget tree, so a throw would
  // leave the app with nothing at all: `ErrorWidget.builder` above needs a tree
  // to build into, and the in-memory [ErrorLog] is only reachable through a
  // screen. The user would get a black window, on every launch, with no way
  // out — which is exactly the unfixable-from-inside state
  // `database_recovery.dart` exists to prevent, reintroduced one level up.
  //
  // `openDatabaseSafely` is itself total and documents that as a contract, so
  // this is a backstop rather than the mechanism: it covers whatever else ends
  // up here later.
  DatabaseOpenResult? opened;
  Object? bootFailure;
  try {
    opened = await openDatabaseSafely();
    // Whatever it was — there is no widget tree yet, so the alternative to
    // catching it is a black screen with no way out.
    // ignore: avoid_catches_without_on_clauses
  } catch (e, s) {
    ErrorLog.instance.record(e, s, context: 'Starting up');
    bootFailure = e;
  }

  final database = opened?.database;
  if (database == null) {
    // No database at all — not even a fresh one. There is nothing for the
    // providers to read, so the app runs without a ProviderScope and shows the
    // one screen that needs no data.
    runApp(
      _FailedStart(error: bootFailure ?? opened?.error ?? 'Unknown error'),
    );
    return;
  }

  runApp(
    ProviderScope(
      observers: [ErrorLogObserver()],
      overrides: [databaseProvider.overrideWithValue(database)],
      child: ZoneCraftApp(recovery: opened!),
    ),
  );
}

/// The app when it has no database to show — the one case where ZoneCraft
/// starts without a `ProviderScope`, because every provider would fail.
class _FailedStart extends StatelessWidget {
  const _FailedStart({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoneCraft',
      debugShowCheckedModeBanner: false,
      theme: zoneCraftLightTheme(),
      home: DataUnavailableScreen(error: error),
    );
  }
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
  static final ValueNotifier<Object?> firstFailure = ValueNotifier<Object?>(
    null,
  );

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

/// The locales the app will resolve to.
///
/// **Declaring the delegates alone does nothing.** Flutter resolves the device
/// locale against this list first, so with `[Locale('en')]` a German phone
/// resolves to English and every Material widget renders English anyway —
/// which is the state this is fixing.
///
/// So the list is every locale Flutter itself translates, minus the
/// right-to-left ones. That split is deliberate, and the two halves are
/// different kinds of thing:
///
/// * **Platform chrome** — the date picker, the text-selection menu, the
///   reorderable list's semantics — is Flutter's, translated by Flutter, and a
///   German user long-pressing text should get "Einfügen". That is not a
///   half-translated app; it is system UI in the system's language.
/// * **ZoneCraft's own ~650 strings** are English, several of them the long
///   explanatory prose the app is actually built around. Translating those is
///   a content job, not a string extraction, and it is not done. The store
///   listing says English.
///
/// RTL is excluded because it is **untested**, not because it is unwanted:
/// declaring `ar` flips the whole layout, and the map chrome, the FAB row and
/// the banner column have never been looked at mirrored. Shipping a layout
/// nobody has seen is worse for an Arabic speaker than leaving them the
/// English one they can at least read around. Remove a code from here once its
/// direction has actually been checked on a device.
const Set<String> _untestedRtlLanguages = {
  'ar',
  'fa',
  'he',
  'iw',
  'ps',
  'sd',
  'ug',
  'ur',
  'yi',
  'ji',
};

/// English is **first, deliberately**. When the device locale matches nothing
/// in this list, Flutter falls back to `supportedLocales.first` — and
/// `kMaterialSupportedLanguages` is a `HashSet`, whose iteration order is
/// arbitrary. Built straight from it, an Arabic or Thai phone would have
/// landed on whatever language happened to come out first, which is a worse
/// answer than English and a much stranger one.
List<Locale> get supportedLocales => [
  const Locale('en'),
  for (final code in kMaterialSupportedLanguages.toList()..sort())
    if (code != 'en' && !_untestedRtlLanguages.contains(code)) Locale(code),
];

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
      // Flutter's own widgets carry translations for ~80 locales and use none
      // of them unless the delegates are declared. Without these, a German
      // phone showed an English date picker, an English "Paste" in the text
      // menu and English semantics on the reorderable layer list, inside an
      // otherwise translated system — and with no supportedLocales at all,
      // nothing was ever laid out right-to-left.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      // One theme, written out rather than seeded, and grounded in the map's
      // own palette — see `ui/theme.dart` for why seeding cannot express it.
      theme: zoneCraftLightTheme(),
      // Full screens — Settings, About, the guide, the outbox — follow the
      // system. The map does not: `MapScreen` pins its own subtree light,
      // because the tiles are bright paper whatever the system says and dark
      // chrome on a bright map is a contrast bug, not dark mode.
      darkTheme: zoneCraftDarkTheme(),
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
      // The map is pinned light, whatever the system theme is.
      //
      // osm-carto has no dark variant: the tiles are bright warm paper at 3am
      // as much as at noon, so chrome that followed the system would be dark
      // buttons on a bright map. That is not dark mode, it is a contrast bug
      // — the "half-migrated dark mode, worse than none" this app avoided
      // until there was a rule for it. The rule: the map and everything drawn
      // over it is light; every full screen the app pushes follows the system.
      //
      // It wraps MapScreen from **outside**, not inside its build. That is
      // load-bearing: `map_screen.build` reads `Theme.of(context)` inline in
      // dozens of places, and a wrapper returned *by* that method is below the
      // context those calls use — so the greyed FABs went dark while the ones
      // that resolve the theme in their own build (MapChrome) stayed light.
      // An ancestor puts the whole subtree, and MapScreen's own context, on
      // the light theme.
      //
      // Pushed routes build under MaterialApp's theme and still follow the
      // system; the sheets and dialogs raised from the map's context inherit
      // this one, which is what we want, since they sit on top of the map.
      child: Theme(data: zoneCraftLightTheme(), child: const MapScreen()),
    );
  }
}
