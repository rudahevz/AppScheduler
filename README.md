# App Scheduler

**Automatically open and close any app or file on a daily schedule — from your Mac menu bar.**

Set Slack to open at 9:00 AM and quit at 6:00 PM. Launch your morning report at 8:30 AM. Have Spotify close itself at midnight. App Scheduler runs silently in the background and handles it all, with zero CPU usage between events.

---

## What it does

App Scheduler sits in your menu bar. Click the clock icon to manage your schedules.

You can add as many entries as you want — each one independently targets any app or file on your Mac, with its own open time, close time, or both. Everything persists across restarts and you can pause individual entries without deleting them.

**Each entry can:**
- Open an app or file at a set time
- Close an app at a set time
- Both open and close on the same daily schedule
- Be paused temporarily without losing its settings

---

## Features

- **Menu bar only** — no Dock icon, no app switcher clutter
- **Multiple schedules** — unlimited independent entries, each with its own app and times
- **Precise timing** — one-shot timer fires at the exact second, not a polling loop
- **Zero CPU between events** — the app sleeps until the next scheduled moment
- **Real app icons** — each entry shows the actual icon of the target app
- **Per-entry pause** — pause and resume individual entries independently
- **Pause All / Resume All** — one button to freeze or unfreeze everything
- **Countdown clock** — HH:MM:SS timer showing time until the next event
- **Customizable keyboard shortcuts** — all shortcuts can be changed and are saved per-user
- **System notifications** — optional alerts when an app opens or closes
- **Open at login** — start automatically when you log in to your Mac
- **Right-click to quit** — right-click the menu bar icon for a quick-exit menu
- **Glass UI** — dark mesh gradient design with sidebar navigation

---

## Keyboard shortcuts

All shortcuts are customizable via **Settings → Shortcuts**.

| Shortcut | Action |
|---|---|
| `⌘N` | Add new schedule |
| `⌘1` | Switch to Schedules tab |
| `⌘2` | Switch to Settings tab |
| `⌘,` | Open Settings |
| `Space` | Pause / Resume All |
| `⌘S` | Save entry (in edit sheet) |
| `⌘⌫` | Delete entry (with confirmation) |
| `⌘W` | Close the popover |
| `Esc` | Close the popover |

---

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

---

## Download

Go to [**Releases**](../../releases) and download the latest `AppScheduler.dmg`.

1. Open the DMG
2. Drag **App Scheduler** to your Applications folder
3. Launch it — it appears in your menu bar

> Signed with a Developer ID certificate and notarized by Apple. No security warnings on launch.

---

## Build from source

```bash
# Clone the repo
git clone https://github.com/rudahevz/AppScheduler.git
cd AppScheduler

# Open in Xcode
open swift-app/AppScheduler.xcodeproj

# Press ⌘R to build and run
```

**Requirements:** Xcode 15 or later

---

## Why not the Mac App Store?

App Scheduler's core feature — closing other apps — requires terminating processes that the App Sandbox does not allow. Like most power-user menu bar utilities (Alfred, Bartender, etc.), it is distributed directly with a Developer ID certificate instead.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history from first prototype to current release.
