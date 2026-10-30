# Worked example: PX5 "ak" firmware unit

One real run of this workflow, for reference. **The verdicts below fit this firmware and this owner only.** Vendor package names (`com.my.*`, `com.car.*`) mean different things on other units, so classify every unit from scratch.

## The unit

- Alpine-branded clone in a 2025 Toyota Corolla Altis 1.6
- PX5: Rockchip RK3368, 8x Cortex-A53, ~1.9 GB RAM, 1024x600
- Android 8.0 userdebug, so `adb shell` runs as root
- ADB over Wi-Fi on port 5555 at every boot (`/init.rk3368.rc` sets `service.adb.tcp.port`), even with Developer options off
- Phone Bluetooth: a separate Goodocom module (`gocsdk_210` daemon on `/dev/ttyS1`, app `com.my.bt`). Android Bluetooth has no controller.
- Wi-Fi: RTL8188EU USB chip, 2.4 GHz only, behind the internal USB hub
- Owner uses: Bluetooth music, reverse camera, radio, steering-wheel buttons. Wanted CarPlay; didn't need Google.

## Car function owners found in step 2

| Function | Package |
|---|---|
| Reverse camera | `com.my.out` (ReverseActivity, the only camera client), `com.car.ui` (BackCameraActivity), `com.canboxsetting` (AVMActivity) |
| Bluetooth calls/music | `com.my.bt` + `gocsdk_210` daemon |
| Radio, car UI | `com.car.ui` |
| Steering-wheel keys | `com.SwcApplication` |
| Amplifier / EQ | `com.eqset` |
| DVR | `com.my.dvr` |

## Baseline

- MemAvailable ~650 MB of 1.87 GB, swap 46 MB free of 509 MB (heavy pressure)
- Uptime 25 days (the unit only sleeps on key-off)
- Biggest RAM users: Google Play Services ~250 MB, Play Store ~140 MB, Google app ~110 MB (always running), Google TTS 92 MB

## What was disabled (39 of 109 packages)

| Batch | Packages |
|---|---|
| 1 Visuals | galaxy4, noisefield, phasebeam, wallpaper.holospiral, musicvis, wallpaper.livepicker, dreams.basic, egg |
| 2 Unused stock apps | email, calendar, calculator2, quicksearchbox, bookmarkprovider, jp.co.omronsoft.openwnn, managedprovisioning, com.my.instructions |
| 3 Printing, old tools | bips, printspooler, printservice.recommendation, google feedback, partnersetup, ES File Explorer 3.2.5.5 |
| 4 Google apps | Google app, Gmail, YouTube, Chrome, Google Calendar sync |
| 5 Projection, voice | Sygic, EasyConnection, `com.ak.speechrecog`, `com.focussync` |
| 6 Google core (owner's explicit choice) | Maps, Play Store, Google TTS, contacts sync, backup transport, gms.policy_sidecar_o, gms, gsf |

Notes:
- `com.ak.speechrecog` started as RISKY (could have been the wheel's voice button). It moved to the disable list once the owner said the wheel has no voice button.
- EasyConnection was safe here only because the owner didn't use phone mirroring. On many units it *is* the CarPlay app.
- Play Services was an active device admin. Android removed it automatically; after an undo, Find My Device has to be turned back on.

## Result

- After the batches: MemAvailable 1.26 GB. After a cold reboot: **1.52 GB**, swap completely free.
- All car functions passed the owner's test.
- Bluetooth music sounded noticeably cleaner afterwards. The likely cause is that the always-listening voice apps no longer hold the microphone open, which on cheap audio HALs can force a lower-quality mode. It's a guess and wasn't verified.

## CarPlay on this unit

- DiPlay 0.2.22, wired: works.
- Wireless: impossible (no Android Bluetooth controller, 2.4 GHz Wi-Fi).
- First connect took ~1 minute with repeated USB drops. The fix: the glove box port marked "3G/USB" (wired straight to the SoC, not via the hub), DiPlay iPhone charging set to Low, and iPhone Auto-Lock off. Result: picture in ~4 seconds.
- Occasional resets of both USB controllers at once point to a power/ground problem in the car wiring, not software.
