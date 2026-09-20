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

/// The three donated services the app talks to, and what a user may say about
/// each one instead.
///
/// One definition rather than three near-identical settings blocks: the label,
/// the hint, the built-in default and the validation are all properties of the
/// service, and the settings screen renders whatever this list holds.
///
/// Why any of this exists: every one of these services is somebody else's
/// machine, run on donations, with a published policy that says so. Nominatim's
/// asks outright that "apps must make sure that they can switch the service at
/// our request at any time"; Overpass's documentation says an app relying on the
/// public instances as a backend is what running your own instance is for. A
/// hardcoded host can only be changed by shipping a new APK, which reaches
/// nobody who stops updating — so the addresses are data.
library;

import 'overpass_client.dart' show overpassEndpoints;
import 'place_search.dart' show defaultNominatimHost;
import 'tile_source.dart';

/// Which service an override applies to.
enum ServiceOverride {
  /// `{z}/{x}/{y}` base-map tile template.
  ///
  /// Note this one cannot re-enable the offline features: prefetching is a
  /// build-time claim about terms someone has read, and a URL typed into a
  /// settings field asserts nothing — see [TileSource.resolve].
  tiles(
    label: 'Map tiles',
    hint: 'https://tiles.example.org/{z}/{x}/{y}.png',
    help:
        'A {z}/{x}/{y} template. Offline downloading stays off whatever you '
        'put here.',
  ),

  /// A full Overpass `/api/interpreter` URL, tried ahead of the public ones.
  overpass(
    label: 'Overpass imports',
    hint: 'https://overpass.example.org/api/interpreter',
    help:
        'Tried first; the public instances stay as a fallback. This is the '
        'one that matters — a border import can pull tens of megabytes off a '
        'donated server.',
  ),

  /// A bare geocoder host; the path and query stay ours.
  nominatim(
    label: 'Place search',
    hint: 'nominatim.example.org',
    help: 'A host name only, without https:// or a path.',
  );

  const ServiceOverride({
    required this.label,
    required this.hint,
    required this.help,
  });

  /// Shown as the field's title.
  final String label;

  /// Shown in the empty field.
  final String hint;

  /// One line under it, saying what the field will and will not do.
  final String help;

  /// What the app uses when this override is unset — shown so that "empty"
  /// reads as a real answer rather than a missing one.
  String get builtInDefault => switch (this) {
    ServiceOverride.tiles => TileSource.configured.urlTemplate,
    ServiceOverride.overpass => overpassEndpoints.first,
    ServiceOverride.nominatim => defaultNominatimHost,
  };

  /// Null when [value] is usable, otherwise why it is not.
  ///
  /// Deliberately thin: this catches the shapes that would fail silently — a
  /// tile template with no coordinates substitutes nothing and every tile comes
  /// back the same, a geocoder host carrying a scheme becomes an unresolvable
  /// name — and leaves "is that server actually there" to the request, which is
  /// the only thing that can really answer it.
  String? validate(String value) {
    final v = value.trim();
    if (v.isEmpty) return null; // empty = use the default
    switch (this) {
      case ServiceOverride.tiles:
        if (!v.startsWith('http')) return 'Must start with http:// or https://';
        for (final token in ['{z}', '{x}', '{y}']) {
          if (!v.contains(token)) return 'Missing $token in the template';
        }
        return null;
      case ServiceOverride.overpass:
        if (!v.startsWith('http')) return 'Must start with http:// or https://';
        return null;
      case ServiceOverride.nominatim:
        if (v.contains('://')) return 'A host name only — no https://';
        if (v.contains('/')) return 'A host name only — no path';
        if (!v.contains('.')) return 'Doesn\'t look like a host name';
        return null;
    }
  }
}
