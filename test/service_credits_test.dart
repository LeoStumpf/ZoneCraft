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
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/service_credits.dart';
import 'package:zonecraft/data/tile_source.dart';
import 'package:zonecraft/ui/import_progress.dart';

/// The app names the free services it relies on while you use them. These
/// hold that each line says whose service it is, and that the one wait that
/// can last minutes actually shows it.
void main() {
  test('each credit names its service and why it is free', () {
    expect(kOverpassCredit, contains('Overpass'));
    expect(kOverpassCredit, contains('volunteers'));
    expect(kNominatimCredit, contains('Nominatim'));
    expect(kTerrainCredit, contains('open'));
    expect(kGiveBackCredit, contains('OpenStreetMap volunteers'));
    expect(kGiveBackShort, contains('volunteers'));
  });

  test('the tile credit says who draws the map', () {
    const osm = TileSource(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
      allowsPrefetch: false,
    );
    expect(tileCredit(osm), contains('OpenStreetMap’s own servers'));
    const keyed = TileSource(
      urlTemplate:
          'https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors · Powered by Geoapify',
      allowsPrefetch: false,
    );
    expect(tileCredit(keyed), contains('maps.geoapify.com'));
    expect(tileCredit(keyed), contains('allowance'));
  });

  testWidgets('an import says who it is waiting for', (tester) async {
    late ImportProgress progress;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => progress = showImportProgress(
              context,
              title: 'Importing benches',
              message: 'Preparing the query…',
              credit: kOverpassCredit,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text(kOverpassCredit), findsOneWidget);
    progress.close();
    await tester.pumpAndSettle();
  });
}
