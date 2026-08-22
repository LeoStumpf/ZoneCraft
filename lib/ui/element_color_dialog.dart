import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart' show ColoredElement;
import '../state/providers.dart';
import 'element_color.dart';

/// What [showElementColorDialog] came back with. `argb == null` means "follow
/// the layer" — the element goes back to its auto shade, and a later layer
/// recolour will carry it along again.
class ElementColorChoice {
  const ElementColorChoice(this.argb);
  final int? argb;
}

/// Picks one element's colour, with "follow the layer" as a first-class option
/// rather than a colour the user has to match by eye.
///
/// [current] is what the element paints in today and [following] whether that
/// is its auto shade, so the dialog can say which state it is in.
Future<ElementColorChoice?> showElementColorDialog(
  BuildContext context, {
  required String title,
  required Color current,
  required bool following,
  required Color layerColor,
  required int shadeIndex,
}) async {
  var picked = current;
  return showDialog<ElementColorChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _swatch(autoShade(layerColor, shadeIndex)),
              title: const Text('Follow the layer'),
              subtitle: Text(
                following
                    ? 'Its own shade of the layer colour — in use now'
                    : 'Back to its own shade of the layer colour',
              ),
              onTap: () =>
                  Navigator.pop(ctx, const ElementColorChoice(null)),
            ),
            const Divider(),
            // The layer's own shade ladder, offered explicitly: these are the
            // colours the layer hands out by itself, so "the same green as my
            // other circles, but that one" is a tap rather than a colour the
            // user has to match by eye in the picker below. Picking one stores
            // it as a plain ARGB — see [shadePalette].
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Shades of the layer colour',
                style: Theme.of(ctx).textTheme.labelMedium,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final shade in shadePalette(layerColor))
                  InkWell(
                    onTap: () => Navigator.pop(
                      ctx,
                      ElementColorChoice(shade.toARGB32()),
                    ),
                    customBorder: const CircleBorder(),
                    child: _swatch(shade),
                  ),
              ],
            ),
            const Divider(height: 24),
            BlockPicker(
              pickerColor: picked,
              onColorChanged: (c) => picked = c,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(ctx, ElementColorChoice(picked.toARGB32())),
          child: const Text('Select'),
        ),
      ],
    ),
  );
}

Widget _swatch(Color c) => Container(
  width: 28,
  height: 28,
  decoration: BoxDecoration(
    color: c,
    shape: BoxShape.circle,
    border: Border.all(color: Colors.black26),
  ),
);

/// The colour control the editor sheets carry: a swatch of what the element
/// paints in, opening [showElementColorDialog] and writing the answer.
///
/// One widget rather than nine copies, because the Elements-list row menu and
/// nine editors must agree on what "follow the layer" means — the same reason
/// `layerHasEditor` is one definition.
///
/// [layerColor] is the owning layer's colour; pass null (and the button hides
/// itself) when the layer isn't resolvable, rather than throwing inside a
/// build.
class ElementColorButton extends ConsumerWidget {
  const ElementColorButton({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    required this.colorArgb,
    required this.colorShade,
    required this.layerColor,
    this.size = 20,
  });

  final ColoredElement kind;
  final String id;

  /// What the dialog is titled — the element's own name.
  final String title;

  final int? colorArgb;
  final int colorShade;
  final Color? layerColor;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = layerColor;
    if (base == null) return const SizedBox.shrink();
    final current = elementColor(
      colorArgb: colorArgb,
      shadeIndex: colorShade,
      layerColor: base,
    );
    return IconButton(
      tooltip: colorArgb == null ? 'Colour (follows the layer)' : 'Colour',
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size + 16, height: size + 16),
      onPressed: () async {
        final choice = await showElementColorDialog(
          context,
          title: title,
          current: current,
          following: colorArgb == null,
          layerColor: base,
          shadeIndex: colorShade,
        );
        if (choice == null) return; // cancelled
        await ref
            .read(repositoryProvider)
            .setElementColor(kind, id, choice.argb);
      },
      icon: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: current,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
      ),
    );
  }
}
