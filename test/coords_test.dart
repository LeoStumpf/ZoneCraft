import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/geo/coords.dart';

void main() {
  group('parseLatLng', () {
    test('parses Google Maps "lat, lng" copy format', () {
      final p = parseLatLng('48.137154, 11.575382');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(48.137154, 1e-9));
      expect(p.longitude, closeTo(11.575382, 1e-9));
    });

    test('accepts negatives and no space', () {
      final p = parseLatLng('-33.8688,151.2093');
      expect(p!.latitude, closeTo(-33.8688, 1e-9));
      expect(p.longitude, closeTo(151.2093, 1e-9));
    });

    test('accepts space-separated and surrounding parens/whitespace', () {
      expect(parseLatLng('  48.1 11.5  '), isNotNull);
      expect(parseLatLng('(48.1, 11.5)'), isNotNull);
    });

    test('rejects partial, malformed, or out-of-range input', () {
      expect(parseLatLng('48.137'), isNull); // one number only
      expect(parseLatLng('48.137,'), isNull);
      expect(parseLatLng('abc, def'), isNull);
      expect(parseLatLng('91, 0'), isNull); // lat > 90
      expect(parseLatLng('0, 181'), isNull); // lng > 180
      expect(parseLatLng(''), isNull);
    });

    test('round-trips through formatLatLng', () {
      final s = formatLatLng(48.137154, 11.575382);
      final p = parseLatLng(s)!;
      expect(p.latitude, closeTo(48.137154, 1e-6));
      expect(p.longitude, closeTo(11.575382, 1e-6));
    });
  });
}
