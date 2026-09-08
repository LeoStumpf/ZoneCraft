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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/geo_import.dart';
import '../data/layer_types.dart';
import '../data/platform_files.dart';
import '../data/repository.dart';
import '../data/serialization.dart';
import '../geo/border_areas.dart' show outerRings;
import '../geo/coords.dart';
import 'feature_search_dialog.dart';
import 'region_geometry.dart';

/// File-pick + parse helpers shared by the layers drawer: per-layer export,
/// importing an external track/area into a freehand layer, and importing a
/// whole layer (new or merged). Kept out of the widget files so the dialog flow
/// is reusable and testable-ish.

/// File types we accept for any geometry import.
///
/// The MIME types are spelled out as well as the extensions, and
/// `application/octet-stream` is among them, because Android's picker filters
/// on MIME: it resolves an extension through the system map, which has no entry
/// for `.geojson`, so it types our **own exports** as octet-stream and greys
/// them out. A picker that cannot open the file the app just wrote is worse
/// than a loose filter — and a file that isn't geometry is rejected with a
/// message either way.
const _importGroup = XTypeGroup(
  label: 'Map geometry',
  extensions: ['geojson', 'json', 'kml', 'kmz', 'gpx'],
  mimeTypes: [
    'application/geo+json',
    'application/json',
    'application/vnd.google-earth.kml+xml',
    'application/vnd.google-earth.kmz',
    'application/gpx+xml',
    'application/xml',
    'text/xml',
    'text/plain',
    'application/octet-stream',
  ],
);

/// Above this many vertices an export is worth warning about before it is
/// written. Administrative borders are the only thing that reaches it in
/// practice — a single state boundary is ~119 000 points on its own, and the
/// file is shared, not just saved.
const int kLargeExportPoints = 50000;

/// Rough bytes per vertex of pretty-printed GeoJSON: two 7-decimal numbers on
/// their own indented lines, plus the brackets. Only used to put a number on
/// the warning, so being a little over is the safe direction.
const int _bytesPerPoint = 45;

/// Warns before writing a very large export, since the result is meant to be
/// shared and a 40 MB attachment is a surprise worth having in advance.
/// Returns true to go ahead. Silent (and true) below [kLargeExportPoints].
Future<bool> confirmLargeExport(BuildContext context, ExportData data) async {
  final points = data.pointCount;
  if (points < kLargeExportPoints) return true;
  final mb = (points * _bytesPerPoint) / (1024 * 1024);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Large export'),
      content: Text(
        'This holds ${_thousands(points)} points and will make a file of '
        'roughly ${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB — administrative '
        'borders are detailed. It exports at full detail, so the map looks '
        'the same on the other side.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Export'),
        ),
      ],
    ),
  );
  return ok == true;
}

String _thousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u202F');
    b.write(s[i]);
  }
  return b.toString();
}

/// Where an export goes once its format is chosen.
enum ExportDestination {
  /// The system share sheet (`share_plus`).
  share,

  /// A location the user picks, via Android's document picker.
  save,
}

/// What [askExportChoice] answers: a format and a destination.
class ExportChoice {
  const ExportChoice(this.format, this.destination);

  /// `'geojson'` or `'kml'` — also the file extension.
  final String format;
  final ExportDestination destination;

  bool get isKml => format == 'kml';

  /// The GeoJSON type stays `application/geo+json` (RFC 7946) rather than the
  /// more widely known `application/json`, because of how Android's document
  /// picker names the file it creates: `FileUtils.buildUniqueFile` replaces
  /// the title's extension with the one the MIME maps to unless they already
  /// agree. Android has no extension mapping for `geo+json` — the same gap
  /// that forces `application/octet-stream` into [_importGroup] — so there is
  /// nothing to swap in and `x.geojson` is saved verbatim. Under
  /// `application/json` the same file would be saved as `x.geojson.json`.
  String get mimeType => isKml
      ? 'application/vnd.google-earth.kml+xml'
      : 'application/geo+json';
}

/// Remembered for the session only: whoever saved once probably wants to save
/// again, and a destination is not worth an `AppSettings` column.
ExportDestination _lastDestination = ExportDestination.share;

