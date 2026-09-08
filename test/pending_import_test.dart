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

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:zonecraft/data/serialization.dart';
import 'package:zonecraft/state/import_preview.dart';

/// What the map draws when a file has been read but not yet written.
///
/// The value of the confirm step is entirely in the drawing: a summary line
/// alone would not answer "is that the right place?". So these tests are about
/// geometry actually surviving into the preview — including the two kinds that
/// are easy to lose, a circle (a centre and a radius, not an outline) and a
/// border area (whose `coords` is only its *first* ring).
ExportLayer _layer(String type, List<ExportObject> objects) => ExportLayer(
      name: type,
      colorArgb: 0xFF112233,
      type: type,
      isInverted: false,
      objects: objects,
    );

void main() {
  test('a line becomes a run the map can trace', () {
    final p = previewOf(ExportData([
      _layer('freeline', [
        ExportObject(
          kind: 'freeline',
          coords: [const LatLng(48.1, 11.5), const LatLng(48.2, 11.7)],
        ),
      ]),
    ]));

    expect(p, isNotNull);
    expect(p!.lines, hasLength(1));
    expect(p.bounds.south, closeTo(48.1, 1e-9));
    expect(p.bounds.east, closeTo(11.7, 1e-9));
    expect(p.summary, '1 layer · 1 object');
  });

  // A circle stores one point and a radius. Tracing its `coords` would draw a
  // single pixel, and boxing them would zoom the camera onto its own centre.
  test('a circle keeps its radius, and the box makes room for it', () {
    final p = previewOf(ExportData([
      _layer('circles', [
        ExportObject(
          kind: 'circle',
          coords: [const LatLng(48.0, 11.0)],
          radiusMeters: 5000,
        ),
      ]),
    ]));

    expect(p, isNotNull);
    expect(p!.circles, hasLength(1));
    expect(p.circles.single.radiusMeters, 5000);
    expect(p.lines, isEmpty, reason: 'a one-point run is not a line');
    // ~5 km is ~0.045°, so the box must be meaningfully taller than nothing.
    expect(p.bounds.north - p.bounds.south, greaterThan(0.08));
  });

  // `coords` is only the first ring of a multi-ring area; `rings` is all of it.
  test('a border area is previewed by all its rings, not just the first', () {
    final outer = [
      const LatLng(48.0, 11.0),
      const LatLng(48.0, 11.2),
      const LatLng(48.2, 11.2),
      const LatLng(48.0, 11.0),
    ];
    final hole = [
      const LatLng(48.05, 11.05),
      const LatLng(48.05, 11.10),
      const LatLng(48.10, 11.10),
      const LatLng(48.05, 11.05),
    ];
    final p = previewOf(ExportData([
      _layer('borders', [
        ExportObject(kind: 'borderarea', coords: outer, rings: [outer, hole]),
      ]),
    ]));

    expect(p!.lines, hasLength(2));
  });

  test('several layers are counted in the summary', () {
    final p = previewOf(ExportData([
      _layer('freeline', [
        ExportObject(
          kind: 'freeline',
          coords: [const LatLng(1, 1), const LatLng(2, 2)],
        ),
      ]),
      _layer('freearea', [
        ExportObject(
          kind: 'freearea',
          coords: [const LatLng(3, 3), const LatLng(4, 4), const LatLng(5, 5)],
        ),
      ]),
    ]));

    expect(p!.summary, '2 layers · 2 objects');
  });

  // Nothing drawable is not a reason to refuse an import — it is a reason to
  // skip the question, which is what a null preview tells the caller to do.
  test('a file with no drawable geometry previews as null', () {
    expect(previewOf(const ExportData([])), isNull);
    expect(
      previewOf(ExportData([_layer('freeline', const [])])),
      isNull,
    );
  });

  test('the decision resolves once, and only once', () async {
    final p = previewOf(ExportData([
      _layer('freeline', [
        ExportObject(
          kind: 'freeline',
          coords: [const LatLng(1, 1), const LatLng(2, 2)],
        ),
      ]),
    ]))!;

    p.answer(keep: true);
    p.answer(keep: false); // a second tap must not throw on a used Completer
    expect(await p.decision, isTrue);
  });
}
