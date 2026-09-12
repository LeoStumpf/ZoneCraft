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

import '../data/database.dart';
import '../data/transit.dart' show transitModeByKey;
import 'poi_layer.dart' show poiIconFor;

/// One pickable marker icon: a stable [key] that goes in the database, a
/// human [label] for the picker, and the [icon] itself.
class PoiIcon {
  const PoiIcon(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

/// One group of the icon picker.
class PoiIconGroup {
  const PoiIconGroup(this.label, this.icons);
  final String label;
  final List<PoiIcon> icons;
}

/// The catalogue a hand-made POI category can pick its marker from.
///
/// **The keys are the persisted format** — a stored `icon_key` is looked up
/// here — so rename a label freely but never a key, and never reuse one for a
/// different icon.
///
/// Every value is a `const IconData` literal written out in this file. That is
/// not styling: Flutter's release build tree-shakes the icon font down to the
/// glyphs it can *see* referenced in source, so an `IconData` assembled at
/// runtime from a code point renders as a blank box in a release APK while
/// looking perfect in debug.
const poiIconGroups = <PoiIconGroup>[
  PoiIconGroup('Places', [
    PoiIcon('pin', 'Pin', Icons.place_outlined),
    PoiIcon('star', 'Star', Icons.star_outline),
    PoiIcon('heart', 'Favourite', Icons.favorite_outline),
    PoiIcon('flag', 'Flag', Icons.flag_outlined),
    PoiIcon('home', 'Home', Icons.home_outlined),
    PoiIcon('work', 'Work', Icons.work_outline),
    PoiIcon('school', 'School', Icons.school_outlined),
    PoiIcon('shop', 'Shop', Icons.storefront_outlined),
    PoiIcon('hotel', 'Hotel', Icons.hotel_outlined),
    PoiIcon('church', 'Church', Icons.church_outlined),
    PoiIcon('museum', 'Museum', Icons.museum_outlined),
    PoiIcon('theatre', 'Theatre', Icons.theater_comedy_outlined),
  ]),
  PoiIconGroup('Food & drink', [
    PoiIcon('cafe', 'Café', Icons.local_cafe_outlined),
    PoiIcon('restaurant', 'Restaurant', Icons.restaurant_outlined),
    PoiIcon('bar', 'Bar', Icons.local_bar_outlined),
    PoiIcon('beer', 'Beer', Icons.sports_bar_outlined),
    PoiIcon('fastfood', 'Fast food', Icons.fastfood_outlined),
    PoiIcon('icecream', 'Ice cream', Icons.icecream_outlined),
    PoiIcon('bakery', 'Bakery', Icons.bakery_dining_outlined),
    PoiIcon('grocery', 'Groceries', Icons.local_grocery_store_outlined),
  ]),
  PoiIconGroup('Outdoors', [
    PoiIcon('peak', 'Summit', Icons.terrain_outlined),
    PoiIcon('park', 'Park', Icons.park_outlined),
    PoiIcon('forest', 'Forest', Icons.forest_outlined),
    PoiIcon('beach', 'Beach', Icons.beach_access_outlined),
    PoiIcon('tent', 'Camping', Icons.cabin_outlined),
    PoiIcon('hike', 'Hiking', Icons.hiking_outlined),
    PoiIcon('water', 'Water', Icons.water_drop_outlined),
    PoiIcon('viewpoint', 'Viewpoint', Icons.photo_camera_outlined),
    PoiIcon('fire', 'Fire pit', Icons.local_fire_department_outlined),
    PoiIcon('pets', 'Animals', Icons.pets_outlined),
  ]),
  PoiIconGroup('Getting around', [
    PoiIcon('parking', 'Parking', Icons.local_parking_outlined),
    PoiIcon('fuel', 'Fuel', Icons.local_gas_station_outlined),
    PoiIcon('charger', 'Charging', Icons.ev_station_outlined),
    PoiIcon('train', 'Train', Icons.train_outlined),
    PoiIcon('bus', 'Bus', Icons.directions_bus_outlined),
    PoiIcon('bike', 'Bicycle', Icons.directions_bike_outlined),
    PoiIcon('boat', 'Boat', Icons.directions_boat_outlined),
    PoiIcon('airport', 'Airport', Icons.flight_outlined),
  ]),
  PoiIconGroup('Useful', [
    PoiIcon('hospital', 'Hospital', Icons.local_hospital_outlined),
    PoiIcon('pharmacy', 'Pharmacy', Icons.local_pharmacy_outlined),
    PoiIcon('toilets', 'Toilets', Icons.wc_outlined),
    PoiIcon('atm', 'Cash', Icons.atm_outlined),
    PoiIcon('post', 'Post', Icons.markunread_mailbox_outlined),
    PoiIcon('wifi', 'Wi-Fi', Icons.wifi_outlined),
    PoiIcon('bench', 'Bench', Icons.chair_outlined),
    PoiIcon('bin', 'Waste', Icons.delete_outline),
    PoiIcon('warning', 'Warning', Icons.warning_amber_outlined),
    PoiIcon('question', 'Unknown', Icons.help_outline),
  ]),
];

/// Every catalogue icon by key — the lookup a stored `icon_key` goes through.
final Map<String, IconData> poiIcons = {
  for (final g in poiIconGroups)
    for (final i in g.icons) i.key: i.icon,
};

/// The default a new hand-made category takes when nothing else is chosen.
const String kDefaultPoiIconKey = 'pin';

/// The marker icon for [set], wherever it came from.
///
/// One resolver, read by the painter, both editors and the Elements list, so a
/// set cannot be drawn with one icon and listed with another. A hand-made
/// category's [PoiSet.iconKey] wins; otherwise it falls back to the built-in
/// category mapping, which is what an Overpass import always uses.
IconData poiSetIcon(PoiSet set) {
  final key = set.iconKey;
  if (key != null) return poiIcons[key] ?? Icons.place_outlined;
  return poiIconFor(set.categoryKey);
}

/// Icon for a station, chosen from the modes that serve it.
///
/// Most specific first: a stop served by both a subway and a bus reads better
/// as a subway station. Every branch is a `const IconData` literal for the
/// tree-shaking reason [poiIconGroups] gives.
IconData transitIconFor(int modeMask) {
  for (final key in const ['subway', 'train', 'light_rail', 'tram', 'ferry']) {
    final m = transitModeByKey(key);
    if (m != null && modeMask & m.bit != 0) {
      return switch (key) {
        'subway' => Icons.subway,
        'train' => Icons.train,
        'light_rail' => Icons.tram,
        'tram' => Icons.tram,
        _ => Icons.directions_boat,
      };
    }
  }
  final bus = transitModeByKey('bus');
  if (bus != null && modeMask & bus.bit != 0) return Icons.directions_bus;
  return Icons.directions_transit;
}

/// The marker icon for one point of [set]: a station icons itself from the
/// modes that serve it, everything else takes its set's icon.
IconData poiPointIcon(PoiPoint p, PoiSet set) =>
    p.modeMask != 0 ? transitIconFor(p.modeMask) : poiSetIcon(set);
