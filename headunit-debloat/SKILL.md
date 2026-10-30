---
name: headunit-debloat
description: Safely debloat and speed up an aftermarket Android car head unit (PX5/PX6, FYT, Topway, TS10, MTCD, "Alpine"/"Pioneer" clones and similar Chinese car stereos) over ADB, with backups, an undo script and small approved batches, and optionally get wired Apple CarPlay working with DiPlay. Use this whenever the user wants to make a car stereo, Android radio, car screen or head unit faster, free up its RAM, disable or remove its bloatware, connect to it with adb, fix slow CarPlay connection on it, or add CarPlay to an Android head unit, even if they never say "debloat".
---

# Head unit debloat

Aftermarket Android head units ship with old Android, 1–4 GB of RAM and a pile of apps nobody uses. Disabling the junk makes them much faster. The danger is that the same firmware also runs the reverse camera, radio, Bluetooth calls, steering-wheel buttons and canbus, often through vendor apps with cryptic names. Breaking one of those in a car is worse than a slow screen, so this skill trades speed of work for safety at every step.

The owner is usually a hobbyist sitting in (or near) their car. Keep explanations short and easy to scan: tables and one-line reasons, not essays.

## Hard rules

These exist because the owner may have no way to reflash the unit, and some of these units have no recovery mode at all.

- Only disable with `pm disable-user --user 0 <pkg>`. Never `pm uninstall`, never delete files, never remount or write to `/system` or `/vendor`, never flash anything. A disabled package comes back with one command; an uninstalled system package may not.
- Never disable anything car-critical. Read `references/classify.md` for the keep patterns. If unsure, it is KEEP and you ask.
- Work in batches of 5–8 packages. Before each batch, show the list with a one-line reason per package and wait for a clear yes.
- Back up before the first change and create the undo script before the first `disable`.
- Don't change "Don't keep activities" or the background process limit. They make these units unstable.
- Don't help bypass the "no video while driving" block (handbrake wire, vendor props). It's a safety feature.
- Google Play Services, Services Framework and TTS are KEEP by default. Only disable them if the owner explicitly asks after hearing the consequences: no Play Store, no Google Maps, no voice guidance, Find My Device off.

## Setup

All scripts are in `scripts/`. They need `adb` on the computer and read the device address from `ANDROID_SERIAL` (or from `device.txt` in the work folder, which `backup.sh` writes).

- Work folder: `~/headunit-debloat/` unless the owner picks another. Backups, the log, `disabled.txt` and the owner's copy of `undo.sh` live there.
- If the owner can't connect yet, walk them through "Getting ADB access" below.

Shell pitfalls that waste time on macOS (zsh):
- `adb shell` swallows stdin. In any `while read` loop, add `</dev/null` to every `adb shell` call or the loop stops after one line.
- zsh doesn't word-split variables, so `ADB="adb -s x"; $ADB shell` fails. Export `ANDROID_SERIAL` instead.
- Don't name a variable `path` in zsh; it is tied to `PATH`.
- macOS has no `timeout`. Run the command in the background and `kill` it.
- `adb shell` output ends lines with `\r`. Pipe through `tr -d '\r'` before comparing.

## Workflow

### 1. Connect and look around (read-only)

```bash
export ANDROID_SERIAL=<ip>:5555
adb connect "$ANDROID_SERIAL"
```

Then ask the owner what they actually use. This changes the whole classification. Typical answers: Bluetooth music and calls, reverse camera, radio, one navigation app, CarPlay/Android Auto through an app or dongle, the DVR. Ask specifically whether they use Google Maps or the Play Store, because that decides the Google question.

### 2. Back up

```bash
scripts/backup.sh ~/headunit-debloat
```

This saves package lists (all, system, third-party, disabled, with APK paths), `getprop`, all settings tables, memory, disk and running processes into a timestamped folder. It changes nothing on the unit. Record the baseline numbers from it: `MemAvailable`, free swap, uptime, the default launcher and keyboard.

Then find out which apps own the car functions, so you know their names before classifying:
- Running processes (`processes.txt`): vendor services usually run all the time.
- Reverse camera: `adb shell dumpsys media.camera` lists camera clients. Also look for activities named Reverse, BackCar, AVM or Camera in `adb shell dumpsys package <pkg>`.
- Bluetooth: many units use a separate module with its own daemon (for example `gocsdk`), not Android Bluetooth. Note which app talks to it.
- Projection or CarPlay: look for zlink, autokit, carlink, tlink, easyconn, carbit or mirror in package names. If CarPlay already works through one of these, it's KEEP.
- Default home: `adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME`.

