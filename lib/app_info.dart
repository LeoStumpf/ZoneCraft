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
const String kAppVersion = '1.4.0';

/// Shown on the About screen under the version.
const String kAppTagline =
    'Composable zone layers on OpenStreetMap — offline, no account, '
    'no tracking.';

/// The contact URL folded into [zoneCraftUserAgent]. The tile policy asks for a
/// User-Agent that "names your app and optionally includes a contact URL or
/// email"; the repository is the address that will outlive any inbox.
const String kAppRepositoryUrl = 'https://github.com/LeoStumpf/ZoneCraft';

/// Where someone who has a problem with the app reaches its author.
///
/// This exists for one audience above all: the people who run the donated
/// services ZoneCraft borrows. They identify a misbehaving client by its
/// [zoneCraftUserAgent] and then have to find a human, and "block it and move
/// on" is what happens when they cannot. So the address is in the app, next to
/// the User-Agent it belongs to, and not only in a repository they would have
/// to go looking for.
const String kContactEmail = 'leo.m.stumpf@gmail.com';

/// The public issue tracker — the other half of the same answer, for anyone who
/// would rather write in the open.
const String kIssuesUrl = '$kAppRepositoryUrl/issues';

/// The one `User-Agent` every outbound request sends.
///
/// OpenStreetMap's tile, Nominatim and API policies all require a string that
/// identifies *this* app and forbid falling back to a library default — and the
/// operators block by exactly this string, so it is the app's identity to them.
/// It lived as four separate literals (tiles, Overpass, Nominatim, terrain),
/// which had already drifted: all four still said `1.0` at app version 1.3.0.
/// Building it from [kAppVersion] means it cannot drift again, and the stable
/// `ZoneCraft/` prefix keeps the app recognisable across releases.
const String zoneCraftUserAgent =
    'ZoneCraft/$kAppVersion (+$kAppRepositoryUrl)';
