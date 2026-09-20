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

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../app_info.dart';

/// The last few errors this run hit, kept **in memory only**, so a user who
/// sees something go wrong has something to paste into a bug report.
///
/// ZoneCraft sends no telemetry and is not going to start: see `main.dart`.
/// That decision is worth keeping, but it left the developer *and the user*
/// with nothing at all — a release build printed its stack traces to a
/// `stderr` nobody will ever read, and an exception thrown inside a `build()`
/// rendered Flutter's default [ErrorWidget], which in release is a featureless
/// grey rectangle with no text and no way out.
///
/// This is the other way to get a bug report: show the error, let the user copy
/// it, let them mail it if they choose to. Three properties make that honest —
///
/// * it is **never written to disk**, so it cannot outlive the process, cannot
///   be picked up by a backup, and adds nothing to the Play data-safety form;
/// * it is **bounded** ([maxEntries]), so a crash loop cannot grow it; and
/// * nothing sends it anywhere. The only way an entry leaves the device is a
///   person pressing Copy and pasting it somewhere themselves.
class ErrorLog {
  ErrorLog._();

  /// The one instance. Errors arrive from `FlutterError.onError` and
  /// `PlatformDispatcher.onError`, which are process-wide themselves.
  static final ErrorLog instance = ErrorLog._();

  /// Enough to cover a cascade (one fault usually reports several times) and
  /// still be readable when pasted into an email.
  static const int maxEntries = 20;

  final Queue<ErrorLogEntry> _entries = Queue<ErrorLogEntry>();

  /// Bumped on every record so a widget can rebuild without polling.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Newest first — which is the order somebody reading a bug report wants.
  List<ErrorLogEntry> get entries => _entries.toList(growable: false);

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;

  void record(Object error, StackTrace? stack, {String? context}) {
    _entries.addFirst(
      ErrorLogEntry(
        when: DateTime.now(),
        error: error.toString(),
        stack: stack?.toString(),
        context: context,
      ),
    );
    while (_entries.length > maxEntries) {
      _entries.removeLast();
    }
    revision.value++;
  }

  void clear() {
    _entries.clear();
    revision.value++;
  }

  /// The whole log as one block of text, for the Copy button.
  ///
  /// It leads with the app version and the platform because a report without
  /// them costs a round-trip to ask, and both are already public knowledge
  /// about the build — nothing here identifies the person.
  String asReport() {
    final b = StringBuffer()
      ..writeln('ZoneCraft $kAppVersion')
      ..writeln('Platform: ${defaultTargetPlatform.name}')
      ..writeln('Errors this run: ${_entries.length}')
      ..writeln();
    for (final e in _entries) {
      b.writeln(e.asReport());
      b.writeln();
    }
    return b.toString().trimRight();
  }
}

/// One recorded failure.
@immutable
class ErrorLogEntry {
  const ErrorLogEntry({
    required this.when,
    required this.error,
    this.stack,
    this.context,
  });

  final DateTime when;
  final String error;
  final String? stack;

  /// What the app was doing, when the call site knew — "Saving the circle",
  /// "Importing borders". Absent for errors caught by the global hooks, which
  /// only ever see the throw.
  final String? context;

  /// A one-line summary for a list row.
  String get summary {
    final firstLine = error.split('\n').first.trim();
    return context == null ? firstLine : '$context — $firstLine';
  }

  String asReport() {
    final b = StringBuffer()
      ..writeln(
        '[${when.toIso8601String()}]'
        '${context == null ? '' : ' $context'}',
      )
      ..writeln(error);
    final s = stack;
    if (s != null && s.isNotEmpty) {
      // A full Flutter stack is dozens of frames of framework plumbing; the
      // top of it is where the fault is and all a report needs.
      final lines = s.trimRight().split('\n');
      b.writeln(lines.take(12).join('\n'));
      if (lines.length > 12) b.writeln('… ${lines.length - 12} more frames');
    }
    return b.toString().trimRight();
  }
}

/// Shows a one-line failure to the user, when the app has a way to.
///
/// Set once, by `main.dart`, to the root [ScaffoldMessenger]. It lives here as
/// a hook rather than an import so that `data/` keeps knowing nothing about
/// widgets; a test leaves it null and reads [ErrorLog] directly.
void Function(String message)? failureNotifier;

/// Runs [future] and records a failure instead of letting it vanish.
///
/// The repository writes fired from the editors are deliberately not awaited —
/// the UI is optimistic and a slider tick must not wait on SQLite. The cost was
/// that a rejected write (a full disk, `SQLITE_BUSY`, a constraint violation)
/// became an unhandled async error: printed, discarded, and on screen an edit
/// that looked saved until the next stream emission took it away. "It randomly
/// loses my edits" is the bug report that follows, with nothing to look at.
///
/// [what] is shown to the user, so it names the thing they did, not the table.
void logAsyncFailure(
  Future<void> future,
  String what, {
  void Function(String message)? onError,
}) {
  unawaited(
    future.catchError((Object e, StackTrace s) {
      ErrorLog.instance.record(e, s, context: what);
      final message = '$what failed. Your other changes are unaffected.';
      (onError ?? failureNotifier)?.call(message);
    }),
  );
}
