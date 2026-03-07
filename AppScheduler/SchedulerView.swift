import SwiftUI
import ServiceManagement
import AppKit

// MARK: - Main View

struct SchedulerView: View {
    @ObservedObject var scheduler: Scheduler
    @State private var editingEntry: ScheduleEntry?  = nil
    @State private var selectedTab:  SidebarTab      = .schedules
    @StateObject private var jiggler = Jiggler.shared

    enum SidebarTab { case schedules, jiggler, settings }

    var body: some View {
        ZStack {
            meshBackground
            glassWindow
        }
        .frame(width: 420, height: 520)
        .sheet(item: $editingEntry) { entry in
            EntrySheet(
                entry: entryBinding(for: entry),
                isNew: !scheduler.config.entries.contains(where: { $0.id == entry.id }),
                onSave:   { scheduler.saveConfig() },
                onDelete: {
                    scheduler.config.entries.removeAll { $0.id == entry.id }
                    scheduler.saveConfig()
                }
            )
        }
        // ── Shortcut notifications from AppDelegate key monitor ──────────────
        .onReceive(NotificationCenter.default.publisher(for: .shortcutFired)) { note in
            guard let raw = note.userInfo?["action"] as? String,
                  let action = ShortcutAction(rawValue: raw) else { return }
            handleShortcut(action)
        }
    }

    // MARK: - Shortcut handler

