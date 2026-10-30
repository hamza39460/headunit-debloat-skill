#!/bin/bash
# Read-only snapshot of a head unit before any change. Changes nothing on the unit.
# Usage: ANDROID_SERIAL=<ip>:5555 ./backup.sh [work_dir]     (work_dir defaults to ~/headunit-debloat)
set -u

: "${ANDROID_SERIAL:?Set the unit address first, e.g. export ANDROID_SERIAL=192.168.1.50:5555}"
export ANDROID_SERIAL
WORK="${1:-$HOME/headunit-debloat}"
OUT="$WORK/backup-$(date +%Y%m%d-%H%M%S)"

adb connect "$ANDROID_SERIAL" >/dev/null 2>&1
if [ "$(adb get-state 2>/dev/null)" != "device" ]; then
  echo "Can't reach $ANDROID_SERIAL. Is ADB on and the unit on the same Wi-Fi?"
  exit 1
fi

mkdir -p "$OUT"
echo "$ANDROID_SERIAL" > "$WORK/device.txt"

# adb shell eats stdin and ends lines with \r
run() { adb shell "$@" </dev/null | tr -d '\r'; }
pkgs() { run pm list packages "$@" | sed 's/^package://' | sort; }

pkgs        > "$OUT/all.txt"
pkgs -s     > "$OUT/system.txt"
pkgs -3     > "$OUT/third_party.txt"
pkgs -d     > "$OUT/disabled.txt"
pkgs -u     > "$OUT/all_incl_uninstalled.txt"
# "package:/system/app/X/X.apk=com.x" -> "com.x<TAB>/system/app/X/X.apk"
run pm list packages -f | awk '{ sub(/^package:/, ""); i = match($0, /=[^=]*$/);
  print substr($0, i + 1) "\t" substr($0, 1, i - 1) }' | sort > "$OUT/all_with_paths.txt"

run getprop                  > "$OUT/getprop.txt"
run settings list global     > "$OUT/settings_global.txt"
run settings list secure     > "$OUT/settings_secure.txt"
run settings list system     > "$OUT/settings_system.txt"
run cat /proc/meminfo        > "$OUT/meminfo.txt"
run dumpsys meminfo          > "$OUT/dumpsys_meminfo.txt"
run df -h                    > "$OUT/df.txt"
run ps -A                    > "$OUT/processes.txt"
run uptime                   > "$OUT/uptime.txt"
run dumpsys media.camera     > "$OUT/camera.txt" 2>/dev/null
run cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME > "$OUT/home.txt"

mem() { awk -v k="$1" '$1 == k":" { printf "%d MB", $2 / 1024 }' "$OUT/meminfo.txt"; }
echo "Backup: $OUT"
echo "Model:     $(grep -m1 'ro.product.model' "$OUT/getprop.txt" | cut -d'[' -f3 | tr -d ']')"
echo "Android:   $(grep -m1 'ro.build.version.release' "$OUT/getprop.txt" | cut -d'[' -f3 | tr -d ']')"
echo "Packages:  $(wc -l < "$OUT/all.txt" | tr -d ' ') total, $(wc -l < "$OUT/third_party.txt" | tr -d ' ') user-installed, $(wc -l < "$OUT/disabled.txt" | tr -d ' ') already disabled"
echo "RAM:       $(mem MemAvailable) available of $(mem MemTotal)"
echo "Swap:      $(mem SwapFree) free of $(mem SwapTotal)"
echo "Uptime:   $(cat "$OUT/uptime.txt")"
