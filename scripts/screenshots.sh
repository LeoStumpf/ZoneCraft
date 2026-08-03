#!/usr/bin/env bash
#
# Play Store screenshots, reproducibly.
#
# The three phone screenshots currently in planning/play-store-assets were taken
# with a bare `adb exec-out screencap` on the Pixel 4a. They are 1080x2340, an
# aspect ratio of 2.167 — and Play requires that "the maximum dimension of your
# screenshot can't be more than twice as long as the minimum dimension". They
# would be rejected. Every modern phone is that shape, so a real device is the
# wrong tool for this job.
#
# This script removes every *technical* source of unreliability:
#
#   * a dedicated emulator at a Play-legal resolution (never crop afterwards),
#   * a frozen status bar (fixed clock, full battery, no notification icons),
#   * animations off, locale and font scale pinned,
#   * a deterministic database, so the same zones sit in the same places,
#   * a dimension check on every capture, so a bad shot cannot reach the Console.
#
# What it deliberately does NOT do is drive the UI. Composing a good shot is a
# judgement call, and tap coordinates rot the moment a button moves. You compose;
# it captures and validates.
#
# Usage:
#   scripts/screenshots.sh setup [phone|tablet7|tablet10]   prepare + boot + seed
#   scripts/screenshots.sh shoot <NN-name>                  capture one screenshot
#   scripts/screenshots.sh finish                           restore, then verify all
#   scripts/screenshots.sh verify                           re-check existing files
#
# The shot list lives in planning/SCREENSHOTS.md. Follow it in order.
#
set -euo pipefail

cd "$(dirname "$0")/.."

FLUTTER_BIN="/home/leo/development/flutter/bin"
command -v flutter >/dev/null 2>&1 || export PATH="$PATH:$FLUTTER_BIN"
ADB="$(command -v adb || echo /usr/bin/adb)"
SDK="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
EMULATOR="$SDK/emulator/emulator"
AVDMANAGER="$SDK/cmdline-tools/latest/bin/avdmanager"
APP_ID="com.leostumpf.zonecraft"
OUT_ROOT="planning/play-store-assets/play-screenshots"
SEED="build/screenshot-seed.sqlite"
STATE=".screenshot-profile" # which profile `setup` last prepared

# --- profiles ----------------------------------------------------------------
# Sizes chosen to satisfy Play *and* to hit its "recommended formats" bar, which
# wants at least four screenshots at 1080px or more in a 9:16 portrait ratio.
#
#   phone     1080x1920  ratio 1.778  (exactly 9:16)
#   tablet7   1200x1920  ratio 1.600
#   tablet10  1600x2560  ratio 1.600
#
# Every one is comfortably inside the 2:1 limit. Do not "fix" these to match a
# real handset — a real handset is what produced the rejects.
profile_spec() {
  case "$1" in
    phone)    echo "zc-shot-phone 1080 1920 420 pixel_5" ;;
    tablet7)  echo "zc-shot-tablet7 1200 1920 240 Nexus 7 2013" ;;
    tablet10) echo "zc-shot-tablet10 1600 2560 320 pixel_tablet" ;;
    *) echo "Unknown profile: $1 (phone|tablet7|tablet10)" >&2; exit 1 ;;
  esac
}

SYSTEM_IMAGE="system-images;android-34;google_apis;x86_64"

# --- helpers -----------------------------------------------------------------
die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "==> $*"; }

# The serial of the running emulator, or empty.
emu_serial() {
  "$ADB" devices | awk '/^emulator-/ {print $1; exit}'
}

