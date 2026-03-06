import Foundation
import AppKit
@preconcurrency import CoreGraphics

// MARK: - Mode

enum JigglerMode: String, CaseIterable, Codable {
    case subtle = "Subtle"
    case human  = "Human"

    var title: String { rawValue }
    var subtitle: String {
        switch self {
        case .subtle: return "1px nudge every 15s via HID"
        case .human:  return "Free movement, pauses for you"
        }
    }
    var icon: String {
        switch self {
        case .subtle: return "cursorarrow.rays"
        case .human:  return "figure.walk.motion"
        }
    }
}

// MARK: - Jiggler engine

@MainActor
class Jiggler: ObservableObject {

    static let shared = Jiggler()

    @Published private(set) var isActive:      Bool = false
    @Published private(set) var humanPaused:   Bool = false   // true while user is moving mouse
    @Published var mode: JigglerMode = .subtle {
        didSet { savePrefs(); restart() }
    }
    @Published private(set) var needsAccessibility: Bool = false

    // Subtle mode
    private var subtleTimer: Timer?

    // Human mode – Bézier arcs
    private var humanPauseTimer:   Timer?
    private var humanMoveTimer:    Timer?
    private var userStoppedTimer:  Timer?   // fires when user stops moving
    private var mouseMonitor:      Any?     // NSEvent global monitor
    private var lastJiggleTime:    Date = .distantPast

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "jigglerMode"),
           let m   = JigglerMode(rawValue: raw) { mode = m }
    }

    // MARK: - Public API

    func start() {
        guard !isActive else { return }
        if !hasAccessibility() {
            needsAccessibility = true
            return
        }
        needsAccessibility = false
        isActive = true
        scheduleWork()
    }

    func stop() {
        isActive    = false
        humanPaused = false
        cancelAll()
        stopMouseMonitor()
    }

    func toggle() { isActive ? stop() : start() }

    // ── Accessibility fix ─────────────────────────────────────────────────────
    // Step 1: AXIsProcessTrustedWithOptions(prompt:true) REGISTERS the app in
    //         the Accessibility list — without this call the app never appears.
    // Step 2: Open System Settings directly at the Accessibility pane so the
    //         user just needs to flip the toggle next to our app name.
    func openAccessibilitySettings() {
        // Register the app in the Accessibility list first, then open Settings.
        // For fresh installs this is all that's needed — the app appears in
        // the list and the user just flips the toggle.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)

        // Small delay so registration completes before Settings opens
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    func registerForAccessibilityIfNeeded() {
        guard !hasAccessibility() else { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    func recheckAccessibility() {
        if hasAccessibility() {
            needsAccessibility = false
            if isActive { scheduleWork() }
        }
    }

    // MARK: - Internals

    private func restart() {
        guard isActive else { return }
        cancelAll()
        stopMouseMonitor()
        humanPaused = false
        scheduleWork()
    }

    private func cancelAll() {
        subtleTimer?.invalidate();     subtleTimer     = nil
        humanPauseTimer?.invalidate(); humanPauseTimer = nil
        humanMoveTimer?.invalidate();  humanMoveTimer  = nil
        userStoppedTimer?.invalidate(); userStoppedTimer = nil
        // animateStep recursion stops automatically because isActive becomes false
    }

    private func scheduleWork() {
        switch mode {
        case .subtle: scheduleSubtle()
        case .human:  startMouseMonitor()
                      scheduleHumanMove(delay: Double.random(in: 0.3...1.5))
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Subtle mode — 1px HID nudge every 15s
    // ─────────────────────────────────────────────────────────────────────────

    private func scheduleSubtle() {
        subtleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.performSubtleJiggle() }
        }
    }

    private func performSubtleJiggle() {
        guard isActive else { return }

        let screen  = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let mouse   = NSEvent.mouseLocation
        let current = CGPoint(x: mouse.x, y: screen.height - mouse.y)

        let dx: CGFloat = Bool.random() ? 1 : -1
        let dy: CGFloat = Bool.random() ? 1 : -1
        let nudged = CGPoint(
            x: (current.x + dx).clamped(to: 0...screen.width),
            y: (current.y + dy).clamped(to: 0...screen.height)
        )

        postMove(to: nudged)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard self?.isActive == true else { return }
            self?.postMove(to: current)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Human mode — free Bézier movement, yields to real user input
    //
    // Movement: Quadratic Bézier arcs, 150–700px, continuous with short pauses.
    // User detection: NSEvent globalMonitor watches for real mouse movement.
    //   If movement arrives that isn't from us (detected via timing), we pause
    //   the jiggler and wait 2s after the user stops before resuming.
    // ─────────────────────────────────────────────────────────────────────────

    private func startMouseMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleRealMouseMove() }
        }
    }

    private func stopMouseMonitor() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
        userStoppedTimer?.invalidate(); userStoppedTimer = nil
    }

    private func handleRealMouseMove() {
        guard isActive, mode == .human else { return }

        // Ignore events that fired very close to our last jiggle post
        // (our events + real events both appear in the global monitor)
        let timeSinceJiggle = Date().timeIntervalSince(lastJiggleTime)
        guard timeSinceJiggle > 0.15 else { return }

        // Real user movement detected — pause jiggler
        if !humanPaused {
            humanPaused = true
            humanMoveTimer?.invalidate();  humanMoveTimer  = nil
            humanPauseTimer?.invalidate(); humanPauseTimer = nil
        }

        // Reset the "user stopped" countdown on every move event
        userStoppedTimer?.invalidate()
        userStoppedTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.userDidStop() }
        }
    }

    private func userDidStop() {
        guard isActive, mode == .human, humanPaused else { return }
        humanPaused = false
        scheduleHumanMove(delay: 0.5)
    }

    private func scheduleHumanMove(delay: Double) {
        humanPauseTimer?.invalidate()
        humanPauseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.beginHumanMove() }
        }
    }

    private func beginHumanMove() {
        guard isActive, !humanPaused else { return }

        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let mouse  = NSEvent.mouseLocation
        let start  = CGPoint(x: mouse.x, y: screen.height - mouse.y)

        let margin: CGFloat = 60
        let range:  CGFloat = CGFloat.random(in: 150...700)
        let angle           = CGFloat.random(in: 0...(2 * .pi))
        let end = CGPoint(
            x: (start.x + cos(angle) * range).clamped(to: margin...(screen.width  - margin)),
            y: (start.y + sin(angle) * range).clamped(to: margin...(screen.height - margin))
        )

        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let cp  = CGPoint(
            x: mid.x + CGFloat.random(in: -200...200),
            y: mid.y + CGFloat.random(in: -200...200)
        )

        let distance     = hypot(end.x - start.x, end.y - start.y)
        let totalSteps   = max(30, Int(distance / 6))
        let stepInterval = Double.random(in: 0.010...0.018)

        // Use recursive DispatchQueue scheduling instead of Timer to avoid
        // capturing a non-Sendable Timer across the concurrency boundary.
        humanMoveTimer?.invalidate()
        humanMoveTimer = nil
        animateStep(step: 0, total: totalSteps, interval: stepInterval,
                    start: start, end: end, cp: cp)
    }

    private func animateStep(step: Int, total: Int, interval: Double,
                             start: CGPoint, end: CGPoint, cp: CGPoint) {
        guard isActive, !humanPaused else { return }

        let rawT  = Double(step) / Double(total)
        let eased = CGFloat(Self.easeInOut(rawT))
        let t1    = 1.0 - eased

        let x = t1*t1*start.x + 2*t1*eased*cp.x + eased*eased*end.x
        let y = t1*t1*start.y + 2*t1*eased*cp.y + eased*eased*end.y
        postMove(to: CGPoint(x: x, y: y))

        if step >= total {
            let pause = Double.random(in: 0.4...3.0)
            scheduleHumanMove(delay: pause)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.animateStep(step: step + 1, total: total, interval: interval,
                              start: start, end: end, cp: cp)
        }
    }

    // ── Shared HID event posting ──────────────────────────────────────────────

    private func postMove(to point: CGPoint) {
        lastJiggleTime = Date()
        let source = CGEventSource(stateID: .hidSystemState)
        if let e = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left) {
            e.post(tap: .cghidEventTap)
        }
    }

    private static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2*t*t : 1 - pow(-2*t + 2, 2) / 2
    }

    // MARK: - Accessibility

    private func hasAccessibility() -> Bool { AXIsProcessTrusted() }

    // MARK: - Persistence

    private func savePrefs() {
        UserDefaults.standard.set(mode.rawValue, forKey: "jigglerMode")
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
