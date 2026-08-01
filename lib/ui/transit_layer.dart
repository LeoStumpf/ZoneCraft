import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/database.dart';
import '../data/transit.dart';
import 'screen_cluster.dart';

/// Renders a `transit` layer: its visible route geometry as coloured polylines,
/// and the stops those routes serve as clustered markers.
///
/// Two sibling widgets rather than one, because flutter_map takes its z-order
/// from the `FlutterMap.children` list — lines must sit *below* markers, which a
/// single widget returning one layer cannot express.

/// Icon for a stop, chosen from the modes that serve it.
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

/// The colour a route draws in: its own OSM `colour` tag, else its mode's
/// fallback. The hex parse already happened at import, so this is one null check.
int routeColorArgb(TransitRoute route) =>
    route.colorArgb ??
    transitModeByKey(route.modeKey)?.colorArgb ??
    0xFF616161;

double routeStrokeWidth(TransitRoute route) =>
    transitModeByKey(route.modeKey)?.strokeWidth ?? 2.0;

/// Whether a stored part's bbox overlaps the visible map. Uses the denormalised
/// bounds so an off-screen part is skipped **without decoding its points**.
bool partVisible(TransitRoutePart part, LatLngBounds view) {
  return part.south <= view.north &&
      part.north >= view.south &&
      part.west <= view.east &&
      part.east >= view.west;
}

/// Memoises `decodeLatLngs` per part id.
///
/// Without it a city import re-allocates tens of thousands of [LatLng]s on
/// every frame. Parts are immutable once imported, so the id is a complete key.
class TransitGeometryCache {
  final Map<String, List<LatLng>> _entries = {};

  List<LatLng> points(TransitRoutePart part) =>
      _entries.putIfAbsent(part.id, () => decodeLatLngs(part.points));

  void forget(Iterable<String> partIds) => _entries.removeAll(partIds);

  int get length => _entries.length;
}

extension _RemoveAll on Map<String, List<LatLng>> {
  void removeAll(Iterable<String> keys) {
    for (final k in keys) {
      remove(k);
    }
  }
}

/// App-wide instance, so it survives the per-frame widget rebuilds.
final transitGeometryCache = TransitGeometryCache();

/// The route geometry of one transit layer.
class TransitLinesLayer extends StatelessWidget {
  const TransitLinesLayer({
    super.key,
    required this.layer,
    required this.routes,
    required this.parts,
  });

  final Layer layer;

  /// This layer's routes (the caller filters).
  final List<TransitRoute> routes;

  /// All parts across every layer; filtered here by route id.
  final List<TransitRoutePart> parts;

  @override
  Widget build(BuildContext context) {
    final visible = {
      for (final r in routes)
        if (r.isVisible) r.id: r,
    };
    if (visible.isEmpty) return const SizedBox.shrink();
    final view = MapCamera.of(context).visibleBounds;

    final polylines = <Polyline>[];
    for (final p in parts) {
      final route = visible[p.routeId];
      if (route == null) continue;
      if (!partVisible(p, view)) continue;
      final pts = transitGeometryCache.points(p);
      if (pts.length < 2) continue;
      polylines.add(Polyline(
        points: pts,
        color: Color(routeColorArgb(route)),
        strokeWidth: routeStrokeWidth(route),
        pattern: route.modeKey == 'ferry'
            ? const StrokePattern.dotted()
            : const StrokePattern.solid(),
      ));
    }
    if (polylines.isEmpty) return const SizedBox.shrink();
    // flutter_map's own per-frame simplification + culling defaults are left
    // alone: they thin for the current zoom, while the import-time RDP handles
    // the durable size.
    return PolylineLayer(polylines: polylines);
  }
}

/// The stops of one transit layer, clustered in screen space.
class TransitStopsLayer extends StatelessWidget {
  const TransitStopsLayer({
    super.key,
    required this.layer,
    required this.stops,
    required this.visibleStopIds,
    this.onClusterTap,
  });

  final Layer layer;

  /// This layer's stops (the caller filters).
  final List<TransitStop> stops;

  /// Ids of the stops at least one *visible* route serves — the invariant that
  /// makes hiding U6 leave Marienplatz standing while the S-Bahn still calls.
  final Set<String> visibleStopIds;

  final void Function(LatLng center)? onClusterTap;

  static const double _clusterRadiusPx = 48;

  /// Below this zoom the names are a wall of text over a city import.
  static const double _labelMinZoom = 14;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds =
        (Offset.zero & camera.size).inflate(2 * _clusterRadiusPx);

    final lls = <LatLng>[];
    final names = <String?>[];
    final masks = <int>[];
    final offs = <Offset>[];
    for (final s in stops) {
      if (!visibleStopIds.contains(s.id)) continue;
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
            _stopMarker(lls[i], masks[i], showLabels ? names[i] : null));
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

  /// One stop: a white disc with its mode icon, name on a plate below.
  Marker _stopMarker(LatLng point, int modeMask, String? name) {
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
            child: Icon(transitIconFor(modeMask),
                size: 13, color: Colors.black87),
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

  /// A cluster badge: member count ringed in the layer colour — the one place a
  /// transit layer's own colour is used, since the lines carry OSM's.
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

/// The stops that at least one visible route serves.
///
/// Computed once per build as a set union over the join rows — no geometry, so
/// it stays trivial even at ~7500 joins.
Set<String> visibleTransitStopIds(
  Iterable<TransitRoute> routes,
  Iterable<TransitRouteStop> join,
) {
  final visibleRoutes = {
    for (final r in routes)
      if (r.isVisible) r.id,
  };
  return {
    for (final j in join)
      if (visibleRoutes.contains(j.routeId)) j.stopId,
  };
}
