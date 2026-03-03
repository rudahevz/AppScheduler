#!/usr/bin/env python3
"""
macOS App Scheduler
Opens and closes a macOS application at specific times.

Usage:
    python app_scheduler.py

Configuration:
    Edit the CONFIG section below to set your app name and times.
"""

import subprocess
import time
from datetime import datetime


# ──────────────────────────────────────────
#  CONFIG — Edit these values
# ──────────────────────────────────────────
APP_NAME   = "Safari"        # The name of the macOS app to control
OPEN_TIME  = "09:00"         # Time to OPEN the app  (24hr format HH:MM)
CLOSE_TIME = "17:00"         # Time to CLOSE the app (24hr format HH:MM)
CHECK_INTERVAL = 30          # How often to check the time (in seconds)
# ──────────────────────────────────────────


def parse_time(time_str: str) -> tuple[int, int]:
    """Parse a HH:MM string into (hour, minute)."""
    h, m = time_str.strip().split(":")
    return int(h), int(m)


def current_hm() -> tuple[int, int]:
    """Return the current (hour, minute)."""
    now = datetime.now()
    return now.hour, now.minute


def open_app(app_name: str):
    """Open a macOS app using the 'open' command."""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Opening '{app_name}'...")
    subprocess.run(["open", "-a", app_name], check=True)


def close_app(app_name: str):
    """Close a macOS app using AppleScript."""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Closing '{app_name}'...")
    script = f'tell application "{app_name}" to quit'
    subprocess.run(["osascript", "-e", script], check=True)


def is_app_running(app_name: str) -> bool:
    """Check if the app is currently running."""
    script = f'tell application "System Events" to (name of processes) contains "{app_name}"'
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True, text=True
    )
    return result.stdout.strip().lower() == "true"


def main():
    open_h,  open_m  = parse_time(OPEN_TIME)
    close_h, close_m = parse_time(CLOSE_TIME)

    print(f"App Scheduler started for '{APP_NAME}'")
    print(f"  Open  at: {OPEN_TIME}")
    print(f"  Close at: {CLOSE_TIME}")
    print(f"Checking every {CHECK_INTERVAL} seconds. Press Ctrl+C to stop.\n")

    opened_today  = False
    closed_today  = False
    last_date     = datetime.now().date()

    while True:
        now       = datetime.now()
        today     = now.date()
        cur_h, cur_m = now.hour, now.minute

        # Reset flags at midnight for a new day
        if today != last_date:
            opened_today = False
            closed_today = False
            last_date    = today

        # Open the app at the scheduled time
        if (cur_h, cur_m) >= (open_h, open_m) and not opened_today:
            if not is_app_running(APP_NAME):
                open_app(APP_NAME)
            else:
                print(f"[{now.strftime('%H:%M:%S')}] '{APP_NAME}' is already running.")
            opened_today = True

        # Close the app at the scheduled time
        if (cur_h, cur_m) >= (close_h, close_m) and not closed_today:
            if is_app_running(APP_NAME):
                close_app(APP_NAME)
            else:
                print(f"[{now.strftime('%H:%M:%S')}] '{APP_NAME}' is not running.")
            closed_today = True

        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nScheduler stopped.")
    except subprocess.CalledProcessError as e:
        print(f"Error controlling app: {e}")
