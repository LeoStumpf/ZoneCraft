import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
