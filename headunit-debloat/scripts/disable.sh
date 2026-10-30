#!/bin/bash
# Disables packages for user 0 and records each one in <work_dir>/disabled.txt, which undo.sh reads.
# Usage: ./disable.sh <work_dir> "<batch note>" [--allow-keep] <pkg> ...
#   --allow-keep  let through names that match a keep pattern (only after the owner confirmed them)
set -u

if [ $# -lt 3 ]; then
  echo "Usage: $0 <work_dir> \"<batch note>\" [--allow-keep] <pkg> ..."
  exit 1
fi
WORK="$1"; NOTE="$2"; shift 2
ALLOW_KEEP=0
if [ "$1" = "--allow-keep" ]; then ALLOW_KEEP=1; shift; fi

if [ -z "${ANDROID_SERIAL:-}" ] && [ -f "$WORK/device.txt" ]; then ANDROID_SERIAL="$(cat "$WORK/device.txt")"; fi
: "${ANDROID_SERIAL:?Set ANDROID_SERIAL or run backup.sh first}"
export ANDROID_SERIAL
adb connect "$ANDROID_SERIAL" >/dev/null 2>&1

# Same list as references/classify.md. Substrings on purpose: a false KEEP only costs some RAM.
KEEP='syu|fyt|ts|tw|canbus|can|mcu|car|launcher|home|radio|fm|bt|bluetooth|phone|dialer|telecom|systemui|settings|inputmethod|keyboard|camera|avm|reverse|backcar|dvr|steer|swc|amp|eq|audio|media|gps|navi|providers|packageinstaller|permissioncontroller|webview|gms|gsf'

LIST="$WORK/disabled.txt"
[ -f "$LIST" ] || echo "# Packages disabled on $ANDROID_SERIAL. undo.sh re-enables these." > "$LIST"
echo "# $NOTE — $(date '+%Y-%m-%d %H:%M')" >> "$LIST"

for pkg in "$@"; do
  if [ "$pkg" = "android" ]; then echo "REFUSED   $pkg (framework)"; continue; fi
  if [ $ALLOW_KEEP -eq 0 ] && echo "$pkg" | grep -qiE "$KEEP"; then
    echo "REFUSED   $pkg (matches keep pattern '$(echo "$pkg" | grep -oiE "$KEEP" | head -1)'; needs --allow-keep)"
    continue
  fi
  out=$(adb shell pm disable-user --user 0 "$pkg" </dev/null 2>&1 | tr -d '\r')
  if echo "$out" | grep -q "new state: disabled-user"; then
    grep -qxF "$pkg" <(grep -v '^#' "$LIST" | awk '{print $1}') || echo "$pkg" >> "$LIST"
    echo "disabled  $pkg"
  else
    echo "FAILED    $pkg: $out"
  fi
done