    private func handleShortcut(_ action: ShortcutAction) {
        switch action {
        case .addSchedule:
            // Only fires on Schedules tab when no sheet is open
            guard selectedTab == .schedules, editingEntry == nil else { return }
            let e = ScheduleEntry()
            scheduler.config.entries.append(e)
            editingEntry = e
            scheduler.entryAdded()
        case .switchSchedules:
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = .schedules }
        case .switchSettings:
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = .settings }
        case .pauseResumeAll:
            guard !scheduler.config.entries.isEmpty else { return }
            let allPaused = scheduler.config.entries.allSatisfy { $0.isPaused }
            for i in scheduler.config.entries.indices { scheduler.config.entries[i].isPaused = !allPaused }
            scheduler.saveConfig()
        case .saveEntry, .deleteEntry, .closePopover:
            break  // handled inside EntrySheet / AppDelegate
        }
    }

    // MARK: - Mesh Background

    var meshBackground: some View {
        ZStack {
            Color(hex: "#080810")
            RadialGradient(colors: [Color(hex: "#7050FF").opacity(0.55), .clear],
                           center: UnitPoint(x: 0.15, y: 0.2), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [Color(hex: "#00B4FF").opacity(0.4),  .clear],
                           center: UnitPoint(x: 0.85, y: 0.1), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [Color(hex: "#FF6478").opacity(0.3),  .clear],
                           center: UnitPoint(x: 0.5,  y: 1.0), startRadius: 0, endRadius: 240)
            RadialGradient(colors: [Color(hex: "#3CC878").opacity(0.2),  .clear],
                           center: UnitPoint(x: 0.1,  y: 0.8), startRadius: 0, endRadius: 200)
        }
        .ignoresSafeArea()
    }

    // MARK: - Glass Window

    var glassWindow: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().background(Color.white.opacity(0.07))
            mainContent
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 10)
    }

    // MARK: - Sidebar

    var sidebar: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#c8f060").opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#c8f060").opacity(0.3), lineWidth: 1))
                    .frame(width: 36, height: 36)
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#c8f060"))
            }
            .accessibilityLabel("App Scheduler")
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.07))

            VStack(spacing: 4) {
                sidebarItem(icon: "rectangle.stack.fill", tab: .schedules,
                            label: "Schedules", tooltip: "View and manage schedules")
                sidebarItem(icon: "cursorarrow.motionlines", tab: .jiggler,
                            label: "Jiggler",   tooltip: "Mouse jiggler")
                sidebarItem(icon: "gearshape.fill",       tab: .settings,
                            label: "Settings",  tooltip: "App settings")
            }
            .padding(.top, 10)
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 4) {
                Circle()
                    .fill(scheduler.isRunning ? Color(hex: "#c8f060") : Color(hex: "#6b7280"))
                    .frame(width: 7, height: 7)
                    .shadow(color: scheduler.isRunning ? Color(hex: "#c8f060").opacity(0.8) : .clear, radius: 5)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                               value: scheduler.isRunning)
                Text(scheduler.isRunning ? "On" : "Off")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(scheduler.isRunning ? Color(hex: "#c8f060") : Color(hex: "#6b7280"))
            }
            .accessibilityLabel(scheduler.isRunning ? "Scheduler is running" : "Scheduler is stopped")
            .padding(.bottom, 14)
        }
        .frame(width: 56)
        .background(Color.black.opacity(0.15))
    }

    @ViewBuilder
    func sidebarItem(icon: String, tab: SidebarTab, label: String, tooltip: String) -> some View {
        let active = selectedTab == tab
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            ZStack {
                if active {
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#c8f060"))
                            .frame(width: 3, height: 20)
                            .offset(x: -4)
                        Spacer()
                    }
                }
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? Color(hex: "#c8f060").opacity(0.12) : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(active ? Color(hex: "#c8f060").opacity(0.25) : Color.clear, lineWidth: 1))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: active ? .semibold : .regular))
                    .foregroundColor(active ? Color(hex: "#c8f060") : Color.white.opacity(0.35))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(tooltip)
    }

    // MARK: - Main Content

    var mainContent: some View {
        VStack(spacing: 0) {
            if selectedTab == .schedules     { schedulesView }
            else if selectedTab == .jiggler  { JigglerView(jiggler: jiggler) }
            else                             { settingsView  }
        }
    }

    // MARK: - Schedules Tab

    var schedulesView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Schedules")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(scheduler.config.entries.filter { !$0.isPaused }.count) active")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Spacer()
                Button {
                    let e = ScheduleEntry()
                    scheduler.config.entries.append(e)
                    editingEntry = e
                    scheduler.entryAdded()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add schedule")
                .help("Add a new schedule")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            if scheduler.config.showCountdown {
                countdownBanner
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            Divider().background(Color.white.opacity(0.06))

            if scheduler.config.entries.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach($scheduler.config.entries) { $entry in
                            EntryRow(
                                entry: $entry,
                                onTap: { editingEntry = entry },
                                onTogglePause: {
                                    entry.isPaused.toggle()
                                    scheduler.saveConfig()
                                }
                            )
                        }
                    }
                    .padding(10)
                }
            }

            Divider().background(Color.white.opacity(0.06))
            bottomBar
        }
    }

    // MARK: - Countdown Banner

    var countdownBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT EVENT")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                    .kerning(1.2)
                Text(scheduler.nextEventLabel.isEmpty ? "No upcoming events" : scheduler.nextEventLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer()
            Text(scheduler.nextEventCountdown)
                .font(.system(size: 22, weight: .ultraLight, design: .monospaced))
                .foregroundColor(scheduler.isRunning ? Color(hex: "#c8f060") : Color.white.opacity(0.2))
                .shadow(color: scheduler.isRunning ? Color(hex: "#c8f060").opacity(0.5) : .clear, radius: 8)
                .monospacedDigit()
                .accessibilityLabel("Time until next event: \(scheduler.nextEventCountdown)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#c8f060").opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#c8f060").opacity(0.12), lineWidth: 1))
        )
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(Color.white.opacity(0.15))
                .accessibilityHidden(true)
            Text("No schedules yet")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.3))
            Text("Press + to add an app or file")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Bar

    var bottomBar: some View {
        HStack(spacing: 8) {
            Text(scheduler.lastAction)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.25))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Last action: \(scheduler.lastAction)")

            let allPaused = scheduler.config.entries.allSatisfy { $0.isPaused }
            Button {
                for i in scheduler.config.entries.indices {
                    scheduler.config.entries[i].isPaused = !allPaused
                }
                scheduler.saveConfig()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: allPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(allPaused ? "Resume All" : "Pause All")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(allPaused ? Color(hex: "#c8f060") : Color.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(allPaused ? Color(hex: "#c8f060").opacity(0.1) : Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(allPaused ? Color(hex: "#c8f060").opacity(0.25) : Color.white.opacity(0.08),
                                    lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .disabled(scheduler.config.entries.isEmpty)
            .accessibilityLabel(allPaused ? "Resume all schedules" : "Pause all schedules")
            .help(allPaused ? "Resume all paused schedules" : "Pause all active schedules")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.1))
    }

    // MARK: - Settings Tab (with slide-in Shortcuts subpanel)

    var settingsView: some View {
        GeometryReader { geo in
            ShortcutsNavigationView(scheduler: scheduler)
        }
    }

    // MARK: - Helpers

    func entryBinding(for entry: ScheduleEntry) -> Binding<ScheduleEntry> {
        guard let idx = scheduler.config.entries.firstIndex(where: { $0.id == entry.id }) else {
            return .constant(entry)
        }
        return $scheduler.config.entries[idx]
    }
}

