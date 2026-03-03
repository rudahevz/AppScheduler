#!/usr/bin/env python3
"""
App Scheduler — macOS Menu Bar App
Requires: pip install rumps
Run with: python3 app_scheduler_app.py
"""

import subprocess
import threading
import time
import json
import os
import tkinter as tk
from tkinter import ttk, messagebox
from datetime import datetime

try:
    import rumps
except ImportError:
    print("Installing rumps...")
    subprocess.run(["pip3", "install", "rumps"], check=True)
    import rumps

# ── Config file to persist settings ────────────────────────────
CONFIG_FILE = os.path.expanduser("~/.app_scheduler_config.json")

PRESET_APPS = [
    ("🧭", "Safari"),
    ("🎵", "Spotify"),
    ("💬", "Slack"),
    ("📝", "Notes"),
    ("✉️", "Mail"),
    ("📅", "Calendar"),
    ("⌨️", "Terminal"),
    ("🖥️", "Finder"),
    ("🎨", "Figma"),
    ("📱", "Messages"),
]

DEFAULT_CONFIG = {
    "app_name": "Safari",
    "open_time": "09:00",
    "close_time": "17:00",
    "interval": 30,
    "enabled": False,
}


def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE) as f:
                return {**DEFAULT_CONFIG, **json.load(f)}
        except Exception:
            pass
    return DEFAULT_CONFIG.copy()


def save_config(cfg):
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)


# ── macOS helpers ───────────────────────────────────────────────

def open_app(name):
    subprocess.run(["open", "-a", name], check=True)

def close_app(name):
    script = f'tell application "{name}" to quit'
    subprocess.run(["osascript", "-e", script], check=True)

def is_running(name):
    script = f'tell application "System Events" to (name of processes) contains "{name}"'
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return r.stdout.strip().lower() == "true"

def parse_time(t):
    h, m = t.split(":")
    return int(h), int(m)


# ── Settings Window ─────────────────────────────────────────────

