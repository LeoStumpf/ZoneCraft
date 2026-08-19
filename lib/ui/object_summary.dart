import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Circle;

import '../data/database.dart';
import '../data/transit.dart';
import '../state/providers.dart';
import 'hit_test.dart';
import 'region_geometry.dart';

/// A layer's objects flattened into rows the Elements list can render and the
/// map can frame: a stable identity, a human title/subtitle, and the geometry
/// needed to zoom to the object.
///
/// Pure (no camera, no providers, no database access) so it is unit-testable —
/// it only reads Drift row objects that callers already have in hand.

/// Identifies one object: its type tag plus its row id and owning layer.
class ObjectRef {
  const ObjectRef({
    required this.kind,
    required this.id,
    required this.layerId,
  });

  final ObjectKind kind;
  final String id;
  final String layerId;

  @override
  bool operator ==(Object other) =>
      other is ObjectRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// One row of the Elements list.
class ObjectSummary {
  const ObjectSummary({
    required this.ref,
    required this.title,
    required this.subtitle,
    required this.center,
    required this.fitPoints,
    this.isPending = false,
    this.colorArgb,
    this.colorShade = 0,
  });

  final ObjectRef ref;

  /// The element's colour override, null when it follows the layer, and which
  /// auto shade of the layer colour it takes while it does (see
  /// `ui/element_color.dart`).
  final int? colorArgb;
  final int colorShade;

  /// The object's label, or a derived positional name ("Circle 3").
  final String title;

  /// Type-specific one-liner (radius, point count, elevation threshold…).
  final String subtitle;

  /// A representative point — used when [fitPoints] holds fewer than two.
  final LatLng center;

  /// Points to frame the camera on. May be a single point for a degenerate
  /// object; callers fall back to a plain `move` in that case.
  final List<LatLng> fitPoints;

  /// The object exists but its data never arrived — the row offers a retry
  /// rather than a zoom. Only transit imports can be pending today.
  final bool isPending;
}

/// The canonical icon for a `Layers.type` — shared by the drawer, the Elements
/// list and the Add button so one type never has two icons.
IconData typeIcon(String layerType) => switch (layerType) {
      'planes' => Icons.change_history,
      'subspace' => Icons.scatter_plot_outlined,
      'freeline' => Icons.polyline,
      'freearea' => Icons.hexagon_outlined,
      'height' => Icons.terrain,
      'poi' => Icons.travel_explore,
      'transit' => Icons.directions_transit,
      'borders' => Icons.public,
      _ => Icons.circle_outlined,
    };

/// Whether a `Layers.type` has an editor at all.
///
/// **All nine do.** The three import types were the exception until their
/// editors landed; they are offline OSM snapshots, so theirs is scoped to what
/// a snapshot can honestly offer — naming, colour, curation, and for a border
/// area its outline, which is the one thing that genuinely forks from upstream
/// and is flagged when it does.
///
/// Kept as a function rather than inlined `true`, because the Elements list and
/// the map's Edit mode have to agree on it: when they didn't, Edit mode armed
/// tap-to-select against types nothing could select, which is a button that
/// visibly does nothing. A tenth type that arrives without an editor says so
/// here, once.
bool layerHasEditor(String layerType) => const {
      'circles',
      'planes',
      'subspace',
      'freeline',
      'freearea',
      'height',
      'poi',
      'transit',
      'borders',
    }.contains(layerType);

/// Formats a ground distance for display: metres below 1 km, then kilometres.
String formatMeters(double meters) {
  if (!meters.isFinite) return '—';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(2)} km' : '${km.round()} km';
}

/// Formats an elevation with a thousands separator ("2,962 m").
String formatElevationMeters(double meters) {
  if (!meters.isFinite) return '—';
  final m = meters.round();
  final withSep = m.abs().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (mm) => '${mm[1]},',
      );
  return '${m < 0 ? '−' : ''}$withSep m';
}

bool _finite(double lat, double lng) => lat.isFinite && lng.isFinite;

