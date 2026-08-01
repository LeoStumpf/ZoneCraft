import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/transit.dart';
import 'hit_test.dart' show geoDistance;
import 'object_summary.dart' show formatMeters;

/// What the user chose to import: the (possibly edited) box, the modes, and the
/// route ids the pre-flight found — already capped, so the fetch is exactly what
/// the dialog promised.
class TransitImportConfig {
  const TransitImportConfig({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.modes,
    required this.heads,
  });

  final double south;
  final double west;
  final double north;
  final double east;
  final Set<TransitMode> modes;
  final List<TransitRouteHead> heads;
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
enum BboxVerdict { ok, warn, tooLarge, invalid }

BboxVerdict checkBbox(double south, double west, double north, double east) {
  if (![south, west, north, east].every((v) => v.isFinite)) {
    return BboxVerdict.invalid;
  }
  if (south >= north || west >= east) return BboxVerdict.invalid;
  final d = bboxDiagonalMeters(south, west, north, east);
  if (!d.isFinite) return BboxVerdict.invalid;
  if (d > transitMaxDiagonalMeters) return BboxVerdict.tooLarge;
  if (d > transitWarnDiagonalMeters) return BboxVerdict.warn;
  return BboxVerdict.ok;
}

/// Asks what to import over [initial], running the Overpass pre-flight so the
/// user sees real per-mode counts (and any connection problem) *before*
/// committing to the multi-megabyte geometry request.
Future<TransitImportConfig?> showTransitImportDialog(
  BuildContext context, {
  required LatLngBounds initial,
  http.Client? client,
}) {
  return showDialog<TransitImportConfig>(
    context: context,
    builder: (_) => _TransitImportDialog(initial: initial, client: client),
  );
}

class _TransitImportDialog extends StatefulWidget {
  const _TransitImportDialog({required this.initial, this.client});

  final LatLngBounds initial;
  final http.Client? client;

  @override
  State<_TransitImportDialog> createState() => _TransitImportDialogState();
}

class _TransitImportDialogState extends State<_TransitImportDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _south;
  late final TextEditingController _west;
  late final TextEditingController _north;
  late final TextEditingController _east;

  final Set<TransitMode> _modes = {...transitModes};

  Timer? _debounce;
  bool _counting = false;
  List<TransitRouteHead>? _heads;
  String? _countError;

