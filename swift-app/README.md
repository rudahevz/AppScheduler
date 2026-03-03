# Swift App

The final, production-ready version of App Scheduler. A native macOS menu bar app built with Swift and SwiftUI targeting macOS 13.0+.

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later

---

## Build & Run

```bash
open AppScheduler.xcodeproj
```

Press `Cmd+R` in Xcode. The app appears in your menu bar as a clock icon.
Left-click to open the scheduler window. Right-click to quit.

---

## File Reference

### `AppSchedulerApp.swift`
App entry point (`@main`). Sets activation policy to `.accessory` to keep the app out of the Dock and App Switcher entirely.

**Changes:** No changes since v1.0.

---

### `AppDelegate.swift`
Manages the menu bar presence and popover window.

- Creates the `NSStatusItem` (menu bar icon) with a `clock.fill` SF Symbol
- Shows/hides the `NSPopover` on left-click — popover uses `.transient` behavior (auto-closes when clicking outside)
- Icon switches to `clock.badge.checkmark.fill` when the scheduler is running
- Right-click or Ctrl+click shows a context menu with **"Quit App Scheduler"** — this is the reliable way to quit since `NSApp.terminate()` can't be called from SwiftUI sheets
- Listens for `schedulerStateChanged` `NotificationCenter` posts to update the icon

**Changes:**
- v1.5: Added right-click context menu for quitting; replaced `togglePopover` with `handleClick` that routes left vs right mouse events
- v1.7: Popover size updated to 420×520 to match new glass UI layout

---

### `Config.swift`
Data models and UserDefaults persistence.

- `ScheduleEntry`: one scheduled item — `id` (UUID), `targetPath`, `targetName`, `openTime?`, `closeTime?`, `isPaused`
- `SchedulerConfig`: the full app config — `entries: [ScheduleEntry]`, `isRunning`, `showCountdown`
- `ConfigStore.load()` / `ConfigStore.save()` encode/decode via `JSONEncoder` into UserDefaults

**Changes:**
- v1.1: Added `targetPath` and `targetName` (replaced `appName`)
- v1.2: Replaced single entry with `entries: [ScheduleEntry]` array; added `ScheduleEntry` struct; UserDefaults key bumped to `v2`
- v1.3: Replaced `isEnabled` per entry with `isPaused`; added `showCountdown`; UserDefaults key bumped to `v3`
- v1.4: Removed `checkInterval` (no longer needed after one-shot timer)

---

### `Scheduler.swift`
The scheduling engine. All logic lives here.

**How it works:**
1. `scheduleNextEvent()` scans all active entries and finds the exact `Date` of the soonest upcoming open or close
2. A single one-shot `Timer` fires at that precise moment — zero CPU between events
3. On fire: `fireEvents(at:)` runs all matching open/close actions, then `scheduleNextEvent()` is called again for the next one
4. A separate 1-second `countdownTimer` drives the `HH:MM:SS` display in the UI only

**Open:** `NSWorkspace.shared.open(url)` — works for `.app` bundles and any file type  
**Close:** Finds matching `NSRunningApplication` by `localizedName` and calls `.terminate()`

**Changes:**
- v1.0: Initial implementation with polling timer; opens apps via modern `NSWorkspace.openApplication(at:)` (replaces deprecated `launchApplication()`)
- v1.1: `openTarget()` switched to `NSWorkspace.shared.open(url)` for file support
- v1.2: Added `dailyState: [UUID: (opened, closed)]` for per-entry tracking
- v1.3: Added `countdownTimer`, `nextEventLabel`, `nextEventCountdown`; added `entryAdded()` auto-start
- v1.4: Replaced polling timer with precise one-shot `Timer`; added `startedAt` to prevent retroactive firing; removed `checkInterval`

---

### `SchedulerView.swift`
All SwiftUI views. This is the largest file and received the most changes.

**Structure (current):**
- `SchedulerView` — root view with mesh gradient background + glass window; routes between Schedules and Settings tabs
- Sidebar (56px) — tab icons, active indicator bar, running status dot
- `schedulesView` — header, optional countdown banner, entry list, footer bar
- `EntryRow` — single entry card: real app icon, time badges, pause button
- `EntrySheet` — modal for adding/editing: file picker, open/close time toggles, delete
- `settingsView` — inline settings rows: Show Countdown toggle, Open at Login toggle, Quit hint

**Changes:**
- v1.0: Initial view with preset app grid and single-target config
- v1.1: Replaced preset grid with `NSOpenPanel` file picker; added Settings sheet with gear icon
- v1.2: Replaced single-target layout with scrollable entry list; added `EntryRow` and `EntrySheet`
- v1.3: Added countdown banner; per-entry pause button; "Pause All / Resume All" bottom bar button
- v1.4: Removed check interval stepper from Settings sheet
- v1.5: Removed broken Quit button from Settings; `NSOpenPanel` now uses `.floating` level, activates app, and positions at top-left of screen; default time shows current HH:MM instead of hardcoded 9:00
- v1.6: All entry icons now use `NSWorkspace.shared.icon(forFile:)` for real system icons; fallback to SF Symbol
- v1.7: Complete redesign — glass sidebar layout with mesh gradient background, `.ultraThinMaterial`, tab navigation, redesigned entry rows with capsule badges, Settings moved to sidebar tab
- v1.7.1: Fixed Swift syntax error — `.padding(.vertical: 2)` → `.padding(.vertical, 2)`

---

### `LaunchAtLogin.swift`
Thin wrapper around `SMAppService` (macOS 13+) for open-at-login support.

- `LaunchAtLogin.isEnabled` — reads current registration state
- `LaunchAtLogin.setEnabled(_ enabled: Bool)` — registers or unregisters the app as a login item

**Changes:** No changes since v1.1 when it was introduced.

---

### `Info.plist`
App metadata and system permissions.

- `LSUIElement = true` — hides the app from Dock and App Switcher
- `LSApplicationCategoryType = public.app-category.utilities`
- `NSAppleEventsUsageDescription` — permission string for AppleScript access

**Changes:** No changes since v1.0.

---

### `Assets.xcassets`
- `AppIcon` — app icon asset (see `AppSchedulerIcon.svg` for the source)
- `AccentColor` — `#c8f060` (yellow-green), used as tint throughout the UI

---

### `AppSchedulerIcon.svg`
A 1024×1024 SVG app icon in the glass style matching the UI:
- Purple/blue/pink mesh gradient background
- Frosted glass card with sidebar layout
- Clock icon as active element with `#c8f060` accent
- Entry rows and countdown visible in the icon composition

To use: open in a browser, export/screenshot at 1024×1024, drag PNG into Xcode's `Assets.xcassets → AppIcon`.