// MARK: - Settings + Shortcuts Navigation

/// Hosts both the Settings list and the Shortcuts editor.
/// The Shortcuts panel slides in from the right over the Settings list.
struct ShortcutsNavigationView: View {
    @ObservedObject var scheduler: Scheduler
    @State private var showShortcuts = false

    var body: some View {
        ZStack(alignment: .leading) {
            settingsContent
                .offset(x: showShortcuts ? -364 : 0)
                .opacity(showShortcuts ? 0 : 1)

            ShortcutsEditorView(onBack: {
                withAnimation(.easeInOut(duration: 0.22)) { showShortcuts = false }
            })
            .offset(x: showShortcuts ? 0 : 364)
            .opacity(showShortcuts ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.22), value: showShortcuts)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── Settings list ──────────────────────────────────────────────────────────

    var settingsContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.06))

            VStack(spacing: 2) {
                settingRow(icon: "timer.circle.fill", iconColor: "#c8f060",
                           title: "Show Countdown",
                           subtitle: "Display HH:MM:SS until next event") {
                    Toggle("Show countdown timer", isOn: $scheduler.config.showCountdown)
                        .toggleStyle(.switch)
                        .tint(Color(hex: "#c8f060"))
                        .labelsHidden()
                        .onChange(of: scheduler.config.showCountdown) { _ in scheduler.saveConfig() }
                }

                settingRowDivider()

                settingRow(icon: "power.circle.fill", iconColor: "#4ade80",
                           title: "Open at Login",
                           subtitle: "Start automatically on login") {
                    Toggle("Open at login", isOn: Binding(
                        get: { LaunchAtLogin.isEnabled },
                        set: { LaunchAtLogin.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(Color(hex: "#c8f060"))
                    .labelsHidden()
                }

                settingRowDivider()

                settingRow(icon: "bell.circle.fill", iconColor: "#60a8f0",
                           title: "Notifications",
                           subtitle: "Alert when an app opens or closes") {
                    Toggle("Enable notifications", isOn: Binding(
                        get: { scheduler.notificationsEnabled },
                        set: { scheduler.setNotificationsEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(Color(hex: "#c8f060"))
                    .labelsHidden()
                }

                settingRowDivider()

                // ── Keyboard Shortcuts nav row ─────────────────────────────────
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showShortcuts = true }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#a78bfa"))
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Keyboard Shortcuts")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.85))
                            Text("Customise shortcuts for every action")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.3))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.25))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Keyboard shortcuts")
                .accessibilityHint("Opens shortcut customisation panel")
                .help("Customise keyboard shortcuts")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()

            Text("App Scheduler · v3.0")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.15))
                .padding(.bottom, 14)
        }
    }

    func settingRow<T: View>(icon: String, iconColor: String, title: String,
                             subtitle: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: iconColor))
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    func settingRowDivider() -> some View {
        Divider()
            .background(Color.white.opacity(0.05))
            .padding(.leading, 46)
    }
}

// MARK: - Shortcuts Editor View

struct ShortcutsEditorView: View {
    let onBack: () -> Void

