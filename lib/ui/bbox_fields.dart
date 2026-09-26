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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../geo/coords.dart';
import 'object_summary.dart' show bboxSizeText;
import 'transit_import_dialog.dart' show validateLat, validateLng;

/// The four S/W/N/E numbers of a box being typed, shared by every import that
/// covers a box — POIs, stations and borders. They were three near-identical
/// copies, and the import sheets are where "the same area, asked the same
/// way" is the whole point.
class BboxControllers {
  BboxControllers(LatLngBounds initial)
    : south = TextEditingController(text: _f(initial.south)),
      west = TextEditingController(text: _f(initial.west)),
      north = TextEditingController(text: _f(initial.north)),
      east = TextEditingController(text: _f(initial.east));

  static String _f(double v) => v.toStringAsFixed(5);

  final TextEditingController south;
  final TextEditingController west;
  final TextEditingController north;
  final TextEditingController east;

  List<TextEditingController> get _all => [south, west, north, east];

  void addListener(VoidCallback l) {
    for (final c in _all) {
      c.addListener(l);
    }
  }

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }

  static double? _v(TextEditingController c) => parseDecimal(c.text.trim());

  double? get s => _v(south);
  double? get w => _v(west);
  double? get n => _v(north);
  double? get e => _v(east);

  /// The box as typed, or null while it is not a usable one — unparseable,
  /// or south ≥ north / west ≥ east. The same "usable" every sheet's verdict
  /// means by malformed/misordered, so the map stops drawing a box exactly
  /// when the sheet stops accepting one.
  LatLngBounds? get box {
    final s = this.s, w = this.w, n = this.n, e = this.e;
    if (s == null || w == null || n == null || e == null) return null;
    if (![s, w, n, e].every((v) => v.isFinite)) return null;
    if (s >= n || w >= e) return null;
    return LatLngBounds(LatLng(s, w), LatLng(n, e));
  }
}

/// "Area", the four fields and the box's size (or what is wrong with it).
class BboxFields extends StatelessWidget {
  const BboxFields({super.key, required this.box});

  final BboxControllers box;

  Widget _coord(TextEditingController c, String label, bool isLat) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          errorText: isLat ? validateLat(c.text) : validateLng(c.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Area', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            _coord(box.south, 'South', true),
            const SizedBox(width: 8),
            _coord(box.north, 'North', true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _coord(box.west, 'West', false),
            const SizedBox(width: 8),
            _coord(box.east, 'East', false),
          ],
        ),
        const SizedBox(height: 8),
        _sizeLine(theme),
      ],
    );
  }

  /// The box's own state: unusable numbers, or its size. What that size
  /// *costs* depends on the import, so each sheet says it separately.
  Widget _sizeLine(ThemeData theme) {
    final err = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w500,
    );
    final s = box.s, w = box.w, n = box.n, e = box.e;
    if (s == null ||
        w == null ||
        n == null ||
        e == null ||
        ![s, w, n, e].every((v) => v.isFinite)) {
      return Text('Enter four numbers to define the area.', style: err);
    }
    if (s >= n || w >= e) {
      return Text(
        'South must be below north, and west below east.',
        style: err,
      );
    }
    return Text(bboxSizeText([s, w, n, e]), style: theme.textTheme.bodySmall);
  }
}