class SettingsWindow:
    def __init__(self, config, on_save):
        self.config = config.copy()
        self.on_save = on_save
        self.selected_app = tk.StringVar(value=self.config["app_name"])
        self._build()

    def _build(self):
        self.root = tk.Tk()
        self.root.title("App Scheduler")
        self.root.resizable(False, False)
        self.root.configure(bg="#0e0f11")

        # Center window
        w, h = 480, 560
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        x = (sw - w) // 2
        y = (sh - h) // 2
        self.root.geometry(f"{w}x{h}+{x}+{y}")

        self._styles()
        self._header()
        self._app_section()
        self._time_section()
        self._interval_section()
        self._actions()

    def _styles(self):
        style = ttk.Style()
        style.theme_use("clam")
        style.configure(".", background="#0e0f11", foreground="#e8eaf0", font=("Menlo", 12))
        style.configure("Header.TLabel", font=("Georgia", 18, "bold"), foreground="#e8eaf0", background="#0e0f11")
        style.configure("Sub.TLabel", font=("Menlo", 10), foreground="#6b7280", background="#0e0f11")
        style.configure("Label.TLabel", font=("Menlo", 10), foreground="#6b7280", background="#0e0f11")
        style.configure("Value.TLabel", font=("Georgia", 22), foreground="#e8eaf0", background="#1e2128")
        style.configure("App.TButton",
            font=("Menlo", 11), padding=(8, 8),
            background="#1e2128", foreground="#6b7280",
            borderwidth=1, relief="flat")
        style.map("App.TButton",
            background=[("active", "#2a2d35"), ("selected", "#1a2810")],
            foreground=[("active", "#e8eaf0"), ("selected", "#c8f060")])
        style.configure("Start.TButton",
            font=("Menlo", 13, "bold"), padding=(12, 12),
            background="#c8f060", foreground="#0e0f11",
            borderwidth=0, relief="flat")
        style.map("Start.TButton",
            background=[("active", "#d8ff70")])
        style.configure("Stop.TButton",
            font=("Menlo", 13, "bold"), padding=(12, 12),
            background="#f06070", foreground="#ffffff",
            borderwidth=0, relief="flat")
        style.map("Stop.TButton",
            background=[("active", "#ff7080")])
        style.configure("TEntry",
            fieldbackground="#1e2128", foreground="#e8eaf0",
            insertcolor="#c8f060", borderwidth=0, relief="flat",
            font=("Menlo", 12))

    def _header(self):
        frame = tk.Frame(self.root, bg="#16181c", pady=16)
        frame.pack(fill="x")

        inner = tk.Frame(frame, bg="#16181c")
        inner.pack(padx=24)

        tk.Label(inner, text="⏰  App Scheduler", font=("Georgia", 17, "bold"),
                 bg="#16181c", fg="#e8eaf0").pack(side="left")

        self.status_label = tk.Label(inner, text="● Idle",
                                      font=("Menlo", 11), bg="#16181c", fg="#6b7280")
        self.status_label.pack(side="right")

        tk.Frame(self.root, bg="#2a2d35", height=1).pack(fill="x")

    def _section_label(self, parent, text):
        tk.Label(parent, text=text.upper(), font=("Menlo", 9),
                 bg="#0e0f11", fg="#6b7280").pack(anchor="w", pady=(14, 6))

    def _app_section(self):
        outer = tk.Frame(self.root, bg="#0e0f11", padx=24)
        outer.pack(fill="x")

        self._section_label(outer, "Select App")

        grid = tk.Frame(outer, bg="#0e0f11")
        grid.pack(fill="x")

        self.app_buttons = {}

        for i, (icon, name) in enumerate(PRESET_APPS):
            row, col = divmod(i, 5)
            btn = tk.Button(
                grid, text=f"{icon}\n{name}",
                font=("Menlo", 10), width=7,
                bg="#1e2128", fg="#6b7280",
                activebackground="#2a2d35", activeforeground="#e8eaf0",
                relief="flat", bd=1, cursor="hand2",
                command=lambda n=name: self._select_app(n)
            )
            btn.grid(row=row, column=col, padx=3, pady=3, sticky="nsew")
            self.app_buttons[name] = btn
            grid.columnconfigure(col, weight=1)

        # Custom input
        custom_frame = tk.Frame(outer, bg="#0e0f11")
        custom_frame.pack(fill="x", pady=(6, 0))

        tk.Label(custom_frame, text="Or type a custom app:", font=("Menlo", 10),
                 bg="#0e0f11", fg="#6b7280").pack(side="left")

        self.custom_var = tk.StringVar()
        self.custom_entry = tk.Entry(custom_frame, textvariable=self.custom_var,
                                      font=("Menlo", 12), bg="#1e2128", fg="#e8eaf0",
                                      insertbackground="#c8f060", relief="flat", bd=4)
        self.custom_entry.pack(side="left", fill="x", expand=True, padx=(8, 0))
        self.custom_var.trace_add("write", self._on_custom_type)

        # Highlight currently selected
        self._select_app(self.config["app_name"], silent=True)

    def _select_app(self, name, silent=False):
        for n, btn in self.app_buttons.items():
            if n == name:
                btn.configure(bg="#1a2810", fg="#c8f060")
            else:
                btn.configure(bg="#1e2128", fg="#6b7280")
        self.selected_app.set(name)
        if not silent:
            self.custom_var.set("")

    def _on_custom_type(self, *_):
        val = self.custom_var.get().strip()
        if val:
            for btn in self.app_buttons.values():
                btn.configure(bg="#1e2128", fg="#6b7280")
            self.selected_app.set(val)

    def _time_section(self):
        outer = tk.Frame(self.root, bg="#0e0f11", padx=24)
        outer.pack(fill="x")
        self._section_label(outer, "Schedule")

        row = tk.Frame(outer, bg="#0e0f11")
        row.pack(fill="x")
        row.columnconfigure(0, weight=1)
        row.columnconfigure(1, weight=1)

        # Open time
        self.open_frame = self._time_block(row, "🟢  Open at", self.config["open_time"])
        self.open_frame["frame"].grid(row=0, column=0, sticky="nsew", padx=(0, 6))

        # Close time
        self.close_frame = self._time_block(row, "🔴  Close at", self.config["close_time"])
        self.close_frame["frame"].grid(row=0, column=1, sticky="nsew", padx=(6, 0))

    def _time_block(self, parent, label, default):
        frame = tk.Frame(parent, bg="#1e2128", padx=14, pady=12)

        tk.Label(frame, text=label, font=("Menlo", 10),
                 bg="#1e2128", fg="#6b7280").pack(anchor="w")

        var = tk.StringVar(value=default)
        entry = tk.Entry(frame, textvariable=var, font=("Georgia", 28),
                         bg="#1e2128", fg="#e8eaf0",
                         insertbackground="#c8f060", relief="flat",
                         width=6, justify="center")
        entry.pack(pady=(4, 0))

        return {"frame": frame, "var": var}

    def _interval_section(self):
        outer = tk.Frame(self.root, bg="#0e0f11", padx=24)
        outer.pack(fill="x")
        self._section_label(outer, "Check Interval")

        frame = tk.Frame(outer, bg="#1e2128", padx=14, pady=12)
        frame.pack(fill="x")

        tk.Label(frame, text="How often to check the clock",
                 font=("Menlo", 11), bg="#1e2128", fg="#6b7280").pack(side="left")

        control = tk.Frame(frame, bg="#1e2128")
        control.pack(side="right")

        self.interval_var = tk.IntVar(value=self.config["interval"])

        tk.Button(control, text="−", font=("Menlo", 14), bg="#0e0f11", fg="#e8eaf0",
                  activebackground="#2a2d35", relief="flat", bd=0, cursor="hand2",
                  command=self._dec_interval).pack(side="left", padx=4)

        self.interval_label = tk.Label(control, textvariable=self.interval_var,
                                        font=("Georgia", 20), bg="#1e2128", fg="#e8eaf0",
                                        width=3, anchor="center")
        self.interval_label.pack(side="left")

        tk.Label(control, text="sec", font=("Menlo", 10),
                 bg="#1e2128", fg="#6b7280").pack(side="left", padx=(2, 8))

        tk.Button(control, text="+", font=("Menlo", 14), bg="#0e0f11", fg="#e8eaf0",
                  activebackground="#2a2d35", relief="flat", bd=0, cursor="hand2",
                  command=self._inc_interval).pack(side="left", padx=4)

    def _dec_interval(self):
        v = self.interval_var.get()
        if v > 5: self.interval_var.set(v - 5)

    def _inc_interval(self):
        v = self.interval_var.get()
        if v < 300: self.interval_var.set(v + 5)

    def _actions(self):
        tk.Frame(self.root, bg="#2a2d35", height=1).pack(fill="x", pady=(16, 0))

        frame = tk.Frame(self.root, bg="#0e0f11", padx=24, pady=16)
        frame.pack(fill="x")

        self.start_btn = tk.Button(
            frame, text="▶  Start Scheduler",
            font=("Menlo", 13, "bold"), bg="#c8f060", fg="#0e0f11",
            activebackground="#d8ff70", relief="flat", bd=0,
            cursor="hand2", pady=12,
            command=self._on_start
        )
        self.start_btn.pack(fill="x")

        self.stop_btn = tk.Button(
            frame, text="■  Stop Scheduler",
            font=("Menlo", 13, "bold"), bg="#f06070", fg="#ffffff",
            activebackground="#ff7080", relief="flat", bd=0,
            cursor="hand2", pady=12,
            command=self._on_stop
        )
        # Don't pack yet — shown only when running

    def _get_values(self):
        return {
            "app_name": self.selected_app.get().strip() or "Safari",
            "open_time": self.open_frame["var"].get(),
            "close_time": self.close_frame["var"].get(),
            "interval": self.interval_var.get(),
        }

    def _on_start(self):
        cfg = self._get_values()
        # Validate times
        try:
            parse_time(cfg["open_time"])
            parse_time(cfg["close_time"])
        except Exception:
            messagebox.showerror("Invalid Time", "Please enter times in HH:MM format.")
            return

        cfg["enabled"] = True
        save_config(cfg)
        self.on_save(cfg)
        self.set_running(True)

    def _on_stop(self):
        cfg = self._get_values()
        cfg["enabled"] = False
        save_config(cfg)
        self.on_save(cfg)
        self.set_running(False)

    def set_running(self, running):
        if running:
            self.status_label.configure(text="● Running", fg="#c8f060")
            self.start_btn.pack_forget()
            self.stop_btn.pack(fill="x")
        else:
            self.status_label.configure(text="● Idle", fg="#6b7280")
            self.stop_btn.pack_forget()
            self.start_btn.pack(fill="x")

    def run(self):
        if self.config.get("enabled"):
            self.set_running(True)
        self.root.mainloop()


