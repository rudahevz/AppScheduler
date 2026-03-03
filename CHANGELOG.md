# Changelog

Complete history of every change made to App Scheduler, from first prototype to final Swift app.

---

## Python Prototype Era

### v0.1 — CLI Script (`python-prototype/v1-cli-script/`)

First working version. A Python terminal script that opens and closes one macOS app on a schedule.

- Opens an app via `open -a <AppName>` using `subprocess`
- Closes an app via AppleScript `tell application X to quit`
- Detects if an app is already running via System Events AppleScript
- Config is defined as constants at the top: `APP_NAME`, `OPEN_TIME`, `CLOSE_TIME`, `CHECK_INTERVAL`
- Runs in a loop in the terminal, polling every N seconds
- Resets open/close flags at midnight to re-trigger the next day

---

### v0.2 — HTML Config UI (`python-prototype/v3-html-ui/`)

A single-file HTML/JS app for generating the Python script visually without editing code.

- Dark theme: `#0e0f11` background, `#c8f060` yellow-green accent
- Preset app grid: Safari, Spotify, Slack, Notes, Mail, Calendar, Terminal + custom input
- Time pickers for open and close times
- Check interval slider (5–300 seconds)
- Generates and syntax-highlights the ready-to-run Python script
- Copy-to-clipboard button
- Uses DM Mono + Fraunces fonts from Google Fonts
- Single `.html` file — no server needed, just open in any browser

---

### v0.3 — Menu Bar App (`python-prototype/v2-menubar-app/`)

First real app experience. A macOS menu bar app using `rumps` + `tkinter`.

- `⏰` icon lives in the menu bar; click to open Settings
- Dark-themed `tkinter` settings window
- Preset apps: Safari, Spotify, Slack, Notes, Mail, Calendar, Terminal, Finder, Figma, Messages
- Persistent config via JSON at `~/.app_scheduler_config.json`
- Scheduler runs on a background thread, polling every N seconds
- Opens apps via `open -a`, closes via AppleScript quit
- `build_app.sh` packages it as a standalone `.app` using PyInstaller
- Build script updated to auto-detect Python 3.11+ (fixes `pyobjc-core 12.0` incompatibility with Python 3.9)

---

## Swift App Era

The Python approach worked but produced an ~80MB bundle and required a runtime. Rewritten from scratch in Swift/SwiftUI for a native, dependency-free experience (~2MB).

---

### v1.0 — Initial Swift App

Complete rewrite. Full Xcode project targeting macOS 13.0+.

**AppSchedulerApp.swift**
- `@main` app entry point
- Sets activation policy to `.accessory` to hide from Dock and App Switcher

**AppDelegate.swift**
- Creates `NSStatusItem` (menu bar icon)
- `NSPopover` with `.transient` behavior — closes when clicking outside
- Icon switches between `clock.fill` (idle) and `clock.badge.checkmark.fill` (running)
- Listens for `schedulerStateChanged` notifications to update the icon

**Config.swift**
- `SchedulerConfig` struct (Codable): `appName`, `openTime`, `closeTime`, `checkInterval`, `isEnabled`, `isRunning`
- `ConfigStore.load()` / `ConfigStore.save()` via UserDefaults + JSON encoding

**Scheduler.swift**
- `@MainActor ObservableObject` managing schedule execution
- Timer polls every N seconds; daily flags reset at midnight
- Opens apps using modern `NSWorkspace.openApplication(at:configuration:completionHandler:)` API — replaces deprecated `launchApplication()`
- `findAppURL()` searches `/Applications`, `~/Applications`, `/System/Applications`
- Closes apps via `NSRunningApplication.terminate()`

**SchedulerView.swift**
- Preset app grid (10 apps) + custom name input
- `DatePicker` for open/close times
- Interval stepper (5–300 seconds)
- Start/Stop button
- Dark theme: `#0e0f11` background, `#1e2128` surfaces, `#c8f060` accent

**Info.plist**
- `LSUIElement = true` — hides from Dock
- `LSApplicationCategoryType = public.app-category.utilities`
- `NSAppleEventsUsageDescription` for permissions

---

### v1.1 — File Picker + Single Target

Replaced preset app grid with a Finder-based file picker. Now supports any app or file type.

**SchedulerView.swift**
- Removed 10-app preset grid
- Added "Choose App or File…" button that opens `NSOpenPanel`
- Shows selected file icon, name, and full path
- Icon adapts to type: `.app`, `.xlsx`, `.xls`, `.csv`, `.pdf`, or generic
- Gear icon `⚙` opens a Settings sheet
- Settings sheet: check interval stepper, open at login toggle, quit button

**Config.swift**
- Added `targetPath` (full filesystem path) and `targetName` (display name)

**Scheduler.swift**
- `openTarget()` now uses `NSWorkspace.shared.open(url)` — works for apps and files alike

**LaunchAtLogin.swift** ← new file
- Thin wrapper around `SMAppService` (macOS 13+)
- `LaunchAtLogin.isEnabled` reads current state
- `LaunchAtLogin.setEnabled(_ enabled: Bool)` registers or unregisters

---

### v1.2 — Multiple Schedule Entries

Each schedule is now an independent entry with its own target and optional open/close times.

**Config.swift**
- New `ScheduleEntry` struct: `id` (UUID), `targetPath`, `targetName`, `openTime?`, `closeTime?`, `isEnabled`
- `SchedulerConfig.entries: [ScheduleEntry]` replaces single-target fields
- UserDefaults key bumped to `SchedulerConfig_v2` to avoid decoding conflicts

