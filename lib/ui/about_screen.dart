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
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../data/tile_source.dart';

/// What the app is, who it talks to, and which of its behaviours are deliberate.
///
/// The last part is the reason this screen exists. Several things about
/// ZoneCraft look like faults from the outside — an import that takes a minute
/// and then fails, a map that will not pre-download, a border box that matches
/// nothing — and every one of them is a published policy of a donated service
/// being honoured. Saying so here is cheaper than answering it once per user,
/// and it keeps the claims in one place where they can be kept true.
///
/// URLs are tappable and still selectable: every one of them is a claim the
/// user may want to check, and a claim you cannot follow is worth less. Opening
/// them needs `url_launcher` *and* the `https` `<intent>` in the Android
/// manifest's `<queries>` block — since API 30 a package is invisible unless
/// queried for, so without it `canLaunchUrl` reports no browser at all and
/// every link silently does nothing. When there is genuinely nothing to open
/// (a desktop test host, a device with no browser) the row stays selectable
/// text rather than pretending to be a link.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  /// Whether anything on this device can open an `https` URL. Probed once for
  /// the whole screen rather than per row: every link here is `https`, so the
  /// answer is the same for all of them, and six `FutureBuilder`s would flicker
  /// six times for one fact.
  bool _canOpenLinks = false;

  @override
  void initState() {
    super.initState();
    unawaited(_probeLinkSupport());
  }

  Future<void> _probeLinkSupport() async {
    var can = false;
    try {
      can = await canLaunchUrl(Uri.parse('https://openstreetmap.org'));
    // With no platform implementation at all (a test host, a desktop build)
    // canLaunchUrl throws rather than answering false.
    // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // No platform implementation (a test host, a desktop build): links stay
      // plain text, which is what this screen did before they were tappable.
    }
    if (mounted && can) setState(() => _canOpenLinks = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefetches = TileSource.current.allowsPrefetch;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.layers, size: 36, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ZoneCraft', style: theme.textTheme.headlineSmall),
                    Text(
                      'Version $kAppVersion',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(kAppTagline, style: theme.textTheme.bodyMedium),

          _Section(
            'Where the data comes from',
            'Everything is fetched on demand, only when you ask for it. '
                'Nothing is downloaded on a timer, on map movement, or in the '
                'background.',
            children: [
              _Service(
                icon: Icons.map_outlined,
                name: 'OpenStreetMap tiles',
                urls: const ['tile.openstreetmap.org'],
                body: 'The base map. Map data and tiles © OpenStreetMap '
                    'contributors, licensed under the Open Database License '
                    '(ODbL).',
                canOpen: _canOpenLinks,
              ),
              _Service(
                icon: Icons.travel_explore,
                name: 'Overpass API',
                urls: const [
                  'overpass-api.de',
                  'overpass.kumi.systems',
                  'overpass.private.coffee',
                ],
                body: 'Points of interest, transit stations and '
                    'administrative areas, fetched once per import and then '
                    'stored on the device. Three community instances are '
                    'tried in turn, because whichever one is busy is the '
                    'variable.',
                canOpen: _canOpenLinks,
              ),
              _Service(
                icon: Icons.search,
                name: 'Nominatim',
                urls: const ['nominatim.openstreetmap.org'],
                body: 'Finds a place by name when you import a feature such '
                    'as a city border or a river.',
                canOpen: _canOpenLinks,
              ),
              _Service(
                icon: Icons.terrain,
                name: 'AWS Terrain Tiles',
                urls: const ['s3.amazonaws.com/elevation-tiles-prod'],
                body: 'Elevation for height layers and the elevation probe. '
                    'A public open-data set aggregated from SRTM, NED and '
                    'others.',
                canOpen: _canOpenLinks,
              ),
            ],
          ),

          _Section(
            'Known limits',
            'These are deliberate, not faults:',
            children: [
              const _Limit(
                'An import can take a minute, and can fail.',
                'The Overpass instances are donated and often queueing. The '
                    'app waits, retries, and moves to another instance — and '
                    'you can press Cancel at any point. Trying again a minute '
                    'later usually works.',
              ),
              const _Limit(
                'Requests are paced to about one per second.',
                'Both Overpass and Nominatim publish that ceiling. Searching '
                    'happens only when you submit a search, never as you type '
                    '— per-keystroke geocoding is forbidden outright.',
              ),
              _Limit(
                prefetches
                    ? 'Map tiles are cached, and this build may fetch ahead.'
                    : 'The map is never downloaded ahead of what you look at.',
                prefetches
                    ? 'This build is pointed at a tile provider of your own, '
                        'so downloading an area ahead of time is available.'
                    : "OpenStreetMap's tile policy defines bulk downloading "
                        'as any pre-emptive fetching, so there is no compliant '
                        'amount of it. Tiles you have viewed are kept, which '
                        'the policy requires, so revisiting an area works with '
                        'no reception.',
              ),
              const _Limit(
                'Imports are snapshots, and do not refresh.',
                'POIs, stations and borders are fetched once and then belong '
                    'to the device. If the underlying map data has changed, '
                    'delete the import and fetch it again.',
              ),
              const _Limit(
                'A border box has to reach a boundary, not sit inside one.',
                'Overpass matches an area when one of its parts is inside the '
                    'box, so a box drawn wholly within a single district '
                    'matches nothing at all.',
              ),
              const _Limit(
                'Border layers cannot be exported yet.',
                'Every other layer type exports to GeoJSON or KML, from the '
                    'layer menu or from Settings.',
              ),
            ],
          ),

          _Section(
            'Privacy',
            'ZoneCraft has no accounts, no analytics, no crash reporting and '
                'no advertising identifier. Nothing you draw or import leaves '
                'the device unless you export it yourself. The services above '
                'necessarily see the request you make and your IP address, '
                'as any web request would.',
          ),

          _Section(
            'Licence',
            'ZoneCraft is free software: you can redistribute it and modify '
                'it under the terms of the GNU Affero General Public License, '
                'either version 3 or (at your option) any later version. It '
                'comes with absolutely no warranty. The full text ships as '
                'LICENSE in the source repository.',
            children: [
              _Service(
                icon: Icons.balance,
                name: 'GNU AGPL v3 or later',
                urls: const ['www.gnu.org/licenses/agpl-3.0.html'],
                body: 'The AGPL requires that anyone you give the app to can '
                    'get its source under the same terms.',
                canOpen: _canOpenLinks,
              ),
              _Service(
                icon: Icons.code,
                name: 'Source',
                urls: const ['github.com/LeoStumpf/ZoneCraft'],
                body: 'The complete corresponding source, as the licence '
                    'requires.',
                canOpen: _canOpenLinks,
              ),
            ],
          ),

          _Section(
            'Other licences',
            'ZoneCraft\u2019s own licence does not cover what it is built on. '
                'Map data © OpenStreetMap contributors, licensed under the '
                'Open Database License (ODbL). The open-source packages keep '
                'their own licences, reproduced in full below.',
            children: [
              _Action(
                icon: Icons.article_outlined,
                label: 'Open-source licences',
                detail: 'Every bundled package and its licence text.',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'ZoneCraft',
                  applicationVersion: kAppVersion,
                  applicationLegalese:
                      '© 2026 Leo Stumpf\nGNU AGPL v3 or later',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled block: heading, optional blurb, then whatever rows belong to it.
class _Section extends StatelessWidget {
  const _Section(this.title, this.blurb, {this.children = const []});

  final String title;
  final String blurb;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 48),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(blurb, style: theme.textTheme.bodySmall),
        if (children.isNotEmpty) const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// One external service: what it is, what it is for, and where it lives.
///
/// [urls] are bare hosts as displayed; each opens as `https://<host>`. They are
/// listed one per line rather than joined, because a joined run of hosts has no
/// sensible single destination.
class _Service extends StatelessWidget {
  const _Service({
    required this.icon,
    required this.name,
    required this.urls,
    required this.body,
    this.canOpen = false,
  });

  final IconData icon;
  final String name;
  final List<String> urls;
  final String body;

  /// Whether this device can open an `https` URL at all — see
  /// [_AboutScreenState._probeLinkSupport]. False keeps the row as selectable
  /// text instead of a link that would do nothing when tapped.
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sized against the text so a large system font doesn't leave the
          // icon marooned beside a much taller block.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.bodyLarge),
                for (final url in urls) _Url(url, canOpen: canOpen),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One address: a link where one can be opened, selectable text where it
/// cannot.
class _Url extends StatelessWidget {
  const _Url(this.host, {required this.canOpen});

  final String host;
  final bool canOpen;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://$host'),
        // A browser, not a web view inside ZoneCraft: these are other people's
        // sites and belong in the user's own browser, with its own history,
        // logins and blocking.
        mode: LaunchMode.externalApplication,
      );
    // A missing browser and a refusing one both mean the link did not open, and
    // the fallback is the same either way.
    // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't open $host")),
      );
    }
  }

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
        onTap: () => unawaited(_open(context)),
        // The row is a line of small text; without this the ripple bleeds
        // across the full column width.
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(host, style: style),
        ),
      ),
    );
  }
}

/// A row that does something in-app rather than pointing somewhere.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One deliberate behaviour, stated as the claim then the reason.
class _Limit extends StatelessWidget {
  const _Limit(this.claim, this.why);

  final String claim;
  final String why;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(claim, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            why,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
