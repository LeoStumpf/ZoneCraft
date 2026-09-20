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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../app_info.dart';
import '../data/osm_notes.dart';
import '../data/overpass_client.dart' show overpassEndpoints;
import '../data/place_search.dart' show defaultNominatimHost;
import '../data/tile_source.dart';
import 'external_link.dart';

/// What ZoneCraft asks of other people's servers, and how to reach its author.
///
/// The app has no backend. Everything on the map arrives from four services run
/// by other people — three of them on donations — and every one of those has a
/// published policy saying what a client may and may not do. That is not a
/// footnote: it is why the map will not pre-download, why an import takes a
/// minute, and why a search happens on submit rather than as you type. A user
/// who does not know that reads all three as bugs.
///
/// The second audience is the operators themselves. They identify a misbehaving
/// client by its `User-Agent` and then need a human to write to; when they
/// cannot find one, the remedy left is to block it. So this page shows the
/// exact User-Agent their logs will contain, next to an address that answers.
class ServicePolicyScreen extends StatefulWidget {
  const ServicePolicyScreen({super.key});

  @override
  State<ServicePolicyScreen> createState() => _ServicePolicyScreenState();
}

class _ServicePolicyScreenState extends State<ServicePolicyScreen> {
  /// Whether this device can open an external URL at all. Probed once, as on
  /// the About screen: without the manifest's `<queries>` entry `canLaunchUrl`
  /// reports no handler, and a link that silently does nothing is worse than
  /// plain text.
  bool _canOpenLinks = false;

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
  }

  Future<void> _probe() async {
    var can = false;
    try {
      can = await canLaunchExternalUrl(Uri.parse('https://openstreetmap.org'));
    // With no platform implementation at all (a test host, a desktop build)
    // canLaunchUrl throws rather than answering false.
    // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Links stay plain, copyable text.
    }
    if (mounted && can) setState(() => _canOpenLinks = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = TileSource.configured;
    final tileHost = Uri.tryParse(tiles.urlTemplate)?.host ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Servers and limits')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'ZoneCraft has no server of its own.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Everything you draw stays on this device. Everything on the map '
            'underneath it comes from services other people run — three of them '
            'on donations, with published rules about what an app like this may '
            'ask for. Those rules are the reason behind several things that '
            'otherwise look broken, so they are written out here rather than '
            'left to be guessed at.',
            style: theme.textTheme.bodyMedium,
          ),

          _Heading('What the app asks for'),
          _Rule(
            icon: Icons.touch_app_outlined,
            title: 'Only when you ask',
            body: 'No request is ever made on a timer, in the background, or '
                'because the map moved. An import runs once, when you start '
                'it, and the result is stored here for good — it is never '
                'refreshed behind your back.',
          ),
          _Rule(
            icon: Icons.speed_outlined,
            title: 'One request per second, at most',
            body: 'Searches and imports queue behind a pacer rather than going '
                'out together, and a repeated search is answered from memory '
                'without asking again. There is deliberately no '
                'search-as-you-type: the geocoder’s policy forbids it.',
          ),
          _Rule(
            icon: Icons.download_outlined,
            title: tiles.allowsPrefetch
                ? 'Offline downloading is on for this build'
                : 'The map is never downloaded ahead of you',
            body: tiles.allowsPrefetch
                ? 'This build was pointed at a tile provider whose terms permit '
                    'fetching ahead, so the offline download exists. On the '
                    'default build it does not.'
                : 'OpenStreetMap defines bulk downloading as any fetching of '
                    'tiles you are not looking at — so there is no small, '
                    'polite amount of it, and there is no "save this area for '
                    'offline" button. Tiles you did look at are kept, which '
                    'their policy asks for.',
          ),
          _Rule(
            icon: Icons.badge_outlined,
            title: 'The app says who it is',
            body: 'Every request carries a name and version, so an operator '
                'seeing a problem can tell which app and which release caused '
                'it — and can find someone to tell.',
          ),
          _Rule(
            icon: Icons.volunteer_activism_outlined,
            title: 'One thing the app can send, and only on a press',
            body: 'If you correct an imported point, the app offers to pass '
                'the correction on as an OpenStreetMap note. You write the '
                'text, you press Send, and that is the only circumstance in '
                'which anything you typed leaves this device. Nothing is ever '
                'sent in a batch, on a timer, or when a connection comes back '
                '— notes are meant to be one person telling another, and the '
                'project asks apps not to generate them automatically.',
          ),

          _Heading('Who is asked for what'),
          _Who(
            icon: Icons.volunteer_activism_outlined,
            what: 'Corrections you send',
            who: osmApiHost,
            note: osmApiIsLive
                ? 'The OpenStreetMap database itself. A note is public and '
                    'permanent, and an anonymous one is not linked to you — '
                    'which also means nobody can write back, so the outbox '
                    'keeps a link to each note for you to follow.'
                : 'This build is pointed at a test server rather than at '
                    'OpenStreetMap, so nothing sent from it reaches real '
                    'mappers.',
            canOpen: _canOpenLinks,
          ),
          _Who(
            icon: Icons.map_outlined,
            what: 'The base map',
            who: tileHost.isEmpty ? tiles.urlTemplate : tileHost,
            note: tiles.isCommunityOsm
                ? 'OpenStreetMap’s own servers, run on donations. Map data '
                    'and tiles © OpenStreetMap contributors (ODbL).'
                : 'A commercial provider, so OpenStreetMap’s donated '
                    'servers are not carrying this app’s map traffic. '
                    'Underlying data is still © OpenStreetMap contributors '
                    '(ODbL).',
            canOpen: _canOpenLinks,
          ),
          _Who(
            icon: Icons.travel_explore,
            what: 'Imports: places, stations, borders',
            who: Uri.tryParse(overpassEndpoints.first)?.host ?? '',
            note: 'Overpass, run by volunteers. Their documentation says an app '
                'that leans on the public instances is what running your own '
                'is for — which is why a border import is capped, one-shot, '
                'and stored here forever afterwards.',
            canOpen: _canOpenLinks,
          ),
          _Who(
            icon: Icons.search,
            what: 'Finding a place by name',
            who: defaultNominatimHost,
            note: 'Nominatim, OpenStreetMap’s geocoder. Capped at one '
                'request per second with results cached, and no '
                'search-as-you-type, which its policy forbids outright.',
            canOpen: _canOpenLinks,
          ),
          _Who(
            icon: Icons.terrain,
            what: 'Ground elevation',
            who: 's3.amazonaws.com/elevation-tiles-prod',
            note: 'A public open dataset. SRTM, 3DEP and GMTED2010 courtesy of '
                'the U.S. Geological Survey; ETOPO1 courtesy of NOAA.',
            canOpen: _canOpenLinks,
          ),

          _Heading('If you would rather not use them'),
          Text(
            'Settings → Data sources points the map, the imports and the '
            'search at servers of your own. Running an Overpass instance is the '
            'one that genuinely helps: it is the heaviest thing this app asks '
            'of anybody, and its own maintainers recommend exactly that. If you '
            'would like to host one for other people to use, please get in '
            'touch — that offer is worth more than a donation.',
            style: theme.textTheme.bodyMedium,
          ),

          _Heading('If you run one of these services'),
          Text(
            'If ZoneCraft is causing you trouble, please write rather than '
            'block — an email gets a fast answer, and the app can be changed or '
            'pointed elsewhere in a release. Its requests identify themselves '
            'in your logs as:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const _CopyableCode(
            label: 'User-Agent',
            value: zoneCraftUserAgent,
          ),
          const SizedBox(height: 12),
          _CopyableCode(
            label: 'Email',
            value: kContactEmail,
            onOpen: _canOpenLinks
                ? () => unawaited(openExternalUrl(
                      Uri(scheme: 'mailto', path: kContactEmail),
                      context: context,
                      failureMessage: 'No email app — address copied instead.',
                      onFailure: () => _copy(kContactEmail),
                    ))
                : null,
          ),
          const SizedBox(height: 12),
          _CopyableCode(
            label: 'Issue tracker',
            value: kIssuesUrl,
            onOpen: _canOpenLinks
                ? () => unawaited(
                      openExternalUrl(Uri.parse(kIssuesUrl), context: context),
                    )
                : null,
          ),
        ],
      ),
    );
  }

  void _copy(String value) {
    unawaited(Clipboard.setData(ClipboardData(text: value)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied')));
  }
}

/// A section heading, with the rule above it.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 48),
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
        ],
      );
}

