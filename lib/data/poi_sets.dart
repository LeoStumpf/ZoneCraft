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

import 'package:latlong2/latlong.dart';

import 'database.dart';
import 'transit.dart';

/// The [PoiSets.categoryKey] a station import is stored under — the catalogue
/// entry in `overpass.dart` of the same name, so a migrated `transit` layer
/// and a radius import of "Transit stations" share an icon and a label.
const kTransitStationCategoryKey = 'transit_station';

/// What a [PoiSet] row's [PoiSets.source] means, in one place.
extension PoiSetKind on PoiSet {
  /// A category the user named and fills by tapping.
  bool get isManual => source == kPoiSourceManual;

  /// A public-transport station import over a bounding box.
  bool get isStationImport => source == kPoiSourceBox;

  /// Fetched from Overpass (radius or box) — a snapshot, not hand-placed.
  bool get isImport => !isManual;

  /// An import that hasn't succeeded yet: the Elements list shows it as a
  /// retry row. A manual set is never pending — nothing was ever fetched.
  bool get isPending => isImport && fetchedAt == null;

  /// The imported box of a station import, or null on the other kinds.
  List<double>? get bbox => isStationImport && south != null
      ? [south!, west!, north!, east!]
      : null;
}

/// **The one drawn == tappable predicate for a POI marker.** `poi_layer`
/// paints a point iff this is true, and `hit_test` offers it iff this is true.
///
/// Gated on the *set's* source, not on `p.modeMask != 0`: a mode-less station
/// in a box import must obey "hide all hides even the untyped ones" (the case
/// two earlier copies of this rule disagreed on), while a mode-less point in a
/// radius or manual set must always draw.
bool poiPointVisible(PoiPoint p, PoiSet? set) =>
    set != null &&
    (!set.isStationImport ||
        transitStationVisible(p.modeMask, set.visibleModeMask));

const Distance _distance = Distance(calculator: Haversine());

/// Half the diagonal of a bounding box, in metres — the radius a box set
/// stores in its NOT NULL [PoiSets.radiusMeters]. Used by the repository for a
/// new box set **and** by the v27 migration for the ones it carries across, so
/// the two never disagree.
double boxCoveringRadiusMeters({
  required double south,
  required double west,
  required double north,
  required double east,
}) =>
    _distance.as(LengthUnit.Meter, LatLng(south, west), LatLng(north, east)) /
    2;
