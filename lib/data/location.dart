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

import 'package:geolocator/geolocator.dart';

/// The device's location, as the one thing the app asks of it: "may I?".
///
/// The one-shot "Locate me" button is the only caller today (track recording,
/// which shared this gate, was dropped in v27), but the service-enabled /
/// permission dance stays here on its own so a second caller cannot grow a
/// subtly different copy of it.
///
/// **Foreground only.** Nothing here asks for background location, and nothing
/// starts a foreground service: the manifest, the iOS usage string and
/// `PRIVACY.md` all promise that the app never reads your position while it is
/// not open, and this is the file that has to keep that true.

/// Checks that location can be used, asking for permission if it has not been
/// asked yet.
///
/// Returns null when good, or a ready-to-show sentence explaining why not.
/// A message rather than an enum because every caller does the same thing with
/// it — put it in a snackbar — and an enum would just move the wording to two
/// places.
Future<String?> ensureLocationReady() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return 'Location services are off. Enable them to use location.';
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'Location permission denied. ZoneCraft works fine without it.';
  }
  return null;
}