/// Eight points on the circle of [radiusMeters] around [center] — enough for
/// `CameraFit.coordinates` to frame the disc without pulling in the full
/// 90-point render ring (and without touching the render cache).
List<LatLng> _ringAround(LatLng center, double radiusMeters) {
  if (!_finite(center.latitude, center.longitude)) return const [];
  if (!radiusMeters.isFinite || radiusMeters <= 0) return [center];
  const bearings = [0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0];
  final ring = <LatLng>[];
  for (final b in bearings) {
    final p = geoDistance.offset(center, radiusMeters, b);
    if (_finite(p.latitude, p.longitude)) ring.add(p);
  }
  return ring.isEmpty ? [center] : ring;
}

/// The centre of the bounding box of [points] (empty ⇒ null).
LatLng? _bboxCenter(List<LatLng> points) {
  if (points.isEmpty) return null;
  var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
}

String _titleOr(String? label, String noun, int index) =>
    (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : '$noun ${index + 1}';

String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

/// Sorts a layer's objects into a stable, user-visible order. There is no
/// object-level `sortOrder` column, so creation order (tie-broken by id) is the
/// order — which is also what the positional names ("Circle 3") count.
List<T> _ordered<T>(
  Iterable<T> rows,
  DateTime Function(T) createdAt,
  String Function(T) id,
) {
  final list = rows.toList()
    ..sort((a, b) {
      final c = createdAt(a).compareTo(createdAt(b));
      return c != 0 ? c : id(a).compareTo(id(b));
    });
  return list;
}

/// One layer's elements as display rows, from the global row providers.
///
/// Shared by the Elements list and the layer-recolour dialog: both have to name
/// the same elements the same way, and neither should be rebuilding this list
/// from fifteen providers by hand.
final layerSummariesProvider = Provider.family<List<ObjectSummary>, String>((
  ref,
  layerId,
) {
  final layer = (ref.watch(layersProvider).asData?.value ?? const <Layer>[])
      .where((l) => l.id == layerId)
      .firstOrNull;
  if (layer == null) return const [];
  return summariseLayer(
    layer,
    circles: ref.watch(circlesProvider).asData?.value ?? const [],
    planes: ref.watch(planesProvider).asData?.value ?? const [],
    subspaces: ref.watch(subspacesProvider).asData?.value ?? const [],
    subspacePoints: ref.watch(subspacePointsProvider).asData?.value ?? const [],
    freeLines: ref.watch(freeLinesProvider).asData?.value ?? const [],
    freeLinePoints: ref.watch(freeLinePointsProvider).asData?.value ?? const [],
    freeAreas: ref.watch(freeAreasProvider).asData?.value ?? const [],
    freeAreaPoints: ref.watch(freeAreaPointsProvider).asData?.value ?? const [],
    heightRegions: ref.watch(heightRegionsProvider).asData?.value ?? const [],
    poiSets: ref.watch(poiSetsProvider).asData?.value ?? const [],
    poiPoints: ref.watch(poiPointsProvider).asData?.value ?? const [],
    transitSets: ref.watch(transitSetsProvider).asData?.value ?? const [],
    transitStops: ref.watch(transitStopsProvider).asData?.value ?? const [],
    borderSets: ref.watch(borderSetsProvider).asData?.value ?? const [],
    borderAreas: ref.watch(borderAreasProvider).asData?.value ?? const [],
  );
});

/// Every object in [layer], as display rows in stable order.
///
/// Callers pass the *global* row lists (the providers are not per-layer); this
/// filters by `layerId` itself.
List<ObjectSummary> summariseLayer(
  Layer layer, {
  List<Circle> circles = const [],
  List<Plane> planes = const [],
  List<Subspace> subspaces = const [],
  List<SubspacePoint> subspacePoints = const [],
  List<FreeLine> freeLines = const [],
  List<FreeLinePoint> freeLinePoints = const [],
  List<FreeArea> freeAreas = const [],
  List<FreeAreaPoint> freeAreaPoints = const [],
  List<HeightRegion> heightRegions = const [],
  List<PoiSet> poiSets = const [],
  List<PoiPoint> poiPoints = const [],
  List<TransitSet> transitSets = const [],
  List<TransitStop> transitStops = const [],
  List<BorderSet> borderSets = const [],
  List<BorderArea> borderAreas = const [],
}) {
  switch (layer.type) {
    case 'circles':
      final rows = _ordered(circles.where((c) => c.layerId == layer.id),
          (c) => c.createdAt, (c) => c.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _circleSummary(rows[i], layer.id, i),
      ];
    case 'planes':
      final rows = _ordered(planes.where((p) => p.layerId == layer.id),
          (p) => p.createdAt, (p) => p.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _planeSummary(rows[i], layer.id, i),
      ];
    case 'subspace':
      final rows = _ordered(subspaces.where((s) => s.layerId == layer.id),
          (s) => s.createdAt, (s) => s.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _subspaceSummary(rows[i], layer.id, i, subspacePoints),
      ];
    case 'freeline':
      final rows = _ordered(freeLines.where((l) => l.layerId == layer.id),
          (l) => l.createdAt, (l) => l.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _freeLineSummary(rows[i], layer.id, i, freeLinePoints),
      ];
    case 'freearea':
      final rows = _ordered(freeAreas.where((a) => a.layerId == layer.id),
          (a) => a.createdAt, (a) => a.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _freeAreaSummary(rows[i], layer.id, i, freeAreaPoints),
      ];
    case 'height':
      final rows = _ordered(heightRegions.where((r) => r.layerId == layer.id),
          (r) => r.createdAt, (r) => r.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _heightSummary(rows[i], layer.id, i),
      ];
    case 'poi':
      final rows = _ordered(poiSets.where((s) => s.layerId == layer.id),
          (s) => s.createdAt, (s) => s.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _poiSetSummary(rows[i], layer.id, i, poiPoints),
      ];
    case 'transit':
      final rows = _ordered(transitSets.where((s) => s.layerId == layer.id),
          (s) => s.createdAt, (s) => s.id);
      return [
        for (var i = 0; i < rows.length; i++)
          _transitSetSummary(rows[i], layer.id, i, transitStops),
      ];
    case 'borders':
      // The imports are bookkeeping; the *areas* are what you came to look at,
      // so the list names them — "Maxvorstadt", not "Border import 1".
      final mine = {
        for (final s in borderSets)
          if (s.layerId == layer.id) s.id,
      };
      final rows = [
        for (final a in borderAreas)
          if (mine.contains(a.setId)) a,
      ]..sort(_byName);
      return [
        for (var i = 0; i < rows.length; i++)
          _borderAreaSummary(rows[i], layer.id, i),
      ];
    default:
      return const [];
  }
}

ObjectSummary _circleSummary(Circle c, String layerId, int index) {
  final center = LatLng(c.centerLat, c.centerLng);
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.circle, id: c.id, layerId: layerId),
    colorArgb: c.colorArgb,
    colorShade: c.colorShade,
    title: _titleOr(c.label, 'Circle', index),
    subtitle: '${formatMeters(c.radiusMeters)} radius',
    center: center,
    fitPoints: _ringAround(center, c.radiusMeters),
  );
}