/// The one export dialog, shared by the per-layer and the whole-database
/// export. Returns null when cancelled.
///
/// Destination is a mode on the dialog rather than a second dialog or a
/// doubled list of rows: sharing is the common case and stays two taps, while
/// saving costs one more and is visible without being modal. The control is
/// only built where a save is possible, so a platform without one sees exactly
/// the dialog this app has always had.
Future<ExportChoice?> askExportChoice(
  BuildContext context, {
  required String title,
}) {
  var destination = platformFilesSupported
      ? _lastDestination
      : ExportDestination.share;
  return showDialog<ExportChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) => SimpleDialog(
        title: Text(title),
        children: [
          if (platformFilesSupported)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              // Labels only, inside a horizontal scroller: a SegmentedButton
              // with icons overflows a dialog at a large system font, and a
              // dialog clips as silently as a bottom sheet does.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<ExportDestination>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ExportDestination.share,
                      label: Text('Share'),
                    ),
                    ButtonSegment(
                      value: ExportDestination.save,
                      label: Text('Save to file'),
                    ),
                  ],
                  selected: {destination},
                  onSelectionChanged: (s) => setInner(() {
                    destination = s.first;
                    _lastDestination = s.first;
                  }),
                ),
              ),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, ExportChoice('geojson', destination)),
            child: const Text('GeoJSON (re-importable)'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, ExportChoice('kml', destination)),
            child: const Text('KML (Google Earth / Maps)'),
          ),
        ],
      ),
    ),
  );
}

/// `2026-08-26T14-31-05` — a file name's worth of "when".
String exportStamp() =>
    DateTime.now().toIso8601String().split('.').first.replaceAll(':', '-');

/// A layer name reduced to something a file system will keep verbatim.
String exportSafeName(String name) =>
    name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

/// Writes [data] in the chosen format and either shares it or hands it to the
/// system document picker. Shows its own snackbars.
///
/// [fileStem] is the name without its extension. The temp file is written
/// either way: it is what `share_plus` needs, and what the platform save
/// streams from.
Future<void> deliverExport(
  BuildContext context,
  ExportData data,
  ExportChoice choice, {
  required String fileStem,
  required String subject,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final content = choice.isKml
        ? exportToKml(data)
        : exportToGeoJson(data);
    final dir = await getTemporaryDirectory();
    final fileName = '$fileStem.${choice.format}';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    if (choice.destination == ExportDestination.save) {
      final saved = await saveFileToDisk(
        sourcePath: file.path,
        suggestedName: fileName,
        mimeType: choice.mimeType,
      );
      if (saved == null) return; // backed out of the picker: say nothing
      messenger.showSnackBar(SnackBar(content: Text('Saved $saved')));
    } else {
      await SharePlus.instance.share(
        ShareParams(
          subject: subject,
          files: [XFile(file.path, mimeType: choice.mimeType)],
        ),
      );
    }
  // An export reaches the user as a message whatever went wrong — a share sheet
  // that failed silently is indistinguishable from one that never opened.
  // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

/// Exports a single [layer] to GeoJSON or KML, then shares or saves it.
Future<void> exportSingleLayer(
  BuildContext context,
  Repository repo,
  Layer layer,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = await repo.exportData(onlyLayerId: layer.id);
  if (!context.mounted) return;
  if (data.objectCount == 0) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Nothing to export in this layer')),
    );
    return;
  }
  if (!await confirmLargeExport(context, data)) return;
  if (!context.mounted) return;
  final choice = await askExportChoice(
    context,
    title: 'Export “${layer.name}” as',
  );
  if (choice == null || !context.mounted) return;
  await deliverExport(
    context,
    data,
    choice,
    fileStem: 'zonecraft-${exportSafeName(layer.name)}-${exportStamp()}',
    subject: 'ZoneCraft layer: ${layer.name}',
  );
}

/// Prompts for the inclusion-circle radius applied to freshly imported
/// freehand lines (the circle within which the line splits the map into two
/// half-disks). Prefilled with [defaultMeters], the radius the renderer would
/// otherwise derive. Returns null when cancelled.
Future<double?> askFreeLineRadius(
  BuildContext context, {
  required double defaultMeters,
}) {
  final controller = TextEditingController(
    text: defaultMeters.round().toString(),
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Line area of interest'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The imported line divides the map only within a circle '
                'around it. Choose that circle\'s radius — you can move and '
                'resize it later in the line editor.',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Radius (m)',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = parseDecimal(controller.text.trim());
                if (n == null || !n.isFinite || n <= 0) {
                  setState(() => error = 'Enter metres > 0');
                  return;
                }
                Navigator.pop(ctx, n);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );
    },
  );
}

