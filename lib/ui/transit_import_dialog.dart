import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/transit.dart';
import 'hit_test.dart' show geoDistance;
import 'object_summary.dart' show formatMeters;

/// The area to import. Every mode is always fetched — it is one cheap query —
/// so there is nothing else to choose here; which types are *shown* is picked
/// afterwards in the Stations filter.
class TransitImportConfig {
  const TransitImportConfig({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  double get diagonalMeters =>
      bboxDiagonalMeters(south, west, north, east);
}

/// Bbox validation, pulled out of the widget so it is testable without a
/// widget test.
String? validateLat(String? v) {
  final n = double.tryParse((v ?? '').trim());
  if (n == null || !n.isFinite) return 'Number';
  if (n < -90 || n > 90) return '−90…90';
  return null;
}

String? validateLng(String? v) {
  final n = double.tryParse((v ?? '').trim());
  if (n == null || !n.isFinite) return 'Number';
  if (n < -180 || n > 180) return '−180…180';
  return null;
}

/// The diagonal of a box, in metres.
double bboxDiagonalMeters(
    double south, double west, double north, double east) {
  return geoDistance.as(
    LengthUnit.Meter,
    LatLng(south, west),
    LatLng(north, east),
  );
}

/// Whether a box is orderable and small enough to import.
enum BboxVerdict {
  ok,
  warn,
  tooLarge,

  /// Unparseable numbers.
  malformed,

  /// Parseable, but south ≥ north or west ≥ east.
  misordered,
}

BboxVerdict checkBbox(double? south, double? west, double? north, double? east) {
  if (south == null || west == null || north == null || east == null) {
    return BboxVerdict.malformed;
  }
  if (![south, west, north, east].every((v) => v.isFinite)) {
    return BboxVerdict.malformed;
  }
  if (south >= north || west >= east) return BboxVerdict.misordered;
  final d = bboxDiagonalMeters(south, west, north, east);
  if (!d.isFinite) return BboxVerdict.malformed;
  if (d > transitMaxDiagonalMeters) return BboxVerdict.tooLarge;
  if (d > transitWarnDiagonalMeters) return BboxVerdict.warn;
  return BboxVerdict.ok;
}

/// Asks which area to import stations for.
Future<TransitImportConfig?> showTransitImportDialog(
  BuildContext context, {
  required LatLngBounds initial,
}) {
  return showDialog<TransitImportConfig>(
    context: context,
    builder: (_) => _TransitImportDialog(initial: initial),
  );
}

class _TransitImportDialog extends StatefulWidget {
  const _TransitImportDialog({required this.initial});

  final LatLngBounds initial;

  @override
  State<_TransitImportDialog> createState() => _TransitImportDialogState();
}

class _TransitImportDialogState extends State<_TransitImportDialog> {
  late final TextEditingController _south;
  late final TextEditingController _west;
  late final TextEditingController _north;
  late final TextEditingController _east;

  @override
  void initState() {
    super.initState();
    String f(double v) => v.toStringAsFixed(5);
    _south = TextEditingController(text: f(widget.initial.south));
    _west = TextEditingController(text: f(widget.initial.west));
    _north = TextEditingController(text: f(widget.initial.north));
    _east = TextEditingController(text: f(widget.initial.east));
    for (final c in [_south, _west, _north, _east]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_south, _west, _north, _east]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) => double.tryParse(c.text.trim());

  BboxVerdict get _verdict =>
      checkBbox(_v(_south), _v(_west), _v(_north), _v(_east));

  bool get _canImport =>
      _verdict == BboxVerdict.ok || _verdict == BboxVerdict.warn;

  void _submit() {
    if (!_canImport) return;
    Navigator.of(context).pop(TransitImportConfig(
      south: _v(_south)!,
      west: _v(_west)!,
      north: _v(_north)!,
      east: _v(_east)!,
    ));
  }

  Widget _coord(TextEditingController c, String label, bool isLat) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          errorText: isLat ? validateLat(c.text) : validateLng(c.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Import transit stations'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Area', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(children: [
                _coord(_south, 'South', true),
                const SizedBox(width: 8),
                _coord(_north, 'North', true),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _coord(_west, 'West', false),
                const SizedBox(width: 8),
                _coord(_east, 'East', false),
              ]),
              const SizedBox(height: 8),
              _sizeLine(theme),
              const SizedBox(height: 12),
              Text(
                'Every station in the area is imported with the types of '
                'transit that serve it. Choose which types to show afterwards '
                'with Stations… in the layer menu.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canImport ? _submit : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  Widget _sizeLine(ThemeData theme) {
    final err = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w500,
    );
    switch (_verdict) {
      case BboxVerdict.malformed:
        return Text('Enter four numbers to define the area.', style: err);
      case BboxVerdict.misordered:
        return Text('South must be below north, and west below east.',
            style: err);
      case BboxVerdict.tooLarge:
      case BboxVerdict.warn:
      case BboxVerdict.ok:
        break;
    }
    final s = _v(_south)!, w = _v(_west)!, n = _v(_north)!, e = _v(_east)!;
    final width =
        geoDistance.as(LengthUnit.Meter, LatLng(s, w), LatLng(s, e));
    final height =
        geoDistance.as(LengthUnit.Meter, LatLng(s, w), LatLng(n, w));
    final size = '${formatMeters(width)} × ${formatMeters(height)}';
    return switch (_verdict) {
      // An explicit, actionable error — never a silent refusal.
      BboxVerdict.tooLarge => Text(
          '$size — too large to import. Pick a box under '
          '${formatMeters(transitMaxDiagonalMeters)} across.',
          style: err,
        ),
      BboxVerdict.warn => Text(
          '$size — a large area; this may take a minute.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: Colors.orange.shade800),
        ),
      _ => Text(size, style: theme.textTheme.bodySmall),
    };
  }
}

/// A blocking progress dialog for the import.
///
/// `barrierDismissible: false` alone does **not** stop the Android back
/// button — the previous version could be dismissed that way, after which the
/// caller's untargeted `Navigator.pop()` popped the map screen itself. The
/// `PopScope` closes that hole, and the caller pops via the returned closer
/// rather than the ambient context.
VoidCallback showTransitProgress(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  var closed = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  return () {
    if (closed) return;
    closed = true;
    navigator.pop();
  };
}
