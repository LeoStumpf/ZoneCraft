import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/overpass.dart';
import 'poi_icons.dart';

/// What a hand-made POI category is: a name and the marker its points draw as.
class PoiCategoryChoice {
  const PoiCategoryChoice({required this.name, required this.iconKey});

  final String name;

  /// A key into [poiIcons]. Picking one of the built-in categories copies that
  /// category's icon into the catalogue key it corresponds to, so a manual set
  /// always icons itself from `iconKey` and never has to fall back.
  final String iconKey;
}

/// Creates or renames a hand-made POI category.
///
/// Deliberately separate from `showPoiImportDialog`: that one configures a
/// *query* (a category, a centre, a radius), and this one names a container the
/// user fills by tapping the map. Conflating them is how a set ends up claiming
/// to be a search that never ran.
///
/// Pass [initial] to edit an existing category rather than create one.
Future<PoiCategoryChoice?> showPoiCategoryDialog(
  BuildContext context, {
  PoiSet? initial,
}) {
  return showDialog<PoiCategoryChoice>(
    context: context,
    builder: (_) => _PoiCategoryDialog(initial: initial),
  );
}

class _PoiCategoryDialog extends StatefulWidget {
  const _PoiCategoryDialog({this.initial});
  final PoiSet? initial;

  @override
  State<_PoiCategoryDialog> createState() => _PoiCategoryDialogState();
}

class _PoiCategoryDialogState extends State<_PoiCategoryDialog> {
  late final TextEditingController _name;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    final set = widget.initial;
    _name = TextEditingController(text: set?.label ?? '');
    _iconKey = set?.iconKey ?? kDefaultPoiIconKey;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The built-in categories, offered as a shortcut: picking "Cafés" fills in
  /// the name and the matching catalogue icon in one tap. Only the ones whose
  /// key exists in the catalogue are listed — the rest have no icon to copy.
  List<PoiCategory> get _shortcuts =>
      [for (final c in poiCategories) if (poiIcons.containsKey(c.key)) c];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit category' : 'New POI category'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Swimming spots',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text('Start from', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final c in _shortcuts)
                    ActionChip(
                      avatar: Icon(poiIcons[c.key], size: 16),
                      label: Text(c.label),
                      onPressed: () => setState(() {
                        _name.text = c.label;
                        _iconKey = c.key;
                      }),
                    ),
                ],
              ),
              const Divider(height: 24),
              Text('Icon', style: theme.textTheme.labelMedium),
              for (final group in poiIconGroups) ...[
                const SizedBox(height: 8),
                Text(group.label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final i in group.icons)
                      IconButton(
                        tooltip: i.label,
                        isSelected: i.key == _iconKey,
                        onPressed: () => setState(() => _iconKey = i.key),
                        icon: Icon(i.icon),
                        style: IconButton.styleFrom(
                          backgroundColor: i.key == _iconKey
                              ? theme.colorScheme.primaryContainer
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // A category with no name would be a row of anonymous pins in the
          // Elements list, which is the one place it has to be findable.
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    PoiCategoryChoice(
                      name: _name.text.trim(),
                      iconKey: _iconKey,
                    ),
                  ),
          child: Text(editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
