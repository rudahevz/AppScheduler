import Foundation
import AppKit

// MARK: - Actions

enum ShortcutAction: String, CaseIterable, Codable {
    case addSchedule     = "Add Schedule"
    case switchSchedules = "Schedules Tab"
    case switchSettings  = "Settings Tab"
    case pauseResumeAll  = "Pause / Resume All"
    case saveEntry       = "Save Entry"
    case deleteEntry     = "Delete Entry"
    case closePopover    = "Close Window"

    var systemImage: String {
        switch self {
        case .addSchedule:     return "plus"
        case .switchSchedules: return "rectangle.stack.fill"
        case .switchSettings:  return "gearshape.fill"
        case .pauseResumeAll:  return "pause.fill"
        case .saveEntry:       return "checkmark"
        case .deleteEntry:     return "trash"
        case .closePopover:    return "xmark"
        }
    }
}

// MARK: - Shortcut model

struct RecordedShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt          // NSEvent.ModifierFlags rawValue (device-independent mask)
    var displayString: String        // e.g. "⌘N", "Space", "⌘⌫"

    // Default shortcuts
    static let defaults: [ShortcutAction: RecordedShortcut] = [
        .addSchedule:     RecordedShortcut(keyCode: 45,  modifierFlags: NSEvent.ModifierFlags.command.rawValue, displayString: "⌘N"),
        .switchSchedules: RecordedShortcut(keyCode: 18,  modifierFlags: NSEvent.ModifierFlags.command.rawValue, displayString: "⌘1"),
        .switchSettings:  RecordedShortcut(keyCode: 19,  modifierFlags: NSEvent.ModifierFlags.command.rawValue, displayString: "⌘2"),
        .pauseResumeAll:  RecordedShortcut(keyCode: 49,  modifierFlags: 0,                                     displayString: "Space"),
        .saveEntry:       RecordedShortcut(keyCode: 1,   modifierFlags: NSEvent.ModifierFlags.command.rawValue, displayString: "⌘S"),
        .deleteEntry:     RecordedShortcut(keyCode: 51,  modifierFlags: NSEvent.ModifierFlags.command.rawValue, displayString: "⌘⌫"),
        .closePopover:    RecordedShortcut(keyCode: 13,  modifierFlags: NSEvent.ModifierFlags.command.rawValue, displayString: "⌘W"),
    ]
}

// MARK: - Store

class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    @Published private(set) var shortcuts: [ShortcutAction: RecordedShortcut]

    private let udKey = "CustomShortcuts_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: "CustomShortcuts_v1"),
           let saved = try? JSONDecoder().decode([String: RecordedShortcut].self, from: data) {
            var merged = RecordedShortcut.defaults
            for (key, val) in saved {
                if let action = ShortcutAction(rawValue: key) { merged[action] = val }
            }
            shortcuts = merged
        } else {
            shortcuts = RecordedShortcut.defaults
        }
    }

    func set(_ shortcut: RecordedShortcut, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        save()
    }

    func resetToDefaults() {
        shortcuts = RecordedShortcut.defaults
        UserDefaults.standard.removeObject(forKey: udKey)
        objectWillChange.send()
    }

    private func save() {
        let dict = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }

    // Match an incoming NSEvent against the stored shortcuts
    func action(for event: NSEvent) -> ShortcutAction? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        let code  = event.keyCode
        for (action, shortcut) in shortcuts {
            if shortcut.keyCode == code && shortcut.modifierFlags == flags { return action }
        }
        // Also fire closePopover on bare Escape (keyCode 53) regardless of custom binding
        if event.keyCode == 53 && flags == 0 { return .closePopover }
        return nil
    }
}

// MARK: - Notification

extension Notification.Name {
    static let shortcutFired = Notification.Name("shortcutFired")
}

// MARK: - Display helpers

extension NSEvent.ModifierFlags {
    var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option)  { s += "⌥" }
        if contains(.shift)   { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

/// Build the human-readable display string for a key combo from a live NSEvent.
func shortcutDisplayString(for event: NSEvent) -> String {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let mods  = flags.symbols

    switch event.keyCode {
    case 49:  return "Space"
    case 36:  return mods + "↩"
    case 51:  return mods + "⌫"
    case 53:  return "Esc"
    case 123: return mods + "←"
    case 124: return mods + "→"
    case 125: return mods + "↓"
    case 126: return mods + "↑"
    case 115: return mods + "↖"
    case 119: return mods + "↘"
    default:
        let ch = (event.charactersIgnoringModifiers ?? "").uppercased()
        return mods + ch
    }
}