# ── Scheduler Thread ────────────────────────────────────────────

class Scheduler:
    def __init__(self):
        self.config = load_config()
        self._running = False
        self._thread = None
        self._opened_today = False
        self._closed_today = False
        self._last_date = None

    def start(self, config):
        self.config = config
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False

    def update_config(self, config):
        self.config = config

    def _loop(self):
        self._opened_today = False
        self._closed_today = False
        self._last_date = None

        while self._running:
            cfg = self.config
            now = datetime.now()
            today = now.date()

            if today != self._last_date:
                self._opened_today = False
                self._closed_today = False
                self._last_date = today

            try:
                open_h, open_m   = parse_time(cfg["open_time"])
                close_h, close_m = parse_time(cfg["close_time"])
                app = cfg["app_name"]

                if (now.hour, now.minute) >= (open_h, open_m) and not self._opened_today:
                    if not is_running(app):
                        open_app(app)
                        print(f"[{now.strftime('%H:%M:%S')}] Opened '{app}'")
                    self._opened_today = True

                if (now.hour, now.minute) >= (close_h, close_m) and not self._closed_today:
                    if is_running(app):
                        close_app(app)
                        print(f"[{now.strftime('%H:%M:%S')}] Closed '{app}'")
                    self._closed_today = True

            except Exception as e:
                print(f"Scheduler error: {e}")

            time.sleep(cfg.get("interval", 30))


