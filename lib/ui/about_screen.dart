import 'package:flutter/material.dart';

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
/// URLs are selectable text rather than links: `url_launcher` is not a
/// dependency, and adding one (plus its Android intent-query manifest entries)
/// to make four addresses tappable is not a trade worth making.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
            children: const [
              _Service(
                icon: Icons.map_outlined,
                name: 'OpenStreetMap tiles',
                url: 'tile.openstreetmap.org',
                body: 'The base map. Map data and tiles © OpenStreetMap '
                    'contributors, licensed under the Open Database License '
                    '(ODbL).',
              ),
              _Service(
                icon: Icons.travel_explore,
                name: 'Overpass API',
                url: 'overpass-api.de · overpass.kumi.systems · '
                    'overpass.private.coffee',
                body: 'Points of interest, transit stations and '
                    'administrative areas, fetched once per import and then '
                    'stored on the device. Three community instances are '
                    'tried in turn, because whichever one is busy is the '
                    'variable.',
              ),
              _Service(
                icon: Icons.search,
                name: 'Nominatim',
                url: 'nominatim.openstreetmap.org',
                body: 'Finds a place by name when you import a feature such '
                    'as a city border or a river.',
              ),
              _Service(
                icon: Icons.terrain,
                name: 'AWS Terrain Tiles',
                url: 's3.amazonaws.com/elevation-tiles-prod',
                body: 'Elevation for height layers and the elevation probe. '
                    'A public open-data set aggregated from SRTM, NED and '
                    'others.',
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
            'Licences',
            'Map data © OpenStreetMap contributors, licensed under the ODbL. '
                'ZoneCraft is built on open-source packages; the full list, '
                'with their licences and the attribution required by each data '
                'source, is in THIRD_PARTY_NOTICES.md in the project '
                'repository.',
            children: const [
              _Service(
                icon: Icons.code,
                name: 'Source',
                url: 'github.com/LeoStumpf/ZoneCraft',
                body: '',
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
class _Service extends StatelessWidget {
  const _Service({
    required this.icon,
    required this.name,
    required this.url,
    required this.body,
  });

  final IconData icon;
  final String name;
  final String url;
  final String body;

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
                SelectableText(
                  url,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
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