/// [o] (a freeline) with its inclusion circle set to [radiusMeters], centred on
/// the line's arc-length midpoint (the same centre the renderer would derive).
ExportObject _withInclusion(ExportObject o, double radiusMeters) {
  final inc = effectiveInclusion(
    lat: null,
    lng: null,
    radiusMeters: radiusMeters,
    points: o.coords,
  );
  return ExportObject(
    kind: o.kind,
    coords: o.coords,
    label: o.label,
    offsetMeters: o.offsetMeters,
    inclusionLat: inc.center.latitude,
    inclusionLng: inc.center.longitude,
    inclusionRadiusMeters: radiusMeters,
  );
}

/// The inclusion radius the renderer would derive for [coords] — used to
/// prefill the radius prompt.
double _derivedRadius(List<LatLng> coords) => effectiveInclusion(
  lat: null,
  lng: null,
  radiusMeters: null,
  points: coords,
).radiusMeters;

/// Imports an external track/area file (GeoJSON/KML/KMZ/GPX) into an existing
/// freehand [layer], adding each line/area as a new object on it.
Future<void> importTrackIntoLayer(
  BuildContext context,
  Repository repo,
  Layer layer,
) async {
  final messenger = ScaffoldMessenger.of(context);
  // A `track` layer takes the file as what it already is — a recorded line —
  // so it skips the inclusion-circle question entirely (a track bounds
  // nothing) and lands in the same track the recorder appends to.
  //
  // A **combined** layer can hold all three, so track wins: this entry is
  // called "Import track…", and importing a GPX as anything else would be a
  // silent reinterpretation of the file.
  final wantTrack = layerHolds(layer, kTrack);
  final wantArea = !wantTrack && layerHolds(layer, kFreeArea);
  try {
    final picked = await openFile(acceptedTypeGroups: const [_importGroup]);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final feats = parseExternalGeometry(picked.name, bytes);
    if (feats.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No line or area geometry in that file')),
      );
      return;
    }
    var objects = <ExportObject>[
      for (final f in feats)
        ExportObject(
          kind: wantArea
              ? 'freearea'
              : wantTrack
                  ? 'track'
                  : 'freeline',
          coords: f.coords,
          label: f.label,
        ),
    ];
    // Freehand lines are bounded to an inclusion circle — let the user pick
    // its radius right at import (each line keeps its own derived centre).
    if (!wantArea && !wantTrack) {
      if (!context.mounted) return;
      final r = await askFreeLineRadius(
        context,
        defaultMeters: _derivedRadius(objects.first.coords),
      );
      if (r == null) return; // cancelled
      objects = [for (final o in objects) _withInclusion(o, r)];
    }
    final n = await repo.mergeIntoLayer(
      layer.id,
      ExportLayer(
        name: layer.name,
        colorArgb: layer.colorArgb,
        type: layer.type,
        isInverted: layer.isInverted,
        objects: objects,
      ),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'Nothing usable to import (need ${wantArea ? '3+' : '2+'} points)'
              : 'Imported $n ${wantArea ? 'area' : 'track'}${n == 1 ? '' : 's'}',
        ),
      ),
    );
  // Same contract as the export above: a failed import says so.
  // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

