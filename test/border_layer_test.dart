import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:zonecraft/ui/border_layer.dart';

/// Reshaping a border outline writes to the database only on drag *end* — one
/// area is a single ring blob, and re-encoding a 119 238-point boundary at
/// 20 fps (then re-decoding every area in the layer behind it) is not something
/// a drag can afford. So the map screen holds the in-progress rings and the
/// painter takes them as a `draft`, which is what makes the border follow the
/// finger instead of snapping when you let go.
///
/// [withDraft] is the swap. It is one line of logic in a painter that needs a
/// live `MapCamera` to build, which is exactly the kind of thing that stops
/// getting tested and then quietly paints the wrong layer.
void main() {
  BorderShape shape(String id, {List<List<LatLng>>? rings}) => BorderShape(
        id: id,
        name: id,
        colorIndex: 0,
        south: 48.0,
        west: 11.0,
        north: 48.1,
        east: 11.1,
        labelPoint: const LatLng(48.05, 11.05),
        rings: rings ??
            const [
              [LatLng(48.0, 11.0), LatLng(48.0, 11.1), LatLng(48.1, 11.1)],
            ],
      );

  test('no draft leaves the list exactly as it was', () {
    final shapes = [shape('a'), shape('b')];
    expect(withDraft(shapes, null), same(shapes));
  });

  test('the draft replaces the stored area of the same id, in place', () {
    final draft = shape('b', rings: const [
      [LatLng(49.0, 12.0), LatLng(49.0, 12.1), LatLng(49.1, 12.1)],
    ]);
    final out = withDraft([shape('a'), shape('b'), shape('c')], draft);
    expect(out.map((s) => s.id), ['a', 'b', 'c'],
        reason: 'paint order is the layer order and must not shuffle');
    expect(out[1], same(draft));
    expect(out[0].rings.single.first, const LatLng(48.0, 11.0));
  });

  test('a draft for an area this layer does not hold changes nothing', () {
    // The map screen keeps one draft for the whole app but hands it to every
    // borders layer it paints; the layers that don't own it must be untouched
    // rather than gaining a stray outline.
    final shapes = [shape('a'), shape('b')];
    final out = withDraft(shapes, shape('elsewhere'));
    expect(out.map((s) => s.id), ['a', 'b']);
    expect(out[0], same(shapes[0]));
    expect(out[1], same(shapes[1]));
  });

  test('a draft against an empty layer stays empty', () {
    expect(withDraft(const [], shape('a')), isEmpty);
  });
}
