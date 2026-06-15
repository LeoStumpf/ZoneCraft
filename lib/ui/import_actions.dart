import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/geo_import.dart';
import '../data/repository.dart';
import '../data/serialization.dart';
import 'admin_area_dialog.dart';

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
    final objects = <ExportObject>[
      for (final f in feats)
        ExportObject(
          kind: wantArea ? 'freearea' : 'freeline',
          coords: f.coords,
          label: f.label,
        ),
    ];
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

/// Searches for an administrative area by name (Nominatim) and imports its
/// boundary as a freehand area — a new layer, or merged into an existing
/// freearea layer. [layers] is the current list (for the merge-target picker).
Future<void> importAdminAreaFlow(
  BuildContext context,
  Repository repo,
  List<Layer> layers,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final place = await showAdminAreaSearchDialog(context);
  if (place == null || !context.mounted) return;

  // One area object per outer ring (a multipolygon yields several). Need 3+
  // points to form an area; drop any degenerate ring.
  final usable = place.rings.where((r) => r.length >= 3).toList();
  if (usable.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('That area has no usable boundary')),
    );
    return;
  }
  final objects = <ExportObject>[
    for (var i = 0; i < usable.length; i++)
      ExportObject(
        kind: 'freearea',
        coords: usable[i],
        label: usable.length == 1 ? place.shortName : '${place.shortName} ${i + 1}',
      ),
  ];
  final layer = ExportLayer(
    name: place.shortName,
    colorArgb: 0xFF43A047,
    type: 'freearea',
    isInverted: false,
    objects: objects,
  );

  final target = await _askNewOrMerge(context, layers, 'freearea');
  if (target == null) return; // cancelled

  try {
    final int count;
    if (target.mergeLayerId != null) {
      count = await repo.mergeIntoLayer(target.mergeLayerId!, layer);
    } else {
      count = await repo.importData(ExportData([layer]));
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Imported ${place.shortName} '
          '($count area${count == 1 ? '' : 's'})'),
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
    // 2. Fall back to generic geometry → synthesize freehand layers.
    data ??= _syntheticLayers(picked.name, bytes);
    if (data == null || data.layers.isEmpty || data.objectCount == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't read any layers from that file")),
      );
      return;
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
