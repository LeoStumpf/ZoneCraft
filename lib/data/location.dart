import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:geolocator/geolocator.dart';

/// The device's location, as the two things the app asks of it: "may I?" and
/// "tell me when I move".
///
/// Both callers — the one-shot "Locate me" button and the track recorder —
/// need the same service-enabled/permission dance, and it is the kind of code
/// that rots into two subtly different copies (one asking for permission the
/// other assumes it has). It lives here once.
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

/// A stream of fixes, one per [distanceFilter] metres moved.
///
/// The filter is what keeps a recording honest and small: standing still emits
/// nothing at all, so a phone left on a table adds no rows and no jitter.
///
/// Deliberately **no** `timeLimit`: on a stream the plugin turns that into an
/// error instead of patience, and a cold GPS fix outdoors can easily take
/// longer than any limit worth setting. A recording that has not started
/// moving yet simply has no points.
///
/// On Android it asks for the **platform location manager** rather than the
/// fused (Play services) provider, which is the opposite of what a
/// "where am I roughly" call wants and the right thing for a recording:
///
/// - fused answers from Wi-Fi and cell towers when GNSS is weak, and a
///   2 km-accurate fix dropped into a walk is not a smoothing artefact, it is
///   a vertex through a neighbouring town;
/// - it keeps recording working on a phone with no Play services at all, which
///   is a device this app should be good on.
///
/// The one-shot [Geolocator.getCurrentPosition] behind "Locate me" deliberately
/// keeps the default: there, a quick approximate answer *is* the feature.
///
/// (It also happens to be the only path the Android emulator's `geo fix`
/// reaches — under fused it delivers the first location and then nothing, which
/// looks exactly like a broken recorder.)
Stream<Position> positionStream({required double distanceFilter}) {
  final filter = distanceFilter.isFinite && distanceFilter > 0
      ? distanceFilter.round()
      : 0;
  return Geolocator.getPositionStream(
    locationSettings: defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.best,
            distanceFilter: filter,
          )
        : LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: filter,
          ),
  );
}
