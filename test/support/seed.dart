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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';
import 'package:zonecraft/geo/border_areas.dart';
import 'package:zonecraft/state/providers.dart';

/// A map holding one layer of every type, and a way to select each element.
class SeededMap {
  SeededMap(this.layers, this.selections, this.ids);
  final List<Layer> layers;
  final List<(String, void Function(ProviderContainer))> selections;

  /// Element ids by kind: `circle`, `poi`, `freearea`, ….
  final Map<String, String> ids;
}

/// One layer of each type, each with long names — the names a user types
/// are the text a fixed-width row has to survive.
Future<SeededMap> seedAllTypes(AppDatabase db) async {
  final repo = Repository(db);
  const lat = 48.137, lng = 11.575;
  const long = 'Kindergartens within walking distance of the old town';
  Future<String> layer(String type) => repo.createLayer(
    name: '$long ($type)',
    colorArgb: 0xFF2196F3,
    type: type,
  );

  final circle = await repo.createCircle(
    layerId: await layer('circles'),
    centerLat: lat,
    centerLng: lng,
    radiusMeters: 1500,
    label: long,
  );

  final subspace = await repo.createSubspace(
    layerId: await layer('subspace'),
    label: long,
  );
  await repo.addSubspacePoint(
    subspaceId: subspace,
    lat: lat,
    lng: lng,
    isMain: true,
    label: long,
  );
  await repo.addSubspacePoint(subspaceId: subspace, lat: lat + 0.02, lng: lng);
  await repo.addSubspacePoint(subspaceId: subspace, lat: lat, lng: lng + 0.03);

  final line = await repo.createFreeLine(
    layerId: await layer('freeline'),
    label: long,
    inclusionLat: lat,
    inclusionLng: lng,
    inclusionRadiusMeters: 3000,
  );
  for (var i = 0; i < 4; i++) {
    await repo.addFreeLinePoint(
      freeLineId: line,
      lat: lat - 0.02 + i * 0.01,
      lng: lng + (i.isEven ? 0.01 : -0.01),
    );
  }

  final area = await repo.createFreeArea(
    layerId: await layer('freearea'),
    label: long,
  );
  for (final (a, b) in const [
    (0.0, 0.0),
    (0.01, 0.0),
    (0.01, 0.01),
    (0.0, 0.01),
  ]) {
    await repo.addFreeAreaPoint(freeAreaId: area, lat: lat + a, lng: lng + b);
  }

  final height = await repo.createHeightRegion(
    layerId: await layer('height'),
    centerLat: lat,
    centerLng: lng,
    radiusMeters: 2000,
    thresholdMeters: 520,
    label: long,
  );

  final poiLayer = await layer('poi');
  final poiSet = await repo.createPoiSet(
    layerId: poiLayer,
    source: kPoiSourceManual,
    categoryKey: 'peak',
    centerLat: lat,
    centerLng: lng,
    radiusMeters: 0,
    label: long,
    iconKey: 'peak',
  );
  final poi = await repo.addManualPoiPoint(
    poiSetId: poiSet,
    lat: lat + 0.005,
    lng: lng + 0.005,
    label: long,
  );
  // Named POIs spread out, and a tight bunch that clusters into a count
  // badge — both are fixed-size markers whose text used to overflow them at a
  // large font, which a single point never showed.
  for (var i = 0; i < 4; i++) {
    await repo.addManualPoiPoint(
      poiSetId: poiSet,
      lat: lat - 0.004 * i,
      lng: lng - 0.006,
      label: 'Café $i',
    );
  }
  for (var i = 0; i < 12; i++) {
    await repo.addManualPoiPoint(
      poiSetId: poiSet,
      lat: lat + 0.0001 * i,
      lng: lng + 0.003,
    );
  }

  final bordersLayer = await repo.createLayer(
    name: '$long (borders)',
    colorArgb: 0xFF2196F3,
    type: 'borders',
    borderLevel: '9',
  );
  await repo.addBorderSet(
    layerId: bordersLayer,
    south: lat - 0.05,
    west: lng - 0.05,
    north: lat + 0.05,
    east: lng + 0.05,
    adminLevel: '9',
    areas: [
      (
        osmId: 12345,
        name: long,
        south: lat - 0.01,
        west: lng - 0.01,
        north: lat + 0.01,
        east: lng + 0.01,
        labelLat: lat,
        labelLng: lng,
        pointCount: 4,
        rings: encodeRings([
          [
            const LatLng(lat - 0.01, lng - 0.01),
            const LatLng(lat - 0.01, lng + 0.01),
            const LatLng(lat + 0.01, lng + 0.01),
            const LatLng(lat + 0.01, lng - 0.01),
          ],
        ]),
        wayIds: const [1, 2],
      ),
    ],
  );
  final border = (await db.select(db.borderAreas).get()).single.id;
  // Look at the seeded objects, close enough for names and clusters.
  await repo.saveCamera(lat, lng, 15);

  final layers = await db.select(db.layers).get();
  return SeededMap(
    layers,
    [
      ('circle', (c) => c.read(selectedCircleProvider.notifier).select(circle)),
      (
        'subspace',
        (c) => c.read(selectedSubspaceProvider.notifier).select(subspace),
      ),
      (
        'freeline',
        (c) => c.read(selectedFreeLineProvider.notifier).select(line),
      ),
      (
        'freearea',
        (c) => c.read(selectedFreeAreaProvider.notifier).select(area),
      ),
      (
        'height',
        (c) => c.read(selectedHeightRegionProvider.notifier).select(height),
      ),
      (
        'poi set',
        (c) => c.read(selectedPoiSetProvider.notifier).select(poiSet),
      ),
      ('poi', (c) => c.read(selectedPoiPointProvider.notifier).select(poi)),
      (
        'border area',
        (c) => c.read(selectedBorderAreaProvider.notifier).select(border),
      ),
    ],
    {
      'circle': circle,
      'subspace': subspace,
      'freeline': line,
      'freearea': area,
      'height': height,
      'poiSet': poiSet,
      'poi': poi,
      'border': border,
    },
  );
}