wait_for_boot() {
  local serial="$1"
  note "waiting for $serial to finish booting…"
  "$ADB" -s "$serial" wait-for-device
  local i=0
  until [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    i=$((i + 1))
    [ "$i" -gt 180 ] && die "emulator did not boot within 3 minutes"
    sleep 1
  done
  sleep 3 # let the launcher settle before we start poking at SystemUI
}

# A clean, identical status bar in every shot. Without this the clock, the
# battery percentage and whatever notification icons happen to be present differ
# between captures — which looks sloppy in a row of thumbnails and leaks whatever
# is on the machine that took them.
enter_demo_mode() {
  local serial="$1"
  "$ADB" -s "$serial" shell settings put global sysui_demo_allowed 1
  local demo="am broadcast -a com.android.systemui.demo -e command"
  # shellcheck disable=SC2086
  "$ADB" -s "$serial" shell $demo enter >/dev/null
  # shellcheck disable=SC2086
  "$ADB" -s "$serial" shell $demo clock -e hhmm 1200 >/dev/null
  # shellcheck disable=SC2086
  "$ADB" -s "$serial" shell $demo battery -e level 100 -e plugged false >/dev/null
  # shellcheck disable=SC2086
  "$ADB" -s "$serial" shell $demo network -e wifi show -e level 4 >/dev/null
  # shellcheck disable=SC2086
  "$ADB" -s "$serial" shell $demo network -e mobile show -e datatype none -e level 4 >/dev/null
  # shellcheck disable=SC2086
  "$ADB" -s "$serial" shell $demo notifications -e visible false >/dev/null
}

exit_demo_mode() {
  local serial="$1"
  "$ADB" -s "$serial" shell am broadcast -a com.android.systemui.demo \
    -e command exit >/dev/null 2>&1 || true
}

# Play's rule, enforced here so it cannot be discovered in the Console instead.
validate_png() {
  python3 - "$1" <<'PY'
import struct, sys
path = sys.argv[1]
with open(path, 'rb') as f:
    head = f.read(33)
if head[:8] != b'\x89PNG\r\n\x1a\n':
    print(f'FAIL  {path}: not a PNG'); sys.exit(1)
w, h = struct.unpack('>II', head[16:24])
ratio = max(w, h) / min(w, h)
problems = []
if min(w, h) < 320:        problems.append('min side < 320px')
if max(w, h) > 3840:       problems.append('max side > 3840px')
if ratio > 2.0:            problems.append(f'aspect {ratio:.3f} exceeds 2:1')
if problems:
    print(f'FAIL  {w}x{h}  {path}\n      ' + '; '.join(problems)); sys.exit(1)
print(f'ok    {w}x{h}  ratio {ratio:.3f}  {path}')
PY
}

# --- commands ----------------------------------------------------------------
cmd_setup() {
  local profile="${1:-phone}"
  read -r avd w h density device <<<"$(profile_spec "$profile")"

  [ -x "$EMULATOR" ] || die "emulator not found at $EMULATOR"
  [ -x "$AVDMANAGER" ] || die "avdmanager not found at $AVDMANAGER"

  if ! "$EMULATOR" -list-avds | grep -qx "$avd"; then
    note "creating AVD $avd ($w x $h, density $density)"
    echo no | "$AVDMANAGER" create avd -n "$avd" -k "$SYSTEM_IMAGE" \
      --device "$device" --force >/dev/null
  fi
  # Force the exact size regardless of the device profile's own defaults —
  # the device profile is only a starting point and its resolution is usually
  # a real handset's, which is the shape we are avoiding.
  local cfg="$HOME/.android/avd/$avd.avd/config.ini"
  python3 - "$cfg" "$w" "$h" "$density" <<'PY'
import sys
cfg, w, h, d = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
want = {'hw.lcd.width': w, 'hw.lcd.height': h, 'hw.lcd.density': d,
        'skin.name': f'{w}x{h}', 'skin.path': '_no_skin', 'showDeviceFrame': 'no'}
lines, seen = [], set()
for line in open(cfg):
    k = line.split('=')[0].strip()
    if k in want:
        lines.append(f'{k} = {want[k]}\n'); seen.add(k)
    else:
        lines.append(line)
for k, v in want.items():
    if k not in seen:
        lines.append(f'{k} = {v}\n')
open(cfg, 'w').writelines(lines)
PY

  if [ -z "$(emu_serial)" ]; then
    note "booting $avd"
    nohup "$EMULATOR" -avd "$avd" -no-boot-anim -no-snapshot-save \
      -gpu swiftshader_indirect >/dev/null 2>&1 &
  else
    note "an emulator is already running — reusing it"
  fi
  local serial; serial="$(emu_serial)"
  local i=0
  while [ -z "$serial" ]; do
    i=$((i + 1)); [ "$i" -gt 120 ] && die "no emulator appeared"
    sleep 1; serial="$(emu_serial)"
  done
  wait_for_boot "$serial"

  note "pinning the environment"
  "$ADB" -s "$serial" shell settings put global window_animation_scale 0
  "$ADB" -s "$serial" shell settings put global transition_animation_scale 0
  "$ADB" -s "$serial" shell settings put global animator_duration_scale 0
  "$ADB" -s "$serial" shell settings put system font_scale 1.0
  "$ADB" -s "$serial" shell settings put system accelerometer_rotation 0
  "$ADB" -s "$serial" shell settings put system user_rotation 0
  "$ADB" -s "$serial" shell cmd uimode night no >/dev/null 2>&1 || true
  enter_demo_mode "$serial"

  note "building + installing a debug APK (run-as needs it debuggable)"
  flutter build apk --debug >/dev/null
  "$ADB" -s "$serial" install -r build/app/outputs/flutter-apk/app-debug.apk >/dev/null

  note "generating the deterministic seed database"
  flutter test tool/make_screenshot_seed.dart >/dev/null
  [ -f "$SEED" ] || die "seed generator produced no $SEED"

  note "seeding"
  # Start once so the app's data dir exists, then stop before overwriting under it.
  "$ADB" -s "$serial" shell am start -n "$APP_ID/.MainActivity" >/dev/null
  sleep 6
  "$ADB" -s "$serial" shell am force-stop "$APP_ID"
  sleep 1
  "$ADB" -s "$serial" push "$SEED" /data/local/tmp/seed.sqlite >/dev/null
  "$ADB" -s "$serial" shell "run-as $APP_ID cp /data/local/tmp/seed.sqlite app_flutter/zonecraft.sqlite" \
    || die "run-as failed — is this a debug build?"
  # Drop any stale WAL/journal, or SQLite may replay over the seed.
  "$ADB" -s "$serial" shell "run-as $APP_ID sh -c 'rm -f app_flutter/zonecraft.sqlite-wal app_flutter/zonecraft.sqlite-shm'" || true
  "$ADB" -s "$serial" shell am start -n "$APP_ID/.MainActivity" >/dev/null

  echo "$profile" > "$STATE"
  cat <<EOF

Ready. Profile: $profile ($w x $h) on $serial

Give the map ~15s to pull tiles before the first shot — there is no prefetch,
so only what is on screen loads, and a half-drawn map is the other way these
come out badly.

Now follow planning/SCREENSHOTS.md and, for each entry:
    scripts/screenshots.sh shoot 01-zones-stacked
EOF
}

cmd_shoot() {
  local name="${1:-}"
  [ -n "$name" ] || die "usage: screenshots.sh shoot <NN-name>"
  [ -f "$STATE" ] || die "run 'screenshots.sh setup' first"
  local profile; profile="$(cat "$STATE")"
  local serial; serial="$(emu_serial)"
  [ -n "$serial" ] || die "no emulator running"

  local dir="$OUT_ROOT/$profile"
  mkdir -p "$dir"
  local out="$dir/$name.png"
  "$ADB" -s "$serial" exec-out screencap -p > "$out"
  if ! validate_png "$out"; then
    rm -f "$out"
    die "capture rejected and deleted — fix the emulator size, do not crop"
  fi
}

cmd_finish() {
  local serial; serial="$(emu_serial)"
  [ -n "$serial" ] && exit_demo_mode "$serial"
  rm -f "$STATE"
  cmd_verify
}

cmd_verify() {
  local failed=0 count=0
  for f in $(find "$OUT_ROOT" -name '*.png' 2>/dev/null | sort); do
    count=$((count + 1))
    validate_png "$f" || failed=1
  done
  echo
  [ "$count" -eq 0 ] && die "no screenshots found under $OUT_ROOT"
  for d in "$OUT_ROOT"/*/; do
    [ -d "$d" ] || continue
    local n; n=$(find "$d" -name '*.png' | wc -l)
    if [ "$n" -lt 2 ]; then
      echo "WARNING: $(basename "$d") has $n screenshot(s); Play requires at least 2"
      failed=1
    elif [ "$n" -gt 8 ]; then
      echo "WARNING: $(basename "$d") has $n; Play accepts at most 8"
      failed=1
    else
      echo "$(basename "$d"): $n screenshots"
    fi
  done
  [ "$failed" -eq 0 ] || die "some screenshots are not uploadable"
  echo "All good."
}

case "${1:-}" in
  setup)  shift; cmd_setup "$@" ;;
  shoot)  shift; cmd_shoot "$@" ;;
  finish) cmd_finish ;;
  verify) cmd_verify ;;
  *) sed -n '2,32p' "$0"; exit 1 ;;
esac
