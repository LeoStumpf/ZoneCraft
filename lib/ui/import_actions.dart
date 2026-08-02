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
import '../data/repository.dart';
import '../data/serialization.dart';
import '../geo/border_areas.dart' show outerRings;
import 'feature_search_dialog.dart';
import 'region_geometry.dart';

/// File-pick + parse helpers shared by the layers drawer: per-layer export,
/// importing an external track/area into a freehand layer, and importing a
/// whole layer (new or merged). Kept out of the widget files so the dialog flow
/// is reusable and testable-ish.

/// File types we accept for any geometry import.
const _importGroup = XTypeGroup(
  label: 'Map geometry',
  extensions: ['geojson', 'json', 'kml', 'kmz', 'gpx'],
);

/// Exports a single [layer] to GeoJSON or KML and opens the share sheet.
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
  final fmt = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Export “${layer.name}” as'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'geojson'),
          child: const Text('GeoJSON (re-importable)'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'kml'),
          child: const Text('KML (Google Earth / Maps)'),
        ),
      ],
    ),
  );
  if (fmt == null) return;
  try {
    final isKml = fmt == 'kml';
    final content = isKml ? exportToKml(data) : exportToGeoJson(data);
    final stamp = DateTime.now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    final safeName = layer.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/zonecraft-$safeName-$stamp.$fmt');
    await file.writeAsString(content);
    await SharePlus.instance.share(ShareParams(
      subject: 'ZoneCraft layer: ${layer.name}',
      files: [
        XFile(
          file.path,
          mimeType: isKml
              ? 'application/vnd.google-earth.kml+xml'
              : 'application/geo+json',
        ),
      ],
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

/// Prompts for the inclusion-circle radius applied to freshly imported
/// freehand lines (the circle within which the line splits the map into two
/// half-disks). Prefilled with [defaultMeters], the radius the renderer would
/// otherwise derive. Returns null when cancelled.
Future<double?> askFreeLineRadius(
  BuildContext context, {
  required double defaultMeters,
}) {
  final controller =
      TextEditingController(text: defaultMeters.round().toString());
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
                final n = double.tryParse(controller.text.trim());
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
  final wantArea = layer.type == 'freearea';
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
          kind: wantArea ? 'freearea' : 'freeline',
          coords: f.coords,
          label: f.label,
        ),
    ];
    // Freehand lines are bounded to an inclusion circle — let the user pick
    // its radius right at import (each line keeps its own derived centre).
    if (!wantArea) {
      if (!context.mounted) return;
      final r = await askFreeLineRadius(context,
          defaultMeters: _derivedRadius(objects.first.coords));
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
    messenger.showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'Nothing usable to import (need ${wantArea ? '3+' : '2+'} points)'
          : 'Imported $n ${wantArea ? 'area' : 'track'}${n == 1 ? '' : 's'}'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

/// Searches for a named OSM feature (Nominatim) and imports its geometry into a
/// freehand layer — areas (boundaries, parks, lakes…) as a freehand area, lines
/// (rivers, roads, coastlines…) as a freehand line — a new layer or merged into
/// an existing same-type one. [layers] is the current list (for the picker).
Future<void> importFeatureFlow(
  BuildContext context,
  Repository repo,
  List<Layer> layers,
) async {
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
          label:
              rings.length == 1 ? place.shortName : '${place.shortName} ${i + 1}',
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
    final r = await askFreeLineRadius(context,
        defaultMeters: _derivedRadius(line));
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

  final target = await _askNewOrMerge(context, layers, type);
  if (target == null) return; // cancelled

  final noun = isArea ? 'area' : 'line';
  try {
    final int count;
    if (target.mergeLayerId != null) {
      count = await repo.mergeIntoLayer(target.mergeLayerId!, layer);
    } else {
      count = await repo.importData(ExportData([layer]));
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Imported ${place.shortName} '
          '($count $noun${count == 1 ? '' : 's'})'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

/// Imports a whole layer from a file: tries ZoneCraft GeoJSON first, then falls
/// back to generic geometry. Asks the user whether to add it as a new layer or
/// merge into an existing same-type one. [layers] is the current layer list
/// (for the merge target picker).
Future<void> importLayerFlow(
  BuildContext context,
  Repository repo,
  List<Layer> layers,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picked = await openFile(acceptedTypeGroups: const [_importGroup]);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();

    // 1. Prefer our own tagged GeoJSON (lossless, all object types).
    ExportData? data = importFromGeoJson(utf8.decode(bytes, allowMalformed: true));
    final fromZonecraft = data != null;
    // 2. Fall back to generic geometry → synthesize freehand layers.
    data ??= _syntheticLayers(picked.name, bytes);
    if (data == null || data.layers.isEmpty || data.objectCount == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't read any layers from that file")),
      );
      return;
    }

    if (!context.mounted) return;
    // Synthesized freehand lines get their inclusion-circle radius chosen at
    // import (ZoneCraft GeoJSON already carries each line's stored circle).
    if (!fromZonecraft &&
        data.layers.any(
            (l) => l.type == 'freeline' && l.objects.isNotEmpty)) {
      final firstLine = data.layers
          .firstWhere((l) => l.type == 'freeline' && l.objects.isNotEmpty)
          .objects
          .first;
      final r = await askFreeLineRadius(context,
          defaultMeters: _derivedRadius(firstLine.coords));
      if (r == null) return; // cancelled
      data = ExportData([
        for (final l in data.layers)
          l.type == 'freeline'
              ? ExportLayer(
                  name: l.name,
                  colorArgb: l.colorArgb,
                  type: l.type,
                  isInverted: l.isInverted,
                  objects: [
                    for (final o in l.objects) _withInclusion(o, r),
                  ],
                )
              : l,
      ]);
    }

    if (!context.mounted) return;
    // Merge is only offered for a single imported layer (unambiguous target).
    final target = data.layers.length == 1
        ? await _askNewOrMerge(context, layers, data.layers.first.type)
        : const _ImportChoice.newLayer();
    if (target == null) return; // cancelled

    final int count;
    if (target.mergeLayerId != null) {
      count = await repo.mergeIntoLayer(target.mergeLayerId!, data.layers.first);
    } else {
      count = await repo.importData(data);
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Imported ${data.layers.length} '
          'layer${data.layers.length == 1 ? '' : 's'} ($count objects)'),
    ));
  } on ArgumentError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: ${e.message}')));
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
    messenger.showSnackBar(SnackBar(
      content: Text('Converted $name to $count freehand '
          'area${count == 1 ? '' : 's'}'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Convert failed: $e')));
  }
}

/// Wraps generic line/area geometry into freehand [ExportLayer]s (one freeline
/// layer for lines, one freearea layer for closed areas).
ExportData? _syntheticLayers(String filename, Uint8List bytes) {
  final feats = parseExternalGeometry(filename, bytes);
  if (feats.isEmpty) return null;
  final lines = [for (final f in feats) if (f.kind == GeometryKind.line) f];
  final areas = [for (final f in feats) if (f.kind == GeometryKind.area) f];
  final layers = <ExportLayer>[];
  final base = filename.split('/').last.split('.').first;
  if (lines.isNotEmpty) {
    layers.add(ExportLayer(
      name: base.isEmpty ? 'Imported lines' : base,
      colorArgb: 0xFF2196F3,
      type: 'freeline',
      isInverted: false,
      objects: [
        for (final f in lines)
          ExportObject(kind: 'freeline', coords: f.coords, label: f.label),
      ],
    ));
  }
  if (areas.isNotEmpty) {
    layers.add(ExportLayer(
      name: base.isEmpty ? 'Imported areas' : base,
      colorArgb: 0xFF43A047,
      type: 'freearea',
      isInverted: false,
      objects: [
        for (final f in areas)
          ExportObject(kind: 'freearea', coords: f.coords, label: f.label),
      ],
    ));
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
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Combine')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return null;
  await repo.combineLayers(sourceId: source.id, targetId: target.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Combined into “${target.name}”.')));
  }
  return target.id;
}

Future<_ImportChoice?> _askNewOrMerge(
  BuildContext context,
  List<Layer> layers,
  String type,
) {
  final mergeable = layers.where((l) => l.type == type).toList();
  return showDialog<_ImportChoice>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Import layer'),
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
