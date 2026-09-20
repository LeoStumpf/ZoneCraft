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
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../data/error_log.dart';
import 'theme.dart';

/// What Flutter paints when a `build()` throws.
///
/// The default [ErrorWidget] is a red band with the message in debug, and in
/// **release** a featureless grey rectangle — no text, no cause, no way out.
/// Since `MapScreen` is the app's `home:`, that grey rectangle *is* the app.
/// The user's only move is to force-quit, and with no telemetry by design,
/// nobody ever learns why.
///
/// This replaces it with something a person can act on: what happened, that
/// their data is intact, and a Copy button so the message can reach the author
/// by the one route that does not involve the app phoning home.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget(this.details, {super.key});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // This widget stands in for one that just failed, and may be mounted
    // *inside* the broken subtree — so it cannot assume a Scaffold, a
    // Directionality or a usable Theme above it. It provides its own.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: OsmPalette.land,
        child: SafeArea(
          child: _ErrorBody(
            title: 'Something went wrong',
            message: details.exceptionAsString(),
            report: () {
              ErrorLog.instance.record(
                details.exception,
                details.stack,
                context: 'Drawing',
              );
              return ErrorLog.instance.asReport();
            },
          ),
        ),
      ),
    );
  }
}

/// The blocking screen shown when the database itself could not be read.
///
/// Distinct from [AppErrorWidget] because the reassurance is different and it
/// is the more frightening failure: the map is empty, and the user's instinct
/// is that their work is gone. It is almost never gone — so that sentence goes
/// first, above the technical detail.
class DataUnavailableScreen extends StatelessWidget {
  const DataUnavailableScreen({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _ErrorBody(
          title: 'Your map could not be loaded',
          lead:
              'Your data has not been deleted. ZoneCraft could not open its '
              'database this time — the file is still on your device.\n\n'
              'Please do not reinstall or use "Clear all data": both would '
              'remove what is still there. Send the details below instead.',
          message: error.toString(),
          report: ErrorLog.instance.asReport,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

/// Shown once, at the launch after the database had to be set aside.
///
/// The user's map is not on screen and they are about to start a new one on top
/// of it — so this says plainly that the old file still exists, where it is, and
/// that reinstalling would be the one action that finally destroys it.
class DatabaseRecoveredScreen extends StatelessWidget {
  const DatabaseRecoveredScreen({
    required this.onContinue,
    this.quarantinedPath,
    this.error,
    super.key,
  });

  final String? quarantinedPath;
  final Object? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = quarantinedPath;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Icon(
              Icons.restore_page_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'ZoneCraft started with an empty map',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              path == null
                  ? 'Your saved map could not be opened this time, so ZoneCraft '
                        'has started fresh. The old data was left where it was.'
                  : 'Your saved map could not be opened this time. Rather than '
                        'delete it, ZoneCraft moved it aside and started fresh — '
                        'so what you see now is empty, but your old file still '
                        'exists.',
              style: theme.textTheme.bodyMedium,
            ),
            if (path != null) ...[
              const SizedBox(height: 16),
              Text('It is here:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                path,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Please do not reinstall the app — that would delete the old file '
              'for good. Send the details below to $kContactEmail and it may '
              'well be recoverable.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '${ErrorLog.instance.asReport()}\n\n'
                        'Old database: ${path ?? "not moved"}',
                  ),
                );
                messenger?.showSnackBar(
                  const SnackBar(content: Text('Details copied')),
                );
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy details'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onContinue,
              child: const Text('Continue with an empty map'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.title,
    required this.message,
    required this.report,
    this.lead,
    this.onRetry,
  });

  final String title;
  final String? lead;
  final String message;
  final String Function() report;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Styled without Theme.of: see AppErrorWidget — there may not be one.
    const ink = kMapInk;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        const Icon(Icons.error_outline, size: 40, color: OsmPalette.health),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          lead ??
              'ZoneCraft hit a problem it could not recover from. Your saved '
                  'layers are on your device and have not been touched.',
          style: const TextStyle(fontSize: 14, color: ink, height: 1.4),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: zoneCraftLight.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(kRadiusMedium),
          ),
          child: SelectableText(
            message,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: ink,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Builder(
          builder: (context) => FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report()));
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(const SnackBar(content: Text('Details copied')));
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy details'),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Paste those details to $kContactEmail, or open an issue at '
          '$kIssuesUrl. Nothing is sent automatically — ZoneCraft has no '
          'telemetry and this text leaves your device only if you send it.',
          style: const TextStyle(fontSize: 12, color: kMapInkSoft, height: 1.4),
        ),
      ],
    );
  }
}

/// The in-memory log, as a screen. Reached from About.
class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = ErrorLog.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent errors'),
        actions: [
          if (!log.isEmpty)
            IconButton(
              tooltip: 'Copy all',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: log.asReport()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Details copied')));
              },
            ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: log.revision,
        builder: (context, _, _) {
          final entries = log.entries;
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nothing has gone wrong since the app started.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 24),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  'These are kept in memory for this run only. They are never '
                  'written to disk and never sent anywhere — copy one into an '
                  'email or an issue if you want the author to see it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                );
              }
              final e = entries[i - 1];
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(e.summary, style: theme.textTheme.bodyMedium),
                subtitle: Text(
                  e.when.toIso8601String(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                children: [
                  SelectableText(
                    e.asReport(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
