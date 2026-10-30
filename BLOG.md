# I debloated my car's Android head unit with Claude Code, then put CarPlay on it

My car is a 2025 Corolla Altis 1.6. It came with one of those Android touchscreens, Alpine branding on the front, a cheap Chinese PX5 unit inside. Android 8, 2 GB of RAM, 1024x600 screen.

It was slow. Like, tap something and wait slow. Google Maps froze it completely, so I stopped using Maps on it. Honestly I'd stopped using it for anything except Bluetooth music and the reverse camera. It was basically an expensive radio.

A few weeks ago I kept seeing posts from people debloating their Android smart TVs with Claude Code. Same idea every time: cheap Android device, loaded with junk, connect over ADB, have Claude figure out what's safe to turn off. I thought, my head unit is just a cheap Android tablet glued into the dashboard. Why not try it there?

## Getting in

First problem: Toyota (or whoever set up this unit) had locked Developer options. Tapping the build number did nothing.

So I installed Activity Launcher. It lets you open any screen of any app directly, including Settings screens that are hidden. I opened Developer options through that, and it was all switched off.

But here's the thing. ADB over Wi-Fi was working anyway. `adb connect` just connected. It turned out the firmware opens ADB on port 5555 at every boot, no matter what the settings say. A lot of these Chinese units do that. Which is convenient for me, and also a bit scary when you think about it, because ADB on this unit runs as root. Anyone on the same Wi-Fi could do whatever they want with it.

The funny part is that the car was parked downstairs and I was sitting on the first floor with my MacBook. The unit was on my home Wi-Fi, so I did the whole thing from upstairs.

## Setting rules first

Before letting Claude touch anything, I wrote down rules. I really didn't want to brick the thing that runs my reverse camera.

- Only disable apps with `pm disable-user`. Never uninstall, never delete files, never touch /system, never flash anything.
- Anything with car-ish names (car, can, mcu, bt, radio, camera, reverse, swc, dvr, launcher, audio and so on) is KEEP. If unsure, ask me.
- Back up everything first.
- Make an undo script before disabling anything.
- Small batches, 5 to 8 apps, and ask me before each batch.
- Keep a log.

I think this was the most important part of the whole thing. With those rules, the worst case was "run undo.sh and reboot".

## What was on it

Claude pulled the package list, settings, memory stats and running processes into a backup folder. 109 packages. Then it sorted them into SAFE, ASK, RISKY and KEEP, with a short reason for each one.

The memory numbers were bad. Out of 1.87 GB, only about 650 MB was available, and swap had 46 MB free out of 509 MB. The unit was constantly squeezing memory. The top users were Google Play Services (around 250 MB), the Play Store (140 MB), the Google app with "OK Google" (110 MB, always running), and Google TTS (92 MB). On a car stereo.

Before classifying anything, Claude worked out which apps actually run the car stuff. This was useful because the vendor apps have names like `com.my.out` and `com.car.ui` that tell you nothing. The reverse camera turned out to be `com.my.out` (the only app actually using the camera), with backup activities in `com.car.ui` and the canbus app. Bluetooth calls and music don't even go through Android. There's a separate Bluetooth module with its own program. Steering wheel keys, EQ, DVR, all vendor apps. All KEEP.

## The batches

Six batches in total:

1. Live wallpapers, screensaver, the Android Easter egg
2. Stock apps I never opened: Email, Calendar, Calculator, a Japanese keyboard, the vendor's "Instructions" app
3. Printing (on a car stereo...), Google feedback, and a 2019 version of ES File Explorer with a known security hole
4. Google app, Gmail, YouTube, Chrome
5. Sygic navigation, EasyConnection, the vendor's voice assistant, a mystery "SYNC" app
6. Google Play Services, Play Store, Maps, Google TTS and friends

Batch 6 went against my own rules, since gms and gsf were on my keep list. But I don't use Maps on this unit (it froze anyway) and I don't need the Play Store in the car. Claude made me confirm it after listing what I'd lose: no Play Store, no Google Maps, no voice guidance, and Find My Device gets switched off. I said fine.

I didn't test after each batch because I was upstairs and didn't feel like going down six times. Claude checked after every batch that the car processes were still running and that nothing had crashed in the logs, and I tested everything in the car at the end.

## Result

After a proper reboot, available memory went from ~650 MB to **~1.52 GB**, and swap was completely free. 39 apps disabled, nothing uninstalled.

