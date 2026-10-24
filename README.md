<div align="center">

<img src="Icon/AppIcon.png" width="128" alt="Notchfall icon">

# Notchfall

**Meeting alerts, and everything else worth a glance, dropping out of your MacBook's notch.**

A tiny macOS menu-bar app. When a meeting is about to start, a black island grows out of the
notch, springs open with a glowing rim and gives you a big **Join** button. The same island
shows your volume and brightness, downloads, clipboard history, Claude Code finishing, apps that
crash and anything a script wants to tell you.

<img src="docs/screenshots/tour.gif" width="820" alt="Music plays beside the notch, an alert drops out of the notch and pauses it, opens a camera check, turns into the on-air indicator during the call, then the Up next list opens and a live countdown sits beside the notch">

</div>

---

## What it does

| | |
|---|---|
| **Drops out of the notch** | Alerts grow out of the camera housing, like the Dynamic Island on an iPhone. First a small bulge, then a spring with a little overshoot. The content blurs into place, then a ripple rings out. |
| **Join in one click** | Finds the Google Meet, Zoom or Microsoft Teams link in the event and puts it on a big **Join** button. |
| **🪞 Camera check** | One click on the alert opens a live, mirrored camera preview inside the island, so you can fix your hair before you **Join**. The camera only runs while it's open. |
| **🎙 On air** | While you're on a call, a slim island shows a red mic light, a camera light and the time left in the meeting. In the last 5 minutes the rim starts to glow, and if another meeting starts straight after, it shows **Next: Sprint Planning at 15:00**. Works with every meeting app. |
| **🎵 Now Playing** | While Apple Music or Spotify plays, the album cover sits in the left wing and a little equaliser, tinted by the cover, dances in the right. Hover the notch for the player: cover, progress, ⏮ ⏯ ⏭. |
| **Pauses for meetings** | When a meeting alert drops, the music pauses. Dismiss or snooze and it plays again; join the call and it waits until the call is over. |
| **☀️ Morning brief** | The first time you sit down at the Mac each morning, the island opens with *Good morning*: how many meetings you have today, the first one, reminders due, and the whole day on a timeline. It tidies itself away after 12 seconds. |
| **🍅 Focus timer** | Menu → **🍅 Focus**: 25 or 50 minutes of focus with a tomato ring counting down beside the notch, then a "Focus session done" alert with **Start break** or **5 more min**. The break counts down in blue and calls you back. |
| **⚡ Charging and 🎧 headphones** | Plug in the charger and the wings show ⚡ Charging and the battery filling to its level. Connect AirPods or other headphones and they show by name with a ✓. Three seconds, then gone. |
| **🚗 Time to leave** | For a meeting at a real address (not a video link), Notchfall asks Apple Maps how long it takes to get there and drops a *Time to leave* alert with the travel time, the start time and a **Directions** button that opens Maps. Driving, walking or transit, or a fixed 15 or 30 minutes if you'd rather not share your location. |
| **📂 File shelf and AirDrop** | Drag a file up to the notch and it opens into two drop zones: **Shelf** keeps it there for later, **AirDrop** sends it to a nearby device. Hover the notch to see the shelf under Up next, then drag files out wherever you need them. |
| **🎤 Mute from anywhere** | **⌃⌥M** mutes the microphone itself, so every meeting app hears silence. The wings say *Muted*, the on-air light shows a struck-through mic, and if a call starts while you're muted you get *You're muted* before you start talking. It unmutes when the call ends. |
| **🔊 Volume and ☀️ brightness** | Turn the volume or brightness up or down and a slim level bar shows in the wings instead of macOS's big box in the middle of the screen. A struck-through speaker when it's muted. |
| **⏳ Downloads** | While Safari, Chrome, Edge, Brave, Arc or Firefox downloads to **~/Downloads**, a ring fills beside the notch with the percent (or the size so far). When it's done: *Downloaded Holiday photos.zip*, and optionally onto the shelf. |
| **📋 Clipboard history** | Off until you turn it on (⚙ Settings → Notch extras). Then **⌃⌥V** opens the last 20 things you copied: text, links, images and files, with the app they came from. Click one to copy it again, then ⌘V. Passwords from password managers are never kept, and nothing is saved to disk. |
| **🤖 Claude Code** | Turn on **Tell me when Claude finishes or needs me** and Claude Code's *done* and *needs your permission* drop out of the notch, with the first line of its reply and a **Show** button that brings its terminal or editor forward. Quiet while you're already looking at it. |
| **🛰 Fleet alerts** | If you run [Nexus](https://github.com/Sravankumartangudu/nexus), an app that quits unexpectedly, stops responding or reports an error drops out of the notch, with **Relaunch**. |
| **⚖️ Dharalu signals** | If you run [Dharalu](https://github.com/Sravankumartangudu/dharalu), a buy / hold / sell change for wheat or a metal shows with the latest price. |
| **📮 From any script** | Drop a small JSON file in `~/.notchfall/inbox` and it shows as a card, a toast or a progress ring. See [Post to the notch](#post-to-the-notch). |
| **Live countdown** | In the minutes before a meeting, a ring and the minutes left sit either side of the notch. The rim starts to glow in the last minute. |
| **Up next on hover** | Move the pointer onto the notch and the island opens into your next four items (three under the player), each with its own join button. |
| **Gets more urgent** | The rim's gradient turns faster as the start gets close and goes red once the meeting is live. The title shimmers, and the badge pulses. |
| **Reminders and timers** | Apple Reminders that are due today (opt-in), plus quick timers from the menu. Each kind has its own colour. |
| **Never covered by the notch** | Text always sits in the "wings" either side of the camera. Nothing important is drawn behind it. |
| **No notch? Still works** | On a Mac or external screen without a notch, the island hangs from the middle of the menu bar. |

<table>
<tr>
<td><img src="docs/screenshots/alert.jpg" alt="Meeting alert with a Join Google Meet button"></td>
<td><img src="docs/screenshots/live.jpg" alt="The same meeting once it's live"></td>
</tr>
<tr>
<td align="center"><sub>2 minutes before: rolling countdown and a draining ring</sub></td>
<td align="center"><sub>Live: red LIVE tag, full ring, shimmering title</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/camera-check.jpg" alt="Camera check: a mirrored camera preview inside the island"></td>
<td><img src="docs/screenshots/on-air.jpg" alt="On air: mic and camera lights, 5 minutes left and the next meeting"></td>
</tr>
<tr>
<td align="center"><sub>🪞 Camera check before you join</sub></td>
<td align="center"><sub>🎙 On air: mic and camera lights, time left, what's next</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/now-playing.jpg" alt="Now Playing: album cover and equaliser either side of the notch"></td>
<td><img src="docs/screenshots/player.jpg" alt="The player on top of Up next: cover, song, progress and transport buttons"></td>
</tr>
<tr>
<td align="center"><sub>🎵 Now Playing in the wings</sub></td>
<td align="center"><sub>Hover: the player on top of Up next</sub></td>
</tr>
<tr>
<td colspan="2"><img src="docs/screenshots/brief.jpg" alt="Morning brief: 4 meetings today, the first one, 2 reminders, and the day on a timeline"></td>
</tr>
<tr>
<td colspan="2" align="center"><sub>☀️ Morning brief: today at a glance, once a day</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/focus.jpg" alt="Focus session counting down beside the notch"></td>
<td><img src="docs/screenshots/focusdone.jpg" alt="Focus session done alert with Start break and 5 more min"></td>
</tr>
<tr>
<td align="center"><sub>🍅 Focusing: the ring drains, minutes and seconds tick</sub></td>
<td align="center"><sub>Done: start the break, or 5 more minutes</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/charging.jpg" alt="Charging toast with 84% and a filling battery"></td>
<td><img src="docs/screenshots/airpods.jpg" alt="AirPods Pro connected toast"></td>
</tr>
<tr>
<td align="center"><sub>⚡ Charger plugged in</sub></td>
<td align="center"><sub>🎧 Headphones connected</sub></td>
</tr>
<tr>
<td colspan="2"><img src="docs/screenshots/leave.jpg" alt="Time to leave alert: 17 min drive to Blue Bottle Coffee, with a Directions button"></td>
</tr>
<tr>
<td colspan="2" align="center"><sub>🚗 Time to leave: Apple Maps travel time, one click to directions</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/drop.jpg" alt="Drop zones under the notch: Shelf and AirDrop"></td>
<td><img src="docs/screenshots/shelf.jpg" alt="The shelf with five files under the Up next list"></td>
</tr>
<tr>
<td align="center"><sub>📂 Drag a file up to the notch</sub></td>
<td align="center"><sub>Hover: the shelf under Up next</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/stillmuted.jpg" alt="You're muted reminder beside the notch"></td>
<td><img src="docs/screenshots/on-air-muted.jpg" alt="On air with a struck-through mic while muted"></td>
</tr>
<tr>
<td align="center"><sub>🎤 A call starts while you're muted</sub></td>
<td align="center"><sub>On air, muted with ⌃⌥M</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/muted.jpg" alt="Muted toast"></td>
<td><img src="docs/screenshots/leavepeek.jpg" alt="Leave-by countdown beside the notch"></td>
</tr>
<tr>
<td align="center"><sub>⌃⌥M: Muted</sub></td>
<td align="center"><sub>🚗 Minutes until you need to leave</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/claude.jpg" alt="Claude is done card with the first line of its reply and a Show button"></td>
<td><img src="docs/screenshots/clips.jpg" alt="Clipboard history under the notch: text, a link, an image and files"></td>
</tr>
<tr>
<td align="center"><sub>🤖 Claude Code is done</sub></td>
<td align="center"><sub>📋 ⌃⌥V: clipboard history</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/download.jpg" alt="Download progress ring and percent beside the notch"></td>
<td><img src="docs/screenshots/volume.jpg" alt="Volume level bar beside the notch"></td>
</tr>
<tr>
<td align="center"><sub>⏳ Downloads in the wings</sub></td>
<td align="center"><sub>🔊 Volume (and ☀️ brightness)</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/fleet.jpg" alt="An app quit unexpectedly, with a Relaunch button"></td>
<td><img src="docs/screenshots/dharalu.jpg" alt="Dharalu: Wheat HOLD to BUY with the latest price"></td>
</tr>
<tr>
<td align="center"><sub>🛰 An app in the fleet quit</sub></td>
<td align="center"><sub>⚖️ A Dharalu signal changed</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/reminder.jpg" alt="Reminder alert"></td>
<td><img src="docs/screenshots/timer.jpg" alt="Timer alert"></td>
</tr>
<tr>
<td align="center"><sub>Apple Reminders (amber)</sub></td>
<td align="center"><sub>Quick timers (mint)</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/upnext.jpg" alt="Up next list opened by hovering the notch"></td>
<td><img src="docs/screenshots/peek.jpg" alt="Live countdown beside the notch"></td>
</tr>
<tr>
<td align="center"><sub>Hover the notch: Up next</sub></td>
<td align="center"><sub>Live countdown in the wings</sub></td>
</tr>
</table>

<sub>The screenshots use made-up events, songs, clips and apps (the app's built-in previews) on a mock desktop. The
camera check shows a drawn stand-in, not a real camera.</sub>

---

## Requirements

- macOS 14 Sonoma or later, on Apple Silicon or Intel.
- A MacBook with a notch looks best. Any Mac works.
- Your calendars in the macOS **Calendar** app. iCloud, Google, Exchange and Outlook
  accounts added in System Settings → Internet Accounts all count.

Work-managed Macs: some company security tools block apps that aren't signed by an
identified developer. If **Open Anyway** doesn't appear in step 3 below, ask your IT team to
allow the app.

---

## Install

1. Download **Notchfall.dmg** from the [latest release](../../releases/latest).
2. Open it and drag **Notchfall** into **Applications**.
3. Open Notchfall from Applications.

   The first time, macOS will block it with a message that it "can't be opened" or is from an
   unidentified developer. This is expected, because the app isn't notarized by Apple. To
   allow it:
   - Open **System Settings → Privacy & Security**.
   - Scroll down to the message about Notchfall and click **Open Anyway**, then confirm.

   Or, in Terminal:
   ```
   xattr -dr com.apple.quarantine /Applications/Notchfall.app
   ```
4. When asked, click **Allow** for Calendar access.
5. Look at the menu bar: Notchfall's icon is a little island with dots falling out of it. Next
   to it is the time until your next meeting, for example `12m`. There's no Dock icon and no
   window.

To see it right away, open the menu and choose **✨ Preview an alert → Take the tour**.

### Build from source

```
git clone https://github.com/Sravankumartangudu/notchfall.git
cd notchfall
./build.sh --install     # builds a universal app into ~/Applications and opens it
```

You only need the Xcode Command Line Tools (`xcode-select --install`). `./build.sh --dist` also
makes `build/Notchfall.dmg` and `build/Notchfall.zip`.

---

## Using it

| You want to… | Do this |
|---|---|
| Join a meeting | Click **Join** on the alert, or the join button in **Up next**, or the meeting in the menu. |
| Be reminded again | **Snooze**: 1 minute for meetings, 5 minutes for reminders and timers (**5 more min** for focus). |
| Close an alert | **✕**, or **Done** when there's no link. |
| See what's next | Hover the notch, or open the menu. |
| Set a timer | Menu → **⏱ Quick timer** → a preset, or **New timer with a label…** |
| Control the music | Hover the notch: ⏮ ⏯ ⏭ on the player. |
| Focus | Menu → **🍅 Focus** → 25 or 50 minutes. While it runs, the same menu shows the time left, **Add 5 minutes** and **Stop the session**. |
| Read the morning brief again | Menu → **✨ Preview an alert → Morning brief** shows how it looks; the real one comes once a day. |
| Get directions | Click **Directions** on a *Time to leave* alert, or the 🗺 button on it in **Up next**. |
| Park a file | Drag it up to the notch and drop it on **Shelf**. Hover the notch to get it back: drag it out, double-click to open, ✕ to take it off. Menu → **📂 Shelf** shows each file in Finder. |
| AirDrop a file | Drag it up to the notch and drop it on **AirDrop**, or **AirDrop** on the shelf to send everything on it. |
| Mute the mic | **⌃⌥M** in any app, or menu → **🎤 Mute microphone**. Press again to unmute. |
| Check your camera | Click 🪞 on a meeting alert. **Back** returns to the alert; **Join** joins. |
| Copy something again | Turn on ⚙ Settings → Notch extras → **Clipboard history** once. Then **⌃⌥V**, then click it (or menu → **📋 Clipboard**). Then ⌘V where you need it. |
| Hear from Claude Code | ⚙ Settings → Claude Code → **Tell me when Claude finishes or needs me**. Start a new Claude Code session afterwards: running ones keep their old hooks. |
| Post from a script | Write a JSON file into `~/.notchfall/inbox` (below). |
| Try the animation | Menu → **✨ Preview an alert** → any item, or **Drop a test alert** (⌘T). |

When alerts appear:

| Item | Shows | Still shows if you were away |
|---|---|---|
| Meeting | at your lead time (2 min by default) | up to 5 min after it started |
| Reminder | at your lead time | up to 1 hour late |
| Quick timer, focus or break | when it ends | always, even after sleep |
| Time to leave | travel time + 5 minutes before the meeting starts | up to 15 min late |
| Morning brief | the first time you're at the Mac between 5:00 and noon, once a day | not shown if you only come back after noon |

Only one alert shows at a time. The next one waits until you close the current one. Cards from
Claude Code, the fleet, Dharalu and scripts queue the same way, and close themselves after 9 seconds
(not while you're pointing at them) unless they need you.

### Post to the notch

Anything that can write a file can use the island. Write a `.json` file into `~/.notchfall/inbox`
(write it under a name starting with a dot, then rename it, so it's never read half-written):

```sh
mkdir -p ~/.notchfall/inbox
echo '{"title":"Backup finished","detail":"2.3 GB to the travel drive","symbol":"externaldrive.fill","tint":"green"}' \
  > ~/.notchfall/inbox/.tmp && mv ~/.notchfall/inbox/.tmp ~/.notchfall/inbox/backup.json
```

| Key | What it does |
|---|---|
| `title` | The headline (needed). |
| `detail` | A second line. |
| `symbol` | Any [SF Symbol](https://developer.apple.com/sf-symbols/) name. |
| `tint` | `red`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `white` or `#rrggbb`. |
| `url` | A link or a file path; the card gets a button that opens it. `action` names the button. |
| `from` | Who it's from, shown at the top of the card. |
| `sticky` | `true` keeps the card up until you close it. |
| `style` | `"toast"` for a small one-line toast in the wings instead of a card. |
| `id` + `progress` | `0` to `1` shows a progress ring in the wings (`label` for your own text). Send `"done": true` with the same `id` to finish it. |

Files are deleted once read. Ones older than 10 minutes (from while Notchfall wasn't running) are
dropped. Turn it off with ⚙ Settings → Notch extras → **Notices from scripts**.

---

## Settings

Everything is under **⚙ Settings** in the menu.

| Setting | Options |
|---|---|
| **Island → Alert drops** | 1, 2, 3, 5 or 10 min before |
| **Island → Live countdown beside the notch** | Off, or from 5, 10, 15 or 30 min before (default 10) |
| **Island → Open "Up next" when hovering the notch** | On / off |
| **Island → On air indicator during calls** | Off; During calendar meetings (default); Whenever the mic or camera is on |
| **Island → Show Now Playing (Music, Spotify)** | On (default) / off |
| **Island → Pause music when a meeting alert drops** | On (default) / off |
| **Island → Morning brief** | On (default) / off |
| **Island → Charging and headphone toasts** | On (default) / off |
| **Island → Catch files dragged to the notch** | On (default) / off: the shelf and AirDrop drop zones |
| **Island → Glow colours** | Aurora, Neon, Ember, Ice, Mono |
| **Island → Show on** | The built-in screen with the notch, or the main screen |
| **Sound → Alert sound** | Off, Glass, Hero, Ping, Pop, Purr, Submarine, Tink |
| **Sound → Voice announcement** | Speaks "Design Review starts in 2 minutes." |
| **What to alert for** | Only meetings with video links; Include Apple Reminders |
| **What to alert for → Time to leave** | Off; Travel time from Apple Maps (default); 15 or 30 min before (no location needed). Driving (default), Walking or Transit. |
| **Microphone** | ⌃⌥M mutes the microphone in any app; Remind me when a call starts muted; Unmute when the call ends (all on by default) |
| **Notch extras** | Volume and brightness levels; Download progress; Put finished downloads on the shelf (off); Clipboard history (off); ⌃⌥V opens the clipboard history; Tell me when an app in the Nexus fleet stops; Notices from scripts (all on unless marked off) |
| **Claude Code** | Tell me when Claude finishes or needs me (adds two hooks to `~/.claude/settings.json`, off until you click); …even while I'm looking at its window (off); …and for headless runs, Agent SDK and scripts (off) |
| **Dharalu** | Buy / hold / sell signal changes (on; only shown when Dharalu is installed) |
| **App → Appearance** | System, Light or Dark for the menu and dialogs. The island is always dark. |
| **App → Launch at login** | On / off |

---

## Privacy

Notchfall reads your calendars, and reminders if you turn them on, **on your Mac only**. It has
no server, no account, no analytics and no network access of its own (two exceptions below: Spotify
covers, and Apple Maps travel times for meetings with an address). Clicking **Join** opens the meeting link in your browser or meeting app.

- **Camera check** asks for camera access the first time you use it. The picture is only shown in
  the island; it's never recorded or saved, and the camera turns off when you close it.
- **On air** only checks *whether* a microphone or camera is in use (the same signal that lights
  macOS's orange and green dots). It never hears or sees anything, and needs no permission.
- **Now Playing** asks Music and Spotify what's playing, using the same AppleScript that Shortcuts
  uses. macOS asks once per app whether Notchfall may control it. Notchfall only talks to a player
  that's already open, so it never launches one. Apple Music covers come straight from the Music
  app; Spotify only gives a link, so Notchfall downloads that one cover image from Spotify's image
  server.
- **Charging and headphones** are read from macOS's own power and Bluetooth audio state on your Mac.
  No permission, nothing leaves the Mac.
- **Time to leave** only looks up meetings that have a real address. It asks for location access the
  first time there's one coming up, then sends your rough location and the meeting's address to Apple
  Maps for the travel time (as the Maps app would). Your location isn't stored. Pick **15 or 30 min
  before** to skip location entirely.
- **File shelf** keeps only the paths of the files you drop, on your Mac. To notice a file drag it
  checks *that* a file is being dragged, never which one, until you drop it. AirDrop is macOS's own.
- **Mute** flips the microphone's own mute switch (or turns its input volume to zero and back). It
  never listens to the microphone, and **⌃⌥M** uses macOS's hot-key API, so it needs no
  Accessibility or Input Monitoring permission.
- **Volume and brightness** are read from macOS's own audio and display settings, a few times a
  second while nothing else happens. No permission.
- **Downloads** looks at the names and sizes of files in **~/Downloads** that are still downloading
  (and Safari's own progress numbers in its `.download` bundle), never what's in them. macOS may ask once whether Notchfall can see the Downloads folder.
- **Clipboard history** is **off** until you turn it on, and kept **in memory only** and gone when Notchfall quits. Items that password
  managers mark as secret (1Password and others that use the standard *concealed* flag) are skipped, and **Clear the history** empties it at any time.
  macOS 15.4 and later asks before an app reads the clipboard by itself: choose **Allow**, or set
  Notchfall to **Always Allow** in System Settings → Privacy & Security → Paste from Other Apps so it
  doesn't ask after each copy.
- **Claude Code** hooks are only added when you click the setting. The first time,
  Notchfall backs up `~/.claude/settings.json` to `settings.json.notchfall-backup` (later clicks
  never overwrite that original copy). It won't touch a settings file that isn't valid JSON, and leaves every other setting and
  hook alone; clicking again removes just its own two. The hooks write what Claude Code passes them
  (folder, session, message) into `~/.notchfall/inbox`; for *done* Notchfall reads the last reply in
  that session's transcript, on your Mac, to show its first line.
- **Fleet alerts** and **Dharalu** only read the status files those apps already write on your Mac.
- **Morning brief** uses the same calendar and reminders Notchfall already reads. To know you're at
  the Mac it only checks that the screen is awake and unlocked and that a key or the mouse was used
  in the last minute; it never sees *what* you typed.

---

## Troubleshooting

**macOS says the app is damaged or can't be opened.**
Run `xattr -dr com.apple.quarantine /Applications/Notchfall.app` in Terminal, then open it again.

**The menu says "Calendar access denied".**
Click that line, or go to System Settings → Privacy & Security → Calendars, and turn Notchfall on.

**The alert didn't appear.**
Check the timing table above. If you dismissed the alert earlier, it won't come back. If the
meeting has no video link, check that **Only meetings with video links** is off.

**Hovering the notch does nothing.**
Hover only works on a screen with a real notch, and only if **Open "Up next" when hovering
the notch** is on. On other screens, use the menu.

**The island shows on the wrong screen.**
Settings → Island → **Show on**.

**On air shows when I'm not on a call.**
Some apps keep the microphone open in the background. Set **On air indicator during calls** to
**During calendar meetings** (the default) so it only shows while a meeting is on.

**Camera check says access is off.**
System Settings → Privacy & Security → Camera, and turn Notchfall on.

**Now Playing doesn't show.**
Notchfall needs permission to control the player: System Settings → Privacy & Security →
Automation → Notchfall, and turn on **Music** and/or **Spotify**. Also check Settings → Island →
**Show Now Playing**. Other players (browsers, Podcasts) aren't supported.

**Time to leave says "Allowing 15 min" instead of a real drive time.**
Notchfall couldn't get your location or find the address. Allow it in System Settings → Privacy &
Security → Location Services → Notchfall (the **Time to leave** menu has a shortcut), and check the
meeting's location is a full street address.

**⌃⌥M does nothing.**
Another app may already use ⌃⌥M; macOS gives a shortcut to whichever app took it first. Check that
**⌃⌥M mutes the microphone in any app** is on, and quit the other app or change its shortcut.

**Muting turns the mic's input volume to zero.**
Some microphones have no mute switch, so Notchfall turns the input volume down instead, and puts it
back when you unmute. If you quit Notchfall while muted, reset it in System Settings → Sound → Input.

**Dragging a file to the notch doesn't open the drop zones.**
Check **Catch files dragged to the notch** is on, and drag right up under the notch. You can also
drop onto the shelf when the island is open on hover.

**The volume or brightness bar doesn't show.**
Check Settings → Notch extras → **Volume and brightness levels**. Brightness only works for the
built-in screen; some external speakers and screens don't report a level at all.

**Downloads don't show.**
Only downloads into **~/Downloads** are seen. If macOS asked about the Downloads folder and you
said no, allow it in System Settings → Privacy & Security → Files and Folders → Notchfall.

**⌃⌥V does nothing, or the history stays empty.**
Clipboard history is off until you turn it on in ⚙ Settings → Notch extras. If it's on but nothing
appears, Notchfall was told *Don't Allow*: change it in System Settings → Privacy & Security →
Paste from Other Apps. Another app may also already use ⌃⌥V. Check **⌃⌥V opens the clipboard history** is on, or use menu →
**📋 Clipboard → Show in the notch**.

**Claude Code finished but nothing dropped.**
Start a new Claude Code session after turning the setting on. By default nothing shows while its
terminal or editor is the app in front (you can already see it): turn on **…even while I'm
looking at its window** to change that. Runs from the Agent SDK or `claude -p` scripts only show
with **…and for headless runs**. To undo everything, copy `settings.json.notchfall-backup` back.

**Two islands draw over each other.**
Another copy of Notchfall (say, a second edition) is running. Notchfall says so and offers to quit
the other one.

**I also use T-Minus.**
Both apps would alert for the same meeting. Keep one running, or set one to **Only meetings
with video links**.

---

## Credits

Notchfall shares its calendar and timer engine with
[T-Minus](https://github.com/Sravankumartangudu/t-minus), and its island is inspired by the
iPhone's Dynamic Island and the many notch apps for the Mac.

## License

[MIT](LICENSE)
