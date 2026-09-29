#!/usr/bin/env bash
#
# Flash the workshop firmware onto a Fairphone 3 over USB.
#
# Plug a phone in fastboot mode and run this script. It works out what
# the phone needs:
#
#   * stock bootloader, locked:   unlocked devinfo, reboot to fastboot, then as below
#   * stock bootloader, unlocked: dummy dtbo, lk2nd on boot, image on userdata
#   * lk2nd already installed:    image on userdata only
#
# Every path erases the phone's userdata partition.
#
# Fastboot mode: power the phone off, hold Volume Down, plug in USB. On a
# phone that already runs lk2nd, wait for the screen to turn on before
# pressing Volume Down.

set -euo pipefail

LK2ND_URL="https://github.com/msm8916-mainline/lk2nd/releases/download/22.0/lk2nd-msm8953.img"
LK2ND_SHA256="79dfe0e49238612bd27cde0d0f2b88c7b65d8917b1673df7529d494e93eeeb3c"
DTBO_URL="https://github.com/z3ntu/dtbo-fp3/releases/download/v1.0/dtbo.img"
DTBO_SHA256="83c9b35c73051f04724ab6ba32c333a9c8f5f258454473e56a7597a4d4563431"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fp3-flash"

# devinfo partition with the unlocked flag set. The stock bootloader
# accepts it while locked, so no Android OEM unlocking step is needed.
DEVINFO="$REPO_DIR/scripts/devinfo-unlocked.gpx"

IMAGE="$REPO_DIR/nerves_livebook_fp3.img"
SERIAL=""
BUILD=false
LOOP=false
YES=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

  -i, --image PATH   firmware image to write to userdata
                     (default: nerves_livebook_fp3.img in the repo)
  -b, --build        build the image first (mix firmware + mix firmware.image);
                     FP3_WIFI_SSID, FP3_WIFI_PASSPHRASE and FP3_APN are passed
                     through to the build
  -s, --serial SN    flash this phone when several are plugged in
  -l, --loop         after each phone, wait for the next one
  -y, --yes          don't ask before erasing
  -n, --dry-run      detect the phone and print the commands without running them
  -h, --help         show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -i|--image) IMAGE="$2"; shift 2 ;;
    -b|--build) BUILD=true; shift ;;
    -s|--serial) SERIAL="$2"; shift 2 ;;
    -l|--loop) LOOP=true; shift ;;
    -y|--yes) YES=true; shift ;;
    -n|--dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

for tool in fastboot curl sha256sum; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

# Check a file's SHA-256. Compares the hash as a string because the
# sha256sum that ships with macOS doesn't take GNU's --check --status.
sha_ok() {
  [ -f "$2" ] && [ "$(sha256sum "$2" | awk '{print $1}')" = "$1" ]
}

# Download a pinned file into the cache and check its hash.
fetch() {
  local url="$1" sha="$2" dest="$CACHE_DIR/$3"
  mkdir -p "$CACHE_DIR"
  if ! sha_ok "$sha" "$dest"; then
    echo "Downloading $url"
    curl -fsSL -o "$dest.part" "$url"
    mv "$dest.part" "$dest"
  fi
  sha_ok "$sha" "$dest" || die "checksum mismatch for $dest"
}

# fastboot prints variables on stderr as "name: value". An unknown
# variable makes fastboot fail, which here just means an empty value.
getvar() {
  { fastboot -s "$1" getvar "$2" 2>&1 || true; } | sed -n "s/^$2: *//p" | head -n1 || true
}

run() {
  echo "+ $*"
  if ! $DRY_RUN; then "$@"; fi
}

# Wait for a phone in fastboot mode and print its serial number. Serials
# in $FLASHED are skipped so --loop waits for a new phone.
FLASHED=" "
wait_for_phone() {
  local shown=false serial
  while true; do
    if [ -n "$SERIAL" ]; then
      serial=$(fastboot devices | awk -v s="$SERIAL" '$1 == s {print $1}')
    else
      serial=$(fastboot devices | awk '{print $1}' | while read -r s; do
        case "$FLASHED" in (*" $s "*) ;; (*) echo "$s" ;; esac
      done | head -n1)
    fi
    if [ -n "$serial" ]; then
      echo "$serial"
      return
    fi
    # A phone booted into Android with USB debugging on can be sent
    # to fastboot directly.
    if command -v adb >/dev/null && adb get-state >/dev/null 2>&1; then
      echo "Android phone found over adb, rebooting it into fastboot" >&2
      adb reboot bootloader >/dev/null 2>&1 || true
    elif ! $shown; then
      echo "Waiting for a phone in fastboot mode: power it off, hold Volume Down, plug in USB..." >&2
      shown=true
    fi
    sleep 2
  done
}

confirm() {
  $YES && return
  read -r -p "$1 [y/N] " answer </dev/tty
  case "$answer" in y|Y|yes|YES) ;; *) die "cancelled" ;; esac
}

flash_phone() {
  local sn="$1" lk2nd unlocked

  lk2nd=$(getvar "$sn" "lk2nd:version")
  if [ -n "$lk2nd" ]; then
    say "Phone $sn runs lk2nd $lk2nd: writing the firmware to userdata"
    confirm "This erases everything on the phone's userdata (notebooks, models). Continue?"
    run fastboot -s "$sn" flash userdata "$IMAGE"
    run fastboot -s "$sn" reboot
    return
  fi

  [ "$(getvar "$sn" product)" = "FP3" ] || \
    echo "Warning: product is '$(getvar "$sn" product)', expected FP3" >&2

  unlocked=$(getvar "$sn" unlocked)
  say "Phone $sn has the stock bootloader (unlocked: ${unlocked:-unknown})"
  confirm "This erases the whole phone and replaces Android with the workshop firmware. Continue?"

  if [ "$unlocked" != "yes" ]; then
    say "Unlocking the bootloader"
    run fastboot -s "$sn" flash devinfo "$DEVINFO"
    # The bootloader reads devinfo only at startup.
    run fastboot -s "$sn" reboot bootloader
    if ! $DRY_RUN; then
      until [ "$(getvar "$sn" unlocked 2>/dev/null)" = "yes" ]; do
        echo "Waiting for the phone to come back unlocked in fastboot mode..."
        sleep 3
      done
    fi
  fi

  say "Installing lk2nd and the workshop firmware"
  run fastboot -s "$sn" set_active a
  run fastboot -s "$sn" flash dtbo "$CACHE_DIR/dtbo.img"
  run fastboot -s "$sn" flash boot "$CACHE_DIR/lk2nd-msm8953.img"
  run fastboot -s "$sn" flash userdata "$IMAGE"
  run fastboot -s "$sn" reboot
}

if $BUILD; then
  say "Building the firmware image"
  (cd "$REPO_DIR" && MIX_TARGET=nerves_system_fp3 mix firmware && \
     MIX_TARGET=nerves_system_fp3 mix firmware.image "$IMAGE")
fi
[ -f "$IMAGE" ] || die "no firmware image at $IMAGE (run with --build, or pass --image)"
[ -f "$DEVINFO" ] || die "no devinfo image at $DEVINFO"

say "Checking lk2nd and dtbo"
fetch "$LK2ND_URL" "$LK2ND_SHA256" lk2nd-msm8953.img
fetch "$DTBO_URL" "$DTBO_SHA256" dtbo.img

while true; do
  sn=$(wait_for_phone)
  flash_phone "$sn"
  FLASHED="$FLASHED$sn "
  say "Done with $sn. The phone boots the workshop firmware; Livebook is at http://nerves.local once it's on the network."
  $LOOP || break
  echo "Unplug it and plug in the next phone."
done
