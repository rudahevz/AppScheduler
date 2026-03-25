# Changelog

## v3.0.3

### Added
- Accessibility Permission grant button in Settings — one tap opens Privacy & Security → Accessibility

---

## v3.0.2

### Fixed
- Apps not closing at scheduled time — root cause was missing `com.apple.security.automation.apple-events` entitlement; restored original `terminate()` logic which works correctly with that entitlement
- File picker (NSOpenPanel) grayed out on first open — added 1.5s activation delay before showing the panel
- Network sandbox error blocking update checker — added `network.client` entitlement
- `ProgressView` constraint warning in Settings
- `clock.badge.plus` SF Symbol unavailable on macOS 13 — replaced with `clock.arrow.circlepath`

### Added
- Check for Updates in Settings tab — silent check on launch, manual check button
- File picker now opens beside the popover instead of behind it
- Default schedule time is now 1 minute from now instead of current time

---

## v3.0.1

### Fixed
- NSOpenPanel crash when selecting an app or file — added missing `com.apple.security.files.user-selected.read-write` entitlement
- SF Symbol `clock.badge.plus` replaced with `clock.arrow.circlepath` for macOS 13 compatibility

---

## v3.0.0 — Mouse Jiggler

### New Feature: Mouse Jiggler

Added a new **Jiggler** tab with two modes to prevent screen lock and keep presence indicators active.

**Subtle** — Posts a real HID-level mouse event every 15 seconds, nudging the cursor 1px then snapping it back. Imperceptible during normal use.

**Human** — Moves the cursor continuously along randomised Bézier arcs with natural pauses, simulating real browsing behaviour. Automatically yields to the user — detects real mouse movement and pauses immediately, resuming 2 seconds after you stop.

Both modes require Accessibility permission.

---

## v2.0.0 — Customizable Keyboard Shortcuts

Complete keyboard shortcut system — shortcuts are now user-configurable and persisted across launches.

---

## v1.9.0 — Keyboard Shortcuts

Nine keyboard shortcuts added across the app following standard macOS conventions.

---

## v1.8.0 — macOS HIG Compliance

Full audit and fixes against Apple's Human Interface Guidelines.

---

## v1.7 — Glass UI Redesign

Complete visual overhaul to match Apple's macOS Sequoia vibrancy / glass aesthetic.

---

## v1.0–v1.6 — Initial Swift App

Complete rewrite from Python prototype. Full Xcode project targeting macOS 13.0+. Added file picker, multiple schedule entries, auto-start, per-entry pause, countdown clock, precise one-shot timer, real app icons, and glass UI.