/// Searches for a named OSM feature (Nominatim) and imports its geometry into a
/// freehand layer — areas (boundaries, parks, lakes…) as a freehand area, lines
/// (rivers, roads, coastlines…) as a freehand line — a new layer or merged into
/// an existing same-type one. [layers] is the current list (for the picker).
///
/// [into] is the layer whose menu started this, if any: the destination
/// question is then already answered and the picker is skipped. The geometry
/// still decides the type, so a *line* feature searched from a freehand **area**
/// layer falls back to the picker rather than being coerced into a polygon.
Future<void> importFeatureFlow(
  BuildContext context,
  Repository repo,
  List<Layer> layers, {
  Layer? into,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final place = await showFeatureSearchDialog(context);
  if (place == null || !context.mounted) return;

  // Route by geometry. Areas → freearea, one object per outer ring (a
  // multipolygon is genuinely several regions). A line feature → freeline, a
  // SINGLE object: its MultiLineString parts (e.g. a river's member ways) are
  // stitched into one continuous divide, so it fills one side instead of many
  // disjoint half-planes that union to cover the whole map.
  final isArea = place.dominantKind == GeometryKind.area;
  final type = isArea ? 'freearea' : 'freeline';
  final List<ExportObject> objects;
  if (isArea) {
    final rings = place.areas.where((c) => c.length >= 3).toList();
    if (rings.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That feature has no usable geometry')),
      );
      return;
    }
    objects = [
      for (var i = 0; i < rings.length; i++)
        ExportObject(
          kind: 'freearea',
          coords: rings[i],
          label: rings.length == 1
              ? place.shortName
              : '${place.shortName} ${i + 1}',
        ),
    ];
  } else {
    final line = stitchPolylines(place.lines);
    if (line.length < 2) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That feature has no usable geometry')),
      );
      return;
    }
    // Pick the inclusion-circle radius right at import (a whole river spans
    // hundreds of km — the circle bounds it to the user's area of interest).
    final r = await askFreeLineRadius(
      context,
      defaultMeters: _derivedRadius(line),
    );
    if (r == null || !context.mounted) return; // cancelled
    objects = [
      _withInclusion(
        ExportObject(kind: 'freeline', coords: line, label: place.shortName),
        r,
      ),
    ];
  }
  final layer = ExportLayer(
    name: place.shortName,
    colorArgb: isArea ? 0xFF43A047 : 0xFF2196F3,
    type: type,
    isInverted: false,
    objects: objects,
  );

  final noun = isArea ? 'area' : 'line';
  final _ImportChoice target;
  if (into != null && into.type == type) {
    target = _ImportChoice.merge(into.id); // started from this layer's menu
  } else {
    final picked = await _askNewOrMerge(
      context,
      layers,
      type,
      note: into == null
          ? null
          : '“${place.shortName}” is a $noun, so it can’t go into '
              '“${into.name}”.',
    );
    if (picked == null) return; // cancelled
    target = picked;
  }

  try {
    final int count;
    if (target.mergeLayerId != null) {
      count = await repo.mergeIntoLayer(target.mergeLayerId!, layer);
    } else {
      count = await repo.importData(ExportData([layer]));
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${place.shortName} '
          '($count $noun${count == 1 ? '' : 's'})',
        ),
      ),
    );
  // Same contract: Overpass, the parser and the write can all fail, and the
  // user needs one sentence rather than three code paths.
  // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

/// Imports a whole layer from a file the user picks: tries ZoneCraft GeoJSON
/// first, then falls back to generic geometry. Asks whether to add it as a new
/// layer or merge into an existing same-type one. [layers] is the current layer
/// list (for the merge target picker).
Future<void> importLayerFlow(
  BuildContext context,
  Repository repo,
  List<Layer> layers,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final XFile? picked;
  final Uint8List bytes;
  try {
    picked = await openFile(acceptedTypeGroups: const [_importGroup]);
    if (picked == null) return;
    bytes = await picked.readAsBytes();
  // The document picker throws platform-specific errors (a revoked grant, a
  // provider that died); all of them mean the file did not arrive.
  // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    return;
  }
  if (!context.mounted) return;
  await importBytesFlow(context, repo, layers, name: picked.name, bytes: bytes);
}

