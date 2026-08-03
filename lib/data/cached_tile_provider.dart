import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'repository.dart';

/// A flutter_map [TileProvider] that serves tiles from the app's Drift-backed
/// [Repository] tile cache, falling back to the network and writing freshly
/// fetched tiles back to the cache. This is what lets the map keep rendering
/// already-seen/prefetched tiles when there's no reception (subway, underground).
///
/// One instance is shared by the base map and the optional transport overlays;
/// tiles are keyed by their full URL, which differs per server, so they coexist
/// safely in a single table.
class CachedTileProvider extends TileProvider {
  /// [client] is owned by the caller (the map screen) and shared across all
  /// tile layers + prefetching, so [dispose] deliberately does **not** close it
  /// — a transport-overlay layer being toggled off mustn't kill the base map.
  CachedTileProvider(this._repo, this._client, {super.headers});

  final Repository _repo;
  final http.Client _client;

  /// Soft cap on the on-disk tile cache; once exceeded, least-recently-used
  /// tiles are evicted after a write.
  static const int maxCacheBytes = 200 * 1024 * 1024;

  /// How long one tile fetch gets. `package:http` has no default timeout, so
  /// without this a stalled connection leaves the request (and the prefetch
  /// loop driving it) hanging forever rather than failing over to the blank
  /// tile the offline path already handles.
  static const Duration fetchTimeout = Duration(seconds: 15);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(
      url: getTileUrl(coordinates, options),
      repo: _repo,
      client: _client,
      headers: headers,
    );
  }

  /// Best-effort offline prefetch: fetch [url] and store it if it isn't cached
  /// already. Returns true if a tile was actually downloaded. Never throws.
  Future<bool> prefetch(String url) async {
    try {
      if (await _repo.hasTile(url)) return false;
      final resp = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(fetchTimeout);
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await _repo.putTile(url, resp.bodyBytes);
        return true;
      }
    } catch (_) {
      // Offline / rate-limited / server error: silently skip.
    }
    return false;
  }
}

/// [ImageProvider] backing [CachedTileProvider]: cache-first, then network.
@immutable
class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({
    required this.url,
    required this.repo,
    required this.client,
    required this.headers,
  });

  final String url;
  final Repository repo;
  final http.Client client;
  final Map<String, String> headers;

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: url,
      informationCollector: () => [DiagnosticsProperty('URL', url)],
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    Future<ui.Codec> decodeBytes(Uint8List bytes) =>
        ui.ImmutableBuffer.fromUint8List(bytes).then(decode);

    // 1. Cache hit -> decode straight from disk, no network.
    final cached = await repo.getTile(url);
    if (cached != null && cached.isNotEmpty) {
      try {
        return await decodeBytes(cached);
      } catch (_) {
        // Corrupt cache entry: fall through and refetch.
      }
    }

    // 2. Miss (or corrupt) -> fetch, store, decode. On any failure throw so
    //    flutter_map shows its blank/error tile (only ever for never-seen
    //    tiles; already-cached areas keep working offline).
    final resp = await client
        .get(Uri.parse(url), headers: headers)
        .timeout(CachedTileProvider.fetchTimeout);
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw NetworkImageLoadException(
        statusCode: resp.statusCode,
        uri: Uri.parse(url),
      );
    }
    final bytes = resp.bodyBytes;
    // Fire-and-forget the writes so decoding isn't blocked on disk I/O.
    unawaited(repo.putTile(url, bytes).then(
          (_) => repo.evictTilesDownTo(CachedTileProvider.maxCacheBytes),
        ));
    return decodeBytes(bytes);
  }

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _CachedTileImage && url == other.url);

  @override
  int get hashCode => url.hashCode;
}
