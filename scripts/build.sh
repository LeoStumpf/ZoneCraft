#!/usr/bin/env bash
#
# Build (and optionally install) the ZoneCraft app.
#
# Usage:
#   scripts/build.sh                     analyze + test, then build a debug APK
#   scripts/build.sh --install           also install on the connected device
#   scripts/build.sh --install --run     install, then launch the app
#   scripts/build.sh --release           build a release APK instead of debug
#   scripts/build.sh --bundle            build a release App Bundle (.aab) for Play
#   scripts/build.sh --skip-checks       skip `flutter analyze` and `flutter test`
#
# Env overrides:
#   DEVICE=<adb-serial>   target a specific device (default: Pixel 4a below)
#   ZONECRAFT_ENV=<path>  file of release settings to source first
#                         (default ~/.config/zonecraft/release.env). It lives
#                         outside the repo because TILE_URL carries an API key.
#                         Anything already exported wins over the file.
#   TILE_URL=<template>   base-map tile URL, e.g.
#                         'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=KEY'
#   TILE_ATTRIBUTION=<s>  the attribution line shown for it
#   OSM_API_URL=<url>     where "Tell OpenStreetMap" sends notes. Unset = the
#                         real database. Use
#                         https://master.apis.dev.openstreetmap.org to test.
#   TILE_ALLOWS_PREFETCH=true
#                         RE-ENABLE the offline features (viewport prefetch +
#                         "download this area"), which are off by default
#                         because OpenStreetMap's tile policy forbids them on
#                         the community servers -- and so do MapTiler and
#                         Thunderforest on their cheaper plans. Set it only when
#                         the provider you pointed TILE_URL at says in writing
#                         that you may. Redirecting the tiles is NOT enough on
#                         its own. See lib/data/tile_source.dart.
#
#   The key belongs in TILE_URL in your environment, never in the repo.
#
set -euo pipefail

# --- config (machine-specific; safe fallbacks below) -------------------------
FLUTTER_BIN="/home/leo/development/flutter/bin"
DEVICE="${DEVICE:-09291JEC226042}" # Pixel 4a
APP_ID="io.github.leostumpf.zonecraft"
MAIN_ACTIVITY="$APP_ID/.MainActivity"

# --- locate repo root, flutter, adb ------------------------------------------
cd "$(dirname "$0")/.."
command -v flutter >/dev/null 2>&1 || export PATH="$PATH:$FLUTTER_BIN"
ADB="$(command -v adb || echo /usr/bin/adb)"

# --- parse args --------------------------------------------------------------
MODE="debug"
BUNDLE=0
INSTALL=0
RUN=0
SKIP_CHECKS=0
for arg in "$@"; do
  case "$arg" in
    --debug)       MODE="debug" ;;
    --release)     MODE="release" ;;
    --bundle|--aab) BUNDLE=1; MODE="release" ;; # App Bundle is always release
    --install)     INSTALL=1 ;;
    --run)         INSTALL=1; RUN=1 ;; # running implies installing first
    --skip-checks) SKIP_CHECKS=1 ;;
    -h|--help)     sed -n '2,35p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

# Release configuration, kept OUTSIDE the repository on purpose: the tile URL
# carries an API key, and a file that is not in the project folder cannot be
# pushed by a broken .gitignore, a `git add -A`, or a fresh clone. Anything
# already exported on the command line wins, so a one-off override still works.
ZONECRAFT_ENV="${ZONECRAFT_ENV:-$HOME/.config/zonecraft/release.env}"
if [ -f "$ZONECRAFT_ENV" ]; then
  # `.` overwrites whatever is already in the environment, so a one-off
  # `TILE_URL=... scripts/build.sh` would be silently ignored in favour of the
  # file -- and the build would claim to use a source it was not using. Keep
  # the caller's values and put them back afterwards.
  _pre_url="${TILE_URL-}"
  _pre_attr="${TILE_ATTRIBUTION-}"
  _pre_prefetch="${TILE_ALLOWS_PREFETCH-}"
  # shellcheck source=/dev/null
  . "$ZONECRAFT_ENV"
  if [ -n "$_pre_url" ]; then TILE_URL="$_pre_url"; fi
  if [ -n "$_pre_attr" ]; then TILE_ATTRIBUTION="$_pre_attr"; fi
  if [ -n "$_pre_prefetch" ]; then TILE_ALLOWS_PREFETCH="$_pre_prefetch"; fi
  unset _pre_url _pre_attr _pre_prefetch
  echo "==> config: $ZONECRAFT_ENV"
