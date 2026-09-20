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

import 'package:flutter_test/flutter_test.dart';
import 'package:zonecraft/data/overpass_client.dart';
import 'package:zonecraft/data/place_search.dart';
import 'package:zonecraft/data/service_overrides.dart';

/// The escape hatch that lets someone stop leaning on the donated services.
///
/// Two things are worth pinning. The **ordering**: a user who points the app at
/// their own Overpass instance did it to stop hitting the public ones, so the
/// override leads — but the public instances stay behind it, because a typo in
/// a self-hosted URL should cost a slow import, not a dead app. And the
/// **validation**: the shapes caught here are the ones that fail *silently* —
/// a tile template with no `{z}` substitutes nothing and every tile comes back
/// identical; a geocoder host carrying `https://` becomes a name that resolves
/// to nothing. Whether the server is really there is left to the request.
void main() {
  tearDown(() {
    overpassEndpointOverride = null;
    nominatimHostOverride = null;
  });

  group('overpassEndpointList', () {
    test('is the public instances when nothing is set', () {
      expect(overpassEndpointList(), overpassEndpoints);
    });

    test('puts an override first and keeps the public ones as fallback', () {
      overpassEndpointOverride = 'https://mine.test/api/interpreter';
      final list = overpassEndpointList();
      expect(list.first, 'https://mine.test/api/interpreter');
      expect(list, containsAll(overpassEndpoints));
      expect(list, hasLength(overpassEndpoints.length + 1));
    });

    test(
      'does not list an endpoint twice when the override is a public one',
      () {
        overpassEndpointOverride = overpassEndpoints.last;
        final list = overpassEndpointList();
        expect(list.first, overpassEndpoints.last);
        expect(list.toSet(), hasLength(list.length));
      },
    );

    test('blank means unset, not an empty endpoint', () {
      overpassEndpointOverride = '   ';
      expect(overpassEndpointList(), overpassEndpoints);
    });

    test('a remembered winner still leads, override included', () {
      overpassEndpointOverride = 'https://mine.test/api/interpreter';
      expect(
        overpassEndpointList(preferEndpoint: overpassEndpoints[1]).first,
        overpassEndpoints[1],
      );
      expect(
        overpassEndpointList(
          preferEndpoint: 'https://mine.test/api/interpreter',
        ).first,
        'https://mine.test/api/interpreter',
      );
    });

    test('an unknown remembered endpoint is ignored, not appended', () {
      // It is a *stale* preference — a URL the user has since removed — and
      // trying it first would spend a timeout on a server nobody chose.
      final list = overpassEndpointList(preferEndpoint: 'https://gone.test/');
      expect(list, overpassEndpoints);
    });
  });

  group('buildPlaceSearchUri', () {
    test('uses the public geocoder by default', () {
      expect(buildPlaceSearchUri('Isar').host, defaultNominatimHost);
    });

    test('honours the process-wide override', () {
      nominatimHostOverride = 'nominatim.mine.test';
      expect(buildPlaceSearchUri('Isar').host, 'nominatim.mine.test');
    });

    test('an explicit host beats the override', () {
      nominatimHostOverride = 'nominatim.mine.test';
      expect(
        buildPlaceSearchUri('Isar', host: 'other.test').host,
        'other.test',
      );
    });

    test('blank means the default, not an empty host', () {
      nominatimHostOverride = '  ';
      expect(buildPlaceSearchUri('Isar').host, defaultNominatimHost);
    });

    test('keeps the query it always sent', () {
      nominatimHostOverride = 'nominatim.mine.test';
      final uri = buildPlaceSearchUri('Isar');
      expect(uri.queryParameters['q'], 'Isar');
      expect(uri.queryParameters['polygon_geojson'], '1');
    });
  });

  group('validation', () {
    test('empty is always fine — it means "use the default"', () {
      for (final which in ServiceOverride.values) {
        expect(which.validate(''), isNull, reason: which.name);
        expect(which.validate('   '), isNull, reason: which.name);
      }
    });

    test('a tile template must carry z, x and y', () {
      expect(
        ServiceOverride.tiles.validate('https://t.test/{z}/{x}/{y}.png'),
        isNull,
      );
      expect(
        ServiceOverride.tiles.validate('https://t.test/{z}/{x}.png'),
        contains('{y}'),
      );
      expect(ServiceOverride.tiles.validate('t.test/{z}/{x}/{y}'), isNotNull);
    });

    test('an Overpass endpoint must be a URL', () {
      expect(
        ServiceOverride.overpass.validate('https://o.test/api/interpreter'),
        isNull,
      );
      expect(ServiceOverride.overpass.validate('o.test'), isNotNull);
    });

    test('a geocoder is a bare host', () {
      expect(ServiceOverride.nominatim.validate('n.example.org'), isNull);
      expect(
        ServiceOverride.nominatim.validate('https://n.example.org'),
        isNotNull,
      );
      expect(
        ServiceOverride.nominatim.validate('n.example.org/search'),
        isNotNull,
      );
      expect(ServiceOverride.nominatim.validate('localhost'), isNotNull);
    });
  });

  test('every service names the default it stands in for', () {
    // The field shows this, so "empty" reads as an answer rather than a gap.
    for (final which in ServiceOverride.values) {
      expect(which.builtInDefault, isNotEmpty, reason: which.name);
    }
    expect(ServiceOverride.nominatim.builtInDefault, defaultNominatimHost);
    expect(ServiceOverride.overpass.builtInDefault, overpassEndpoints.first);
  });
}
