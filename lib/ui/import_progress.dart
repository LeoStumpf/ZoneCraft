import 'dart:async';

import 'package:flutter/material.dart';

import '../data/overpass_client.dart';

/// The progress dialog shared by the Overpass-backed imports (transit, borders).
///
/// An import can legitimately take two minutes — a slow public instance answers
/// in 60–160 s, and a big answer takes a while to arrive after that. A fixed
/// "Importing…" for that long is indistinguishable from a hang, so this shows
/// **what is happening, where, and for how long**: the stage, which instance is
/// being asked (and how far down the failover list we are), bytes as they land,
/// and an elapsed clock that keeps moving even while Overpass is silent.

/// A handle on an open progress dialog: push new text into it, then close it.
class ImportProgress {
  ImportProgress._(this._message, this._close);

  final ValueNotifier<String> _message;
  final void Function() _close;
  var _closed = false;

  /// Replaces the message shown. Safe after [close] (a no-op).
  void update(String message) {
    if (_closed) return;
    _message.value = message;
  }

  /// Reports an Overpass request's progress in words.
  void report(OverpassProgress p) => update(describeOverpassProgress(p));

  /// Idempotent: the caller closes on every exit path, including `finally`.
  void close() {
    if (_closed) return;
    _closed = true;
    _close();
  }
}

/// One line describing where an Overpass request has got to.
///
/// Pure, so the wording is testable without a widget test.
String describeOverpassProgress(OverpassProgress p) {
  // Only name the position in the failover list once we've actually moved on —
  // "instance 1 of 3" on the happy path is noise about a thing that hasn't
  // happened.
  final where = p.endpointIndex > 1
      ? '${p.host} (instance ${p.endpointIndex} of ${p.endpointCount})'
      : p.host;
  final retry = p.attempt > 1 ? ', try ${p.attempt}' : '';
  switch (p.stage) {
    case OverpassStage.contacting:
      // Named as a *wait*, not as progress, and bounded. This phase can sit
      // still for over a minute on a slow instance, and "is this downloading or
      // is it just going to time out?" is the only question worth answering
      // while it does — so say that nothing has arrived, and when we give up.
      final giveUp = p.timeout.inSeconds;
      return 'Waiting for a reply from $where$retry — nothing yet '
          '(gives up after ${giveUp < 60 ? '${giveUp}s' : '${giveUp ~/ 60}m'})';
    case OverpassStage.downloading:
      final got = formatBytes(p.bytes);
      final total = p.totalBytes;
      return total == null || total <= 0
          ? 'Downloading from ${p.host} — $got'
          : 'Downloading from ${p.host} — $got of ${formatBytes(total)}';
    case OverpassStage.processing:
      return 'Reading ${formatBytes(p.bytes)} from ${p.host}…';
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Opens the dialog and returns its handle.
///
/// `barrierDismissible: false` alone does **not** stop the Android back
/// button — an earlier version could be dismissed that way, after which the
/// caller's untargeted `Navigator.pop()` popped the map screen itself. The
/// `PopScope` closes that hole, and the caller pops via the returned handle
/// rather than the ambient context.
///
/// [onCancel] adds a Cancel button and points the back gesture at it. The route
/// still never pops itself — cancelling asks the *import* to stop, and the
/// caller closes this dialog when it has, so the two can't get out of step.
ImportProgress showImportProgress(
  BuildContext context, {
  required String title,
  required String message,
  VoidCallback? onCancel,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final notifier = ValueNotifier<String>(message);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onCancel?.call();
      },
      child: _ImportProgressDialog(
        title: title,
        message: notifier,
        onCancel: onCancel,
      ),
    ),
  );
  return ImportProgress._(notifier, navigator.pop);
}

class _ImportProgressDialog extends StatefulWidget {
  const _ImportProgressDialog({
    required this.title,
    required this.message,
    this.onCancel,
  });

  final String title;
  final ValueNotifier<String> message;
  final VoidCallback? onCancel;

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  final _elapsed = Stopwatch()..start();
  Timer? _tick;

  /// Cancelling isn't instant — a request already on the wire has to be let go
  /// of, and a `compute()` isolate has to finish. Saying so beats a button that
  /// stays live and looks ignored.
  var _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    // The one thing guaranteed to keep moving. While a slow instance sits on
    // the request there are no bytes and no stage change for a minute, and a
    // frozen dialog is what "it just hangs" actually means.
    _tick = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = _elapsed.elapsed.inSeconds;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: widget.message,
            builder: (_, message, _) =>
                Text(message, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 4),
          Text(
            seconds < 60
                ? '${seconds}s elapsed'
                : '${seconds ~/ 60}m ${seconds % 60}s elapsed',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
      actions: widget.onCancel == null
          ? null
          : [
              TextButton(
                onPressed: _cancelRequested
                    ? null
                    : () {
                        setState(() => _cancelRequested = true);
                        widget.onCancel!.call();
                      },
                child: Text(_cancelRequested ? 'Cancelling…' : 'Cancel'),
              ),
            ],
    );
  }
}
