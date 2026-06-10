#!/usr/bin/env bash
#
# Build (and optionally install) the ZoneCraft APK.
#
# Usage:
#   scripts/build.sh                     analyze + test, then build a debug APK
#   scripts/build.sh --install           also install on the connected device
#   scripts/build.sh --install --run     install, then launch the app
#   scripts/build.sh --release           build a release APK instead of debug
#   scripts/build.sh --skip-checks       skip `flutter analyze` and `flutter test`
#
# Env overrides:
#   DEVICE=<adb-serial>   target a specific device (default: Pixel 4a below)
#
set -euo pipefail

# --- config (machine-specific; safe fallbacks below) -------------------------
FLUTTER_BIN="/home/leo/development/flutter/bin"
DEVICE="${DEVICE:-09291JEC226042}" # Pixel 4a
APP_ID="com.zonecraft.zonecraft"
MAIN_ACTIVITY="$APP_ID/.MainActivity"

# --- locate repo root, flutter, adb ------------------------------------------
cd "$(dirname "$0")/.."
command -v flutter >/dev/null 2>&1 || export PATH="$PATH:$FLUTTER_BIN"
ADB="$(command -v adb || echo /usr/bin/adb)"

# --- parse args --------------------------------------------------------------
MODE="debug"
INSTALL=0
RUN=0
SKIP_CHECKS=0
for arg in "$@"; do
  case "$arg" in
    --debug)       MODE="debug" ;;
    --release)     MODE="release" ;;
    --install)     INSTALL=1 ;;
    --run)         INSTALL=1; RUN=1 ;; # running implies installing first
    --skip-checks) SKIP_CHECKS=1 ;;
    -h|--help)     sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

# --- checks ------------------------------------------------------------------
if [ "$SKIP_CHECKS" -eq 0 ]; then
  echo "==> flutter analyze"
  flutter analyze
  echo "==> flutter test"
  flutter test
fi

# --- build -------------------------------------------------------------------
echo "==> flutter build apk --$MODE"
flutter build apk --"$MODE"
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