/// A plane's region is an unbounded half-plane, so there is nothing to frame:
/// the two foci are used instead, which puts the dividing bisector in view.
ObjectSummary _planeSummary(Plane p, String layerId, int index) {
  final a = LatLng(p.aLat, p.aLng);
  final b = LatLng(p.bLat, p.bLng);
  final pts = [
    if (_finite(p.aLat, p.aLng)) a,
    if (_finite(p.bLat, p.bLng)) b,
  ];
  final center = _bboxCenter(pts) ?? a;
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.plane, id: p.id, layerId: layerId),
    colorArgb: p.colorArgb,
    colorShade: p.colorShade,
    title: _titleOr(p.label, 'Plane', index),
    subtitle: 'Nearer side: ${p.nearA ? 'A' : 'B'}',
    center: center,
    fitPoints: pts.isEmpty ? [center] : pts,
  );
}

ObjectSummary _subspaceSummary(
  Subspace s,
  String layerId,
  int index,
  List<SubspacePoint> allPoints,
) {
  final pts = [
    for (final p in allPoints)
      if (p.subspaceId == s.id && _finite(p.lat, p.lng)) LatLng(p.lat, p.lng),
  ];
  final main = allPoints
      .where((p) => p.subspaceId == s.id && p.isMain && _finite(p.lat, p.lng))
      .map((p) => LatLng(p.lat, p.lng))
      .firstOrNull;
  final center = main ?? _bboxCenter(pts) ?? const LatLng(0, 0);
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.subspace, id: s.id, layerId: layerId),
    colorArgb: s.colorArgb,
    colorShade: s.colorShade,
    title: _titleOr(s.label, 'Subspace', index),
    subtitle: _plural(pts.length, 'point'),
    center: center,
    fitPoints: pts.isEmpty ? [center] : pts,
  );
}