**Scheduler.swift**
- `dailyState: [UUID: (opened: Bool, closed: Bool)]` tracks per-entry daily state
- Iterates all entries on each tick; skips disabled ones
- `openTarget()` and `closeTarget()` now accept a `ScheduleEntry`

**SchedulerView.swift**
- Main view is a scrollable entry list
- `EntryRow`: file icon, name, open/close time tags (green open, red close, grey disabled)
- Tap a row to open `EntrySheet` for editing
- `EntrySheet`: file picker, open/close time toggles + pickers, enable toggle, delete button
- `+ Add` button in bottom bar adds a new entry
- Empty state shown when list is empty

---

### v1.3 — Auto-Start + Per-Entry Pause + Countdown Clock

**Auto-start**
- Adding an entry calls `entryAdded()` which starts the scheduler automatically
- Scheduler auto-starts on launch if entries already exist

**Config.swift**
- Replaced `isEnabled` per entry with `isPaused` (clearer semantics)
- Added `showCountdown: Bool` to `SchedulerConfig`
- UserDefaults key bumped to `SchedulerConfig_v3`

**Scheduler.swift**
- Added `nextEventLabel: String` and `nextEventCountdown: String` published properties
- `countdownTimer` fires every second to update the display
- `recomputeNextEvent()` finds the soonest upcoming open/close across all active entries

**SchedulerView.swift**
- Countdown banner at the top showing `HH:MM:SS` and next event name
- Per-entry ⏸/▶ pause button on each row
- Global "Pause All / Resume All" toggle button in the bottom bar (replaced Stop button)
- `showCountdown` toggle added to Settings sheet

---

### v1.4 — Precise One-Shot Timer (Zero CPU)

Replaced the polling timer with an exact one-shot timer that sleeps until the next event.

**Scheduler.swift**
- Removed polling `actionTimer` entirely
- `scheduleNextEvent()` calculates the exact `Date` of the next open/close across all entries
- A single `Timer` fires at that precise moment, executes actions, then immediately schedules the next one
- `fireEvents(at:)` matches entries by exact `HH:MM` and runs open/close
- Zero CPU usage between events; only the 1-second countdown display timer runs continuously
- Added `startedAt: Date` — actions only fire for times that occur after the scheduler started (prevents firing on past times from today)

**Config.swift**
- Removed `checkInterval` — no longer needed

**SchedulerView.swift**
- Removed check interval stepper from Settings sheet

---

### v1.5 — Quit via Right-Click + NSOpenPanel Positioning

**AppDelegate.swift**
- Replaced single `togglePopover` action with `handleClick` that detects left vs right mouse button
- Right-click or Ctrl+click on the menu bar icon shows a context menu with "Quit App Scheduler"
- `quitApp()` calls `NSApplication.shared.terminate(nil)` from AppKit (reliable, not from SwiftUI)
- Left-click still toggles the popover as before

**SchedulerView.swift**
- Removed broken "Quit" button from Settings sheet (SwiftUI sheets can't reliably call `NSApp.terminate`)
- `NSOpenPanel` (file picker) now:
  - `panel.level = .floating` — renders above the popover
  - `NSApp.activate(ignoringOtherApps: true)` — brings app forward before showing panel
  - `panel.setFrameOrigin()` — positions panel at top-left of screen near the Apple logo
- Default time for new entries now shows the current time (HH:MM) instead of hardcoded 9:00 AM

---

### v1.6 — Real App Icons

**SchedulerView.swift**
- `EntryRow` and `EntrySheet` now use `NSWorkspace.shared.icon(forFile:)` to load the real system icon for each selected app or file
- Icons render at 28×28pt inside a rounded square, clipped with `RoundedRectangle(cornerRadius: 6)`
- Paused entries dim the icon to 35% opacity
- Falls back to an SF Symbol only if the path is empty or icon can't be loaded

---

### v1.7 — Glass UI Redesign (Concept B — Sidebar Navigation)

Complete visual overhaul to match Apple's macOS Sequoia vibrancy / glass aesthetic.

**SchedulerView.swift** — full rewrite
- Replaced the flat dark layout with a two-panel glass window:
  - **56px sidebar** on the left with icon-based tab navigation
  - **Main content area** on the right
- Sidebar tabs: Schedules (stack icon) and Settings (gear icon) — Settings moved out of a sheet
- Active tab: `#c8f060` accent bar on the left edge + tinted background; inactive icons dimmed
- Status dot at the bottom of the sidebar pulses green when running
- **Background**: layered radial mesh gradients (purple, blue, pink, green) behind `.ultraThinMaterial` — matches macOS Sequoia wallpaper aesthetic
- **Glass border**: `LinearGradient` stroke from bright white (top-left) to faint (bottom-right) for depth
- **Countdown banner**: faint green-tinted panel, `HH:MM:SS` in `#c8f060` with soft glow when running
- **Entry rows**: card design with real app icons, capsule time badges (green open dot, red close dot), per-entry pause button glows yellow when paused
- **EntrySheet**: mini mesh gradient background, same glass aesthetic, section labels in monospaced uppercase
- **Settings tab**: inline rows for Show Countdown, Open at Login, Quit hint — no more sheet
- Popover size updated to 420×520

**AppDelegate.swift**
- Popover `contentSize` updated to `NSSize(width: 420, height: 520)`

---

### v1.7.1 — Swift Syntax Fix

**SchedulerView.swift**
- Fixed `.padding(.vertical: 2)` and `.padding(.horizontal: 6)` — Swift requires comma syntax not colon: `.padding(.vertical, 2)`
- Two occurrences in `timeBadge()` inside `EntryRow`
