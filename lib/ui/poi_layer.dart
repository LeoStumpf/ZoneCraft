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
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../data/poi_sets.dart';
import 'camera_viewport.dart';
import 'element_color.dart';
import 'poi_icons.dart';
import 'screen_cluster.dart';

/// The marker icon for a POI category key (see `poiCategories` in
/// `data/overpass.dart`). Unknown keys fall back to a generic place pin.
IconData poiIconFor(String categoryKey) => switch (categoryKey) {
      'bench' => Icons.chair_outlined,
      'post_box' => Icons.markunread_mailbox_outlined,
      'drinking_water' => Icons.water_drop_outlined,
      'toilets' => Icons.wc_outlined,
      'waste_basket' => Icons.delete_outline,
      'cafe' => Icons.local_cafe_outlined,
      'restaurant' => Icons.restaurant_outlined,
      'pharmacy' => Icons.local_pharmacy_outlined,
      'library' => Icons.local_library_outlined,
      'aquarium' => Icons.set_meal_outlined,
      'zoo' => Icons.pets_outlined,
      'golf_course' => Icons.golf_course_outlined,
      'consulate' => Icons.flag_outlined,
      'transit_station' => Icons.directions_transit_outlined,
      'hospital' => Icons.local_hospital_outlined,
      'cinema' => Icons.local_movies_outlined,
      _ => Icons.place_outlined,
    };

/// Renders one `poi` layer's stored points as markers, collapsing any that
/// would overlap at the current zoom into count badges (clusters).
///
/// The look of a single POI matches the old global Overpass overlay: a small
/// white disc with the category icon and the OSM name (when present) on a tiny
/// plate below. Clusters are a slightly larger disc ringed in the layer colour
/// showing the member count (plus the category icon when all members share
/// one); tapping a cluster zooms in via [onClusterTap], which splits it apart.
///
/// A **station import** (a box set) draws by the same rules with three
/// differences it brought with it from the old `transit` layer: each station
/// icons itself from the modes that serve it ([poiPointIcon]), the set's
/// per-mode filter decides which draw at all ([poiPointVisible] — the one
/// predicate the hit test reads too), and name plates only appear from zoom
/// [_labelMinZoom], because a state-sized import is thousands of names.
///
/// Clustering runs in screen space per frame ([clusterOffsets]) after culling
/// to the viewport (+margin), so panning/zooming only ever handles the visible
/// points — the layer stays cheap even with thousands of stored points.
class PoiMarkersLayer extends StatelessWidget {
  const PoiMarkersLayer({
    super.key,
    required this.layer,
    required this.sets,
    required this.pointsBySet,
    this.onClusterTap,
  });

  final Layer layer;

  /// This layer's POI sets (each carries the category its points render as).
  final List<PoiSet> sets;

  /// Every stored point keyed by set id (`poiPointsBySetProvider`); only the
  /// entries of [sets] are read. A map rather than a flat list because this
  /// widget rebuilds on every camera tick, and a city of stations is thousands
  /// of rows to scan per set per frame.
  final Map<String, List<PoiPoint>> pointsBySet;

  /// A station import's name plates appear from this zoom; a hand-placed or
  /// radius-imported POI shows its name at any zoom, as it always did.
  static const double _labelMinZoom = 14;

  /// Called with a cluster's position when it is tapped (the map should zoom).
  final void Function(LatLng center)? onClusterTap;

  /// Two icon markers closer than this collapse into a cluster. Chosen so
  /// neither the 26 px discs nor their name plates overlap.
  static const double _clusterRadiusPx = 48;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final showStationLabels = camera.zoom >= _labelMinZoom;
    // One POI *set* is one element of the layer, so the colour lives there:
    // two categories imported into one layer read apart at a glance.
    final layerColor = Color(layer.colorArgb);
    final colorBySet = {
      for (final s in sets)
        s.id: elementColor(
          colorArgb: s.colorArgb,
          shadeIndex: s.colorShade,
          layerColor: layerColor,
        ),
    };