# ── Menu Bar App ────────────────────────────────────────────────

class AppSchedulerMenuBar(rumps.App):
    def __init__(self):
        super().__init__("⏰", quit_button=None)
        self.config = load_config()
        self.scheduler = Scheduler()
        self.window = None

        self.menu = [
            rumps.MenuItem("Open Settings", callback=self.open_settings),
            rumps.MenuItem("Status: Idle", callback=None),
            None,  # separator
            rumps.MenuItem("Quit", callback=self.quit_app),
        ]

        if self.config.get("enabled"):
            self.scheduler.start(self.config)
            self._set_status(True)

    @rumps.clicked("Open Settings")
    def open_settings(self, _=None):
        def on_save(cfg):
            self.config = cfg
            if cfg.get("enabled"):
                if not self.scheduler._running:
                    self.scheduler.start(cfg)
                else:
                    self.scheduler.update_config(cfg)
                self._set_status(True)
            else:
                self.scheduler.stop()
                self._set_status(False)

        # Run settings window in a thread so menu bar stays responsive
        def show():
            win = SettingsWindow(self.config, on_save)
            win.run()

        t = threading.Thread(target=show, daemon=True)
        t.start()

    def _set_status(self, running):
        label = f"Status: {'Running ✓' if running else 'Idle'}"
        self.menu["Status: Idle"].title = label
        self.menu[label] = self.menu.pop("Status: Idle", None) if running else None
        self.title = "⏰" if not running else "⏰●"

    def quit_app(self, _):
        self.scheduler.stop()
        rumps.quit_application()


# ── Entry point ─────────────────────────────────────────────────

if __name__ == "__main__":
    print("Starting App Scheduler...")
    print("Look for ⏰ in your macOS menu bar.")
    AppSchedulerMenuBar().run()
