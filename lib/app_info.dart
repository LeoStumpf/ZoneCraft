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
const String kAppVersion = '1.3.0';

/// Shown on the About screen under the version.
const String kAppTagline =
    'Composable zone layers on OpenStreetMap — offline, no account, '
    'no tracking.';