/// The same import with the file already in hand.
///
/// [importLayerFlow] above and a file another app shared into ZoneCraft (see
/// `data/platform_files.dart`, consumed in `map_screen`) both run *this*, so a
/// shared file and a picked one are the same import: same ZoneCraft-GeoJSON-
/// first order, same freehand-line radius prompt, same new-or-merge choice,
/// same thinning rule.
///
/// [name] is only ever a file name — [parseExternalGeometry] sniffs its
/// extension and a synthesized layer is named after its stem.
Future<void> importBytesFlow(
  BuildContext context,
  Repository repo,
  List<Layer> layers, {
  required String name,
  required Uint8List bytes,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    // 1. Prefer our own tagged GeoJSON (lossless, all object types).
    ExportData? data = importFromGeoJson(
      utf8.decode(bytes, allowMalformed: true),
    );
    final fromZonecraft = data != null;
    // 2. Fall back to generic geometry → synthesize freehand layers.
    data ??= _syntheticLayers(name, bytes);
    if (data == null || data.layers.isEmpty || data.objectCount == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't read any layers from that file"),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    // Synthesized freehand lines get their inclusion-circle radius chosen at
    // import (ZoneCraft GeoJSON already carries each line's stored circle).
    if (!fromZonecraft &&
        data.layers.any((l) => l.type == 'freeline' && l.objects.isNotEmpty)) {
      final firstLine = data.layers
          .firstWhere((l) => l.type == 'freeline' && l.objects.isNotEmpty)
          .objects
          .first;
      final r = await askFreeLineRadius(
        context,
        defaultMeters: _derivedRadius(firstLine.coords),
      );
      if (r == null) return; // cancelled
      data = ExportData([
        for (final l in data.layers)
          l.type == 'freeline'
              ? ExportLayer(
                  name: l.name,
                  colorArgb: l.colorArgb,
                  type: l.type,
                  isInverted: l.isInverted,
                  objects: [for (final o in l.objects) _withInclusion(o, r)],
                )
              : l,
      ]);
    }

    if (!context.mounted) return;
    // Merge is only offered for a single imported layer (unambiguous target).
    final target = data.layers.length == 1
        ? await _askNewOrMerge(
            context,
            layers,
            data.layers.first.type,
            borderLevel: data.layers.first.borderLevel,
          )
        : const _ImportChoice.newLayer();
    if (target == null) return; // cancelled

    // Our own GeoJSON comes back verbatim: thinning what this app wrote would
    // change the shape on every round-trip. A generic file still gets the RDP
    // pass — that is where the GPS jitter and the thousand-point city outlines
    // are.
    final int count;
    if (target.mergeLayerId != null) {
      count = await repo.mergeIntoLayer(
        target.mergeLayerId!,
        data.layers.first,
        simplify: !fromZonecraft,
      );
    } else {
      count = await repo.importData(data, simplify: !fromZonecraft);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${data.layers.length} '
          'layer${data.layers.length == 1 ? '' : 's'} ($count objects)',
        ),
      ),
    );
  // ArgumentError is how the importer reports a *rejected file* — data, not a
  // programming mistake — so it is caught deliberately to be shown.
  // ignore: avoid_catching_errors
  } on ArgumentError catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Import failed: ${e.message}')),
    );
  // The rejection above is typed; this is the backstop that keeps any other
  // failure from becoming an unhandled async error.
  // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

/// Turns one **already-imported** border area into freehand areas — the offline
/// twin of [importFeatureFlow].
///
/// The point is not to re-fetch something you already have on the device: a
/// borders layer is a read-only OSM snapshot with no editor, and this is how a
/// shape gets out of it and into geometry you own, can drag, offset, invert and
/// export. Same new-or-merge choice as every other import, so it lands where
/// you want it.
///
/// Holes are dropped: a freehand area is a single ring with no notion of one,
/// so a hole carried across would render as solid fill exactly where the real
/// area has a gap. Exclaves survive as separate areas ([outerRings]).
Future<void> convertBorderAreaFlow(
  BuildContext context,
  Repository repo,
  List<Layer> layers, {
  required String name,
  required List<List<LatLng>> rings,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final usable = [
    for (final r in outerRings(rings))
      if (r.length >= 3) r,
  ];
  if (usable.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('That area has no usable geometry')),
    );
    return;
  }

  final target = await _askNewOrMerge(context, layers, 'freearea');
  if (target == null) return; // cancelled

  final layer = ExportLayer(
    name: name,
    colorArgb: 0xFF43A047,
    type: 'freearea',
    isInverted: false,
    objects: [
      for (var i = 0; i < usable.length; i++)
        ExportObject(
          kind: 'freearea',
          coords: usable[i],
          label: usable.length == 1 ? name : '$name ${i + 1}',
        ),
    ],
  );

  try {
    final count = target.mergeLayerId != null
        ? await repo.mergeIntoLayer(target.mergeLayerId!, layer)
        : await repo.importData(ExportData([layer]));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Converted $name to $count freehand '
          'area${count == 1 ? '' : 's'}',
        ),
      ),
    );
  // Same contract: a failed conversion says so rather than doing nothing.
  // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Convert failed: $e')));
  }
}

