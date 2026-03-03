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

---

### v1.8.0 — macOS HIG Compliance

Full audit and fixes against Apple's Human Interface Guidelines.

**SchedulerView.swift**
- FIX #1 — Removed all `.preferredColorScheme(.dark)` and `.colorScheme(.dark)` modifiers — app now respects the user's system appearance (Light / Dark / Auto)
- FIX #2 — Replaced plain `Button("Delete")` in `EntrySheet` with a `.confirmationDialog` showing "Delete Schedule?" with a destructive `Button("Delete", role: .destructive)` and a cancel option — prevents accidental deletion
- FIX #3 — Added `.accessibilityLabel()` to 22 interactive elements across `EntryRow`, `EntrySheet`, the sidebar tab buttons, countdown banner, and bottom bar controls
- FIX #4 — Added `.help()` tooltips to 7 icon-only buttons (pause/resume, add, sidebar tabs, start/stop) so their purpose is clear on hover
- Updated version footer to `v1.8`

**AppDelegate.swift**
- FIX #1 — Removed `.environment(\.colorScheme, .dark)` from the popover's root view

**Scheduler.swift**
- FIX #5 — Added `import UserNotifications`
- Added `notificationsEnabled: Bool` `@Published` property persisted to `UserDefaults`
- Added `setNotificationsEnabled(_ enabled: Bool)` which requests `UNUserNotificationCenter` authorization when toggling on
- Added `sendNotification(title:body:)` private helper
- `openTarget()` and `closeTarget()` now call `sendNotification` after each action

**Info.plist**
- FIX #6 — Bumped `CFBundleShortVersionString` from `1.0` to `1.8.0`, `CFBundleVersion` to `18`
- Added `NSUserNotificationUsageDescription` key with usage string

---

### v1.9.0 — Keyboard Shortcuts

Nine keyboard shortcuts added across the app, following standard macOS conventions.

**SchedulerView.swift**
- `⌘N` — Add new schedule entry (`.keyboardShortcut("n", modifiers: .command)` on the + button)
- `⌘1` — Switch to Schedules tab (`.keyboardShortcut("1", modifiers: .command)` on sidebar item)
- `⌘2` — Switch to Settings tab (`.keyboardShortcut("2", modifiers: .command)` on sidebar item)
- `⌘,` — Open Settings tab (standard macOS preferences shortcut via invisible background button)
- `Space` — Pause / Resume All (`.keyboardShortcut(.space, modifiers: [])` on bottom bar button)
- `⌘S` — Save entry in EntrySheet (`.keyboardShortcut("s", modifiers: .command)` on Save button)
- `⌘⌫` — Delete entry, shows confirmation dialog (`.keyboardShortcut(.delete, modifiers: .command)` on Delete button)
- Added "Keyboard Shortcuts" reference row to the Settings tab listing all shortcuts
- Updated version footer to `v1.9`

**AppDelegate.swift**
- Added `private var keyMonitor: Any?` property for NSEvent monitor lifetime management
- `⌘W` — Close popover (`NSEvent.addLocalMonitorForEvents(matching: .keyDown)` local monitor, fires only when popover is shown)
- `Escape` — Close popover (same monitor, keyCode 53)
- Monitor is removed in `quitApp()` to avoid leaks

---

### v2.0.0 — Customizable Keyboard Shortcuts

Complete keyboard shortcut system rewrite — shortcuts are now user-configurable and persisted across launches.

**Shortcuts.swift** ← new file
- `ShortcutAction` enum with 7 actions: `addSchedule`, `switchSchedules`, `switchSettings`, `pauseResumeAll`, `saveEntry`, `deleteEntry`, `closePopover` — each with a system SF Symbol icon
- `RecordedShortcut` struct: `Codable` model storing `keyCode` (UInt16), `modifierFlags` (UInt rawValue), and `displayString` (e.g. `"⌘N"`, `"Space"`, `"⌘⌫"`)
- `RecordedShortcut.defaults`: default shortcuts matching the v1.9 hardcoded values
- `ShortcutStore` singleton `ObservableObject`: loads/saves to `UserDefaults` key `"CustomShortcuts_v1"`, merges saved shortcuts with defaults, provides `set()`, `resetToDefaults()`, and `action(for: NSEvent)` matcher
- `Notification.Name.shortcutFired` for bridging NSEvent → SwiftUI
- `NSEvent.ModifierFlags.symbols` extension: converts flags to `⌃⌥⇧⌘` symbols
- `shortcutDisplayString(for: NSEvent)` helper: builds human-readable strings, handles special keys (Space, Return, Delete, Escape, arrows, Home, End)

