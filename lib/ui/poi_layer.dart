import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import 'camera_viewport.dart';
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

/// Renders one `poi` layer's stored POIs as markers, collapsing any that would
/// overlap at the current zoom into count badges (clusters).
///
/// The look of a single POI matches the old global Overpass overlay: a small
/// white disc with the category icon and the OSM name (when present) on a tiny
/// plate below. Clusters are a slightly larger disc ringed in the layer colour
/// showing the member count (plus the category icon when all members share
/// one); tapping a cluster zooms in via [onClusterTap], which splits it apart.
///
/// Clustering runs in screen space per frame ([clusterOffsets]) after culling
/// to the viewport (+margin), so panning/zooming only ever handles the visible
/// points — the layer stays cheap even with hundreds of stored POIs.
class PoiMarkersLayer extends StatelessWidget {
  const PoiMarkersLayer({
    super.key,
    required this.layer,
    required this.sets,
    required this.points,
    this.onClusterTap,
  });

  final Layer layer;

  /// This layer's POI sets (each carries the category its points render as).
  final List<PoiSet> sets;

  /// The points of [sets].
  final List<PoiPoint> points;

  /// Called with a cluster's position when it is tapped (the map should zoom).
  final void Function(LatLng center)? onClusterTap;

  /// Two icon markers closer than this collapse into a cluster. Chosen so
  /// neither the 26 px discs nor their name plates overlap.
  static const double _clusterRadiusPx = 48;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final catBySet = {for (final s in sets) s.id: s.categoryKey};

    // Cull to the viewport (+margin so edge clusters don't pop) and project.
    final bounds = cameraViewport(camera).inflate(2 * _clusterRadiusPx);
    final lls = <LatLng>[];
    final names = <String?>[];
    final cats = <String>[];
    final offs = <Offset>[];
    for (final p in points) {
      final cat = catBySet[p.poiSetId];
      if (cat == null) continue;
      final ll = LatLng(p.lat, p.lng);
      final o = camera.latLngToScreenOffset(ll);
      if (!bounds.contains(o)) continue;
      lls.add(ll);
      names.add(p.name);
      cats.add(cat);
      offs.add(o);
    }
    if (offs.isEmpty) return const SizedBox.shrink();

    final clusters = clusterOffsets(offs, _clusterRadiusPx);
    final markers = <Marker>[];
    for (final c in clusters) {
      if (c.indices.length == 1) {
        final i = c.indices.single;
        markers.add(_poiMarker(lls[i], cats[i], names[i]));
      } else {
        // Anchor the badge at the members' mean position (average lat/lng is
        // fine at cluster scale).
        var lat = 0.0, lng = 0.0;
        String? sharedCat = cats[c.indices.first];
        for (final i in c.indices) {
          lat += lls[i].latitude;
          lng += lls[i].longitude;
          if (cats[i] != sharedCat) sharedCat = null;
        }
        final center =
            LatLng(lat / c.indices.length, lng / c.indices.length);
        markers.add(_clusterMarker(center, c.indices.length, sharedCat));
      }
    }
    return MarkerLayer(markers: markers);
  }

  /// A single POI: white disc + category icon, name on a tiny plate below.
  Marker _poiMarker(LatLng point, String categoryKey, String? name) {
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
              border: Border.all(color: Colors.black26),
            ),
            child:
                Icon(poiIconFor(categoryKey), size: 16, color: Colors.black87),
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
  Marker _clusterMarker(LatLng center, int count, String? sharedCategory) {
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
            border: Border.all(color: Color(layer.colorArgb), width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 3),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sharedCategory != null)
                Icon(poiIconFor(sharedCategory),
                    size: 13, color: Colors.black87),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: sharedCategory != null ? 11 : 14,
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
