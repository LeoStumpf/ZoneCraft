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
import 'package:latlong2/latlong.dart';

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

/// One position fix, asked for now: the permission gate, a fix under a time
/// limit, and a check that it is a real number.
///
/// Returns the fix, or a ready-to-show sentence saying why there is none —
/// never both. Shared by the map's Locate me and the Elements list's "distance
/// from you" sort, so the two cannot grow different ideas of what a usable fix
/// is. Has no side effects: the caller decides what to do with the result.
Future<({LatLng? fix, String? problem})> currentPosition() async {
  try {
    final problem = await ensureLocationReady();
    if (problem != null) return (fix: null, problem: problem);
    // A time limit, because indoors or with a cold GPS `getCurrentPosition`
    // simply never returns. The plugin throws TimeoutException, which the
    // catch below turns into a sentence.
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 20),
      ),
    );
    // A NaN LatLng would corrupt the map camera and crash every subsequent
    // projection.
    if (!pos.latitude.isFinite || !pos.longitude.isFinite) {
      return (
        fix: null,
        problem: 'Could not get a valid location fix. Try again outdoors.',
      );
    }
    return (fix: LatLng(pos.latitude, pos.longitude), problem: null);
    // geolocator throws a family of typed errors (service off, permission
    // gone, timeout) that all end in the same sentence.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return (fix: null, problem: 'Could not get your location.');
  }
}
