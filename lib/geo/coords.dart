import 'package:latlong2/latlong.dart';

/// Parses a number the way the person typing it meant it, accepting **either**
/// decimal separator.
///
/// `double.tryParse` only accepts `.`, but on a German/French/Spanish device the
/// numeric keyboard's decimal key is `,`. Typing `1,5` into a radius field
/// therefore returned null and the field silently did nothing — no error, no
/// change. Every numeric input in the app goes through here instead.
///
/// Only a *lone* comma is treated as a decimal point. `1,234` is genuinely
/// ambiguous (1.234 in Germany, 1234 in the UK), so a comma with exactly three
/// digits after it and at least one before is read as a **thousands** grouping
/// and dropped — the reading that agrees with both conventions on the value.
/// Anything with more than one comma is grouping too (`1,234,567`).
double? parseDecimal(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (s.contains('.') && s.contains(',')) {
    // Both present: whichever comes last is the decimal separator, the other is
    // grouping. Covers "1.234,5" and "1,234.5" alike.
    final decimal = s.lastIndexOf('.') > s.lastIndexOf(',') ? '.' : ',';
    s = s.replaceAll(decimal == '.' ? ',' : '.', '');
    if (decimal == ',') s = s.replaceAll(',', '.');
  } else if (s.contains(',')) {
    s = RegExp(r'^-?\d+(,\d{3})+$').hasMatch(s)
        ? s.replaceAll(',', '') // grouping: 1,234 / 1,234,567
        : s.replaceAll(',', '.'); // decimal: 1,5
  }
  final n = double.tryParse(s);
  return (n != null && n.isFinite) ? n : null;
}

/// Parses a single "lat, lng" string into a [LatLng], or null if it isn't two
/// valid, in-range numbers.
///
/// Accepts what you get from Google Maps ("right-click → copy" gives
/// `48.137154, 11.575382`), as well as space- or comma-separated variants and
/// optional surrounding whitespace/parentheses. Longitude beyond ±180 is
/// rejected; latitude beyond ±90 too.
///
/// A comma-decimal pair (`48,137154 11,575382`, which is what a German keyboard
/// produces) splits into **four** pieces rather than two; they are rejoined
/// pairwise, since the only reading of four numbers here is two coordinates.
/// [parseDecimal] cannot be used on the two-piece path for that reason: the
/// comma has already been consumed as the separator.
LatLng? parseLatLng(String input) {
  // Strip parentheses and any leading/trailing junk, then split on comma or
  // whitespace runs.
  final cleaned = input.replaceAll(RegExp(r'[()]'), '').trim();
  var parts = cleaned
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length == 4) {
    parts = ['${parts[0]}.${parts[1]}', '${parts[2]}.${parts[3]}'];
  }
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
