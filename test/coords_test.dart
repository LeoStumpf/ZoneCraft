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

    test('accepts a comma-decimal pair, as a German keyboard produces', () {
      // Splits into four pieces, not two — rejoined pairwise.
      final p = parseLatLng('48,137154 11,575382');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(48.137154, 1e-9));
      expect(p.longitude, closeTo(11.575382, 1e-9));
    });

    test('a comma-decimal pair separated by a comma too still reads', () {
      final p = parseLatLng('48,137154,11,575382');
      expect(p!.latitude, closeTo(48.137154, 1e-9));
      expect(p.longitude, closeTo(11.575382, 1e-9));
    });
  });

  group('parseDecimal', () {
    test('accepts either decimal separator', () {
      expect(parseDecimal('1.5'), closeTo(1.5, 1e-12));
      expect(parseDecimal('1,5'), closeTo(1.5, 1e-12));
      expect(parseDecimal('-0,25'), closeTo(-0.25, 1e-12));
      expect(parseDecimal(' 500 '), 500);
    });

    test('reads a lone 3-digit comma group as thousands, not as a decimal', () {
      // "1,234" means 1234 in the UK and 1.234 in Germany; dropping the
      // grouping is the reading both conventions agree on for the *value*.
      expect(parseDecimal('1,234'), 1234);
      expect(parseDecimal('1,234,567'), 1234567);
    });

    test('with both separators, the last one is the decimal point', () {
      expect(parseDecimal('1.234,5'), closeTo(1234.5, 1e-9));
      expect(parseDecimal('1,234.5'), closeTo(1234.5, 1e-9));
    });

    test('rejects what is not a number', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('   '), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal('1,2,3'), isNull);
      expect(parseDecimal('NaN'), isNull); // parses, but is not finite
      expect(parseDecimal('Infinity'), isNull);
    });
  });
}
