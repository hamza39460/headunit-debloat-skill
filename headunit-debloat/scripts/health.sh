#!/bin/bash
# Quick check after each batch: memory, car processes still alive, recent crashes and ANRs.
# Usage: ./health.sh [process_name ...]     e.g. ./health.sh com.my.out com.car.ui com.my.bt gocsdk_210
set -u

: "${ANDROID_SERIAL:?Set ANDROID_SERIAL, e.g. export ANDROID_SERIAL=192.168.1.50:5555}"
export ANDROID_SERIAL
adb connect "$ANDROID_SERIAL" >/dev/null 2>&1

run() { adb shell "$@" </dev/null | tr -d '\r'; }

run cat /proc/meminfo | awk '
  $1 == "MemTotal:"     { t = $2 }
  $1 == "MemAvailable:" { a = $2 }
  $1 == "SwapTotal:"    { st = $2 }
  $1 == "SwapFree:"     { sf = $2 }
  END { printf "RAM:      %d MB available of %d MB\nSwap:     %d MB free of %d MB\n", a/1024, t/1024, sf/1024, st/1024 }'
echo "Disabled: $(run pm list packages -d | grep -c .) packages"
echo "Uptime:  $(run uptime)"

if [ $# -gt 0 ]; then
  echo "Car processes:"
  for p in "$@"; do
    if [ -n "$(run pidof "$p")" ]; then echo "  ok        $p"; else echo "  NOT RUNNING  $p"; fi
  done
fi

echo "Recent crashes:"
run logcat -b crash -d -t 20 | grep -E 'FATAL|Process:' | tail -10 | sed 's/^/  /'
echo "Recent ANRs:"
run logcat -d | grep -E 'ANR in' | tail -5 | sed 's/^/  /'
echo "(Empty sections = nothing found.)"