/// Freehand lines frame their **inclusion circle**, not their raw extent: an
/// imported river's bounding box spans a continent, while the inclusion circle
/// is the part that actually renders.
ObjectSummary _freeLineSummary(
  FreeLine l,
  String layerId,
  int index,
  List<FreeLinePoint> allPoints,
) {
  final pts = [
    for (final p in (allPoints.where((p) => p.freeLineId == l.id).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))))
      if (_finite(p.lat, p.lng)) LatLng(p.lat, p.lng),
  ];
  final LatLng center;
  final List<LatLng> fit;
  if (pts.isEmpty) {
    center = LatLng(l.inclusionLat ?? 0, l.inclusionLng ?? 0);
    fit = [center];
  } else {
    final inc = effectiveInclusion(
      lat: l.inclusionLat,
      lng: l.inclusionLng,
      radiusMeters: l.inclusionRadiusMeters,
      points: pts,
    );
    center = inc.center;
    fit = _ringAround(inc.center, inc.radiusMeters);
  }
  final offset = l.offsetMeters;
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.freeLine, id: l.id, layerId: layerId),
    colorArgb: l.colorArgb,
    colorShade: l.colorShade,
    title: _titleOr(l.label, 'Line', index),
    subtitle: offset == 0
        ? _plural(pts.length, 'point')
        : '${_plural(pts.length, 'point')} · offset ${formatMeters(offset.abs())}',
    center: center,
    fitPoints: fit,
  );
}

ObjectSummary _freeAreaSummary(
  FreeArea a,
  String layerId,
  int index,
  List<FreeAreaPoint> allPoints,
) {
  final pts = [
    for (final p in (allPoints.where((p) => p.freeAreaId == a.id).toList()
      ..sort((x, y) => x.sortOrder.compareTo(y.sortOrder))))
      if (_finite(p.lat, p.lng)) LatLng(p.lat, p.lng),
  ];
  final center = _bboxCenter(pts) ?? const LatLng(0, 0);
  final offset = a.offsetMeters;
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.freeArea, id: a.id, layerId: layerId),
    colorArgb: a.colorArgb,
    colorShade: a.colorShade,
    title: _titleOr(a.label, 'Area', index),
    subtitle: offset == 0
        ? _plural(pts.length, 'point')
        : '${_plural(pts.length, 'point')} · offset ${formatMeters(offset.abs())}',
    center: center,
    fitPoints: pts.isEmpty ? [center] : pts,
  );
}

ObjectSummary _heightSummary(HeightRegion r, String layerId, int index) {
  final center = LatLng(r.centerLat, r.centerLng);
  final band = r.aboveThreshold ? 'above' : 'below';
  final parts = [
    '$band ${formatElevationMeters(r.thresholdMeters)}',
    formatMeters(r.radiusMeters),
    if (r.generatedAt == null) 'not generated',
  ];
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.heightRegion, id: r.id, layerId: layerId),
    colorArgb: r.colorArgb,
    colorShade: r.colorShade,
    title: _titleOr(r.label, 'Height area', index),
    subtitle: parts.join(' · '),
    center: center,
    fitPoints: _ringAround(center, r.radiusMeters),
  );
}