fi

DART_DEFINES=()
# Tile source. Forwarded in every mode (unlike the DSN) so an offline-capable
# debug build is one export away.
if [ -n "${TILE_URL:-}" ]; then
  DART_DEFINES+=(--dart-define=TILE_URL="$TILE_URL")
  # Printed with the key masked: this line ends up in terminal scrollback, in a
  # CI log, and in whatever the user pastes into a bug report.
  echo "==> tile source: $(printf '%s' "$TILE_URL" | sed -E 's/(([Aa][Pp][Ii])?[Kk]ey=)[^&]*/\1***/g')"
fi
if [ -n "${TILE_ATTRIBUTION:-}" ]; then
  DART_DEFINES+=(--dart-define=TILE_ATTRIBUTION="$TILE_ATTRIBUTION")
fi
if [ "${TILE_ALLOWS_PREFETCH:-}" = "true" ]; then
  if [ -z "${TILE_URL:-}" ]; then
    echo "!!! TILE_ALLOWS_PREFETCH=true without TILE_URL: refusing." >&2
    echo "    That would bulk-download from OpenStreetMap's donated servers," >&2
    echo "    which their tile policy forbids outright." >&2
    exit 1
  fi
  DART_DEFINES+=(--dart-define=TILE_ALLOWS_PREFETCH=true)
  echo "==> prefetch + area download ENABLED (you asserted the provider allows it)"
fi
# Where corrections are sent. Unset means the real OpenStreetMap database.
# Point it at https://master.apis.dev.openstreetmap.org while developing:
# a note filed against the live database to see whether a button works is one
# a volunteer then has to read, understand and close by hand.
if [ -n "${OSM_API_URL:-}" ]; then
  DART_DEFINES+=(--dart-define=OSM_API_URL="$OSM_API_URL")
  echo "==> OSM API: $OSM_API_URL (reports do NOT go to openstreetmap.org)"
fi

# --- checks ------------------------------------------------------------------
if [ "$SKIP_CHECKS" -eq 0 ]; then
  echo "==> flutter analyze"
  flutter analyze
  echo "==> flutter test"
  flutter test
fi

# --- build -------------------------------------------------------------------
if [ "$BUNDLE" -eq 1 ]; then
  echo "==> flutter build appbundle --release"
  flutter build appbundle --release "${DART_DEFINES[@]}"
  AAB="build/app/outputs/bundle/release/app-release.aab"
  echo "==> built $AAB (upload this to Play Console)"
  echo "Done."
  exit 0
fi

echo "==> flutter build apk --$MODE"
flutter build apk --"$MODE" "${DART_DEFINES[@]}"
APK="build/app/outputs/flutter-apk/app-$MODE.apk"
echo "==> built $APK"

# --- install / run -----------------------------------------------------------
if [ "$INSTALL" -eq 1 ]; then
  echo "==> install on $DEVICE (-r preserves data, exercises migrations)"
  "$ADB" -s "$DEVICE" install -r "$APK"
fi
if [ "$RUN" -eq 1 ]; then
  echo "==> launch $MAIN_ACTIVITY"
  "$ADB" -s "$DEVICE" shell am start -n "$MAIN_ACTIVITY" >/dev/null
fi

echo "Done."
