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
import 'osm_report.dart' show OsmReportSubject;
import 'overpass.dart';
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
  List<double>? get bbox =>
      isStationImport && south != null ? [south!, west!, north!, east!] : null;
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

// --- What a POI set is called, and what OSM tag is behind it ---------------
//
// These live here rather than on a screen because three places ask the same
// questions of the same rows: the map's hit menu, the imported-point editor,
// and the OpenStreetMap report the editor can raise. They were private
// statics on `_MapScreenState`, which meant the editor host could not be
// lifted out of that class without taking them with it.

/// The set a POI belongs to, or null when it is gone.
PoiSet? poiSetOf(List<PoiSet> sets, String setId) =>
    sets.where((s) => s.id == setId).firstOrNull;

/// The catalogue entry a POI set's category corresponds to, or null.
///
/// For an import this is simply the category it was fetched with. For a
/// hand-made category it is [poiSetCatalogueCategory]'s answer — the same rule
/// that files it with the imports in the Elements list, so a category is never
/// listed as "Benches" and reported as something else, or the other way round.
PoiCategory? poiCategoryTag(List<PoiSet> sets, String setId) {
  final set = poiSetOf(sets, setId);
  return set == null ? null : poiSetCatalogueCategory(set);
}

/// The built-in category [set] **is**, or null when it is none of them.
///
/// An import is the category it was fetched with. A hand-made category is one
/// only when both halves agree: its key is a catalogue key (it was started
/// from the "Benches" preset, or given the bench icon) **and** its name says
/// the same thing — empty, or the catalogue's label up to case and a plural
/// ("Bench", "benches"). The icon alone is not enough: a category called
/// "Picnic spots" that happens to use the bench icon is the user's own idea,
/// and filing it under Benches — or reporting it to OSM as `amenity=bench` —
/// would put words in their mouth.
PoiCategory? poiSetCatalogueCategory(PoiSet set) {
  final c = poiCategories.where((c) => c.key == set.categoryKey).firstOrNull;
  if (c == null || !set.isManual) return c;
  final label = set.label?.trim() ?? '';
  if (label.isEmpty) return c;
  return singularName(label) == singularName(c.label) ? c : null;
}

/// [name] lower-cased with an English plural ending taken off, so "Benches",
/// "Bench" and "bench" compare equal — and "Cafés"/"Café", "Pharmacies"/
/// "Pharmacy". Deliberately crude: it only has to make one name agree with
/// the catalogue's label for the same thing, never to be correct English.
String singularName(String name) {
  final n = name.trim().toLowerCase();
  if (n.endsWith('ies') && n.length > 4) {
    return '${n.substring(0, n.length - 3)}y';
  }
  if (n.endsWith('ches') || n.endsWith('shes') || n.endsWith('xes')) {
    return n.substring(0, n.length - 2);
  }
  if (n.endsWith('s') && !n.endsWith('ss') && n.length > 1) {
    return n.substring(0, n.length - 1);
  }
  return n;
}

/// The human name of the category a POI's set imported ("Cafés"), for the
/// point editor's subtitle. Falls back to the raw key so an old set whose
/// category has since been renamed still says something.
String poiCategoryLabel(List<PoiSet> sets, String setId) {
  final set = poiSetOf(sets, setId);
  if (set == null) return 'POI';
  // A hand-made category has no OSM tag behind it, so its own name is the
  // only thing that describes it.
  if (set.isManual) return set.label ?? 'Category';
  return poiCategories
          .where((c) => c.key == set.categoryKey)
          .firstOrNull
          ?.label ??
      set.categoryKey;
}

/// Everything an OpenStreetMap note needs to know about [p] — as it is now,
/// or as it will be once a change being saved right now has landed ([name],
/// [lat], [lng]), so "Save & publish" can compose from the new values without
/// waiting for the row to come back.
///
/// For an import the original is what OSM returned: the stored `orig*` once
/// the point is a fork, else its current values — exactly what the repository
/// records as `orig*` on a first edit. A hand-placed point has no original.
///
/// One builder, read by every delete and by the map's move banner, so a note
/// written from any of them describes the same point in the same words.
OsmReportSubject osmSubjectFor(
  PoiPoint p,
  List<PoiSet> sets, {
  String? name,
  double? lat,
  double? lng,
}) {
  final tag = poiCategoryTag(sets, p.poiSetId);
  final hand = poiSetOf(sets, p.poiSetId)?.isManual ?? false;
  final forked = p.editedAt != null;
  final changing = name != null || lat != null || lng != null;
  return OsmReportSubject(
    lat: lat ?? p.lat,
    lng: lng ?? p.lng,
    name: name == null ? p.name : (name.isEmpty ? null : name),
    origLat: hand ? null : (forked ? p.origLat : p.lat),
    origLng: hand ? null : (forked ? p.origLng : p.lng),
    origName: hand ? null : (forked ? p.origName : p.name),
    edited: !hand && (forked || changing),
    categoryLabel: poiCategoryLabel(sets, p.poiSetId),
    tagKey: tag?.tagKey,
    tagValue: tag?.tagValue,
    osmType: p.osmType,
    osmId: p.osmId,
    poiPointId: p.id,
  );
}