**AppDelegate.swift**
- Removed hardcoded `keyCode` checks (13, 53)
- NSEvent monitor now calls `ShortcutStore.shared.action(for: event)` to match events dynamically
- `.closePopover` handled directly in the monitor; all other actions posted via `NotificationCenter` with `.shortcutFired` and action rawValue in `userInfo`

**SchedulerView.swift**
- Removed all `.keyboardShortcut()` SwiftUI modifiers (now centralized in the NSEvent monitor)
- Removed invisible `⌘,` background button
- Added `.onReceive(NotificationCenter.default.publisher(for: .shortcutFired))` to dispatch actions: `addSchedule`, `switchSchedules`, `switchSettings`, `pauseResumeAll`
- `saveEntry` and `deleteEntry` handled in `EntrySheet` via its own `.onReceive`
- Replaced static "Keyboard Shortcuts" Settings row with a tappable `→` navigation row
- Removed "Quit App" row from Settings (right-click on menu bar icon remains the correct pattern)
- Added `ShortcutsNavigationView` wrapper with slide-in animation (`.easeInOut(duration: 0.22)`)

**ShortcutsEditorView** (inside SchedulerView.swift)
- Header: ← Back button, "Shortcuts" title, Reset button with confirmation dialog
- Scrollable list of all 7 actions with icon, name, and tappable shortcut badge
- Badge states: normal (shows current shortcut), recording (pulsing dot + "recording…"), none ("none" in dim text)
- Tap any badge → starts recording mode via `NSEvent.addLocalMonitorForEvents`
- Recording requires at least one modifier key (⌘⌥⌃⇧); bare Space is the only allowed unmodified key
- Escape (keyCode 53) cancels recording without saving
- Valid combo → builds `RecordedShortcut` → calls `ShortcutStore.shared.set()` → stops recording
- `@State private var pulsing` drives the recording indicator animation
- Full `.accessibilityLabel()` on all rows describing current shortcut state and recording mode

**Info.plist**
- `CFBundleShortVersionString` bumped to `2.0.0`, `CFBundleVersion` to `20`

---

### Distribution Setup

Added signing, notarization, and automated release infrastructure (not a Swift code change).

**AppScheduler.entitlements** ← new file
- Hardened Runtime enabled (`com.apple.security.cs.*` keys)
- `com.apple.security.automation.apple-events = true` for open/close scheduling
- No App Sandbox (incompatible with core features: arbitrary app launching and process termination)

**project.pbxproj**
- Release build config: `CODE_SIGN_STYLE = Manual`, `CODE_SIGN_IDENTITY = "Developer ID Application"`, `ENABLE_HARDENED_RUNTIME = YES`, `OTHER_CODE_SIGN_FLAGS = "--timestamp --options=runtime"`
- `CODE_SIGN_ENTITLEMENTS` wired to `AppScheduler/AppScheduler.entitlements` in both Debug and Release
- `PRODUCT_BUNDLE_IDENTIFIER` set to `com.rudakirsch.appscheduler`
- Fixed UUID collision bug: `B006` previously assigned to both `Shortcuts.swift` and `Assets.xcassets` — now unique IDs throughout

**.github/workflows/release.yml** ← new file
- Triggers on version tag push (`v*.*.*`) or manual dispatch
- Runs on `macos-15` runner (avoids `xcodebuild -exportArchive` segfault present on macos-14/Xcode 15)
- Steps: checkout → import Developer ID cert into temp keychain → `xcodebuild archive` → copy `.app` from archive + re-sign with `codesign` → `xcrun notarytool submit --wait` → `xcrun stapler staple` → `create-dmg` → sign + notarize DMG → upload artifact → create GitHub Release

**scripts/build-release.sh** ← new file
- Same pipeline as CI but runs locally on your Mac
- Reads `TEAM_ID`, `BUNDLE_ID`, `APPLE_ID`, `APP_PASSWORD` from environment variables