/// One public-transport import. The Elements row frames the **imported box**,
/// which is the thing that was chosen.
///
/// A set whose `fetchedAt` is null never finished — it shows as a retry row
/// carrying the reason, so a failed import is something you can come back to
/// rather than a snackbar you missed.
ObjectSummary _transitSetSummary(
  TransitSet s,
  String layerId,
  int index,
  List<TransitStop> allStops,
) {
  final center = LatLng((s.south + s.north) / 2, (s.west + s.east) / 2);
  final width = geoDistance.as(
      LengthUnit.Meter, LatLng(s.south, s.west), LatLng(s.south, s.east));
  final height = geoDistance.as(
      LengthUnit.Meter, LatLng(s.south, s.west), LatLng(s.north, s.west));
  final size = '${formatMeters(width)} × ${formatMeters(height)}';

  // Which types were asked for is part of what this row *is*: a set holding
  // only trains looks identical to a failed bus import otherwise.
  final partial = s.modeMask & transitAllModesMask != transitAllModesMask;
  final types = partial ? transitModeLabels(s.modeMask).toLowerCase() : null;

  final pending = s.fetchedAt == null;
  final String title;
  final String subtitle;
  if (pending) {
    title = 'Import didn\'t finish';
    subtitle = [
      if (s.lastError != null) s.lastError!,
      ?types,
      size,
      'tap to try again',
    ].join(' · ');
  } else {
    final stations =
        s.stationCount > 0 ? s.stationCount : allStops.where((x) => x.setId == s.id).length;
    title = _titleOr(s.label, 'Transit import', index);
    subtitle = [
      _plural(stations, 'station'),
      ?types,
      size,
      'imported ${_shortDate(s.fetchedAt!)}',
    ].join(' · ');
  }

  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.transitSet, id: s.id, layerId: layerId),
    colorArgb: s.colorArgb,
    colorShade: s.colorShade,
    title: title,
    subtitle: subtitle,
    center: center,
    // An import is a snapshot with no refresh path, so framing it means framing
    // exactly what was fetched.
    fitPoints: [LatLng(s.south, s.west), LatLng(s.north, s.east)],
    isPending: pending,
  );
}

/// Sorts border areas the way a person would look for one: by name, then by id
/// so the order is stable. Deliberately not `_ordered`'s creation order — these
/// are named, non-positional objects arriving in whatever order Overpass listed
/// them, and "find Maxvorstadt in a list of 97" is the actual task.
int _byName(BorderArea a, BorderArea b) {
  final an = a.name?.trim() ?? '';
  final bn = b.name?.trim() ?? '';
  if (an.isEmpty != bn.isEmpty) return an.isEmpty ? 1 : -1; // unnamed last
  final c = an.toLowerCase().compareTo(bn.toLowerCase());
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// One imported administrative area — a district, a municipality, a country.
///
/// The row frames the **area itself**, which is possible because nothing is
/// clipped to the import box: what is stored is the whole boundary.
ObjectSummary _borderAreaSummary(BorderArea a, String layerId, int index) {
  final center = LatLng((a.south + a.north) / 2, (a.west + a.east) / 2);
  final width = geoDistance.as(
      LengthUnit.Meter, LatLng(a.south, a.west), LatLng(a.south, a.east));
  final height = geoDistance.as(
      LengthUnit.Meter, LatLng(a.south, a.west), LatLng(a.north, a.west));
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.borderArea, id: a.id, layerId: layerId),
    colorArgb: a.colorArgb,
    title: _titleOr(a.name, 'Area', index),
    subtitle: [
      '${formatMeters(width)} × ${formatMeters(height)}',
      _plural(a.pointCount, 'point'),
      // An outline reshaped by hand is no longer what OSM says, and the list is
      // where you'd look to find out which of 97 areas you touched.
      if (a.editedAt != null) 'edited',
    ].join(' · '),
    center: center,
    fitPoints: [LatLng(a.south, a.west), LatLng(a.north, a.east)],
  );
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

ObjectSummary _poiSetSummary(
  PoiSet s,
  String layerId,
  int index,
  List<PoiPoint> allPoints,
) {
  final center = LatLng(s.centerLat, s.centerLng);
  final count = allPoints.where((p) => p.poiSetId == s.id).length;
  return ObjectSummary(
    ref: ObjectRef(kind: ObjectKind.poiSet, id: s.id, layerId: layerId),
    colorArgb: s.colorArgb,
    colorShade: s.colorShade,
    title: _titleOr(s.label, 'POI set', index),
    subtitle: '${_plural(count, 'POI')} · within ${formatMeters(s.radiusMeters)}',
    center: center,
    fitPoints: _ringAround(center, s.radiusMeters),
  );
}
