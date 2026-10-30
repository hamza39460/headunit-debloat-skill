# headunit-debloat

A [Claude Code](https://claude.com/claude-code) skill that safely cleans up and speeds up cheap Android car head units (PX5/PX6, FYT, Topway, TS10, MTCD and the many "Alpine"/"Pioneer" clones) over ADB. It can also help you get wired Apple CarPlay working with [DiPlay](https://github.com/shihabal3amri/DiPlay).

I built this after doing it on my own car. The unit in my 2025 Corolla Altis 1.6 had ~650 MB of free RAM and was too slow to use. After the debloat it has ~1.5 GB free and runs CarPlay. The write-up is in [BLOG.md](BLOG.md).

## What it does

You tell Claude Code something like *"my head unit is at 192.168.1.50:5555, help me debloat it"*, and the skill makes it follow a careful process:

1. Connects over Wi-Fi ADB and asks what you actually use in the car
2. Backs up package lists, settings and memory stats before touching anything
3. Classifies every package as SAFE / ASK / RISKY / KEEP, with a reason for each
4. Creates an `undo.sh` that puts everything back
5. Disables apps in small batches (5–8), asking you before each one
6. Checks memory, car processes and crash logs after each batch
7. Keeps a log of everything it did
8. Optionally: wired CarPlay with DiPlay, plus fixes for slow connections

## Safety rules

- Only `pm disable-user`. It never uninstalls, never deletes files, never touches `/system`, never flashes anything. Anything it disables comes back with one command.
- Anything that looks car-related (camera, reverse, canbus, mcu, bt, radio, swc, dvr, launcher, audio...) is KEEP unless you say otherwise. The scripts enforce this too.
- Google Play Services stays unless you explicitly ask, after it explains what you'd lose.

**Tested on one unit only** (PX5, Android 8.0, "ak" firmware). The process is generic and Claude asks when it sees something it doesn't recognize, but your unit may differ. You use this at your own risk. If you try it on another unit, please open an issue with what worked and what didn't.

## Install

You need [Claude Code](https://claude.com/claude-code) and `adb` (Android platform tools; on a Mac: `brew install android-platform-tools`).

```bash
git clone https://github.com/hamza39460/headunit-debloat-skill.git
mkdir -p ~/.claude/skills
cp -r headunit-debloat-skill/headunit-debloat ~/.claude/skills/
```

Then open Claude Code anywhere and ask it to debloat your head unit.

Works on macOS and Linux. On Windows, use WSL or Git Bash.

## Getting ADB access to the head unit

You need ADB working before anything else. Make sure the head unit and your laptop are on the same Wi-Fi (your phone hotspot works fine).

### 1. Try connecting directly first

On a lot of Chinese head units, ADB over Wi-Fi is already on, even when Developer options are hidden or turned off. Mine was like that: the firmware opens port 5555 at every boot.

1. Find the head unit's IP: Settings → Wi-Fi → tap the connected network. Or check your router's / hotspot's connected devices.
2. Connect:
   ```bash
   adb connect 192.168.1.50:5555
   adb devices
   ```
3. If the head unit shows an "Allow USB debugging?" popup, tap **Allow**.

If `adb devices` shows the unit as `device`, you're done. Skip the rest.

### 2. If that's refused: turn on Developer options

The normal way is Settings → About → tap **Build number** 7 times, then Developer options → turn on **USB debugging** (and **ADB over network** if your unit has it).

On my unit the build number tap was locked, so Developer options couldn't be opened from Settings. What worked:

1. Put the [Activity Launcher](https://f-droid.org/packages/de.szalkowski.activitylauncher/) APK on a USB stick (or install it from the Play Store if your unit has it).
2. Install it with the unit's file manager or APK installer.
3. Open Activity Launcher, search for **Settings**, and open **Developer options** (the activity is usually `com.android.settings.Settings$DevelopmentSettingsActivity`).
4. Turn on USB debugging, then go back to step 1.

### 3. Android 11 and newer

Use Developer options → **Wireless debugging** → **Pair device with pairing code**, then:

```bash
adb pair 192.168.1.50:<pairing port>     # enter the code shown on the screen
adb connect 192.168.1.50:<port shown under Wireless debugging>
```

### A word on security

With network ADB on, anyone on the same Wi-Fi can control the head unit, and on many of these units ADB runs as root. Only connect it to networks you trust.

## What's in here

```
headunit-debloat/              the skill (copy this folder to ~/.claude/skills/)
  SKILL.md                     rules and step-by-step workflow
  scripts/backup.sh            read-only snapshot of the unit
  scripts/disable.sh           disables a batch and records it for undo
  scripts/undo.sh              puts everything back
  scripts/health.sh            memory, car processes, crashes after each batch
  references/classify.md       how to sort packages into SAFE / ASK / RISKY / KEEP
  references/carplay.md        DiPlay, wireless check, slow connection fixes
  references/example-px5.md    my unit, as a worked example
BLOG.md                        the story of how this started
```

You can also run the scripts without Claude:

```bash
export ANDROID_SERIAL=192.168.1.50:5555
headunit-debloat/scripts/backup.sh ~/headunit-debloat
headunit-debloat/scripts/disable.sh ~/headunit-debloat "Batch 1: wallpapers" com.android.galaxy4 com.android.noisefield
headunit-debloat/scripts/health.sh
cp headunit-debloat/scripts/undo.sh ~/headunit-debloat/ && ~/headunit-debloat/undo.sh
```

## Credits

- [DiPlay](https://github.com/shihabal3amri/DiPlay) by shihabal3amri, the CarPlay receiver that makes the CarPlay part possible
- [xcertplay](https://github.com/shilapi/xcertplay), which DiPlay is based on
- [Activity Launcher](https://github.com/butzist/ActivityLauncher)

Not affiliated with Apple, Toyota, Alpine or any head unit maker. CarPlay is a trademark of Apple Inc.

## License

MIT
