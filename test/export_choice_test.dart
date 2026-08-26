import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/platform_files.dart';
import 'package:zonecraft/ui/import_actions.dart';

/// The export dialog gained a destination, and the destination only exists
/// where the platform can save a file. This pins the other half down: on a
/// platform that cannot, the dialog must be exactly the one this app has
/// always had — two format rows and nothing else.
void main() {
  /// Opens the dialog and hands back a one-slot box the answer lands in.
  Future<List<ExportChoice?>> show(WidgetTester tester) async {
    final answer = <ExportChoice?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              answer.add(await askExportChoice(context, title: 'Export as'));
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('offers no destination where nothing can be saved', (
    tester,
  ) async {
    expect(platformFilesSupported, isFalse); // the host VM
    await show(tester);
    expect(find.text('GeoJSON (re-importable)'), findsOneWidget);
    expect(find.text('KML (Google Earth / Maps)'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Save to file'), findsNothing);
    expect(find.byType(SegmentedButton<ExportDestination>), findsNothing);
  });

  testWidgets('answers the tapped format, destined for the share sheet', (
    tester,
  ) async {
    final answer = await show(tester);
    await tester.tap(find.text('KML (Google Earth / Maps)'));
    await tester.pumpAndSettle();
    expect(answer, hasLength(1));
    expect(answer.single!.format, 'kml');
    expect(answer.single!.destination, ExportDestination.share);
  });

  testWidgets('answers null when dismissed', (tester) async {
    final answer = await show(tester);
    await tester.tapAt(const Offset(10, 10)); // the barrier
    await tester.pumpAndSettle();
    expect(answer, hasLength(1));
    expect(answer.single, isNull);
  });

  test('the GeoJSON MIME is the one the document picker will not rename', () {
    // Android has no extension mapping for geo+json, so DocumentsUI leaves
    // "x.geojson" alone. Under application/json it would save "x.geojson.json".
    const geo = ExportChoice('geojson', ExportDestination.save);
    expect(geo.mimeType, 'application/geo+json');
    expect(geo.isKml, isFalse);
    const kml = ExportChoice('kml', ExportDestination.share);
    expect(kml.mimeType, 'application/vnd.google-earth.kml+xml');
    expect(kml.isKml, isTrue);
  });
}
