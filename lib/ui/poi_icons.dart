import 'package:flutter/material.dart';

import '../data/database.dart';
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
