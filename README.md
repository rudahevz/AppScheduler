# App Scheduler

A macOS menu bar app that automatically opens and closes apps or files on a daily schedule. Set Slack to open at 9:00 AM and close at 6:00 PM, or have an Excel report launch every morning — all managed silently from your menu bar.

---

## Project History

This project started as a Python CLI script and evolved into a native Swift app over multiple iterations:

```
AppScheduler/
├── python-prototype/
│   ├── v1-cli-script/        Original Python terminal script
│   ├── v2-menubar-app/       Python menu bar app (rumps + tkinter)
│   └── v3-html-ui/           HTML/JS config UI prototype
└── swift-app/                Final native Swift/SwiftUI macOS app ← use this
```

---

## Final App — Swift (Recommended)

Native macOS menu bar app. ~2MB, no dependencies, no Python or runtime required.

**Requirements:** macOS 13.0 (Ventura) or later · Xcode 15 or later

**To build:**
```bash
open swift-app/AppScheduler.xcodeproj
# Press Cmd+R in Xcode to build and run
```

**Features:**
- Lives entirely in the menu bar — no Dock icon
- Schedule multiple apps or files independently
- Each entry has an optional open time, close time, or both
- Pause/resume individual entries or all at once
- Countdown clock (HH:MM:SS) to next scheduled event
- Precise one-shot timer — zero CPU usage between events
- Real app icons pulled from the system for each entry
- Glass UI with sidebar navigation (macOS Sequoia style)
- Open at login via SMAppService
- Right-click the menu bar icon to quit
- All settings persist via UserDefaults

---

## Python Prototype

Built first to validate the concept. See [`python-prototype/README.md`](python-prototype/README.md).

---

## App Icon

`swift-app/AppSchedulerIcon.svg` — A 1024×1024 glass-style icon matching the app's UI aesthetic.
To use in Xcode: export as PNG at 1024×1024, then drag into `Assets.xcassets → AppIcon`.

---

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md) for the complete version-by-version history.