/// Wraps generic line/area geometry into freehand [ExportLayer]s (one freeline
/// layer for lines, one freearea layer for closed areas).
ExportData? _syntheticLayers(String filename, Uint8List bytes) {
  final feats = parseExternalGeometry(filename, bytes);
  if (feats.isEmpty) return null;
  final lines = [
    for (final f in feats)
      if (f.kind == GeometryKind.line) f,
  ];
  final areas = [
    for (final f in feats)
      if (f.kind == GeometryKind.area) f,
  ];
  final layers = <ExportLayer>[];
  final base = filename.split('/').last.split('.').first;
  if (lines.isNotEmpty) {
    layers.add(
      ExportLayer(
        name: base.isEmpty ? 'Imported lines' : base,
        colorArgb: 0xFF2196F3,
        type: 'freeline',
        isInverted: false,
        objects: [
          for (final f in lines)
            ExportObject(kind: 'freeline', coords: f.coords, label: f.label),
        ],
      ),
    );
  }
  if (areas.isNotEmpty) {
    layers.add(
      ExportLayer(
        name: base.isEmpty ? 'Imported areas' : base,
        colorArgb: 0xFF43A047,
        type: 'freearea',
        isInverted: false,
        objects: [
          for (final f in areas)
            ExportObject(kind: 'freearea', coords: f.coords, label: f.label),
        ],
      ),
    );
  }
  return layers.isEmpty ? null : ExportData(layers);
}

/// Result of the new-vs-merge prompt.
class _ImportChoice {
  const _ImportChoice.newLayer() : mergeLayerId = null;
  const _ImportChoice.merge(this.mergeLayerId);
  final String? mergeLayerId;
}

/// Irreversibly merges [source] into another same-type layer picked from
/// [targets]: shows a target picker, then a confirmation, then calls
/// [Repository.combineLayers]. Returns the target layer id it merged into (so
/// the caller can re-select the active layer), or null if cancelled.
Future<String?> combineLayerFlow(
  BuildContext context,
  Repository repo,
  Layer source,
  List<Layer> targets,
) async {
  if (targets.isEmpty) return null;
  final targetId = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Combine “${source.name}” into…'),
      children: [
        for (final l in targets)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, l.id),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.merge),
              title: Text(l.name),
            ),
          ),
      ],
    ),
  );
  if (targetId == null || !context.mounted) return null;
  final target = targets.firstWhere((l) => l.id == targetId);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Combine layers?'),
      content: Text(
        'Move all objects from “${source.name}” into “${target.name}” and '
        'delete “${source.name}”. They take on “${target.name}”’s colour and '
        'settings. This can’t be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Combine'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return null;
  await repo.combineLayers(sourceId: source.id, targetId: target.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Combined into “${target.name}”.')),
      );
  }
  return target.id;
}

/// Asks where an import of [type] should go. [note] explains *why* the question
/// is being asked when the caller already had a destination in mind (see
/// [importFeatureFlow]) — without it, a picker appearing out of a layer's own
/// menu reads as a bug.
Future<_ImportChoice?> _askNewOrMerge(
  BuildContext context,
  List<Layer> layers,
  String type, {
  String? note,
  String? borderLevel,
}) {
  // One borders layer holds one admin level, so a level-8 file can only merge
  // into a level-8 layer — offering the others would be offering an error.
  final mergeable = layers
      .where((l) =>
          l.type == type &&
          (type != 'borders' ||
              borderLevel == null ||
              l.borderLevel == borderLevel))
      .toList();
  return showDialog<_ImportChoice>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: note == null
          ? const Text('Import layer')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Import layer'),
                const SizedBox(height: 6),
                Text(note, style: Theme.of(ctx).textTheme.bodyMedium),
              ],
            ),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, const _ImportChoice.newLayer()),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add),
            title: Text('Add as a new layer'),
          ),
        ),
        if (mergeable.isNotEmpty) const Divider(),
        for (final l in mergeable)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, _ImportChoice.merge(l.id)),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.merge),
              title: Text('Merge into “${l.name}”'),
            ),
          ),
      ],
    ),
  );
}
