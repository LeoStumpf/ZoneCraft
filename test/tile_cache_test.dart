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

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zonecraft/data/cached_tile_provider.dart';
import 'package:zonecraft/data/database.dart';
import 'package:zonecraft/data/repository.dart';

/// The 200 MB cap is the app's one defence against the tile cache growing
/// without limit, and it had no test at all — so "capped at 200 MB" was a
/// claim about code nothing had ever run. These are the two properties that
/// matter: it evicts, and it evicts the *least recently used* tile.
void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() => db.close());

  Uint8List bytesOf(int n) => Uint8List(n);

  test('tileCacheBytes counts what was stored', () async {
    expect(await repo.tileCacheBytes(), 0);
    await repo.putTile('a', bytesOf(100));
    await repo.putTile('b', bytesOf(250));
    expect(await repo.tileCacheBytes(), 350);
  });

  test('re-storing a tile replaces it rather than adding to it', () async {
    await repo.putTile('a', bytesOf(100));
    await repo.putTile('a', bytesOf(400));
    expect(await repo.tileCacheBytes(), 400);
  });

  test('eviction does nothing while under the cap', () async {
    await repo.putTile('a', bytesOf(100));
    await repo.evictTilesDownTo(1000);
    expect(await repo.getTile('a'), isNotNull);
  });

  test('eviction drops tiles until under the cap', () async {
    for (var i = 0; i < 10; i++) {
      await repo.putTile('tile$i', bytesOf(100));
    }
    expect(await repo.tileCacheBytes(), 1000);

    await repo.evictTilesDownTo(450);
    expect(await repo.tileCacheBytes(), lessThanOrEqualTo(450));
  });

  // The whole point of tracking `lastUsedAt` on read. If eviction ignored it,
  // the tile you are looking at right now would be as likely to go as one from
  // a city you left a week ago.
  test('eviction takes the least recently used first', () async {
    for (var i = 0; i < 4; i++) {
      await repo.putTile('tile$i', bytesOf(100));
      // putTile stamps millisecond timestamps, so without a gap the four rows
      // are indistinguishable and the order is whatever SQLite feels like.
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Touch the oldest, which should now outlive the others.
    await repo.getTile('tile0');

    await repo.evictTilesDownTo(150);

    expect(await repo.getTile('tile0'), isNotNull,
        reason: 'just used, so it should be the last to go');
    expect(await repo.getTile('tile1'), isNull);
  });

  test('clearing empties the cache', () async {
    await repo.putTile('a', bytesOf(100));
    await repo.clearTileCache();
    expect(await repo.tileCacheBytes(), 0);
    expect(await repo.getTile('a'), isNull);
  });

  // A round number that is easy to change by accident and expensive to get
  // wrong in either direction — too small and the map re-fetches constantly on
  // a train, too large and the app eats a phone's storage.
  test('the advertised cap is what the provider actually uses', () {
    expect(CachedTileProvider.maxCacheBytes, 200 * 1024 * 1024);
  });
}
