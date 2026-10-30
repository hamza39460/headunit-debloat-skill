# CarPlay on an Android head unit

Read this when the owner wants Apple CarPlay on a unit that doesn't already have it, or when their CarPlay is slow to connect or drops.

## First: does the unit already have it?

Many units already do CarPlay through a vendor app (ZLink, AutoKit, TLink, Carbit, EasyConnection), sometimes with a USB dongle. If CarPlay already works, don't install another CarPlay app. Make sure the existing one is KEEP, and skip to "Slow connection and drops" if that's the problem.

## Wired CarPlay with DiPlay

DiPlay (https://github.com/shihabal3amri/DiPlay) is an open-source CarPlay receiver for Android head units, based on xcertplay (https://github.com/shilapi/xcertplay). It works over a USB cable with no extra hardware. It's an unofficial preview: not from Apple, and an iOS update could break it. Tell the owner that up front.

Before installing:
- Android version: check the release's minimum SDK against `getprop ro.build.version.sdk` (0.2.x needs Android 7+).
- CPU: check `getprop ro.product.cpu.abilist` against the ABIs the release supports.

Install:
1. Download the APK and the `SHA256SUMS` file from the GitHub release page. Have the owner approve the download (name, source, size).
2. Verify the checksum (`shasum -a 256 <apk>` on macOS) and compare it with `SHA256SUMS`. Don't install if it doesn't match.
3. `adb install -r <apk>`, then add `com.shihab.diplay` to `installed.txt` in the work folder.
4. The owner plugs in the iPhone and accepts the prompts on the phone.

When the iPhone is plugged in, Android may ask which app to open for it. Choosing DiPlay with "Always" makes CarPlay start automatically.

DiPlay turns on its own accessibility services (USB auto-confirm, wheel keys). Leave them alone.

## Can it go wireless?

Every DiPlay wireless mode needs the iPhone paired with the head unit's **Android** Bluetooth, because the Wi-Fi details are sent over Bluetooth. Pairing in the car's own Bluetooth app doesn't count. Check, read-only:

```bash
adb shell ls /sys/class/bluetooth/                       # empty = Android has no BT controller
adb shell dumpsys bluetooth_manager | head -40           # state, enable attempts
adb shell settings get global bluetooth_on
```

Many units run phone Bluetooth through a separate module with its own daemon (for example Goodocom `gocsdk` on a serial port). In that case Android Bluetooth has no radio, every enable attempt times out, and **wireless CarPlay through DiPlay is impossible**. Don't try to take the serial port away from the vendor daemon or install driver libraries in `/vendor`. It breaks the car's calls and music and goes against the no-`/system` rule.

Wi-Fi matters too. Many cheap units have a 2.4 GHz-only USB Wi-Fi chip (for example RTL8188EU). CarPlay over 2.4 GHz may work but lags.

If wireless isn't possible, the alternative is an external wireless CarPlay adapter (Carlinkit-style), which has its own Bluetooth and Wi-Fi. Mention it; don't push it.

## Slow connection and drops

Read the logs before guessing:

```bash
adb shell dmesg | grep -iE 'usb|hub|disconnect|EMI' | tail -50
adb shell logcat -d | grep -iE 'diplay|iap2|carplay|ncm' | tail -100
adb shell cat /data/data/com.shihab.diplay/files/logs/diplay.log | tail -200   # needs root adb (userdebug builds)
```

Patterns and fixes:

| What the log shows | Likely cause | Fix |
|---|---|---|
| iPhone disconnects and re-enumerates in a loop | Port behind the unit's internal USB hub, or a long or poor cable | Use the port wired straight to the SoC (see below), a short good cable |
| `disabled by hub (EMI?)` | Power or electrical noise on the hub | Lower charging current, a different port; if both USB controllers reset together, it's power/ground |
| Wi-Fi turns off when CarPlay connects or drops | The Wi-Fi chip sits on the same internal hub. A hub reset kills Wi-Fi, and Android leaves it off | Move the phone to the direct port; turn Wi-Fi back on |
| Connection starts, then stops after ~30 s | iPhone locks the screen during setup | iPhone Settings → Display & Brightness → Auto-Lock → Never while testing |

Find which port is direct:

```bash
adb shell 'for d in /sys/bus/usb/devices/*; do [ -f $d/idVendor ] && echo "$(basename $d) $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/product 2>/dev/null)"; done'
```

Apple devices show as vendor `05ac`. A path like `1-1.3` sits behind a hub (`1-1`); a path like `3-1` hangs straight off a root controller. Ask the owner to try each physical port and run it again. On one PX5 unit the dashboard port with a "3G/USB" sticker was the direct one.

DiPlay also has a charging setting: Settings → USB connection → iPhone charging (Normal / Reduced / Low). Low draws the least current and helps on weak ports.

On that PX5 unit, the direct port plus Low charging plus Auto-Lock off took the first picture from about a minute to about 4 seconds.

## Panel buttons

On most units the panel HOME and BACK buttons arrive as normal Android key events, so:
- HOME opens the Android launcher.
- BACK goes to DiPlay, which may leave the CarPlay screen.

DiPlay 0.2.x has Settings → Vehicle → Wheel keys → "External controller (experimental)", which sends hardware BACK to CarPlay as its own Back. Check the setting still exists in the installed version before telling the owner about it.

If the owner wants HOME to always return to CarPlay, a small home-screen app that opens DiPlay when an iPhone is attached can do it. Build it only if they ask, and only if they understand it replaces the default launcher (undo with `cmd package set-home-activity <original launcher>`).

## Video while driving

Many units blank video when the car moves (a handbrake wire or a speed signal). If CarPlay goes white or blank while driving, that block is the cause. Point the owner to the unit's and DiPlay's own documentation. Don't tamper with the handbrake wiring or vendor system properties, and don't help work around the block.
