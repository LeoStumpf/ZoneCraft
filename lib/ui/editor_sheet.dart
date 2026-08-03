import 'package:flutter/material.dart';

import '../data/database.dart';

/// Shared chrome for the six docked object editors.
///
/// All six grew the same shell independently — `Material > SafeArea > Padding >
/// Column` — and so grew the same two failures at a large system font size,
/// found on a Pixel 4a at Settings → Display → Font size *Largest* (1.3x):
///
/// * **The body was chopped.** A `Column` in a bottom sheet takes the height it
///   wants and is clipped by whatever is left. At 1.0x everything happened to
///   fit; at 1.3x the freehand-area editor was cut mid-"Point 4", putting *Add
///   point*, *Offset* and *Label* past the bottom of the screen with no way to
///   reach them. Nothing overflowed loudly — no yellow-and-black stripes —
///   because clipping is silent, which is why this survived to now.
/// * **The layer picker wrapped and clipped.** `DropdownButton` lays its
///   selected item out at a fixed interactive height; scaled-up text wraps to a
///   second line and the row cuts it in half ("Alts / tadt" for a layer named
///   "Altstadt").
///
/// [EditorSheet] is the fix for the first: cap the sheet at a fraction of the
/// screen and scroll the overflow, so the content is always reachable at any
/// text scale, in landscape, and with the keyboard up. [EditorLayerPicker] is
/// the fix for the second.
///
/// The cap is deliberately a *fraction of the viewport* rather than a pixel
/// constant: the sheet has to leave the map usable, and "usable" scales with
/// the screen, not with the font.
class EditorSheet extends StatelessWidget {
  const EditorSheet({super.key, required this.children});

  /// The editor's rows, laid out in a start-aligned column.
  final List<Widget> children;

  /// Most of the screen the sheet may take before it starts scrolling. Leaves
  /// the map visible above it, which is the point of a *docked* editor — you
  /// are editing a thing you need to see.
  static const double maxHeightFraction = 0.6;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "which layer does this object belong to" dropdown in every editor's
/// title row.
///
/// Takes the row's slack and **ellipsises on one line**. Both halves matter: a
/// layer named after an imported border ("Ludwigsvorstadt-Isarvorstadt") is far
/// wider than the row, and without `maxLines: 1` a scaled-up font wraps instead
/// of ellipsising — which a `DropdownButton`'s fixed-height selected item then
/// slices through the middle of.
class EditorLayerPicker extends StatelessWidget {
  const EditorLayerPicker({
    super.key,
    required this.layers,
    required this.selectedId,
    required this.onChanged,
  });

  /// The layers of this editor's own type.
  final List<Layer> layers;

  /// The object's current layer id; shows the hint when it isn't in [layers].
  final String selectedId;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: DropdownButton<String>(
        isExpanded: true,
        value: layers.any((l) => l.id == selectedId) ? selectedId : null,
        hint: const Text('Layer'),
        // The closed-state label. Without this the *menu* items' own layout
        // (which may wrap freely) is reused for the button, and that is what
        // gets clipped.
        selectedItemBuilder: (context) => [
          for (final l in layers)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
        ],
        items: [
          for (final l in layers)
            DropdownMenuItem(
              value: l.id,
              child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// A pixel measurement that was chosen against text, scaled to the system font
/// size.
///
/// Hard-coded pixels around text are the other half of the clipping problem.
/// A 220 px point list is three rows at 1.0x and barely one and a half at 1.3x;
/// a 130 px number field fits "Offset (m)" and its helper at 1.0x and
/// ellipsises both at 1.3x. Passing the value that was right at the default
/// scale through here keeps the *content* that fits constant instead of the
/// box.
double scaledPx(BuildContext context, double atDefaultScale) =>
    MediaQuery.textScalerOf(context).scale(atDefaultScale);