    @ObservedObject private var store = ShortcutStore.shared
    @State private var recording: ShortcutAction? = nil
    @State private var monitor: Any? = nil
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 8) {
                Button { onBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Settings")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#a78bfa"))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Settings")
                .help("Back to Settings")

                Spacer()

                Text("Shortcuts")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    showResetConfirm = true
                } label: {
                    Text("Reset")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset all shortcuts to defaults")
                .help("Reset to default shortcuts")
                .confirmationDialog("Reset all shortcuts to defaults?",
                                    isPresented: $showResetConfirm,
                                    titleVisibility: .visible) {
                    Button("Reset to Defaults", role: .destructive) { store.resetToDefaults() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All custom shortcuts will be lost.")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.06))

            // Hint when recording
            if recording != nil {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#c8f060"))
                    Text("Press a key combo — Esc to cancel")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#c8f060").opacity(0.8))
                }
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#c8f060").opacity(0.06))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Shortcut rows
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(ShortcutAction.allCases, id: \.self) { action in
                        shortcutRow(action: action)
                        if action != ShortcutAction.allCases.last {
                            Divider()
                                .background(Color.white.opacity(0.04))
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { stopRecording() }
    }

    // ── Single shortcut row ────────────────────────────────────────────────────

    @ViewBuilder
    func shortcutRow(action: ShortcutAction) -> some View {
        let isRecordingThis = recording == action
        let current = store.shortcuts[action]

        HStack(spacing: 12) {
            // Action icon
            Image(systemName: action.systemImage)
                .font(.system(size: 13))
                .foregroundColor(isRecordingThis ? Color(hex: "#c8f060") : Color.white.opacity(0.45))
                .frame(width: 20)
                .accessibilityHidden(true)

            // Action name
            Text(action.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isRecordingThis ? .white : Color.white.opacity(0.75))

            Spacer()

            // Shortcut badge — tap to start recording
            Button {
                if isRecordingThis { stopRecording() }
                else               { startRecording(for: action) }
            } label: {
                Group {
                    if isRecordingThis {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: "#c8f060"))
                                .frame(width: 5, height: 5)
                                .opacity(pulsing ? 0.3 : 1.0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(), value: pulsing)
                            Text("recording…")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(hex: "#c8f060"))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(hex: "#c8f060").opacity(0.1))
                        .overlay(Capsule().stroke(Color(hex: "#c8f060").opacity(0.4), lineWidth: 1))
                        .clipShape(Capsule())
                    } else if let sc = current {
                        Text(sc.displayString)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.7))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.white.opacity(0.07))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                            .clipShape(Capsule())
                    } else {
                        Text("none")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.2))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.white.opacity(0.03))
                            .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecordingThis
                ? "Recording new shortcut for \(action.rawValue). Press any key combo."
                : "Shortcut for \(action.rawValue): \(current?.displayString ?? "none"). Tap to change.")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(isRecordingThis ? Color(hex: "#c8f060").opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @State private var pulsing = false

    // ── Recording logic ────────────────────────────────────────────────────────

    private func startRecording(for action: ShortcutAction) {
        stopRecording()
        recording = action
        pulsing   = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels recording
            if event.keyCode == 53 && flags.isEmpty {
                stopRecording()
                return nil
            }

            // Require at least one modifier (except Space and function keys)
            // to avoid capturing bare letters that the user might be typing
            let allowBare: Set<UInt16> = [49]   // Space
            let hasMod = !flags.intersection([.command, .option, .control, .shift]).isEmpty
            guard hasMod || allowBare.contains(event.keyCode) else { return nil }

            let display = shortcutDisplayString(for: event)
            let newShortcut = RecordedShortcut(
                keyCode:       event.keyCode,
                modifierFlags: flags.rawValue,
                displayString: display
            )
            store.set(newShortcut, for: action)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        recording = nil
        pulsing   = false
    }
}

// MARK: - Entry Row

struct EntryRow: View {
    @Binding var entry: ScheduleEntry
    let onTap: () -> Void
    let onTogglePause: () -> Void