/// One thing the app does on purpose, stated as the claim then the reason.
class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One service: what it provides, whose machine it is, and on what terms.
class _Who extends StatelessWidget {
  const _Who({
    required this.icon,
    required this.what,
    required this.who,
    required this.note,
    required this.canOpen,
  });

  final IconData icon;
  final String what;
  final String who;
  final String note;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(what, style: theme.textTheme.bodyLarge),
                if (who.isNotEmpty)
                  _HostLink(who, canOpen: canOpen),
                const SizedBox(height: 2),
                Text(note, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A host, as a link where one can be opened and plain text where it cannot.
class _HostLink extends StatelessWidget {
  const _HostLink(this.host, {required this.canOpen});

  final String host;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      decoration: canOpen ? TextDecoration.underline : null,
      decorationColor: theme.colorScheme.primary,
    );
    if (!canOpen) return SelectableText(host, style: style);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => unawaited(openExternalUrl(
          Uri.parse('https://$host'),
          context: context,
          failureMessage: "Couldn't open $host",
        )),
        child: Text(host, style: style),
      ),
    );
  }
}

/// A value an operator needs to be able to take away with them.
///
/// Always copyable, and openable only when the device can actually handle the
/// scheme: the whole point of this block is that somebody trying to reach a
/// human does not hit a dead button.
class _CopyableCode extends StatelessWidget {
  const _CopyableCode({
    required this.label,
    required this.value,
    this.onOpen,
  });

  final String label;
  final String value;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  SelectableText(
                    value,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            if (onOpen != null)
              IconButton(
                tooltip: 'Open',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: onOpen,
              ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: value)));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
