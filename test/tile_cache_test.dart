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

import 'package:drift/drift.dart' show Variable;
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

  Future<int> stampOf(String url) async {
    final row = await db
        .customSelect(
          'SELECT last_used_at AS t FROM tile_cache WHERE url = ?',
          variables: [Variable<String>(url)],
        )
        .getSingle();
    return row.read<int>('t');
  }

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
  //
  // The rows are backdated first because serving a tile only re-stamps it once
  // per `tileTouchIntervalMs` — see there. That is the contract: recency is
  // tracked to within the interval, not to the millisecond.
  test('eviction takes the least recently used first', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 4; i++) {
      await repo.putTile('tile$i', bytesOf(100));
      // Well past the touch interval, and each one older than the last.
      await db.customStatement(
        'UPDATE tile_cache SET last_used_at = ? WHERE url = ?',
        [now - Repository.tileTouchIntervalMs * (10 - i), 'tile$i'],
      );
    }
    // Touch the oldest, which should now outlive the others.
    await repo.getTile('tile0');

    await repo.evictTilesDownTo(150);

    expect(await repo.getTile('tile0'), isNotNull,
        reason: 'just used, so it should be the last to go');
    expect(await repo.getTile('tile1'), isNull);
  });

  // getTile used to UPDATE on every tile it served: a pan is dozens of tiles a
  // second, most re-served seconds apart, so a read became dozens of write
  // transactions a second on the single connection the whole app shares.
  group('serving a tile does not write every time', () {
    test('a tile used again straight away is not re-stamped', () async {
      await repo.putTile('a', bytesOf(100));
      final before = await stampOf('a');

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.getTile('a');

      expect(await stampOf('a'), before,
          reason: 'within the touch interval, so no write');
    });

    test('a stale tile is re-stamped, or LRU would stop meaning anything',
        () async {
      await repo.putTile('a', bytesOf(100));
      // Backdate past the interval — the same thing a week of not looking at
      // this part of the map would do.
      final old = DateTime.now().millisecondsSinceEpoch -
          Repository.tileTouchIntervalMs -
          1000;
      await db.customStatement(
        'UPDATE tile_cache SET last_used_at = ? WHERE url = ?',
        [old, 'a'],
      );

      await repo.getTile('a');
      expect(await stampOf('a'), greaterThan(old));
    });

    test('the bytes come back either way', () async {
      await repo.putTile('a', bytesOf(7));
      expect((await repo.getTile('a'))!.length, 7);
      expect((await repo.getTile('a'))!.length, 7);
    });
  });

  // The audit flagged concurrent eviction as over-evicting. Checked, and it
  // did not: every run read the same total, selected the same oldest rows, and
  // the redundant deletes hit rows already gone. What they really cost was the
  // same full SUM scan and delete dozens of times over, on the one connection
  // the app shares — while panning, which is when the map needs it. So these
  // test what coalescing actually buys, not a race that does not happen.
  group('concurrent eviction does one pass, not ten', () {
    test('a call arriving mid-run joins it instead of starting another', () {
      final a = repo.evictTilesDownTo(1000);
      final b = repo.evictTilesDownTo(1000);
      expect(identical(a, b), isTrue);
      return Future.wait([a, b]);
    });

    test('a later call starts a fresh run once the first has finished',
        () async {
      for (var i = 0; i < 10; i++) {
        await repo.putTile('tile$i', bytesOf(100));
      }
      await repo.evictTilesDownTo(800);
      expect(await repo.tileCacheBytes(), lessThanOrEqualTo(800));

      // Not joined to the finished one — it has to do real work.
      await repo.evictTilesDownTo(300);
      expect(await repo.tileCacheBytes(), lessThanOrEqualTo(300));
    });

    test('ten racing calls leave the cache at the cap, not empty', () async {
      for (var i = 0; i < 20; i++) {
        await repo.putTile('tile$i', bytesOf(100));
      }
      await Future.wait([
        for (var i = 0; i < 10; i++) repo.evictTilesDownTo(1000),
      ]);

      final left = await repo.tileCacheBytes();
      expect(left, lessThanOrEqualTo(1000));
      expect(left, greaterThan(800));
    });
  });

  // The change that removes the correctness risk rather than the waste: the
  // total is re-read each pass instead of decremented from one taken at the
  // start. With more rows than fit in a batch this takes several passes, and
  // a stale number would carry its error through all of them.
  group('a multi-pass eviction stops at the cap', () {
    test('200 tiles down to a small cap lands just under it', () async {
      for (var i = 0; i < 200; i++) {
        await repo.putTile('tile$i', bytesOf(100));
      }
      expect(await repo.tileCacheBytes(), 20000);

      await repo.evictTilesDownTo(5000);

      final left = await repo.tileCacheBytes();
      expect(left, lessThanOrEqualTo(5000));
      expect(left, greaterThan(4800),
          reason: 'several batches, and it still stopped at the cap');
    });

    test('a cap of zero empties it rather than looping forever', () async {
      for (var i = 0; i < 5; i++) {
        await repo.putTile('tile$i', bytesOf(100));
      }
      await repo.evictTilesDownTo(0);
      expect(await repo.tileCacheBytes(), 0);
    });
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