    var appIcon: NSImage? {
        guard !entry.targetPath.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: entry.targetPath)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(entry.isPaused ? 0.04 : 0.06))
                    .frame(width: 34, height: 34)
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable().scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .opacity(entry.isPaused ? 0.3 : 1.0)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(entry.isPaused ? 0.15 : 0.4))
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.targetName.isEmpty ? "Unnamed" : entry.targetName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(entry.isPaused ? 0.25 : 0.9))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    timeBadge(time: entry.openTime,  isOpen: true)
                    timeBadge(time: entry.closeTime, isOpen: false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double-tap to edit")

            Spacer()

            Button { onTogglePause() } label: {
                Image(systemName: entry.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(entry.isPaused ? Color(hex: "#c8f060") : Color.white.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(entry.isPaused ? Color(hex: "#c8f060").opacity(0.1) : Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(entry.isPaused ? Color(hex: "#c8f060").opacity(0.25) : Color.white.opacity(0.08),
                                        lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isPaused ? "Resume \(entry.targetName)" : "Pause \(entry.targetName)")
            .help(entry.isPaused ? "Resume this schedule" : "Pause this schedule")

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.white.opacity(0.15))
                .accessibilityHidden(true)
                .onTapGesture { onTap() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(entry.isPaused ? 0.02 : 0.05))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(entry.isPaused ? 0.04 : 0.08), lineWidth: 1))
        )
    }

    private var rowAccessibilityLabel: String {
        var parts = [entry.targetName.isEmpty ? "Unnamed" : entry.targetName]
        if let t = entry.openTime  { parts.append("opens at \(shortTime(t))") }
        if let t = entry.closeTime { parts.append("closes at \(shortTime(t))") }
        if entry.isPaused          { parts.append("paused") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    func timeBadge(time: Date?, isOpen: Bool) -> some View {
        let color = isOpen ? Color(hex: "#4ade80") : Color(hex: "#ff6b6b")
        let emptyLabel = isOpen ? "no open" : "no close"
        if let t = time {
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 4, height: 4)
                Text(shortTime(t))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(color.opacity(0.85))
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.08))
            .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
            .clipShape(Capsule())
            .accessibilityHidden(true)
        } else {
            HStack(spacing: 3) {
                Circle().fill(Color.white.opacity(0.15)).frame(width: 4, height: 4)
                Text(emptyLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.2))
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.white.opacity(0.03))
            .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
            .clipShape(Capsule())
            .accessibilityHidden(true)
        }
    }

    func shortTime(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }
}

// MARK: - Entry Sheet

struct EntrySheet: View {
    @Binding var entry: ScheduleEntry
    let isNew: Bool
    let onSave: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var useOpen:  Bool = false
    @State private var useClose: Bool = false
    @State private var openTime:  Date = defaultTime()
    @State private var closeTime: Date = defaultTime()
    @State private var showDeleteConfirmation = false

