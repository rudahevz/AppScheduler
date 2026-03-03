# Python Prototype

Early iterations of App Scheduler built in Python to validate the concept quickly before rewriting in Swift.

> These are kept for historical reference. The production app is in [`../swift-app/`](../swift-app/).

---

## v1 — CLI Script (`v1-cli-script/`)

A terminal script. Runs in a loop and opens/closes one app on a schedule.

**Requirements:** Python 3.9+

**Run:**
```bash
python3 app_scheduler.py
```

Edit the constants at the top:
```python
APP_NAME       = "Spotify"   # App to control
OPEN_TIME      = "09:00"     # 24hr format
CLOSE_TIME     = "17:00"
CHECK_INTERVAL = 30          # seconds between checks
```

Press `Ctrl+C` to stop.

---

## v2 — Menu Bar App (`v2-menubar-app/`)

A proper macOS menu bar app with a settings UI. Uses `rumps` for the menu bar and `tkinter` for the settings window.

**Requirements:** Python 3.11+ (3.9 has a conflict with `pyobjc-core 12.0`)

**Install and run:**
```bash
pip3 install rumps pyobjc-framework-Cocoa
python3 app_scheduler_app.py
```

**Build as a standalone `.app` bundle:**
```bash
chmod +x build_app.sh && ./build_app.sh
```

The build script auto-detects Python 3.11+ and uses PyInstaller to create a self-contained `.app` (~80MB). The resulting app can be dragged to `/Applications` and launched like any native app.

**Note:** macOS may show a security warning on first launch since the app is not from the App Store. Go to System Settings → Privacy & Security → "Open Anyway".

---

## v3 — HTML Config UI (`v3-html-ui/`)

A single-file HTML page for configuring and generating the Python script visually.

**Run:** Open `app_scheduler_ui.html` in any browser. No server needed.

Pick your app and times, then click Copy to get a ready-to-run Python script.
