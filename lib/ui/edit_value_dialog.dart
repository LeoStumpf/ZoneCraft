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
import 'package:latlong2/latlong.dart' show LatLng;

import '../geo/coords.dart' show formatLatLng, parseLatLng;

/// A changed value, and whether to publish it too.
typedef EditedValue = ({String value, bool publish});

/// Edit one value, then **Save** — or **Save & publish…** when [canPublish],
/// which only saves first and then opens the publish sheet, so nothing leaves
/// the device without that sheet's own Send.
///
/// The field has a **clear** button: a coordinate pair is long, and the
/// usual thing to do with the old one is replace it whole with one pasted
/// from somewhere else.
class EditValueDialog extends StatefulWidget {
  const EditValueDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.hint,
    required this.validate,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
    this.canPublish = true,
  });

  final String title;
  final String initial;
  final String hint;
  final String? Function(String) validate;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final bool canPublish;

  @override
  State<EditValueDialog> createState() => _EditValueDialogState();
}

class _EditValueDialogState extends State<EditValueDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done({required bool publish}) {
    if (widget.validate(_text.text) != null) return;
    Navigator.pop<EditedValue>(context, (value: _text.text, publish: publish));
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.validate(_text.text);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: widget.keyboard,
        textCapitalization: widget.capitalization,
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: error,
          suffixIcon: _text.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(_text.clear),
                ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _done(publish: false),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.canPublish)
          OutlinedButton(
            onPressed: error == null ? () => _done(publish: true) : null,
            child: const Text('Save & publish…'),
          ),
        FilledButton(
          onPressed: error == null ? () => _done(publish: false) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Asks for a position, starting from [lat]/[lng]. Null on Cancel.
Future<({LatLng at, bool publish})?> showPositionDialog(
  BuildContext context, {
  required double lat,
  required double lng,
  String title = 'Position',
  bool canPublish = false,
}) async {
  final answer = await showDialog<EditedValue>(
    context: context,
    builder: (_) => EditValueDialog(
      title: title,
      initial: formatLatLng(lat, lng),
      hint: 'lat, lng — e.g. 48.137, 11.575',
      keyboard: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      canPublish: canPublish,
      validate: (t) =>
          parseLatLng(t) == null ? 'Not a position — try 48.137, 11.575' : null,
    ),
  );
  if (answer == null) return null;
  return (at: parseLatLng(answer.value)!, publish: answer.publish);
}
