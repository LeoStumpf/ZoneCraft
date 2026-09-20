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
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the user's browser — the one way the whole app does it.
///
/// Returns false when nothing could handle the link, having shown
/// [failureMessage] first if a [context] was given.
///
/// Two details are load-bearing and were written down only once before, inside
/// the About screen: these are other people's sites, so they belong in the
/// user's own browser rather than a web view of ours
/// ([LaunchMode.externalApplication]); and `launchUrl` both *returns* false and
/// *throws* when nothing can handle the link (a test host, a desktop build, a
/// device whose browser the manifest's `<queries>` block cannot see), so a
/// caller that only checks the return value still crashes on the platforms that
/// throw.
Future<bool> openExternalUrl(
  Uri url, {
  BuildContext? context,
  String failureMessage = 'Could not open a browser.',
  VoidCallback? onFailure,
}) async {
  final messenger = context == null ? null : ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    // A missing browser and a refusing one both mean the link did not open, and
    // the fallback is the same either way.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage)));
    onFailure?.call();
  }
  return opened;
}

/// Whether this device can open [url] at all.
///
/// Android hides other apps unless the manifest's `<queries>` block asks for
/// them, so this answers false for a scheme ZoneCraft did not declare — and it
/// *throws* where there is no platform implementation (a test host, a desktop
/// build), which is why no caller should use `canLaunchUrl` directly. A screen
/// probes once and then shows plain, copyable text instead of a dead link.
Future<bool> canLaunchExternalUrl(Uri url) async {
  try {
    return await canLaunchUrl(url);
    // No platform implementation: treat as "cannot", which is the safe answer.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return false;
  }
}

/// Where the map's "© OpenStreetMap contributors" credit points.
///
/// The ODbL attribution guideline asks for a route to the origin and licence of
/// the data when the attribution text does not spell them out — which a credit
/// short enough to sit in a map corner never does.
final Uri osmCopyrightUrl = Uri.parse(
  'https://www.openstreetmap.org/copyright',
);

/// Where the map's elevation credit points: the per-source attribution list the
/// Terrain Tiles dataset requires be honoured wherever its data is displayed.
final Uri terrainAttributionUrl = Uri.parse(
  'https://github.com/tilezen/joerd/blob/master/docs/attribution.md',
);

/// The credit itself, kept beside the link it abbreviates.
///
/// The bucket the height layers read (`elevation-tiles-prod`) is free and
/// keyless, but it is not unattributed: the dataset is an aggregate, and
/// Tilezen's list asks that the *underlying* providers be named — not "AWS",
/// which is only the host. The full list is longer than a map corner can hold,
/// so this names the sources covering the zoom levels the app samples and
/// [terrainAttributionUrl] carries the rest.
const String kTerrainAttribution =
    'Elevation: Terrain Tiles — SRTM, 3DEP and GMTED2010 courtesy of the '
    'U.S. Geological Survey; ETOPO1 courtesy of NOAA';
