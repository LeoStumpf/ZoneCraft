import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/platform_files.dart';

/// The pure half of the share-target path. Everything else about receiving a
/// file — intent matching, `content:` resolution, `OpenableColumns` — is
/// Android and can only be checked on a device.
void main() {
  group('ensureExtension', () {
    test('keeps a name that already carries a known extension', () {
      expect(
        ensureExtension('munich.geojson', 'application/octet-stream'),
        'munich.geojson',
      );
      expect(ensureExtension('trip.gpx', null), 'trip.gpx');
    });

    test('matches the extension case-insensitively', () {
      expect(ensureExtension('Area.KML', 'application/json'), 'Area.KML');
    });

    test('repairs a nameless attachment from its MIME type', () {
      expect(
        ensureExtension('attachment', 'application/vnd.google-earth.kml+xml'),
        'attachment.kml',
      );
      expect(
        ensureExtension('download', 'application/geo+json'),
        'download.geojson',
      );
    });

    test('ignores MIME parameters', () {
      expect(
        ensureExtension('export', 'application/json; charset=utf-8'),
        'export.json',
      );
    });

    // The parser sniffs the bytes when it sees no extension it knows, so a
    // guessed one would stop it from ever getting there.
    test('leaves the name alone when the MIME says nothing', () {
      expect(
        ensureExtension('attachment', 'application/octet-stream'),
        'attachment',
      );
      expect(ensureExtension('attachment', null), 'attachment');
    });

    test('an earlier dot does not count as the extension', () {
      expect(
        ensureExtension('city.2024.geojson', 'application/octet-stream'),
        'city.2024.geojson',
      );
      expect(
        ensureExtension('city.2024', 'application/geo+json'),
        'city.2024.geojson',
      );
    });

    test('a name that is nothing but an extension is left alone', () {
      expect(ensureExtension('.geojson', 'application/geo+json'), '.geojson');
      expect(ensureExtension('.hidden', 'application/geo+json'),
          '.hidden.geojson');
    });
  });

  group('IncomingFile.fromMap', () {
    test('is null without a usable path', () {
      expect(IncomingFile.fromMap(null), isNull);
      expect(IncomingFile.fromMap({'name': 'x.geojson'}), isNull);
      expect(IncomingFile.fromMap({'path': ''}), isNull);
      expect(IncomingFile.fromMap({'path': 42}), isNull);
    });

    test('falls back to a placeholder name', () {
      final f = IncomingFile.fromMap({'path': '/tmp/a'})!;
      expect(f.name, 'shared');
      expect(f.mimeType, isNull);
      expect(f.importName, 'shared');
    });

    test('carries the display name and MIME through to importName', () {
      final f = IncomingFile.fromMap({
        'path': '/tmp/a',
        'name': 'attachment',
        'mimeType': 'application/gpx+xml',
      })!;
      expect(f.name, 'attachment');
      expect(f.importName, 'attachment.gpx');
    });
  });

  // The channel is Android-only, so the host VM must behave as if nothing had
  // ever been shared rather than throwing MissingPluginException.
  test('the platform half is absent off Android', () async {
    expect(platformFilesSupported, isFalse);
    expect(await takeSharedFile(), isNull);
    expect(
      await saveFileToDisk(
        sourcePath: '/tmp/a',
        suggestedName: 'a.geojson',
        mimeType: 'application/geo+json',
      ),
      isNull,
    );
  });
}
