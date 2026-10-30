#!/bin/bash
# Re-enables packages disabled during the head unit debloat.
# Reads disabled.txt (and installed.txt) from the folder this script is in.
# Usage: ./undo.sh                    -> re-enable everything in disabled.txt
#        ./undo.sh <pkg> ...          -> re-enable only the given packages
#        ./undo.sh --remove-installed -> uninstall apps listed in installed.txt
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${ANDROID_SERIAL:-}" ] && [ -f "$DIR/device.txt" ]; then ANDROID_SERIAL="$(cat "$DIR/device.txt")"; fi
: "${ANDROID_SERIAL:?Set the unit address, e.g. export ANDROID_SERIAL=192.168.1.50:5555}"
export ANDROID_SERIAL
adb connect "$ANDROID_SERIAL" >/dev/null 2>&1

# One package per line; "#" starts a comment.
read_list() { [ -f "$1" ] && grep -v '^[[:space:]]*#' "$1" | awk 'NF {print $1}'; }

if [ "${1:-}" = "--remove-installed" ]; then
  for pkg in $(read_list "$DIR/installed.txt"); do
    echo "$pkg -> $(adb uninstall "$pkg" </dev/null 2>&1 | tr -d '\r')"
  done
  exit 0
fi

if [ $# -gt 0 ]; then TARGETS=("$@"); else TARGETS=($(read_list "$DIR/disabled.txt")); fi
if [ ${#TARGETS[@]} -eq 0 ]; then echo "Nothing to re-enable ($DIR/disabled.txt is empty or missing)."; exit 0; fi

for pkg in "${TARGETS[@]}"; do
  if adb shell pm enable "$pkg" </dev/null 2>&1 | grep -q "new state: enabled"; then
    echo "enabled   $pkg"
  elif adb shell cmd package install-existing "$pkg" </dev/null 2>&1 | grep -qi "installed"; then
    echo "restored  $pkg"
  else
    echo "FAILED    $pkg"
  fi
done

echo "Done. Reboot the head unit to be sure everything is back."
echo "If you re-enabled com.google.android.gms: turn Find My Device back on in Settings > Security > Device admin apps."
