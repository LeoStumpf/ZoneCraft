import 'package:latlong2/latlong.dart';

/// Parses a single "lat, lng" string into a [LatLng], or null if it isn't two
/// valid, in-range numbers.
///
/// Accepts what you get from Google Maps ("right-click → copy" gives
/// `48.137154, 11.575382`), as well as space- or comma-separated variants and
/// optional surrounding whitespace/parentheses. Longitude beyond ±180 is
/// rejected; latitude beyond ±90 too.
LatLng? parseLatLng(String input) {
  // Strip parentheses and any leading/trailing junk, then split on comma or
  // whitespace runs.
  final cleaned = input.replaceAll(RegExp(r'[()]'), '').trim();
  final parts = cleaned
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lng = double.tryParse(parts[1]);
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}

/// Formats a coordinate as a copy-paste-friendly "lat, lng" string.
String formatLatLng(double lat, double lng) =>
    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
