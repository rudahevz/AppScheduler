import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var scheduler: Scheduler!
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        scheduler = Scheduler()

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "App Scheduler")
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: SchedulerView(scheduler: scheduler)
        )

        if scheduler.config.isRunning { updateIcon(running: true) }

        // MARK: - Keyboard shortcut monitor
        // Reads from ShortcutStore so user customisations are respected.
        // Returns nil to consume the event; returns the event to pass it through.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown else { return event }

            guard let action = ShortcutStore.shared.action(for: event) else { return event }

            // closePopover is handled here; all other actions are broadcast
            // via NotificationCenter so the SwiftUI layer can react.
            if action == .closePopover {
                self.popover.performClose(nil)
            } else {
                NotificationCenter.default.post(
                    name: .shortcutFired,
                    object: nil,
                    userInfo: ["action": action.rawValue]
                )
            }
            return nil  // consume the event
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSchedulerStateChanged),
            name: .schedulerStateChanged,
            object: nil
        )
    }

    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "App Scheduler", action: nil, keyEquivalent: ""))
            menu.addItem(.separator())
            let quitItem = NSMenuItem(title: "Quit App Scheduler", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            DispatchQueue.main.async { self.statusItem.menu = nil }
        } else {
            togglePopover()
        }
    }

    @objc func quitApp() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        NSApplication.shared.terminate(nil)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func onSchedulerStateChanged(_ notification: Notification) {
        let running = notification.userInfo?["running"] as? Bool ?? false
        updateIcon(running: running)
    }

    func updateIcon(running: Bool) {
        DispatchQueue.main.async {
            let symbol = running ? "clock.badge.checkmark.fill" : "clock.fill"
            self.statusItem.button?.image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: "App Scheduler"
            )
        }
    }
}

extension Notification.Name {
    static let schedulerStateChanged = Notification.Name("schedulerStateChanged")
    static let quitRequested         = Notification.Name("quitRequested")
}