    var appIcon: NSImage? {
        guard !entry.targetPath.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: entry.targetPath)
    }

    var body: some View {
        ZStack {
            ZStack {
                Color(hex: "#080810")
                RadialGradient(colors: [Color(hex: "#7050FF").opacity(0.4), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 300)
                RadialGradient(colors: [Color(hex: "#00B4FF").opacity(0.25), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 260)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                Divider().background(Color.white.opacity(0.07))
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        filePickerRow
                        timesSection
                    }
                    .padding(16)
                }
                if !isNew {
                    Divider().background(Color.white.opacity(0.06))
                    deleteRow
                }
            }
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(width: 340, height: isNew ? 320 : 360)
        .onAppear {
            useOpen  = entry.openTime  != nil
            useClose = entry.closeTime != nil
            if let t = entry.openTime  { openTime  = t }
            if let t = entry.closeTime { closeTime = t }
        }
        .confirmationDialog(
            "Delete \"\(entry.targetName.isEmpty ? "this schedule" : entry.targetName)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This schedule will be permanently removed.")
        }
        // Save and Delete shortcuts fire via notification from AppDelegate monitor
        .onReceive(NotificationCenter.default.publisher(for: .shortcutFired)) { note in
            guard let raw = note.userInfo?["action"] as? String,
                  let action = ShortcutAction(rawValue: raw) else { return }
            switch action {
            case .saveEntry:
                entry.openTime  = useOpen  ? openTime  : nil
                entry.closeTime = useClose ? closeTime : nil
                onSave(); dismiss()
            case .deleteEntry:
                if !isNew { showDeleteConfirmation = true }
            default: break
            }
        }
    }

    var sheetHeader: some View {
        HStack {
            Text(isNew ? "New Schedule" : "Edit Schedule")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button {
                entry.openTime  = useOpen  ? openTime  : nil
                entry.closeTime = useClose ? closeTime : nil
                onSave()
                dismiss()
            } label: {
                Text("Save")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#080810"))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color(hex: "#c8f060"))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save schedule")
            .help("Save this schedule (⌘S)")
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.black.opacity(0.1))
    }

    var filePickerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("TARGET")
            Button { pickFile() } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.white.opacity(entry.targetPath.isEmpty ? 0.05 : 0.08))
                            .frame(width: 36, height: 36)
                        if let icon = appIcon {
                            Image(nsImage: icon)
                                .resizable().scaledToFit()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: entry.targetPath.isEmpty ? "plus.circle" : "app.fill")
                                .font(.system(size: 15))
                                .foregroundColor(entry.targetPath.isEmpty
                                                 ? Color.white.opacity(0.25) : Color(hex: "#c8f060"))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.targetName.isEmpty ? "Choose App or File…" : entry.targetName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(entry.targetName.isEmpty
                                             ? Color.white.opacity(0.3) : Color.white.opacity(0.9))
                            .lineLimit(1).truncationMode(.middle)
                        if !entry.targetPath.isEmpty {
                            Text(entry.targetPath)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.25))
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.2))
                        .accessibilityHidden(true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(entry.targetPath.isEmpty
                                    ? Color.white.opacity(0.08) : Color(hex: "#c8f060").opacity(0.3),
                                    lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.targetName.isEmpty
                                ? "Choose app or file"
                                : "Selected: \(entry.targetName). Tap to change.")
            .help("Choose the app or file to schedule")
        }
    }

    var timesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("SCHEDULE")
            timeToggleRow(label: "Open at",  dotColor: "#4ade80", isOn: $useOpen,  time: $openTime)
            timeToggleRow(label: "Close at", dotColor: "#ff6b6b", isOn: $useClose, time: $closeTime)
        }
    }

    @ViewBuilder
    func timeToggleRow(label: String, dotColor: String, isOn: Binding<Bool>, time: Binding<Date>) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color(hex: isOn.wrappedValue ? dotColor : "#4a5260"))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(isOn.wrappedValue ? 0.85 : 0.35))
                .frame(width: 58, alignment: .leading)
            if isOn.wrappedValue {
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
            } else {
                Text("disabled")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.2))
            }
            Spacer()
            Toggle(label, isOn: isOn)
                .toggleStyle(.switch)
                .tint(Color(hex: dotColor))
                .labelsHidden()
                .scaleEffect(0.75, anchor: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn.wrappedValue ? Color(hex: dotColor).opacity(0.2) : Color.white.opacity(0.06),
                            lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.15), value: isOn.wrappedValue)
    }

    var deleteRow: some View {
        Button { showDeleteConfirmation = true } label: {
            Label("Delete Schedule", systemImage: "trash")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#ff6b6b"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(Color.black.opacity(0.05))
        .accessibilityLabel("Delete this schedule")
        .help("Permanently remove this schedule (⌘⌫)")
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.white.opacity(0.25))
            .kerning(1.5)
            .accessibilityHidden(true)
    }

    func pickFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App or File"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application, .spreadsheet, .pdf, .item]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let ps = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: sf.minX + 20, y: sf.maxY - ps.height + 20))
        }
        if panel.runModal() == .OK, let url = panel.url {
            entry.targetPath = url.path
            entry.targetName = url.deletingPathExtension().lastPathComponent
        }
    }
}

// MARK: - Jiggler View

