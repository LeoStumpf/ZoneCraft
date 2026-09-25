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

import 'tile_source.dart';

/// Who the app relies on, said in one friendly sentence each — shown at the
/// moment you use the service, and nowhere written twice.
///
/// ZoneCraft has no server of its own. Its map, its imports, its search and
/// its terrain all come from services other people run for free, most of them
/// volunteers on donated machines. Their rules are also why some things are
/// slow on purpose — an import that waits its turn, a search that only runs
/// on a press — and a wait that is explained reads as courtesy rather than as
/// a broken app. So each wait names who it is waiting for, and why.
///
/// **Never counted by `UiHints`.** These sit inside a wait or a form the user
/// is already looking at, so showing them costs nothing, and the fourth
/// import is as slow as the first: it deserves the same explanation.
///
/// Pure strings, no Flutter, so the dialogs, the "Servers and limits" page and
/// the tests all read the same words.

/// Shown while an Overpass import runs — the one wait that can last minutes.
const String kOverpassCredit =
    'Imports come from Overpass, a free service run by volunteers for everyone '
    'who builds on OpenStreetMap. Requests from all its users queue up '
    'together, so at a busy moment yours can take a minute or two — the app '
    'waits its turn rather than pushing, which is what keeps it free for all.';

/// Shown under the place search boxes.
const String kNominatimCredit =
    'Search by Nominatim, OpenStreetMap’s free place finder, running on '
    'donated servers. One search per press, never as you type, so it stays '
    'quick for everyone.';

/// Shown in the height editor, beside Generate.
const String kTerrainCredit =
    'Heights come from free, open elevation data — terrain tiles built from '
    'USGS and NOAA surveys and hosted as open data. Each area is fetched '
    'once, then kept on your phone.';

/// Why publishing a fix is worth doing: the publish sheet's first line.
const String kGiveBackCredit =
    'Everything on this map — the streets, the benches, the borders — was put '
    'there by OpenStreetMap volunteers, free for anyone to use, this app '
    'included. Passing on what you found is how you give something back: it '
    'makes the map better for you and for everyone who uses it next.';

/// The same thought, short enough to sit above the editor's Publish button.
const String kGiveBackShort =
    'OpenStreetMap is made by volunteers — your fix improves it for everyone.';

/// Who draws the base map for [source], in a sentence.
///
/// The community servers are OpenStreetMap's own, run on donations. A keyed
/// provider is named by its host, since that is the one thing the build can
/// state about it for certain, and its allowance is shared by every install.
String tileCredit(TileSource source) {
  if (source.isCommunityOsm) {
    return 'The map is drawn by OpenStreetMap’s own servers, run on '
        'donations. The app keeps every tile you have seen, so they are '
        'asked for each one only once.';
  }
  final host = Uri.tryParse(source.urlTemplate)?.host ?? '';
  final who = host.isEmpty ? 'a map provider' : host;
  return 'The map is drawn from OpenStreetMap data by $who, on a free '
      'allowance shared by everyone using ZoneCraft. The app keeps every tile '
      'you have seen, so each is fetched only once.';
}
