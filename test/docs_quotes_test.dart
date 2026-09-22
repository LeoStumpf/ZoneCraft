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

// The docs are published, not merely written.
//
// `docs/` is the source of the GitHub wiki (`.github/workflows/wiki.yml`
// pushes it). A wiki is a separate git repository, so before the move nothing
// in this project could see the docs at all — and `docs/Layer-Types.md` quotes
// all seven Add-layer subtitles **word for word**. A string edit in
// `layer_actions.dart` therefore silently makes a published page wrong, which
// is precisely what happened the day the welcome copy was rewritten.
//
// These tests are the whole reason the docs moved into the repository.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/ui/layer_actions.dart';

/// Markdown wraps, the Dart literal does not — compare on words, not columns.
String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  final docsDir = Directory('docs');

  test('docs/ is where the wiki comes from', () {
    expect(
      docsDir.existsSync(),
      isTrue,
      reason:
          'docs/ holds the published wiki pages; see .github/workflows/wiki.yml',
    );
  });

  // The coupling that justifies all of this. `Layer-Types.md` reproduces each
  // subtitle verbatim, in italics, before explaining the type in more depth.
  test('Layer-Types.md quotes every Add-layer subtitle verbatim', () {
    final page = _flat(File('docs/Layer-Types.md').readAsStringSync());

    expect(kLayerTypeChoices, hasLength(7));
    for (final choice in kLayerTypeChoices) {
      final subtitle = choice.subtitle;
      if (subtitle == null) continue;
      expect(
        page.contains(_flat(subtitle)),
        isTrue,
        reason:
            'docs/Layer-Types.md no longer quotes the ${choice.label} subtitle.\n'
            'It must contain, word for word:\n  $subtitle\n'
            'Change the page in the same commit as the string, or the wiki '
            'publishes something the app does not say.',
      );
    }
  });

  // A renamed page breaks every link to it, and the break is invisible from
  // here: it only shows once the wiki is published. A target carrying `/` or
  // `:` is an ordinary URL (docs/ links to PRIVACY.md on github.com) and is
  // left alone — as the publish step's rewrite also leaves it alone.
  test('every link between doc pages points at a page that exists', () {
    final link = RegExp(r'\]\(([^):/\s]+)\.md(#[^)]*)?\)');
    final broken = <String>[];

    for (final file in docsDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.md')) continue;
      for (final m in link.allMatches(file.readAsStringSync())) {
        final target = File('docs/${m.group(1)}.md');
        if (!target.existsSync()) {
          broken.add('${file.uri.pathSegments.last} -> ${m.group(1)}.md');
        }
      }
    }

    expect(broken, isEmpty, reason: 'dead links between doc pages');
  });

  // Home.md teaches the same loop the first-run sheet does. The two are not
  // compared character by character on purpose: the page adds emphasis and
  // markdown punctuation, so a verbatim assertion would be false precision and
  // would fail on a purely typographic edit. What must not drift is which two
  // controls the example teaches, and that there are still three steps.
  test('Home.md still teaches the three-step example', () {
    final home = File('docs/Home.md').readAsStringSync();
    final example = home.substring(home.indexOf('## For example'));

    expect(RegExp(r'^1\.', multiLine: true).hasMatch(example), isTrue);
    expect(RegExp(r'^2\.', multiLine: true).hasMatch(example), isTrue);
    expect(RegExp(r'^3\.', multiLine: true).hasMatch(example), isTrue);
    expect(example.toLowerCase(), contains('circle'));
    expect(example, contains('Fill outside'));
  });
}