struct JigglerView: View {
    @ObservedObject var jiggler: Jiggler

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Jiggler")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(jiggler.isActive ? "active" : "inactive")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(jiggler.isActive
                                         ? Color(hex: "#c8f060").opacity(0.8)
                                         : Color.white.opacity(0.3))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.06))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    // ── Accessibility warning ────────────────────────────
                    if jiggler.needsAccessibility {
                        accessibilityBanner
                    }

                    // ── Mode cards ───────────────────────────────────────
                    sectionLabel("MODE")
                    HStack(spacing: 8) {
                        ForEach(JigglerMode.allCases, id: \.self) { m in
                            modeCard(m)
                        }
                    }

                    // ── Human mode description ───────────────────────────
                    if jiggler.mode == .human {
                        humanDescription
                    }
                }
                .padding(14)
            }

            Divider().background(Color.white.opacity(0.06))

            // ── Toggle button ────────────────────────────────────────────
            toggleBar
        }
    }

    // ── Mode card ─────────────────────────────────────────────────────────────

    @ViewBuilder
    func modeCard(_ m: JigglerMode) -> some View {
        let selected = jiggler.mode == m
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { jiggler.mode = m }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: m.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selected ? Color(hex: "#c8f060") : Color.white.opacity(0.35))
                        .accessibilityHidden(true)
                    Spacer()
                    if selected {
                        Circle()
                            .fill(Color(hex: "#c8f060"))
                            .frame(width: 7, height: 7)
                    }
                }
                Text(m.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(selected ? .white : Color.white.opacity(0.5))
                Text(m.subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(selected
                                     ? Color.white.opacity(0.45)
                                     : Color.white.opacity(0.2))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected
                          ? Color(hex: "#c8f060").opacity(0.07)
                          : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected
                                    ? Color(hex: "#c8f060").opacity(0.3)
                                    : Color.white.opacity(0.07),
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(m.title) mode. \(m.subtitle)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // ── Human description box ─────────────────────────────────────────────────

    var humanDescription: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#60a8f0").opacity(0.7))
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text("Moves the cursor in natural arcs with random pauses — like a person browsing. Never clicks or right-clicks.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#60a8f0").opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#60a8f0").opacity(0.12), lineWidth: 1))
        )
    }

    // ── Accessibility banner ──────────────────────────────────────────────────

    var accessibilityBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#ffb347"))
                    .accessibilityHidden(true)
                Text("Accessibility permission required")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#ffb347"))
            }
            Text("Click \"Open Settings\", find App Scheduler in the list and enable it. If it doesn't appear, quit and relaunch the app, then try again.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    jiggler.openAccessibilitySettings()
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#080810"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(hex: "#ffb347"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Accessibility settings")

                Button {
                    jiggler.recheckAccessibility()
                } label: {
                    Text("I've enabled it ↩")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.white.opacity(0.05))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Re-check accessibility permission")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#ffb347").opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#ffb347").opacity(0.2), lineWidth: 1))
        )
    }

    // ── Section label ─────────────────────────────────────────────────────────

    func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.25))
                .kerning(1.5)
            Spacer()
        }
        .accessibilityHidden(true)
    }

    // ── Bottom toggle bar ─────────────────────────────────────────────────────

    var toggleBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: jiggler.isActive && !jiggler.humanPaused
                            ? statusColor.opacity(0.8) : .clear, radius: 4)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true),
                               value: jiggler.isActive)
                    .accessibilityHidden(true)
                Text(statusLabel)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(statusColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { jiggler.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: jiggler.isActive ? "stop.fill" : "play.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(jiggler.isActive ? "Stop" : "Start")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundColor(jiggler.isActive
                                 ? Color(hex: "#ff6b6b")
                                 : Color(hex: "#c8f060"))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(jiggler.isActive
                              ? Color(hex: "#ff6b6b").opacity(0.10)
                              : Color(hex: "#c8f060").opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(jiggler.isActive
                                    ? Color(hex: "#ff6b6b").opacity(0.25)
                                    : Color(hex: "#c8f060").opacity(0.25),
                                    lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(jiggler.isActive ? "Stop jiggler" : "Start jiggler")
            .help(jiggler.isActive ? "Stop mouse jiggler" : "Start mouse jiggler")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.1))
    }

    private var statusColor: Color {
        if !jiggler.isActive      { return Color(hex: "#6b7280") }
        if jiggler.humanPaused    { return Color(hex: "#ffb347") }
        return Color(hex: "#c8f060")
    }

    private var statusLabel: String {
        if !jiggler.isActive      { return "Stopped" }
        if jiggler.humanPaused    { return "Yielding to you…" }
        return "Jiggling…"
    }
}

// MARK: - Helpers

func defaultTime() -> Date {
    let now = Date()
    let cal = Calendar.current
    let c = cal.dateComponents([.hour, .minute], from: now)
    return cal.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: now) ?? now
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
