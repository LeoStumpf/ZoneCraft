import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/database.dart';
import '../data/transit.dart';
import 'screen_cluster.dart';

/// Renders a `transit` layer: its imported **stations**, clustered in screen
/// space, filtered by which transit types serve them.
///
/// There is no line geometry — see `data/transit.dart` for why.

/// Icon for a station, chosen from the modes that serve it.
IconData transitIconFor(int modeMask) {
  // Most specific first: a stop served by both a subway and a bus reads better
  // as a subway station.
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

/// The stations that should be drawn: those whose own modes intersect the
/// visible-mode mask of the import they came from.
///
/// **Invariant:** a station shows iff *at least one* of its modes is enabled —
/// so unticking Bus leaves Pasing Bahnhof standing, because a train stops
/// there. A station with no modes at all (`modeMask == 0`, ~0.1 % of Munich)
/// shows whenever anything is enabled, so it can never become unreachable.
List<TransitStop> visibleTransitStations(
  Iterable<TransitStop> stations,
  Map<String, int> visibleMaskBySetId,
) {
  return [
    for (final s in stations)
      if (_visible(s.modeMask, visibleMaskBySetId[s.setId])) s,
  ];
}

bool _visible(int stationMask, int? visibleMask) {
  if (visibleMask == null) return false; // not one of this layer's sets
  if (visibleMask == 0) return false; // everything hidden
  if (stationMask == 0) return true; // "no type given" — never orphaned
  return stationMask & visibleMask != 0;
}

/// The stations of one transit layer.
class TransitStationsLayer extends StatelessWidget {
  const TransitStationsLayer({
    super.key,
    required this.layer,
    required this.stations,
    this.onClusterTap,
  });

  final Layer layer;

  /// Already filtered by [visibleTransitStations].
  final List<TransitStop> stations;

  final void Function(LatLng center)? onClusterTap;

  static const double _clusterRadiusPx = 48;

  /// Below this zoom the names are a wall of text over a city import.
  static const double _labelMinZoom = 14;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const MarkerLayer(markers: []);
    final camera = MapCamera.of(context);
    final bounds = (Offset.zero & camera.size).inflate(2 * _clusterRadiusPx);

    final lls = <LatLng>[];
    final names = <String?>[];
    final masks = <int>[];
    final offs = <Offset>[];
    for (final s in stations) {
      if (!s.lat.isFinite || !s.lng.isFinite) continue;
      final ll = LatLng(s.lat, s.lng);
      final o = camera.latLngToScreenOffset(ll);
      if (!bounds.contains(o)) continue;
      lls.add(ll);
      names.add(s.name);
      masks.add(s.modeMask);
      offs.add(o);
    }
    if (offs.isEmpty) return const MarkerLayer(markers: []);

    final showLabels = camera.zoom >= _labelMinZoom;
    final markers = <Marker>[];
    for (final c in clusterOffsets(offs, _clusterRadiusPx)) {
      if (c.indices.length == 1) {
        final i = c.indices.first;
        markers.add(
            _stationMarker(lls[i], masks[i], showLabels ? names[i] : null));
        continue;
      }
      var lat = 0.0, lng = 0.0, mask = 0;
      for (final i in c.indices) {
        lat += lls[i].latitude;
        lng += lls[i].longitude;
        mask |= masks[i];
      }
      markers.add(_clusterMarker(
        LatLng(lat / c.indices.length, lng / c.indices.length),
        c.indices.length,
        mask,
      ));
    }
    return MarkerLayer(markers: markers);
  }

  /// One station: a white disc with its mode icon, name on a plate below.
  Marker _stationMarker(LatLng point, int modeMask, String? name) {
    const coreSize = 22.0;
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
                Icon(transitIconFor(modeMask), size: 13, color: Colors.black87),
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

  /// A cluster badge: member count ringed in the layer colour.
  Marker _clusterMarker(LatLng center, int count, int modeMask) {
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
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(transitIconFor(modeMask), size: 13, color: Colors.black87),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
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
