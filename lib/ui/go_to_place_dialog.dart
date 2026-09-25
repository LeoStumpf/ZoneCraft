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

import 'package:flutter/material.dart';

import '../data/place_search.dart';
import '../data/service_credits.dart';
import 'service_credit_line.dart';

/// Type a place, move the map there. Changes nothing.
///
/// The app opened on Munich at zoom 5 on a fresh install and had **no way to
/// type a place name at all** — the only geocoder route was bolted onto the
/// feature *import* flow, whose button appears solely on freehand line and
/// area layers, and the layer a new install is seeded with is `circles`. So a
/// first-time user anywhere but southern Germany had exactly two ways to reach
/// their own town: pinch-pan across a continent, or grant location permission.
///
/// Deliberately separate from `feature_search_dialog`: that one *writes* — it
/// imports a boundary as an editable layer — and this one only moves the
/// camera. Sharing a dialog would have meant one button that sometimes edits
/// the map and sometimes does not.
Future<PlaceResult?> showGoToPlaceDialog(BuildContext context) {
  return showDialog<PlaceResult>(
    context: context,
    builder: (_) => const _GoToPlaceDialog(),
  );
}

class _GoToPlaceDialog extends StatefulWidget {
  const _GoToPlaceDialog();

  @override
  State<_GoToPlaceDialog> createState() => _GoToPlaceDialogState();
}

class _GoToPlaceDialogState extends State<_GoToPlaceDialog> {
  final _controller = TextEditingController();
  bool _searching = false;
  String? _error;
  List<PlaceResult>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs on submit and on the search button only.
  ///
  /// Never per keystroke: Nominatim's usage policy forbids autocomplete
  /// outright, and `searchPlaces` additionally paces and caches so that
  /// repeating a search — type, look, cancel, reopen, type again — cannot
  /// become the request pattern that gets a client blocked.
  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    final res = await searchPlaces(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      if (res == null) {
        _error =
            'Search failed — offline, or the geocoder is busy. '
            'Try again shortly.';
      } else {
        // Everything is navigable, shape or no shape.
        _results = res;
        if (res.isEmpty) _error = 'Nothing found for “$q”.';
      }
    });
  }

  String _subtitle(PlaceResult r) {
    final kind = [
      r.category,
      r.type,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    return kind.isEmpty ? r.displayName : '$kind · ${r.displayName}';
  }

  IconData _icon(PlaceResult r) {
    if (r.areas.isNotEmpty) return Icons.hexagon_outlined;
    if (r.lines.isNotEmpty) return Icons.polyline;
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Go to place'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Town, street or landmark',
                hintText: 'e.g. Lisbon, or Bahnhofstrasse Ulm',
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _searching ? null : _search,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_searching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else if (results != null && results.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = results[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_icon(r)),
                      title: Text(r.shortName),
                      subtitle: Text(
                        _subtitle(r),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, r),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moves the map only — nothing is added to your layers.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    const ServiceCreditLine(kNominatimCredit),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
