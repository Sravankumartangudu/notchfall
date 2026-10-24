# Changelog

## 1.5.0 (2026-10-24)

More than meetings: the island now shows the things you'd otherwise look away for.

- **🔊 Volume and ☀️ brightness.** Change either and a slim level bar shows in the wings, with a
  struck-through speaker when muted. Settings → Notch extras → **Volume and brightness levels**.
- **⏳ Downloads.** Downloads into ~/Downloads from Safari, Chrome, Edge, Brave, Arc or Firefox
  fill a ring beside the notch with the percent (Safari's own progress numbers, or the size so far
  for other browsers); when done, *Downloaded …*, and (opt-in) onto the shelf. Only file names and
  sizes are looked at; a download that stalls for 90 seconds stops spinning.
- **📋 Clipboard history** (opt-in: Settings → Notch extras). **⌃⌥V** opens the last 20 things you copied (text, links, images,
  files) under the notch; click one to copy it again. Also menu → **📋 Clipboard**. In memory
  only; password-manager items are never kept. macOS 15.4+ asks before an app reads the clipboard,
  so turning it on explains how to allow it (*Always Allow*) and points to the setting if it's off.
- **🤖 Claude Code.** Settings → Claude Code → **Tell me when Claude finishes or needs me** adds two
  hooks to ~/.claude/settings.json (the original is backed up the first time; click again to remove just Notchfall's two). *Claude is done* shows
  the folder and the first line of its reply; *Claude needs you* shows what it's asking; **Show**
  brings the terminal or editor forward. Quiet while you're already looking at it, and for
  headless runs, unless you say otherwise.
- **🛰 Fleet alerts.** With Nexus 1.11 or later, an app in the fleet that quits unexpectedly, stops
  responding or reports an error drops out of the notch, with **Relaunch**.
- **⚖️ Dharalu.** A buy / hold / sell change for wheat or a metal shows with the latest price and
  **Open Dharalu**.
- **📮 Post to the notch.** Scripts can drop JSON files into ~/.notchfall/inbox for a card, a toast
  or a progress ring. See the README.
- Cards queue one at a time, wait for alerts, close after 9 seconds unless you're pointing at them,
  and stay up when they need you.
- If another copy of Notchfall is drawing on the notch, it says so and offers to quit it.
- **✨ Preview an alert** gains Claude Code is done / needs you, Download progress, Volume,
  Brightness, Clipboard history, An app quit unexpectedly, Notice from a script and Dharalu signal
  change.

## 1.4.0 (2026-10-24)

- **🚗 Time to leave.** Meetings at a real address (not a video link) get a *Time to leave* alert
  when it's time to go: travel time from Apple Maps plus 5 minutes, the start time, the address
  and a **Directions** button that opens Maps. A *LEAVE NOW* countdown sits beside the notch
  before it. Driving, walking or transit, or a fixed 15 or 30 minutes with no location at all.
  Location is only asked for once a meeting with an address comes up.
- **📂 File shelf and AirDrop.** Drag a file up to the notch and two drop zones open: **Shelf**
  keeps it for later, **AirDrop** sends it to a nearby device. Hover the notch to see the shelf
  under **Up next**: drag files back out, double-click to open, ✕ to take one off, or AirDrop
  them all. Menu → **📂 Shelf** shows each file in Finder. Up to 12 files; only their paths are kept.
- **🎤 Mute from anywhere.** **⌃⌥M** (or menu → **🎤 Mute microphone**) mutes the microphone
  itself, so every meeting app hears silence. The wings say *Muted* / *Mic on*, the on-air light
  shows a struck-through mic, a call that starts while you're muted gets *You're muted*, and the
  mic comes back on when the call ends. No Accessibility permission needed.
- New settings: Island → **Catch files dragged to the notch**; What to alert for → **Time to
  leave**; and a **Microphone** section.
- **✨ Preview an alert** gains Time to leave, Leave-by countdown, Muted, You're muted, On air
  (muted), Drop a file and Shelf.

## 1.3.0 (2026-10-24)

- **☀️ Morning brief.** Once a day, the first time you're at the Mac between 5:00 and noon, the
  island opens with *Good morning*: meetings today, the first one, reminders due and a timeline of
  the day, with **Calendar** and **Got it**. It closes itself after 12 seconds (not while you're
  pointing at it), and waits if a meeting is about to start.
- **🍅 Focus timer.** Menu → **🍅 Focus** → 25 or 50 minutes. A tomato ring and mm:ss count down
  beside the notch; when it's done, an alert offers **Start break** or **5 more min**, and the break
  calls you back with **Back to focus**. Sessions survive a restart.
- **⚡ Charging and 🎧 headphones toasts.** Plugging in the charger shows the battery filling to its
  level; connecting AirPods or other headphones shows their name. Three seconds each, at most once a
  minute per device. Settings → Island → **Charging and headphone toasts**.
- **✨ Preview an alert** gains Morning brief, Charging, Headphones connected, Focus session and
  Focus session done.

## 1.2.0 (2026-10-24)

- **🎵 Now Playing.** While Apple Music or Spotify plays, the album cover sits in the left wing and
  an equaliser tinted by the cover dances in the right. Hovering the notch shows the player on top
  of **Up next**: cover, song, artist, progress and ⏮ ⏯ ⏭.
- **Pauses for meetings.** When a meeting alert drops the music pauses; dismissing or snoozing
  plays it again, and after **Join** it waits until the call is over. Settings → Island →
  **Pause music when a meeting alert drops**.
- Notchfall only talks to a player that's already open, so it never launches Music or Spotify.
- **✨ Preview an alert** gains **Now Playing**, and **Take the tour** starts with music playing.

## 1.1.0 (2026-10-24)

- **🪞 Camera check.** A new button on meeting alerts opens a live, mirrored camera preview inside
  the island, with **Back** and **Join**. The camera only runs while it's open.
- **🎙 On air.** While you're on a call, a slim island beside the notch shows mic and camera lights
  and the time left in the meeting. The rim glows in the last 5 minutes, and a **Next** line appears
  when another meeting starts straight after. Settings → Island → **On air indicator during calls**
  (Off / During calendar meetings / Whenever the mic or camera is on).
- Always-listening voice assistants (Siri, wake-word apps) don't count as being on a call.
- **✨ Preview an alert** gains **Camera check** and **On air**, and **Take the tour** shows both.

## 1.0.0 (2026-10-23)

First release.

- Meeting, reminder and timer alerts grow out of the notch with a bulge, a spring, a content
  blur-in and a ripple.
- Animated glow rim that speeds up and turns red as the start gets close; five colour sets.
- Rolling countdown, draining ring badge, LIVE / DUE NOW / TIME'S UP tags, a shimmering title once
  live, and attendee initials.
- One-click **Join** for Google Meet, Zoom and Microsoft Teams links in the event.
- Live countdown beside the notch in the minutes before a meeting.
- **Up next** list when you hover the notch.
- Apple Reminders (opt-in) and quick timers.
- Works without a notch: the island hangs from the middle of the menu bar.
- Sound, voice announcement, launch at login, System / Light / Dark appearance.
- **✨ Preview an alert** menu, including **Take the tour**.
