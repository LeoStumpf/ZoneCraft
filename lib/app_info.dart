/// Facts about the build that the UI needs to state out loud.
///
/// The version is a plain constant rather than `package_info_plus`. That
/// package is already in the tree — transitively, via `geolocator_linux` — but
/// promoting it to a declared dependency, and adding an async platform call at
/// startup, to read back a number this repo already controls is a poor trade
/// for one string. `test/app_info_test.dart` parses `pubspec.yaml` and fails if
/// the two ever diverge, which is the only thing the package would have bought.
library;

/// The user-facing version, matching `pubspec.yaml`'s `version:` before the
/// `+buildNumber`.
const String kAppVersion = '1.2.0';

/// Shown on the About screen under the version.
const String kAppTagline =
    'Composable zone layers on OpenStreetMap — offline, no account, '
    'no tracking.';