Then I went down to the car and tested everything: reverse camera, Bluetooth music, radio, steering wheel buttons. All working. And the unit was actually fast. Menus open right away.

One thing I didn't expect: Bluetooth music sounds better now. Before, vocals sounded kind of muddy and high volume sounded harsh. Now it's clean. My best guess is that the two voice assistants were always listening, keeping the microphone open, and on cheap hardware that can push the whole audio system into a lower-quality "voice" mode. I haven't proven it, but the difference is obvious.

## Then I got greedy: CarPlay

Once the unit wasn't drowning anymore, I wanted to see if it could do CarPlay. It never had it.

I found [DiPlay](https://github.com/shihabal3amri/DiPlay), an open-source CarPlay receiver for Android head units, based on [xcertplay](https://github.com/shilapi/xcertplay). Claude downloaded the release, checked the checksum against the one published with the release, and installed it over ADB.

I plugged in my iPhone with a cable and CarPlay showed up on the screen. On a unit that was barely usable a few hours earlier.

## Can it go wireless?

DiPlay has wireless options too, so obviously I wanted that. This is where the logs said no.

Every wireless mode in DiPlay needs the iPhone to pair with the head unit's Android Bluetooth, because that's how the phone receives the Wi-Fi details. Claude checked the unit, and Android on this unit has no Bluetooth hardware at all. The only Bluetooth chip belongs to that separate module the car uses for calls and music, and its own program has it locked. Android's Bluetooth doesn't even have a driver for it. Every attempt to turn it on just times out.

Getting around that would mean replacing system files, and the Wi-Fi is 2.4 GHz only anyway, so even if it worked, it'd probably lag. So wired it is. If you want wireless on a unit like this, a wireless CarPlay adapter is the way.

## The slow connection

Wired CarPlay worked, but it took around a minute to connect every time. Sometimes it dropped and reconnected, and my Wi-Fi turned itself off at the same time.

This is where having Claude read the logs really paid off. The kernel log showed the iPhone dropping off USB and coming back, over and over. The unit has an internal USB hub, and the port I was using sat behind it. The Wi-Fi chip is on the same hub. So whenever the hub reset, it took both CarPlay and Wi-Fi down, and Android didn't turn Wi-Fi back on.

There are two USB ports. The one I was using is next to the cigarette lighter. The other one is in the glove box, has a sticker saying "3G/USB", and it turned out to be wired straight to the processor, not through the hub. Moving the phone there, lowering the iPhone charging current in DiPlay's settings, and turning off Auto-Lock on the iPhone (it was locking the screen in the middle of setup) brought it down to **about 4 seconds** from plugging in to seeing CarPlay.

There are still occasional resets where both USB controllers drop at the same moment. That looks like a power or ground problem in the car wiring, not software, so that's a job for another day.

## What didn't work

- **Wireless CarPlay.** Explained above, the hardware just doesn't allow it.
- **Auto door lock.** I asked Claude if the head unit could lock the doors when the car starts moving. It looked through the canbus settings and found the canbus is set to "NONE", so the unit doesn't talk to the car's computer at all. From what I can tell it's a setting in the car's own computer, so it needs an OBD tool, not the head unit.

## Turning it into a skill

A few people asked for the code. The honest answer is that my exact list of disabled apps is useless for anyone else. Different firmware, different vendor apps, different names. What's actually useful is the *process*: back up, classify carefully, undo script first, small batches, check the car still works.

So I turned that process into a Claude Code skill. You install it, tell Claude your head unit's IP, and it follows the same careful steps on your unit, asking you about anything it doesn't recognize. It also has the CarPlay notes and the USB connection fixes. It's here: **https://github.com/hamza39460/headunit-debloat-skill**. If you want to try it, there's a step-by-step guide in the repo ([GUIDE.md](GUIDE.md)) that starts from installing adb and finding your head unit's IP.

I've only tested it on my own unit, so if you try it on yours, let me know how it goes.

## If you want to try this

- Check whether ADB is already open: `adb connect <unit ip>:5555`. There's a good chance it is.
- Set your rules before letting anything touch the unit. Disable, never uninstall.
- Find out which apps run your reverse camera and Bluetooth *before* disabling anything.
- If your unit already has CarPlay through some app like ZLink or EasyConnection, keep that app. On my unit EasyConnection was safe to disable because I didn't use it. On yours it might be the CarPlay app.
- If CarPlay is slow to connect, try every USB port. One of them is probably wired straight to the board.

Thanks to the DiPlay and xcertplay folks. None of the CarPlay part would exist without them.
