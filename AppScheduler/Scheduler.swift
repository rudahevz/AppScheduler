import Foundation
import AppKit
import UserNotifications  // FIX #5

@MainActor
class Scheduler: ObservableObject {
    @Published var config: SchedulerConfig
    @Published var isRunning: Bool = false
    @Published var lastAction: String = "Waiting..."
    @Published var nextEventLabel: String = ""
    @Published var nextEventCountdown: String = "--:--:--"

    // FIX #5 — user-controlled notifications toggle (persisted in UserDefaults)
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    private var eventTimer: Timer?       // fires once at next scheduled event
    private var countdownTimer: Timer?   // fires every second to update the HH:MM:SS display
    private var startedAt: Date = Date()
    private var dailyState: [UUID: (opened: Bool, closed: Bool)] = [:]
    private var lastDate: DateComponents?

    init() {
        self.config = ConfigStore.load()
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        isRunning = config.isRunning
        if isRunning {
            startedAt = Date()
            scheduleNextEvent()
            scheduleCountdownTimer()
        }
    }

    func entryAdded() {
        if !isRunning { start() } else {
            // Reschedule in case new entry is sooner than current next event
            scheduleNextEvent()
            saveConfig()
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        config.isRunning = true
        startedAt = Date()
        dailyState = [:]
        saveConfig()
        scheduleNextEvent()
        scheduleCountdownTimer()
        notifyStateChange(running: true)
        lastAction = "Scheduler started at \(timeString(Date()))"
    }

    func stop() {
        isRunning = false
        config.isRunning = false
        eventTimer?.invalidate();    eventTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        nextEventCountdown = "--:--:--"
        nextEventLabel = ""
        saveConfig()
        notifyStateChange(running: false)
        lastAction = "Scheduler stopped"
    }

    func saveConfig() {
        ConfigStore.save(config)
        if isRunning { scheduleNextEvent() }
        recomputeCountdown()
    }

    // MARK: - Precise one-shot event timer

    private func scheduleNextEvent() {
        eventTimer?.invalidate()
        eventTimer = nil

        guard let next = nextScheduledEvent() else {
            recomputeCountdown()
            return
        }

        let delay = next.date.timeIntervalSinceNow
        guard delay > 0 else {
            recomputeCountdown()
            return
        }

        eventTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fireEvents(at: next.date)
                self?.scheduleNextEvent()   // immediately schedule the one after
            }
        }

        recomputeCountdown()
    }

    /// Finds the soonest upcoming open or close time across all active entries.
    private func nextScheduledEvent() -> (date: Date, entries: [(ScheduleEntry, Bool)])? {
        let now = Date()
        let cal = Calendar.current
        var candidates: [(date: Date, entry: ScheduleEntry, isOpen: Bool)] = []

        for entry in config.entries where !entry.isPaused {
            for (time, isOpen) in [(entry.openTime, true), (entry.closeTime, false)] {
                guard let t = time else { continue }
                let h = cal.component(.hour,   from: t)
                let m = cal.component(.minute, from: t)

                // Build next occurrence at exactly HH:MM:00
                var comps = cal.dateComponents([.year, .month, .day], from: now)
                comps.hour = h; comps.minute = m; comps.second = 0
                guard var candidate = cal.date(from: comps) else { continue }

                // If already past today, push to tomorrow
                if candidate <= now {
                    candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                }
                candidates.append((candidate, entry, isOpen))
            }
        }

        guard !candidates.isEmpty else { return nil }
        candidates.sort { $0.date < $1.date }

        let soonest = candidates[0].date
        // Group all entries that fire at exactly the same time
        let group = candidates.filter { $0.date == soonest }.map { ($0.entry, $0.isOpen) }
        return (soonest, group)
    }

    /// Called exactly when a scheduled moment arrives — executes all matching actions.
    private func fireEvents(at date: Date) {
        let cal = Calendar.current
        let h = cal.component(.hour,   from: date)
        let m = cal.component(.minute, from: date)
        let today = cal.dateComponents([.year, .month, .day], from: date)

        if lastDate != nil && today != lastDate { dailyState = [:] }
        lastDate = today

        for entry in config.entries where !entry.isPaused {
            var state = dailyState[entry.id] ?? (opened: false, closed: false)

            if let t = entry.openTime, !state.opened {
                let eh = cal.component(.hour, from: t)
                let em = cal.component(.minute, from: t)
                if eh == h && em == m {
                    openTarget(entry)
                    state.opened = true
                }
            }
            if let t = entry.closeTime, !state.closed {
                let eh = cal.component(.hour, from: t)
                let em = cal.component(.minute, from: t)
                if eh == h && em == m {
                    closeTarget(entry)
                    state.closed = true
                }
            }
            dailyState[entry.id] = state
        }
    }

    // MARK: - Countdown display (every second, only for UI)

    private func scheduleCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recomputeCountdown() }
        }
        recomputeCountdown()
    }

    func recomputeCountdown() {
        guard isRunning, let next = nextScheduledEvent() else {
            nextEventCountdown = "--:--:--"
            nextEventLabel = ""
            return
        }

        let diff = max(0, next.date.timeIntervalSinceNow)
        let total = Int(diff)
        let hh = total / 3600
        let mm = (total % 3600) / 60
        let ss = total % 60
        nextEventCountdown = String(format: "%02d:%02d:%02d", hh, mm, ss)

        // Build label from all entries firing at that moment
        let names = next.entries.map { (entry, isOpen) in
            "\(isOpen ? "Open" : "Close") \(entry.targetName)"
        }.joined(separator: ", ")
        nextEventLabel = names
    }


    // MARK: - Notifications (FIX #5)

    func setNotificationsEnabled(_ enabled: Bool) {
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    self.notificationsEnabled = granted
                }
            }
        } else {
            notificationsEnabled = false
        }
    }

    private func sendNotification(title: String, body: String) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Open / Close

    private func openTarget(_ entry: ScheduleEntry) {
        guard !entry.targetPath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: entry.targetPath))
        lastAction = "Opened \(entry.targetName) at \(timeString(Date()))"
        sendNotification(title: "Opened \(entry.targetName)", body: "Scheduled open at \(timeString(Date()))")  // FIX #5
    }

    private func closeTarget(_ entry: ScheduleEntry) {
        let name = entry.targetName

        // Match by bundle URL (exact path) — much more reliable than localizedName
        // which can differ from the filename for some apps (e.g. localized names,
        // or apps where the .app name differs from the display name).
        // Falls back to localizedName comparison if the path doesn't match anything,
        // so it still works for edge cases like apps launched from different paths.
        let targetURL = URL(fileURLWithPath: entry.targetPath).standardizedFileURL
        var apps = NSWorkspace.shared.runningApplications.filter {
            guard let bundleURL = $0.bundleURL else { return false }
            return bundleURL.standardizedFileURL == targetURL
        }
        if apps.isEmpty {
            // Fallback: match by name (handles edge cases)
            apps = NSWorkspace.shared.runningApplications.filter {
                $0.localizedName?.lowercased() == name.lowercased()
            }
        }

        apps.forEach { $0.terminate() }
        lastAction = apps.isEmpty
            ? "\(name) wasn't running at \(timeString(Date()))"
            : "Closed \(name) at \(timeString(Date()))"
        if !apps.isEmpty {
            sendNotification(title: "Closed \(name)", body: "Scheduled close at \(timeString(Date()))")
        }
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func notifyStateChange(running: Bool) {
        NotificationCenter.default.post(
            name: .schedulerStateChanged,
            object: nil,
            userInfo: ["running": running]
        )
    }
}
