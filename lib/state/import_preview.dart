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

import 'dart:async';

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/serialization.dart';

/// A parsed import waiting for a yes or no, with nothing written yet.
///
/// Importing used to be a leap: you picked a file, it landed in the database,
/// and only then could you look at where it actually was. This is the same
/// parse, held in front of the map instead — so "is this the right file, and is
/// that the right place?" is answered *before* anything is written, and a no
/// costs nothing to undo because nothing happened.
///
/// It lives in a provider rather than being passed down because the two entry
/// points sit in different widgets — the layers drawer's picker and a file
/// another app shared into ZoneCraft — while only the map screen can draw it.
class PendingImport {
  PendingImport({
    required this.summary,
    required this.lines,
    required this.circles,
    required this.bounds,
  });

  /// One line naming what was found, e.g. "2 layers · 34 objects".
  final String summary;

  /// Every object's geometry as a point run. Rings arrive closed already.
  final List<List<LatLng>> lines;

  /// The radius-defined objects (circles, height regions), which have a centre
  /// and a radius rather than an outline to trace.
  final List<({LatLng center, double radiusMeters})> circles;

  /// Everything above, boxed — what the camera is fitted to.
  final LatLngBounds bounds;

  final Completer<bool> _decision = Completer<bool>();

  /// Completes true to write the import, false to throw it away.
  Future<bool> get decision => _decision.future;

  void answer({required bool keep}) {
    if (!_decision.isCompleted) _decision.complete(keep);
  }
}

/// The import currently being previewed, or null.
///
/// One-shot in the same shape as `receivedPointProvider`: something that is not
/// the map screen puts an offer up, the map screen draws it and answers.
class PendingImportNotifier extends Notifier<PendingImport?> {
  @override
  PendingImport? build() => null;

  void offer(PendingImport p) => state = p;
  void clear() => state = null;
}

final pendingImportProvider =
    NotifierProvider<PendingImportNotifier, PendingImport?>(
        PendingImportNotifier.new);

/// Builds a [PendingImport] from parsed [data], or null when there is no
/// geometry to show.
///
/// A file can legitimately contain objects with no drawable outline — a POI set
/// is points, an empty layer is nothing — and previewing an empty map would be
/// a worse answer than not previewing at all, so those go straight through.
PendingImport? previewOf(ExportData data) {
  final lines = <List<LatLng>>[];
  final circles = <({LatLng center, double radiusMeters})>[];
  var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
  var any = false;

  void see(LatLng p) {
    if (!p.latitude.isFinite || !p.longitude.isFinite) return;
    any = true;
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  for (final layer in data.layers) {
    for (final o in layer.objects) {
      final r = o.radiusMeters;
      // A circle and a height region are a centre plus a radius; tracing their
      // stored `coords` would draw a single point.
      if (r != null && r > 0 && o.coords.isNotEmpty &&
          (o.kind == 'circle' || o.kind == 'height')) {
        circles.add((center: o.coords.first, radiusMeters: r));
        see(o.coords.first);
        // The radius is metres and the box is degrees; a degree of latitude is
        // ~111 km everywhere, which is close enough to keep a lone circle from
        // filling only its own centre pixel.
        final pad = r / 111000;
        see(LatLng(
          (o.coords.first.latitude - pad).clamp(-90, 90),
          o.coords.first.longitude,
        ));
        see(LatLng(
          (o.coords.first.latitude + pad).clamp(-90, 90),
          o.coords.first.longitude,
        ));
        continue;
      }
      // `rings` is the whole of a multi-ring object; `coords` is only its
      // first. Prefer the former where it exists.
      final rings = o.rings;
      final runs = (rings != null && rings.isNotEmpty) ? rings : [o.coords];
      for (final run in runs) {
        for (final p in run) {
          see(p);
        }
        if (run.length >= 2) lines.add(run);
      }
    }
  }
  if (!any) return null;

  final objects = data.objectCount;
  final n = data.layers.length;
  return PendingImport(
    summary: '$n layer${n == 1 ? '' : 's'} · '
        '$objects object${objects == 1 ? '' : 's'}',
    lines: lines,
    circles: circles,
    bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
  );
}