### 3. Classify

Write `classification.md` in the work folder with four groups, each package with what it is and why. Follow `references/classify.md`. The groups:

| Group | Meaning |
|---|---|
| SAFE | Nothing in the car uses it, and the owner doesn't |
| ASK | Depends on how the owner uses the car (Google apps, nav apps, mirroring) |
| RISKY | Probably fine, but little gain or unclear dependencies. Leave alone |
| KEEP | Car-critical, core Android, or matches a keep pattern |

Show the RAM hogs from `dumpsys_meminfo.txt` next to the ASK group. That's where the big wins usually are, and it helps the owner decide.

`references/example-px5.md` is a worked example from one real unit. Use it to see what the result looks like. Don't copy its verdicts to another unit: vendor package names mean different things on different firmware.

Stop here and let the owner review before anything is disabled.

### 4. Create the undo script

```bash
cp scripts/undo.sh ~/headunit-debloat/undo.sh
```

`undo.sh` re-enables everything listed in `disabled.txt` in its own folder, or only the packages you name. Tell the owner the two commands they'd need in a panic:

```bash
~/headunit-debloat/undo.sh                 # everything back
~/headunit-debloat/undo.sh com.example.app # one package back
```

### 5. Disable in batches

Group packages so a broken function is easy to trace: wallpapers and toys first, then unused stock apps, then printing, then the ASK items the owner approved.

```bash
scripts/disable.sh ~/headunit-debloat "Batch 1: live wallpapers" pkg1 pkg2 ...
```

`disable.sh` disables each package, checks that it reports `disabled-user`, and appends it to `disabled.txt` with the batch name, so the undo list can never drift from what was really done. It refuses any name that matches a keep pattern. Substring matching over-matches on purpose: `com.android.printspooler` contains "ts", for example. If the owner has confirmed such a package, pass `--allow-keep` and say in the log why it's actually safe.

After each batch:

```bash
scripts/health.sh
```

It shows memory, whether the car processes you noted in step 2 are still alive (pass their names as arguments), and any crash or ANR in the log. Then ask the owner to test the car functions they use, or to batch the testing at the end if they prefer. Say clearly which way you're going.

### 6. Log everything

Keep `log.md` in the work folder: baseline numbers, each batch with its packages, the health check results, test results, and anything surprising. The owner (or a future session) should be able to read it and know exactly what state the unit is in.

### 7. Final check

- Reboot with `adb reboot`. A key-off is usually only sleep on these units, so check `uptime` to be sure it really rebooted.
- Run `health.sh` again, compare memory with the baseline, and confirm wireless ADB came back.
- Ask the owner to test everything once more: reverse camera, Bluetooth music and calls, radio, steering-wheel buttons, plus any app they use.

## Optional: CarPlay

If the owner wants Apple CarPlay and the unit doesn't already have it, read `references/carplay.md`. It covers:
- installing DiPlay (open source) for wired CarPlay
- checking whether wireless is possible on this hardware
- fixing slow connections and drops by reading the logs
- the panel HOME/BACK buttons

Add anything you install to `installed.txt` in the work folder, one package per line, so `undo.sh --remove-installed` can take it off again.

## Getting ADB access

Most of these units turn on ADB over the network at boot, even when Developer options look off. Try that first:

1. Find the unit's IP address: Settings → Wi-Fi → tap the connected network, or the router's device list. The unit and the computer must be on the same Wi-Fi.
2. Run `adb connect <ip>:5555`. If an "Allow USB debugging?" prompt appears on the head unit, tap Allow.

If that's refused:
- Open Developer options: Settings → About → tap "Build number" 7 times, then turn on USB debugging (and "ADB over network" if listed).
- If the build number tap is locked, install Activity Launcher (`de.szalkowski.activitylauncher`, from F-Droid or the Play Store) from a USB stick. Open it, search for Settings and launch "Developer options" directly.
- On Android 11+, use Settings → Developer options → Wireless debugging → "Pair device with pairing code", then `adb pair <ip>:<pair-port>` followed by `adb connect`.
- Some brands hide Developer options behind a factory-settings code. The owner can find it in their unit's forum thread. Don't guess codes; factory menus can also change hardware settings.

Warn the owner once: with network ADB on, anyone on the same Wi-Fi can control the unit, often as root. Use it only on trusted networks.
