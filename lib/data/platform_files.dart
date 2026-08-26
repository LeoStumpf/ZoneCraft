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

import 'dart:io' show File, Platform;

import 'package:flutter/services.dart';

/// The Android side of file sharing: receiving a geometry file another app
/// handed us, and writing an export through the system file picker.
///
/// Both are `MainActivity.kt` over one MethodChannel — deliberately custom and
/// not a package (`receive_sharing_intent` and `file_picker` were both
/// rejected: two more dependencies for a page of Kotlin we can read). The
/// second one exists because `file_selector_android` implements `openFile` but
/// throws `UnimplementedError` from `getSaveLocation`, which is why an export
/// could be shared everywhere and saved nowhere.
///
/// Every entry point is a no-op off Android, so tests and any future iOS build
/// simply behave as if nothing had been shared and never offer "Save to file".
const MethodChannel _channel = MethodChannel('com.leostumpf.zonecraft/files');

/// Whether the platform half of this file exists. Gates the "Save to file"
/// option in the export dialog.
bool get platformFilesSupported => Platform.isAndroid;

const Map<String, String> _extensionForMime = {
  'application/geo+json': 'geojson',
  'application/json': 'json',
  'application/vnd.google-earth.kml+xml': 'kml',
  'application/vnd.google-earth.kmz': 'kmz',
  'application/gpx+xml': 'gpx',
};

const Set<String> _knownExtensions = {'geojson', 'json', 'kml', 'kmz', 'gpx'};

/// Appends the extension implied by [mimeType] when [name] carries none we
/// recognise — the mail-attachment case, where the file arrives called
/// "attachment" and only the MIME says what it is.
///
/// Pure, and the testable half of the share path. When the MIME says nothing
/// either the name is left alone on purpose: [parseExternalGeometry] sniffs
/// the bytes when it doesn't recognise an extension, and a wrong extension
/// would stop it from ever getting there.
String ensureExtension(String name, String? mimeType) {
  final dot = name.lastIndexOf('.');
  // `>= 0`, not `> 0`: the "a leading dot is not an extension separator" rule
  // is about extracting a stem, and all this asks is whether the name already
  // ends in something the parser recognises. A file called ".geojson" does.
  if (dot >= 0 &&
      _knownExtensions.contains(name.substring(dot + 1).toLowerCase())) {
    return name;
  }
  final ext =
      _extensionForMime[mimeType?.split(';').first.trim().toLowerCase()];
  if (ext == null) return name;
  return '$name.$ext';
}

/// A file another app shared into ZoneCraft, already copied into our cache.
class IncomingFile {
  const IncomingFile({required this.path, required this.name, this.mimeType});

  /// Absolute path of the cache copy. The original `content:` uri is never
  /// handed across: its read grant belongs to the activity's task and can be
  /// revoked the moment the sending app finishes.
  final String path;

  /// The provider's display name ("munich.geojson"), not the cache file's
  /// name, which is sanitised on the platform side.
  final String name;

  /// What the provider claimed the file is. Often `application/octet-stream`,
  /// and often a lie; only used to recover a missing extension.
  final String? mimeType;

  static IncomingFile? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final path = map['path'];
    if (path is! String || path.isEmpty) return null;
    final name = map['name'];
    final mime = map['mimeType'];
    return IncomingFile(
      path: path,
      name: name is String && name.isNotEmpty ? name : 'shared',
      mimeType: mime is String ? mime : null,
    );
  }

  /// The name the importer should see.
  String get importName => ensureExtension(name, mimeType);

  Future<Uint8List> readBytes() => File(path).readAsBytes();

  /// The cache copy has done its job. The platform side also clears the folder
  /// before the next copy, so a failure here is harmless.
  Future<void> dispose() async {
    try {
      await File(path).delete();
    } catch (_) {
      // Already gone, or never ours to delete.
    }
  }
}

/// Picks up a file shared into the app, if one is waiting. Returns null when
/// there is none — the normal case on every launch and every resume.
///
/// One-shot: the platform side forgets the file as it hands it over, so
/// calling this at startup *and* on resume cannot double-import.
Future<IncomingFile?> takeSharedFile() async {
  if (!platformFilesSupported) return null;
  try {
    final map = await _channel.invokeMapMethod<String, Object?>(
      'takeSharedFile',
    );
    return IncomingFile.fromMap(map);
  } on MissingPluginException {
    return null; // no platform half (tests, another platform)
  }
}

/// Writes [sourcePath] to a location the user picks (Android SAF
/// `ACTION_CREATE_DOCUMENT`). Returns the chosen file's display name, or null
/// if the user backed out. Throws [PlatformException] if the write failed.
///
/// Takes a path rather than bytes: an administrative-borders export is tens of
/// megabytes, and both callers have already written the temp file the share
/// sheet would otherwise use.
Future<String?> saveFileToDisk({
  required String sourcePath,
  required String suggestedName,
  required String mimeType,
}) async {
  if (!platformFilesSupported) return null;
  try {
    return await _channel.invokeMethod<String>('saveFile', {
      'sourcePath': sourcePath,
      'suggestedName': suggestedName,
      'mimeType': mimeType,
    });
  } on MissingPluginException {
    return null;
  }
}
