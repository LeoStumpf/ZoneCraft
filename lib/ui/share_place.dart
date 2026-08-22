import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;

import '../data/shared_point.dart';
import 'editor_sheet.dart';

/// Asks for a pasted position and parses it.
///
/// The field starts pre-filled from the clipboard, because the one thing the
/// user certainly just did is copy a message. Everything
/// [decodeSharedPointLink] accepts works here — a `zonecraft://` link, a
/// `geo:` URI, an OpenStreetMap link, a bare coordinate, or the whole chat
/// message with the words still around it.
Future<SharedPoint?> showPastePlaceDialog(BuildContext context) async {
  final clip = await Clipboard.getData('text/plain');
  if (!context.mounted) return null;
  return showDialog<SharedPoint>(
    context: context,
    builder: (ctx) => _PastePlaceDialog(initialText: clip?.text ?? ''),
  );
}

/// The controller lives in the dialog's own [State], not in the caller.
///
/// Disposing one right after `await showDialog(...)` looks harmless and is not:
/// the route is still animating out, the `TextField` still depends on the
/// controller, and the framework asserts `_dependents.isEmpty` when the element
/// goes. Owning it here means it is disposed when the widget really is gone.
class _PastePlaceDialog extends StatefulWidget {
  const _PastePlaceDialog({required this.initialText});
  final String initialText;

  @override
  State<_PastePlaceDialog> createState() => _PastePlaceDialogState();
}

class _PastePlaceDialogState extends State<_PastePlaceDialog> {
  late final TextEditingController _controller;
  SharedPoint? _parsed;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _parsed = decodeSharedPointLink(widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = _parsed;
    return AlertDialog(
      title: const Text('Open a shared place'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Paste a link, a message or a coordinate',
              isDense: true,
            ),
            onChanged: (t) =>
                setState(() => _parsed = decodeSharedPointLink(t)),
          ),
          const SizedBox(height: 12),
          // A live readout rather than an error on submit: it says which
          // coordinate was found in a message that has words around it, so a
          // wrong pick is visible before anything happens.
          Text(
            point == null
                ? 'No coordinate found yet'
                : [
                    if (point.name != null) point.name!,
                    point.coordText,
                  ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: point == null ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: point == null ? null : () => Navigator.pop(context, point),
          child: const Text('Show it'),
        ),
      ],
    );
  }
}

/// The docked sheet a received position shows: what arrived, and the two things
/// that can be done with it.
///
/// Nothing has been written to the database at this point — [onKeep] is what
/// writes, and Dismiss leaves no trace. That is the whole reason a shared point
/// is a provider value rather than a row.
class ReceivedPlaceSheet extends StatelessWidget {
  const ReceivedPlaceSheet({
    super.key,
    required this.point,
    required this.onKeep,
    required this.onDismiss,
  });

  final SharedPoint point;
  final VoidCallback onKeep;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorSheet(
      children: [
        Row(
          children: [
            const Icon(Icons.place_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                point.name ?? 'Shared place',
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
          ],
        ),
        Text(point.coordText, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Nothing has been saved. Add it to a layer to keep it.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onKeep,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add to layer…'),
          ),
        ),
      ],
    );
  }
}


/// Asks for an optional name before sharing [point].
///
/// Returns null when cancelled, [point] unchanged when skipped, and a renamed
/// copy otherwise. Naming is offered because a bare pair of numbers in a chat
/// is unreadable a day later — but Skip is one tap, so it never blocks sending.
Future<SharedPoint?> showShareNameDialog(
  BuildContext context,
  SharedPoint point,
) =>
    showDialog<SharedPoint>(
      context: context,
      builder: (ctx) => _ShareNameDialog(point: point),
    );

class _ShareNameDialog extends StatefulWidget {
  const _ShareNameDialog({required this.point});
  final SharedPoint point;

  @override
  State<_ShareNameDialog> createState() => _ShareNameDialogState();
}

class _ShareNameDialogState extends State<_ShareNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.point.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SharedPoint _named(String raw) =>
      SharedPoint.named(widget.point.lat, widget.point.lng, raw) ??
      widget.point;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share this place'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.point.coordText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              hintText: 'e.g. the meeting point',
              isDense: true,
            ),
            onSubmitted: (v) => Navigator.pop(context, _named(v)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, widget.point),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _named(_controller.text)),
          child: const Text('Share'),
        ),
      ],
    );
  }
}
