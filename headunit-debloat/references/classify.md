# Classifying head unit packages

Read this before writing `classification.md`. The goal is a list the owner can review in two minutes and trust.

## Keep patterns

A package whose name contains any of these is KEEP unless the owner explicitly says otherwise after you explain what it does:

```
syu fyt ts tw canbus can mcu car launcher home radio fm bt bluetooth phone dialer telecom
systemui settings inputmethod keyboard camera avm reverse backcar dvr steer swc amp eq audio
media gps navi providers packageinstaller permissioncontroller webview gms gsf
```

Plus anything that is core Android framework (`android`, `com.android.shell`, `com.android.keychain`, `ext.services`, `ext.shared`, network and certificate helpers).

These are deliberately broad substrings, so they over-match: `tts`, `contacts` and `printspooler` contain "ts", `scan` contains "can", `googlequicksearchbox` contains "eq". That's fine. A false KEEP costs a few MB of RAM; a false SAFE can kill the reverse camera. When a match is clearly accidental, put the package in ASK with the reason, and let the owner decide.

`scripts/disable.sh` enforces the same list, so a package that slipped through will be refused until you pass `--allow-keep`.

## Vendor prefixes

Vendor apps rarely have helpful names. Some common prefixes:

| Prefix | Usually |
|---|---|
| `com.syu.*`, `com.fyt.*` | FYT units (UIS7862, SC9853i) |
| `com.ts.*`, `com.tw.*` | Topway / TS10 family |
| `com.microntek.*` | MTCD / MTCE (PX5 Android 8–10) |
| `com.my.*`, `com.car.*`, `com.ak.*` | "ak" firmware PX5 units |
| `com.nwd.*`, `com.hct.*`, `com.zxw.*` | other OEMs |

Treat every vendor app as KEEP or RISKY by default. Only call one SAFE if it's obviously cosmetic (a manual, a demo video) and nothing running depends on it. When you're not sure what a vendor app does, check:
- `adb shell dumpsys package <pkg>`: activities, services, receivers and permissions. A service that starts at boot, or permissions like CAMERA, RECORD_AUDIO or serial access, mean it does real work.
- Whether it's running right now (`processes.txt` from the backup).
- `adb shell dumpsys media.camera` for camera clients (the reverse camera app).

## What usually lands where

**SAFE** (if the owner doesn't use them):
- live wallpapers, the wallpaper picker, screensaver ("dreams"), the Android Easter egg
- printing (`bips`, `printspooler`, `printservice.recommendation`)
- stock Email, Calendar app (not the calendar *provider*), Calculator, old Quick Search Box, bookmark provider
- extra keyboards that aren't the active one
- work-profile setup (`managedprovisioning`)
- Google feedback and partner setup
- old ES File Explorer 3.x (it has a known remote file access hole, CVE-2019-6447)

**ASK** (big RAM wins, but depend on the owner):
- Google app / "OK Google" (`googlequicksearchbox`). Often always running.
- Gmail, YouTube, Chrome (check Chrome isn't the WebView provider)
- bundled navigation apps (Sygic, iGo)
- phone mirroring apps (EasyConnection, Carbit, ZLink, AutoKit). **KEEP if CarPlay or Android Auto runs through them.**
- vendor voice assistants. Check whether a steering-wheel voice button uses it first.
- Play Store

**RISKY** (leave alone, little gain):
- setup wizard stubs and one-time initializers. Disabling can break the Home button on some firmware.
- backup helpers, storage manager, HTML viewer, captive portal login, companion device manager
- Gallery (may be how DVR clips are viewed), deskclock (may feed the home-screen clock), MusicFX (an EQ app may hook into it)
- MMS and WAP push if the unit has a modem
- the vendor's APK installer or file manager, if it's how the owner installs apps from USB

**KEEP**: everything that matches a keep pattern, the active launcher and keyboard, all `providers`, `packageinstaller`, `webview`, `documentsui`, `externalstorage`, `mtp`, Settings, SystemUI, location, and the vendor's car apps.

## Google core

`com.google.android.gms`, `gsf` and `tts` are KEEP by default. If the owner wants them gone, explain first:
- Google Maps, Play Store and anything else using Google sign-in stops working.
- Voice guidance needs a TTS engine. With Google TTS off there may be none.
- Play Services is often an active device admin (Find My Device). Android drops it automatically when it's disabled; the owner has to turn it back on by hand after an undo.

If they still want it, disable the apps first (Maps, Play Store, TTS, sync adapters), then `gms`, then `gsf`, in a batch of their own.

## Output format

```markdown
# Package classification — <unit model> (<Android version>, <SoC>)

Generated <date>. <N> packages total, <M> already disabled.
Backup: `backup-<timestamp>/`

## SAFE TO DISABLE (<n>)
| # | Package | What it is | Why safe |

## ASK — depends on your usage
| Package | What it is | RAM now | Note |

## RISKY — recommend leaving alone
| Package | What it is | Why leave it |

## KEEP (<n>)
| Package | What it is | Why keep |
```
