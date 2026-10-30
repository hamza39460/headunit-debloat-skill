# Step-by-step guide

This is the long version: how to go from a slow Android head unit to a cleaned-up one (and optionally CarPlay), step by step. If you just want the story, read [BLOG.md](BLOG.md).

Take your time with it. Nothing here needs to be done in one sitting, and every change can be undone.

**Contents**

1. [What you need](#1-what-you-need)
2. [Install adb on your laptop](#2-install-adb-on-your-laptop)
3. [Put the head unit and laptop on the same Wi-Fi](#3-put-the-head-unit-and-laptop-on-the-same-wi-fi)
4. [Find the head unit's IP address](#4-find-the-head-units-ip-address)
5. [Connect with ADB](#5-connect-with-adb)
6. [Using Claude Code](#6-using-claude-code) (new to Claude Code? start here)
7. [Start the debloat](#7-start-the-debloat)
8. [Review the backup and the classification](#8-review-the-backup-and-the-classification)
9. [Approve the batches and test the car](#9-approve-the-batches-and-test-the-car)
10. [Reboot and final test](#10-reboot-and-final-test)
11. [If something breaks](#11-if-something-breaks)
12. [Optional: CarPlay with DiPlay](#12-optional-carplay-with-diplay)
13. [Troubleshooting](#13-troubleshooting)
14. [Doing it without Claude](#14-doing-it-without-claude)

---

## 1. What you need

- A laptop (Mac, Linux or Windows)
- Your head unit and laptop on the same Wi-Fi. Home Wi-Fi if the car is parked close enough, otherwise a phone hotspot.
- A USB stick, only if you need to install Activity Launcher (step 5)
- [Claude Code](https://claude.com/claude-code)
- For CarPlay: an iPhone and a good, short USB cable

Turn the car on (ignition or ACC) while you work. When the car is off, the head unit sleeps and the connection drops.

## 2. Install adb on your laptop

`adb` (Android Debug Bridge) is the tool that talks to the head unit.

**Mac**
```bash
brew install android-platform-tools
```

**Ubuntu / Debian**
```bash
sudo apt install adb
```

**Windows**
1. Download "SDK Platform-Tools for Windows" from https://developer.android.com/tools/releases/platform-tools
2. Unzip it, for example to `C:\platform-tools`
3. Open a terminal in that folder. Or, better, use WSL (Windows Subsystem for Linux) and follow the Ubuntu steps, because the skill's scripts are bash scripts.

Check it works:
```bash
adb version
```

## 3. Put the head unit and laptop on the same Wi-Fi

On the head unit: Settings → Wi-Fi → connect to the same network as your laptop.

Using a phone hotspot? Connect both the head unit and the laptop to it. Some hotspots block devices from seeing each other ("client isolation"). If you can't connect later, that's the first thing to suspect.

## 4. Find the head unit's IP address

The IP address looks like `192.168.1.50` or `172.20.10.3`. You need it to connect. Try these in order.

### Option A: on the head unit itself

- Settings → Wi-Fi → tap the network you're connected to (or the gear / "i" next to it). Look for **IP address**.
- If it's not there: Settings → About → **Status** → IP address.
- On some units it's under Settings → Network → Wi-Fi → Advanced.

### Option B: your router or hotspot

- **Home router:** open the router's admin page (often `192.168.1.1` or `192.168.0.1` in a browser, or the router's app) and look at the list of connected devices. The head unit usually shows up as `android-xxxxxxxx`, the model name (like `px5`), or a name with no brand.
- **Android phone hotspot:** Settings → Hotspot → Connected devices. Some phones show the IP; others only the name.
- **iPhone hotspot:** the iPhone doesn't show IP addresses, but devices on an iPhone hotspot always get an address between `172.20.10.2` and `172.20.10.14`. Use option C with `172.20.10.0/28`.

### Option C: scan the network from your laptop

The head unit listens for ADB on port 5555, so you can scan for anything with that port open.

First find your laptop's own IP to know which network to scan:

```bash
# Mac
ipconfig getifaddr en0
# Linux
hostname -I
# Windows
ipconfig
```

If your laptop is `192.168.1.23`, the network is `192.168.1.x`.

**With nmap** (Mac: `brew install nmap`, Ubuntu: `sudo apt install nmap`):
```bash
nmap -p 5555 --open 192.168.1.0/24
```
Any address it lists is almost certainly your head unit.

**Without installing anything** (Mac, replace `192.168.1` with your network):
```bash
for i in $(seq 1 254); do (nc -z -G 1 192.168.1.$i 5555 >/dev/null 2>&1 && echo "found 192.168.1.$i") & done; wait
```
On Linux, use `nc -z -w 1` instead of `nc -z -G 1`.

If the scan finds nothing, ADB over Wi-Fi isn't on yet. Find the IP with option A or B, then go to step 5B.

### Tip: keep the IP from changing

The IP can change after a few days. If your router lets you, add a "DHCP reservation" for the head unit so it always gets the same address.

## 5. Connect with ADB

### 5A. Try a direct connection first

On many Chinese head units ADB over Wi-Fi is already switched on, even when Developer options look off. Mine was like that. So just try:

```bash
adb connect 192.168.1.50:5555
adb devices
```

- `192.168.1.50:5555   device` means you're in. Go to step 6.
- `unauthorized` means a popup is waiting on the head unit screen ("Allow USB debugging?"). Tick "Always allow" and tap **Allow**, then run `adb devices` again.
- `connection refused` means ADB isn't on yet. Go to 5B.
- `timed out` means the IP is wrong, the devices are on different networks, or the unit is asleep. Recheck steps 3 and 4.

### 5B. Turn on Developer options

The normal way:
1. Settings → About → tap **Build number** 7 times. You'll see "You are now a developer".
2. Settings → Developer options → turn on **USB debugging**. If you see **ADB over network** or **Wireless ADB**, turn that on too.
3. Try 5A again.

### 5C. If the build number tap is locked

On my unit tapping the build number did nothing. Activity Launcher gets around that by opening the hidden Developer options screen directly.

1. Download the Activity Launcher APK from F-Droid: https://f-droid.org/packages/de.szalkowski.activitylauncher/ (or install it from the Play Store if your unit has it)
2. Copy the APK to a USB stick and plug it into the head unit
3. Open the unit's file manager (or its "APK Installer" app), find the APK and install it. Allow "unknown sources" if it asks.
4. Open Activity Launcher → search for **Settings** → expand it → tap **Developer options** (`com.android.settings.Settings$DevelopmentSettingsActivity`)
5. Turn on USB debugging (and ADB over network if listed)
6. Try 5A again

Some brands hide this behind a factory settings password instead. Search your unit's forum thread for it. Don't guess codes, because factory menus can also change hardware settings.

### 5D. Android 11 and newer

Newer units use pairing instead of port 5555:
1. Developer options → **Wireless debugging** → turn on → **Pair device with pairing code**
2. On the laptop, using the IP, port and code shown on screen:
   ```bash
   adb pair 192.168.1.50:37123
   ```
3. Then connect using the port shown on the main Wireless debugging screen (it's a different port):
   ```bash
   adb connect 192.168.1.50:41234
   ```

### A security warning

With ADB on over the network, anyone on the same Wi-Fi can control the head unit, often with full root access. Only connect it to networks you trust, and avoid public Wi-Fi with ADB on.

## 6. Using Claude Code

Never used Claude Code before? This section covers everything you need for this project.

### What it is

Claude Code is Claude (the AI from Anthropic) running in your terminal. Unlike the chat website, it can run commands on your computer, like `adb`, read their output and decide what to do next. That's what makes this work: Claude talks to your head unit through adb while you watch and approve.

### What you need

A paid Claude plan (Pro, Max, Team or Enterprise) or an Anthropic Console (API) account. The free claude.ai plan doesn't include Claude Code.

### Install it

**Mac, Linux or WSL:**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows PowerShell:**
```powershell
irm https://claude.ai/install.ps1 | iex
```

**Or with Homebrew on a Mac:**
```bash
brew install --cask claude-code
```

Open a new terminal window and check it worked:
```bash
claude --version
```

If it says `command not found`, see the [official install troubleshooting](https://code.claude.com/docs/en/troubleshoot-install.md). For everything else about installing, see https://code.claude.com/docs/en/setup.

Prefer not to use a terminal? There's also a Claude desktop app with Claude Code built in. The skill works there too.

### Log in

Run:
```bash
claude
```
The first time, it opens your browser to log in with your Claude account. After that it starts straight away.

### Install the skill

A "skill" is a folder of instructions and scripts that teaches Claude how to do a specific job. This one teaches it the safe way to debloat a head unit. Personal skills live in `~/.claude/skills/`.

```bash
git clone https://github.com/hamza39460/headunit-debloat-skill.git
mkdir -p ~/.claude/skills
cp -r headunit-debloat-skill/headunit-debloat ~/.claude/skills/
```

Check Claude can see it: start `claude` and type `/skills`. You should see `headunit-debloat` in the list. No restart needed if Claude Code was already running.

### How the skill gets used

You don't have to run the skill yourself. When you ask about your head unit, Claude notices the request matches the skill and loads it on its own.

If you want to be sure, start your message with the skill's name:

```
/headunit-debloat my head unit is at 192.168.1.50:5555
```

### Permission prompts

Before Claude runs a command, it asks you. You'll see the command and options like **Yes**, **Yes, and don't ask again** for that kind of command, or **No**.

- **Read the commands.** For this project they should be `adb` commands that read information, the skill's scripts (`backup.sh`, `disable.sh`, `health.sh`), or `pm disable-user`.
- Saying "don't ask again" for harmless read commands saves time. For anything that changes the head unit, it's worth approving each one.
- If you see `pm uninstall`, anything touching `/system`, or anything you don't understand, say **No** and ask Claude why it wants to run it.

### Talking to it

Just type normally, like you're messaging someone who knows Android well.

- Say what you use in the car. "I use Bluetooth music, calls, reverse camera and Google Maps" is the most useful sentence you can type.
- Ask why. "Why is this app safe to disable?" is a fine question at any point.
- Say no. "Skip YouTube in this batch, I use it" works.
- If you're in the car, say so. "I'm testing now, wait for me" works too.

### Stopping and coming back

- Press **Esc** to stop Claude in the middle of something. Then type what you want instead.
- Type `/exit` (or press Ctrl+C twice) to quit.
- To continue later where you left off, run `claude --continue` in the same folder. `claude --resume` lets you pick from older sessions.

Claude also keeps `~/headunit-debloat/log.md` up to date, so even in a fresh session you can say "read my log.md and continue".

## 7. Start the debloat

Tell Claude your head unit's address and what you use in the car. The more you say, the better it classifies. For example:

> My car's Android head unit is at 192.168.1.50:5555. It's really slow. Can you debloat it? I only use Bluetooth music, calls, the reverse camera and the radio. I don't use Google Maps or the Play Store on it.

or

> Help me clean up my head unit at 172.20.10.3:5555. I use Google Maps on it and CarPlay through ZLink, so keep those.

Claude will connect and ask a few questions about what you use. Answer honestly: if you're not sure whether you use something, say so, and it stays.

Claude will ask permission before running commands. Read them. Everything it should be doing is either reading information or `pm disable-user`.

## 8. Review the backup and the classification

First Claude backs up your unit into `~/headunit-debloat/backup-<date>/`: the full package list, settings and memory stats. Nothing on the unit changes. It shows you a summary like:

```
Packages:  109 total, 12 user-installed, 0 already disabled
RAM:       650 MB available of 1871 MB
Swap:      46 MB free of 508 MB
```

Write the RAM number down. That's your "before".

Then it works out which apps run your car functions (reverse camera, Bluetooth, radio, steering wheel keys) and sorts every package into four groups in `~/headunit-debloat/classification.md`:

| Group | What it means | What you do |
|---|---|---|
| SAFE | Nothing in the car uses it | Skim it |
| ASK | Depends on you | **Answer these** |
| RISKY | Probably fine, but not worth it | Leave alone |
| KEEP | Car-critical or core Android | Leave alone |

The ASK group is where the big memory wins are. Typical questions:
- **Google app / "OK Google"**: do you use voice commands? Is there a voice button on the steering wheel?
- **Google Maps, Play Store, Play Services**: do you use Maps or install apps on the unit? If yes, keep them.
- **Mirroring apps (EasyConnection, ZLink, AutoKit, Carbit)**: if your CarPlay or Android Auto goes through one of these, **keep it**.
- **Bundled nav apps (Sygic, iGo)**: keep the one you use.

Claude also creates `~/headunit-debloat/undo.sh` at this point. Remember where it is.

## 9. Approve the batches and test the car

Claude disables apps in small groups of 5 to 8, and asks before each one with a reason per app. Before you say yes:
- Read the list. Anything you recognize and use? Say no to that one.
- Anything with car, camera, bt, radio, can, mcu or your brand's name in it should not be in a batch. Ask if you see one.

After each batch Claude checks memory, makes sure the car apps are still running, and looks for crashes. Then test in the car (or tell Claude you'll test everything at the end):

- [ ] Reverse camera: shift into R
- [ ] Bluetooth music: play something from your phone
- [ ] Bluetooth calls: make a short call
- [ ] Radio
- [ ] Steering wheel buttons (volume, next track)
- [ ] Anything else you use: DVR, navigation, CarPlay app, EQ, AC display

If something stopped working, say so. Claude can re-enable that batch right away (see step 11).

## 10. Reboot and final test

When all batches are done, Claude reboots the unit (`adb reboot`). Turning the car off and on usually isn't a real reboot. These units just sleep.

After the reboot:
- Claude checks memory again. Compare it with your "before" number. Mine went from ~650 MB to ~1.5 GB available.
- Wireless ADB should come back by itself within a minute. If it doesn't, check the IP again (step 4).
- Do the car checklist from step 9 one more time.

Everything Claude did is in `~/headunit-debloat/log.md`.

## 11. If something breaks

Every app was only disabled, not removed, so everything can come back.

**Put one app back:**
```bash
~/headunit-debloat/undo.sh com.example.someapp
```

**Put one batch back:** open `~/headunit-debloat/disabled.txt`. The batches are labelled there. Pass the apps from that batch:
```bash
~/headunit-debloat/undo.sh com.app.one com.app.two com.app.three
```

**Put everything back:**
```bash
~/headunit-debloat/undo.sh
```

**Remove apps that were installed (like DiPlay):**
```bash
~/headunit-debloat/undo.sh --remove-installed
```

Reboot the head unit after undoing. If you re-enabled Google Play Services, turn Find My Device back on in Settings → Security → Device admin apps.

## 12. Optional: CarPlay with DiPlay

Skip this if your unit already has CarPlay.

[DiPlay](https://github.com/shihabal3amri/DiPlay) is an open-source CarPlay app for Android head units. It's an unofficial preview, not from Apple, and an iOS update could break it someday.

### Install

Ask Claude:

> Can you install DiPlay for wired CarPlay?

It checks your Android version and CPU, downloads the latest release from GitHub, verifies the checksum and installs it. To do it by hand: download the APK from the [releases page](https://github.com/shihabal3amri/DiPlay/releases), then:
```bash
adb install -r DiPlay-<version>.apk
```

### First connection

1. Plug your iPhone into the head unit with a USB cable
2. If the head unit asks which app to open for the iPhone, pick **DiPlay** and **Always**
3. On the iPhone, allow the connection / trust prompts
4. CarPlay should show up on the screen

### Settings worth changing

- **iPhone charging:** DiPlay → Settings → USB connection → iPhone charging → **Low**. Weak USB ports drop the phone if it pulls too much current.
- **Auto-Lock:** iPhone Settings → Display & Brightness → Auto-Lock → **Never** while you're setting things up. My first connections kept failing because the phone locked itself in the middle.
- **BACK button:** DiPlay → Settings → Vehicle → Wheel keys → **External controller (experimental)**. With this on, the panel's BACK button works as CarPlay's back instead of leaving CarPlay.

### If it's slow to connect: find the right USB port

My CarPlay took about a minute to connect until I switched ports. Many units have an internal USB hub, and some ports go through it while one goes straight to the board. The direct one is much more stable.

Try each port, and ask Claude:

> CarPlay takes a long time to connect. Can you check the logs and tell me which USB port the iPhone is on?

Or check yourself while the iPhone is plugged in:
```bash
adb shell 'for d in /sys/bus/usb/devices/*; do [ -f $d/idVendor ] && echo "$(basename $d) $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/product 2>/dev/null)"; done'
```
The iPhone shows up as `05ac:...`. A short path like `3-1` is a direct port. A path like `1-1.3` means it's behind a hub. On my unit the direct port was the one in the glove box with a "3G/USB" sticker. The one next to the cigarette lighter was behind the hub.

With the direct port, Low charging and Auto-Lock off, my CarPlay comes up about 4 seconds after plugging in.

### Wireless CarPlay?

DiPlay's wireless modes need the head unit's Android Bluetooth to pair with the iPhone. On many cheap units (mine included) Android has no Bluetooth hardware. The car's Bluetooth runs on a separate module Android can't use. Ask Claude to check:

> Can my head unit do wireless CarPlay with DiPlay?

If it can't, the answer is a wireless CarPlay adapter that plugs into USB.

## 13. Troubleshooting

| Problem | What to try |
|---|---|
| `adb: command not found` | adb isn't installed or isn't on your PATH. Redo step 2. |
| `failed to connect ... Connection refused` | ADB isn't on. Step 5B or 5C. |
| `failed to connect ... Operation timed out` | Wrong IP, different networks, hotspot client isolation, or the unit is asleep. Recheck steps 3 and 4. |
| `unauthorized` | Accept the popup on the head unit screen. |
| `offline` | `adb disconnect`, then `adb connect <ip>:5555` again. Still offline? `adb kill-server` and retry. |
| Connected yesterday, not today | The IP probably changed. Step 4, then consider a DHCP reservation. |
| Reverse camera, radio or Bluetooth stopped working | Undo the last batch (step 11), reboot, tell Claude which batch broke it. |
| Home button does nothing | A setup or launcher package was disabled. Undo the last batch. |
| CarPlay takes long to connect or drops | Step 12: direct USB port, Low charging, Auto-Lock off, short cable. |
| Wi-Fi turns off when CarPlay connects | The Wi-Fi chip shares a USB hub with the port you're using. Use the direct port. |
| CarPlay screen goes white while driving | That's the unit's video-while-driving block. Check your unit's and DiPlay's documentation. |

## 14. Doing it without Claude

The scripts work on their own too. You lose the classification help, so you have to decide yourself what's safe.

```bash
cd headunit-debloat-skill/headunit-debloat/scripts
export ANDROID_SERIAL=192.168.1.50:5555

# 1. Backup (changes nothing)
./backup.sh ~/headunit-debloat

# 2. Look at what's installed
cat ~/headunit-debloat/backup-*/all.txt

# 3. Make your undo script
cp undo.sh ~/headunit-debloat/

# 4. Disable a batch (refuses anything that looks car-related)
./disable.sh ~/headunit-debloat "Batch 1: wallpapers" com.android.galaxy4 com.android.noisefield

# 5. Check health (pass the car apps you found)
./health.sh com.my.out com.car.ui

# Undo everything
~/headunit-debloat/undo.sh
```

Read [references/classify.md](headunit-debloat/references/classify.md) for what usually counts as safe, and [references/example-px5.md](headunit-debloat/references/example-px5.md) for what I disabled on mine. Don't copy my list: vendor app names mean different things on different units.

---

Tried it on your unit? Open an issue with the model and what worked. It helps the next person.
