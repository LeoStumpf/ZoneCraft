import 'package:latlong2/latlong.dart';

import '../geo/coords.dart';

/// The URI scheme a shared ZoneCraft position uses.
///
/// A **custom** scheme, not `https`: an https App Link only opens the app when
/// the domain serves a matching `.well-known/assetlinks.json`, and there is no
/// domain to host one on. The trade is that WhatsApp will not linkify
/// `zonecraft://…` — which is exactly why [shareMessage] never relies on the
/// link alone and why the paste path exists.
const String kSharedPointScheme = 'zonecraft';

/// The host part of a shared-position link (`zonecraft://p?…`). A host rather
/// than a path so a later "share a layer" link can be `zonecraft://l?…`
/// without either having to parse the other's shape.
const String _sharedPointHost = 'p';

/// One position someone sent, or is about to send: a coordinate and an
/// optional name for it.
///
/// Deliberately *not* an element. Receiving a position must not write to the
/// database — a link tapped by accident should leave nothing behind — so this
/// is the pure value that travels, and turning it into a circle or a POI is a
/// separate, explicit step.
class SharedPoint {
  const SharedPoint({required this.lat, required this.lng, this.name});

  final double lat;
  final double lng;

  /// What to call it, when the sender named it. Trimmed and never empty —
  /// [named] is the only constructor that sets it.
  final String? name;

  /// A [SharedPoint] with [name] normalised: whitespace trimmed, an empty or
  /// whitespace-only name becoming null, and a non-finite or out-of-range
  /// coordinate rejected outright.
  static SharedPoint? named(double lat, double lng, [String? name]) {
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    final n = name?.trim();
    return SharedPoint(lat: lat, lng: lng, name: (n == null || n.isEmpty) ? null : n);
  }

  LatLng get latLng => LatLng(lat, lng);

  /// The coordinate in the app's one display format (`coords.formatLatLng`).
  String get coordText => formatLatLng(lat, lng);
}

/// The deep link for [p] — `zonecraft://p?lat=…&lng=…&n=…`.
///
/// Built with [Uri], so a name carrying `&`, spaces or emoji is percent-encoded
/// rather than silently truncating the query at the next separator.
String encodeSharedPointLink(SharedPoint p) => Uri(
      scheme: kSharedPointScheme,
      host: _sharedPointHost,
      queryParameters: {
        'lat': p.lat.toStringAsFixed(6),
        'lng': p.lng.toStringAsFixed(6),
        if (p.name != null) 'n': p.name!,
      },
    ).toString();

/// Reads a shared position out of [input], whatever shape it arrives in.
///
/// Tolerant on purpose: the receiving end is a person pasting a chat message,
/// not a parser reading a file. In order it accepts
///
/// 1. a `zonecraft://p?lat=…&lng=…` link,
/// 2. a `geo:lat,lng` URI (what other map apps share),
/// 3. an OpenStreetMap link carrying `mlat`/`mlon`,
/// 4. anything [parseLatLng] handles — including the German comma-decimal pair
///    and a Google Maps copy-paste,
///
/// and if the whole string is none of those, it **scans** it for the first
/// substring that is: a pasted WhatsApp message arrives with words around the
/// coordinate, and asking the user to trim it by hand is the kind of friction
/// that makes a share feature unused.
SharedPoint? decodeSharedPointLink(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final direct = _decodeWhole(text);
  if (direct != null) return direct;

  // Scan: try each whitespace-delimited token as a URI, then every adjacent
  // pair of tokens as a bare "lat, lng" (which is two tokens once split).
  final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  for (final t in tokens) {
    final hit = _decodeUri(t);
    if (hit != null) return hit;
  }
  for (var i = 0; i < tokens.length; i++) {
    for (var n = 1; n <= 4 && i + n <= tokens.length; n++) {
      final hit = _decodeBare(tokens.sublist(i, i + n).join(' '));
      if (hit != null) return hit;
    }
  }
  return null;
}

SharedPoint? _decodeWhole(String text) =>
    _decodeUri(text) ?? _decodeBare(text);

/// The three URI shapes, or null when [text] is not a URI we know.
SharedPoint? _decodeUri(String text) {
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  final q = uri.queryParameters;

  switch (uri.scheme.toLowerCase()) {
    case kSharedPointScheme:
      if (uri.host.toLowerCase() != _sharedPointHost) return null;
      return SharedPoint.named(
        double.tryParse(q['lat'] ?? '') ?? double.nan,
        double.tryParse(q['lng'] ?? '') ?? double.nan,
        q['n'],
      );
    case 'geo':
      // `geo:48.1,11.5` and `geo:0,0?q=48.1,11.5(Label)` — the coordinate is
      // in the path, and a zero path with a `q` means the q is the real one.
      final label = q['q'];
      final fromPath = parseLatLng(uri.path.split(';').first);
      if (label != null) {
        final m = RegExp(r'^([^(]+)(?:\((.*)\))?$').firstMatch(label);
        final pt = m == null ? null : parseLatLng(m.group(1)!);
        if (pt != null) {
          return SharedPoint.named(pt.latitude, pt.longitude, m?.group(2));
        }
      }
      if (fromPath == null) return null;
      return SharedPoint.named(fromPath.latitude, fromPath.longitude);
    case 'http':
    case 'https':
      // An OpenStreetMap marker link, which is what [shareMessage] sends as the
      // fallback for a friend who does not have the app — so a message shared
      // onward from one of those still round-trips.
      final lat = double.tryParse(q['mlat'] ?? '');
      final lon = double.tryParse(q['mlon'] ?? '');
      if (lat == null || lon == null) return null;
      return SharedPoint.named(lat, lon);
    default:
      return null;
  }
}

SharedPoint? _decodeBare(String text) {
  final pt = parseLatLng(text);
  if (pt == null) return null;
  return SharedPoint.named(pt.latitude, pt.longitude);
}

/// An OpenStreetMap link showing [p] with a marker — the line a friend without
/// ZoneCraft can actually tap.
String osmMarkerLink(SharedPoint p) {
  final lat = p.lat.toStringAsFixed(6);
  final lng = p.lng.toStringAsFixed(6);
  return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng'
      '#map=17/$lat/$lng';
}

/// The message that goes into the share sheet.
///
/// Three lines, each for a different reader: the coordinate for a human (and
/// for the paste box, which parses it), the `zonecraft://` link for someone who
/// has the app, and an OpenStreetMap link for someone who does not. Any one of
/// the three is enough for [decodeSharedPointLink] to recover the position, so
/// a message that survives only partially still works.
String shareMessage(SharedPoint p) {
  final head = p.name == null ? p.coordText : '${p.name} — ${p.coordText}';
  return '$head\n${encodeSharedPointLink(p)}\n${osmMarkerLink(p)}';
}
