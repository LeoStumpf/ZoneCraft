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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/main.dart';

void main() {
  group('supportedLocales', () {
    // Flutter falls back to supportedLocales.first when the device matches
    // nothing, and the list is built from a HashSet whose order is arbitrary.
    // Built naively, a Thai phone lands on a random language.
    test('English is the fallback, not whatever the hash set yields first', () {
      expect(supportedLocales.first, const Locale('en'));
    });

    test('offers many languages, so Flutter’s own widgets translate', () {
      expect(supportedLocales.length, greaterThan(50));
      for (final code in ['de', 'fr', 'es', 'pt', 'pl', 'ja']) {
        expect(
          supportedLocales.map((l) => l.languageCode),
          contains(code),
        );
      }
    });

    // Not unwanted — untested. Declaring one mirrors the entire layout, and
    // the map chrome, the FAB row and the banner column have never been seen
    // that way. Remove a code from the exclusion list once it has been checked
    // on a device, and this test will follow.
    test('right-to-left locales stay out until the layout is checked', () {
      final codes = supportedLocales.map((l) => l.languageCode).toSet();
      for (final rtl in ['ar', 'he', 'fa', 'ur']) {
        expect(codes, isNot(contains(rtl)));
      }
    });

    test('no locale is listed twice', () {
      final codes = supportedLocales.map((l) => l.toString()).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });
  });
}
