// Generates the deterministic database used for Play Store screenshots.
//
// Run it with `flutter test` rather than `dart run` — `AppDatabase` reaches
// `drift_flutter`, which reaches Flutter, so a plain Dart VM cannot load it:
//
//   flutter test tool/make_screenshot_seed.dart
//
// It writes `build/screenshot-seed.sqlite`, which `scripts/screenshots.sh`
// pushes onto the emulator. Building it through the app's own `Repository`
// rather than by hand-writing SQL means the file always matches the current
// schema and always goes through the real migrations.
//
// Everything here is fixed: the same coordinates, the same colours, the same
// order, every run. That is the whole point — a screenshot set you cannot
// reproduce is one you cannot retake when a single shot is wrong.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/overpass.dart' show PoiResult;
import 'package:zonecraft/data/repository.dart';

/// Munich. Chosen because it is dense enough that every layer type has
/// something real to show, and because the border and transit fixtures below
/// were traced from it.
const _cityLat = 48.1372;
const _cityLng = 11.5756;

// The palette the shots use. Distinct hues so overlapping layers read clearly
// at thumbnail size, which is how most people will first see them.
//
// Layer names are kept short for the same reason: the drawer's name column is
// narrow, and "Outside the Altstadt" ellipsises to "The Altst…" — fine in use,
// sloppy in a store screenshot.
const _blue = 0xFF2196F3;
const _orange = 0xFFFF9800;
const _purple = 0xFF9C27B0;
const _green = 0xFF4CAF50;

void main() {
  test('write the screenshot seed database', () async {
    final file = File('build/screenshot-seed.sqlite');
    if (file.existsSync()) file.deleteSync();
    file.parent.createSync(recursive: true);

    final db = AppDatabase.forTesting(NativeDatabase(file));
    final repo = Repository(db);

    // --- A POI set, hidden, created FIRST -----------------------------------
    // Present so the layers drawer shows a marker-type layer alongside the
    // region ones, and so shot 05 can switch it on without an import.
    //
    // Created first, which puts it at the BOTTOM of the stack. The active layer
    // defaults to the topmost one, and an active POI layer makes the primary
    // FAB read "Import POIs" — a call to action for a feature the hero shot is
    // not about. With a region layer on top it reads "Add area" instead.
    final pois = await repo.createLayer(
      name: 'Cafés',
      colorArgb: _green,
      type: 'poi',
    );
    await repo.updateLayer(pois, isVisible: false);
    final poiSet = await repo.createPoiSet(
      layerId: pois,
      categoryKey: 'cafe',
      centerLat: _cityLat,
      centerLng: _cityLng,
      radiusMeters: 1500,
      label: 'Cafés',
    );
    await repo.addPoiPoints(poiSet, const [
      PoiResult(lat: 48.1385, lng: 11.5745, categoryKey: 'cafe', name: 'Café am Dom'),
      PoiResult(lat: 48.1401, lng: 11.5772, categoryKey: 'cafe', name: 'Rösterei'),
      PoiResult(lat: 48.1359, lng: 11.5719, categoryKey: 'cafe', name: 'Kaffeehaus'),
      PoiResult(lat: 48.1344, lng: 11.5798, categoryKey: 'cafe', name: 'Espressobar'),
      PoiResult(lat: 48.1418, lng: 11.5688, categoryKey: 'cafe', name: 'Stadtcafé'),
      PoiResult(lat: 48.1367, lng: 11.5831, categoryKey: 'cafe', name: 'Bohne & Blatt'),
    ]);

    // --- "Within 3 km" (circle) --------------------------------------------
    // The simplest zone, and the one that reads instantly in a thumbnail.
    final circles = await repo.createLayer(
      name: '3 km ring',
      colorArgb: _blue,
      type: 'circles',
    );
    await repo.createCircle(
      layerId: circles,
      centerLat: _cityLat,
      centerLng: _cityLng,
      radiusMeters: 2200,
      label: 'Marienplatz',
    );

    // --- "Closer to the station" (plane) -----------------------------------
    // Shows the half-plane type, and overlaps the circle so the intersection
    // — the actual product idea — is visible.
    final planes = await repo.createLayer(
      name: 'Near Hbf',
      colorArgb: _orange,
      type: 'planes',
    );
    await repo.createPlane(
      layerId: planes,
      aLat: 48.1402,
      aLng: 11.5600, // München Hbf
      bLat: 48.1183,
      bLng: 11.6011, // Ostbahnhof
      label: 'Hbf vs Ost',
    );

    // --- "The old town" (freehand area) ------------------------------------
    // Gives the composite a hand-drawn, non-circular edge, and lands inside the
    // other two so the three-way intersection is the darkest thing on screen —
    // which is the product idea in one image.
    //
    // Deliberately NOT inverted. An inverted layer at this zoom colours the
    // entire viewport, which turned the first attempt at the hero shot into a
    // flat purple wash with the map barely visible. Invert gets its own shot
    // (04), zoomed in far enough to actually read.
    final areas = await repo.createLayer(
      name: 'Altstadt',
      colorArgb: _purple,
      type: 'freearea',
    );
    final area = await repo.createFreeArea(layerId: areas, label: 'Altstadt');
    await repo.addFreeAreaPoints(area, const [
      LatLng(48.1421, 11.5695),
      LatLng(48.1436, 11.5806),
      LatLng(48.1389, 11.5872),
      LatLng(48.1321, 11.5842),
      LatLng(48.1305, 11.5731),
      LatLng(48.1352, 11.5658),
    ]);

    // Camera: framed so the whole circle plus a margin of map fits at
    // 1080x1920, with the half-plane edge crossing the frame diagonally. Fixed,
    // so every run frames identically.
    await repo.saveCamera(_cityLat, _cityLng, 12.4);
    await repo.updateUncertainty(250);

    await db.close();

    // Fail loudly rather than push an empty file onto the emulator.
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(4096));
    // ignore: avoid_print
    print('wrote ${file.path} (${file.lengthSync()} bytes)');
  });
}