  @override
  void initState() {
    super.initState();
    String f(double v) => v.toStringAsFixed(5);
    _south = TextEditingController(text: f(widget.initial.south));
    _west = TextEditingController(text: f(widget.initial.west));
    _north = TextEditingController(text: f(widget.initial.north));
    _east = TextEditingController(text: f(widget.initial.east));
    for (final c in [_south, _west, _north, _east]) {
      c.addListener(_scheduleCount);
    }
    _scheduleCount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_south, _west, _north, _east]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) => double.tryParse(c.text.trim());

  ({double south, double west, double north, double east})? get _box {
    final s = _v(_south), w = _v(_west), n = _v(_north), e = _v(_east);
    if (s == null || w == null || n == null || e == null) return null;
    return (south: s, west: w, north: n, east: e);
  }

  BboxVerdict get _verdict {
    final b = _box;
    if (b == null) return BboxVerdict.invalid;
    return checkBbox(b.south, b.west, b.north, b.east);
  }

  void _scheduleCount() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _runCount);
    if (_heads != null || _countError != null) {
      setState(() {
        _heads = null;
        _countError = null;
      });
    }
  }

  Future<void> _runCount() async {
    final b = _box;
    if (b == null ||
        _modes.isEmpty ||
        _verdict == BboxVerdict.invalid ||
        _verdict == BboxVerdict.tooLarge) {
      return;
    }
    setState(() {
      _counting = true;
      _countError = null;
    });
    final outcome = await countTransitRoutes(
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
      modes: _modes,
      client: widget.client,
    );
    if (!mounted) return;
    setState(() {
      _counting = false;
      _heads = outcome.value;
      _countError = outcome.message;
    });
  }

  /// The heads that will actually be imported: the chosen modes, capped.
  List<TransitRouteHead> get _selected {
    final keys = {for (final m in _modes) m.key};
    final all = [
      for (final h in _heads ?? const <TransitRouteHead>[])
        if (keys.contains(h.modeKey)) h,
    ];
    return all.length <= transitRouteCap
        ? all
        : all.sublist(0, transitRouteCap);
  }

  bool get _canImport =>
      _verdict != BboxVerdict.invalid &&
      _verdict != BboxVerdict.tooLarge &&
      _modes.isNotEmpty &&
      _selected.isNotEmpty;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final b = _box;
    if (b == null || !_canImport) return;
    Navigator.of(context).pop(TransitImportConfig(
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
      modes: {..._modes},
      heads: _selected,
    ));
  }

  Widget _coord(TextEditingController c, String label, bool isLat) {
    return Expanded(
      child: TextFormField(
        controller: c,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: isLat ? validateLat : validateLng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = _box;
    final verdict = _verdict;

    return AlertDialog(
      title: const Text('Import transit lines'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                const SizedBox(height: 6),
                _sizeLine(theme, b, verdict),
                const SizedBox(height: 12),
                Text('Modes', style: theme.textTheme.labelLarge),
                for (final m in transitModes)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _modes.contains(m),
                    title: Text(m.label),
                    secondary: Container(
                      width: 18,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(m.colorArgb),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    subtitle: _modeCount(m),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _modes.add(m);
                        } else {
                          _modes.remove(m);
                        }
                      });
                      _scheduleCount();
                    },
                  ),
                const SizedBox(height: 8),
                _countLine(theme),
              ],
            ),
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

  Widget? _modeCount(TransitMode m) {
    final heads = _heads;
    if (heads == null) return null;
    final n = heads.where((h) => h.modeKey == m.key).length;
    return Text(n == 0 ? 'none here' : '$n route${n == 1 ? '' : 's'}');
  }

  Widget _sizeLine(
    ThemeData theme,
    ({double south, double west, double north, double east})? b,
    BboxVerdict verdict,
  ) {
    if (b == null || verdict == BboxVerdict.invalid) {
      return Text(
        'South must be below north, and west below east.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.error),
      );
    }
    final w = geoDistance.as(LengthUnit.Meter, LatLng(b.south, b.west),
        LatLng(b.south, b.east));
    final h = geoDistance.as(LengthUnit.Meter, LatLng(b.south, b.west),
        LatLng(b.north, b.west));
    final size = '${formatMeters(w)} × ${formatMeters(h)}';
    return switch (verdict) {
      BboxVerdict.tooLarge => Text(
          '$size — too large. Zoom in or pick a smaller box.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.error),
        ),
      BboxVerdict.warn => Text(
          '$size — a big area; the import may take a minute.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: Colors.orange.shade800),
        ),
      _ => Text(size, style: theme.textTheme.bodySmall),
    };
  }

  Widget _countLine(ThemeData theme) {
    if (_counting) {
      return Row(children: [
        const SizedBox(
            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('Checking…', style: theme.textTheme.bodySmall),
      ]);
    }
    final error = _countError;
    if (error != null) {
      return Row(children: [
        Expanded(
          child: Text(
            error,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ),
        TextButton(onPressed: _runCount, child: const Text('Retry')),
      ]);
    }
    final heads = _heads;
    if (heads == null) return const SizedBox(height: 14);
    if (_modes.isEmpty) {
      return Text('Pick at least one mode.',
          style: theme.textTheme.bodySmall);
    }
    final keys = {for (final m in _modes) m.key};
    final total = heads.where((h) => keys.contains(h.modeKey)).length;
    if (total == 0) {
      return Text('No transit routes in this area.',
          style: theme.textTheme.bodySmall);
    }
    final capped = total > transitRouteCap;
    return Text(
      capped
          ? '$total routes found — the first $transitRouteCap will be imported.'
          : '$total route${total == 1 ? '' : 's'} will be imported.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: capped ? Colors.orange.shade800 : null,
      ),
    );
  }
}

/// A blocking progress dialog for the geometry fetch, which legitimately takes
/// seconds to a minute. Returns a closer the caller must call.
///
/// (The POI import just awaits silently — its request is small enough that the
/// user never notices.)
void showTransitProgress(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Flexible(child: Text('Importing transit lines…')),
        ],
      ),
    ),
  );
}
