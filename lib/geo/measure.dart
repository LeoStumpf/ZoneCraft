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

import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Ground measurements of the geometry the app stores — the numbers an
/// Elements row quotes beside a name ("12 points · 3.4 km", "8 points ·
/// 2.1 km²").
///
/// Pure spherical maths, no Flutter, so the summariser and its tests can call
/// it without a widget tree. Non-finite points are skipped rather than
/// poisoning the sum: an imported file with one bad coordinate still gets a
/// number for the rest.

const Distance _haversine = Distance(calculator: Haversine());

bool _finite(LatLng p) => p.latitude.isFinite && p.longitude.isFinite;

/// Length of [pts] along the ground, in metres: the Haversine sum of its
/// segments. Fewer than two usable points is a length of zero.
double polylineLengthMeters(List<LatLng> pts) {
  LatLng? prev;
  var total = 0.0;
  for (final p in pts) {
    if (!_finite(p)) continue;
    if (prev != null) total += _haversine.as(LengthUnit.Meter, prev, p);
    prev = p;
  }
  return total;
}

/// Area of the polygon [ring] encloses, in square metres, on a sphere.
///
/// Chamberlain & Duquette's formula, `A = |R²/2 · Σ (λ₂−λ₁)(2 + sin φ₁ + sin
/// φ₂)|` over the closed ring in radians — exact for the small spherical
/// polygons this app holds (a drawn area, a district, a river's inclusion
/// disc) and orientation-independent thanks to the `abs`. It is *not* meant
/// for continent-sized rings, where the linear-in-longitude approximation
/// drifts. The ring is closed implicitly, so a repeated closing vertex is
/// harmless; fewer than three distinct usable points is an area of zero.
double polygonAreaSquareMeters(List<LatLng> ring) {
  final pts = [for (final p in ring) if (_finite(p)) p];
  if (pts.length >= 2 &&
      pts.first.latitude == pts.last.latitude &&
      pts.first.longitude == pts.last.longitude) {
    pts.removeLast();
  }
  if (pts.length < 3) return 0;
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    final dLng = b.longitudeInRad - a.longitudeInRad;
    sum += dLng * (2 + sin(a.latitudeInRad) + sin(b.latitudeInRad));
  }
  return (sum * earthRadius * earthRadius / 2).abs();
}