    // Cull to the viewport (+margin so edge clusters don't pop) and project.
    final bounds = cameraViewport(camera).inflate(2 * _clusterRadiusPx);
    final lls = <LatLng>[];
    final names = <String?>[];
    final icons = <IconData>[];
    final masks = <int>[];
    final colors = <Color>[];
    final offs = <Offset>[];
    for (final s in sets) {
      final points = pointsBySet[s.id];
      if (points == null) continue;
      final color = colorBySet[s.id] ?? layerColor;
      final labels = !s.isStationImport || showStationLabels;
      for (final p in points) {
        if (!poiPointVisible(p, s)) continue;
        final ll = LatLng(p.lat, p.lng);
        if (!ll.latitude.isFinite || !ll.longitude.isFinite) continue;
        final o = camera.latLngToScreenOffset(ll);
        if (!bounds.contains(o)) continue;
        lls.add(ll);
        names.add(labels ? p.name : null);
        icons.add(poiPointIcon(p, s));
        masks.add(p.modeMask);
        colors.add(color);
        offs.add(o);
      }
    }
    if (offs.isEmpty) return const SizedBox.shrink();

    final clusters = clusterOffsets(offs, _clusterRadiusPx);
    final markers = <Marker>[];
    for (final c in clusters) {
      if (c.indices.length == 1) {
        final i = c.indices.single;
        markers.add(_poiMarker(lls[i], icons[i], names[i], colors[i]));
      } else {
        // Anchor the badge at the members' mean position (average lat/lng is
        // fine at cluster scale).
        var lat = 0.0, lng = 0.0;
        IconData? sharedIcon = icons[c.indices.first];
        Color? sharedColor = colors[c.indices.first];
        var allStations = true;
        var maskUnion = 0;
        for (final i in c.indices) {
          lat += lls[i].latitude;
          lng += lls[i].longitude;
          if (icons[i] != sharedIcon) sharedIcon = null;
          if (colors[i] != sharedColor) sharedColor = null;
          if (masks[i] == 0) allStations = false;
          maskUnion |= masks[i];
        }
        // A badge over stations of several modes still says what it holds:
        // the icon of the most specific mode among them.
        if (sharedIcon == null && allStations) {
          sharedIcon = transitIconFor(maskUnion);
        }
        final center =
            LatLng(lat / c.indices.length, lng / c.indices.length);
        // A badge over two differently-coloured sets belongs to neither, so it
        // falls back to the layer's own colour.
        markers.add(_clusterMarker(
            center, c.indices.length, sharedIcon, sharedColor ?? layerColor));
      }
    }
    return MarkerLayer(markers: markers);
  }

  /// A single POI: white disc + its set's icon, name on a tiny plate below.
  Marker _poiMarker(
      LatLng point, IconData icon, String? name, Color color) {
    const coreSize = 26.0;
    const labelHeight = 14.0;
    const gap = 1.0;
    final hasLabel = name != null && name.isNotEmpty;
    // Equal top/bottom padding keeps the disc centred on the point.
    const pad = gap + labelHeight;
    return Marker(
      point: point,
      width: hasLabel ? 140 : coreSize,
      height: hasLabel ? coreSize + 2 * pad : coreSize,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLabel) const SizedBox(height: pad),
          Container(
            width: coreSize,
            height: coreSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              // The disc's ring is the POI's colour — the icon itself has to
              // stay legible, so the tint goes on the border, not the fill.
              border: Border.all(color: color, width: 2),
            ),
            child:
                Icon(icon, size: 16, color: Colors.black87),
          ),
          if (hasLabel) ...[
            const SizedBox(height: gap),
            SizedBox(
              height: labelHeight,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A cluster badge: member count ringed in the layer colour, plus the
  /// category icon when every member shares one. Tap to zoom in.
  Marker _clusterMarker(
      LatLng center, int count, IconData? sharedIcon, Color color) {
    const size = 38.0;
    return Marker(
      point: center,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClusterTap == null ? null : () => onClusterTap!(center),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 3),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sharedIcon != null)
                Icon(sharedIcon,
                    size: 13, color: Colors.black87),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: sharedIcon != null ? 11 : 14,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
