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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/tile_source.dart';
import '../geo/tiles.dart';
import '../state/providers.dart';

/// A small square of the map around one place, with the place marked in the
/// middle — so an unnamed bench in the Elements list has a street corner to be
/// told apart by.
///
/// **One cached tile image per covered tile, not a map widget.** A
/// `FlutterMap` per row would be a gesture arena, a camera and a tile layer
/// for every visible line of a list that can hold thousands. This is at most
/// four `Image`s, read through the map's own [mapTileProviderProvider] — the
/// same cache, the same `User-Agent`, and offline wherever the map has been.
///
/// Fetching is the list's, not the app's: `Image` defers loading while the list
/// is flung (`ScrollAwareImageProvider`), and only rows on screen are built, so
/// what is fetched is what is looked at — viewing, which the tile policies
/// allow, never prefetching, which they do not.
class PoiThumbnail extends ConsumerWidget {
  const PoiThumbnail(this.at, {super.key, this.size = 56});

  final LatLng at;

  /// Width and height, in logical pixels.
  final double size;

  /// Zoom 16 — the zoom the map is usually read at when looking for a bench,
  /// so a thumbnail is mostly tiles the map has **already cached**: it costs
  /// the tile server next to nothing and works offline wherever you have
  /// looked. (Zoom 17 was sharper and fetched a fresh tile for every row.)
  static const int zoom = 16;

  /// How many tile pixels the square shows — about 250 m of central Europe,
  /// enough streets around the place to tell it from the next one.
  static const double windowPx = 112;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = ref.watch(mapTileProviderProvider);
    final template = TileSource.resolve(
      ref.watch(settingsProvider).asData?.value.tileUrlOverride,
    ).urlTemplate;
    final scale = size / windowPx;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Stack(
            children: [
              if (tiles != null &&
                  at.latitude.isFinite &&
                  at.longitude.isFinite)
                for (final t in tileWindow(
                  at.latitude,
                  at.longitude,
                  zoom,
                  windowPx,
                ))
                  Positioned(
                    left: t.left * scale,
                    top: t.top * scale,
                    width: 256 * scale,
                    height: 256 * scale,
                    child: Image(
                      image: tiles.imageFor(
                        fillTileUrl(template, zoom, t.x, t.y),
                      ),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                      // Offline and never seen: the neutral square stays.
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
                        opacity: sync || frame != null ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: child,
                      ),
                    ),
                  ),
              Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(blurRadius: 2, color: Colors.black38),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
