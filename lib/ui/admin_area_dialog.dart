import 'package:flutter/material.dart';

import '../data/place_search.dart';

/// A search dialog that geocodes a place name (Nominatim) and lets the user
/// pick a boundary to import. Returns the chosen [PlaceResult], or null if
/// cancelled. Network errors / empty results are surfaced inline.
Future<PlaceResult?> showAdminAreaSearchDialog(BuildContext context) {
  return showDialog<PlaceResult>(
    context: context,
    builder: (_) => const _AdminAreaDialog(),
  );
}

class _AdminAreaDialog extends StatefulWidget {
  const _AdminAreaDialog();

  @override
  State<_AdminAreaDialog> createState() => _AdminAreaDialogState();
}

class _AdminAreaDialogState extends State<_AdminAreaDialog> {
  final _controller = TextEditingController();
  bool _searching = false;
  String? _error;
  List<PlaceResult>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        _error = 'Search failed — offline or rate-limited. Try again shortly.';
      } else {
        _results = res;
        if (res.isEmpty) _error = 'No areas with a boundary found for “$q”.';
      }
    });
  }

  String _subtitle(PlaceResult r) {
    final kind = [r.category, r.type]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    final pts = '${r.pointCount} pts';
    return kind.isEmpty ? pts : '$kind · $pts';
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return AlertDialog(
      title: const Text('Import admin area'),
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
                labelText: 'Place name',
                hintText: 'e.g. Munich, Bavaria',
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                      leading: const Icon(Icons.public),
                      title: Text(r.displayName,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_subtitle(r)),
                      onTap: () => Navigator.of(context).pop(r),
                    );
                  },
                ),
              )
            else
              Text(
                'Type a city, district or country name, then search. The '
                'matching boundary is imported as a freehand area.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
