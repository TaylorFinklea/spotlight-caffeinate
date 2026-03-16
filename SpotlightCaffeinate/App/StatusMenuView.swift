import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Bindable var controller: CaffeinateController
    @Environment(\.openWindow) private var openWindow
    @State private var settingsExpanded = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            statusHeader
            presetsSection
            if controller.isRunning {
                activeSessionSection
            }
            customDurationSection
            if !controller.recentSessions.isEmpty {
                recentSessionsSection
            }
            footerSection
        }
        .padding(16)
        .frame(width: 360)
    }

    private var statusHeader: some View {
        let now = controller.currentTime
        let remainingFraction = CGFloat(controller.snapshot.remainingFraction(at: now))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                BoltIconView(fillFraction: remainingFraction, size: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.isRunning ? "Caffeinate Active" : "Caffeinate Idle")
                        .font(.headline)

                    Text(controller.snapshot.statusLine(at: now))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if controller.isRunning, controller.snapshot.startedAt != nil || controller.snapshot.endsAt != nil {
                HStack(spacing: 14) {
                    if let startedAt = controller.snapshot.startedAt {
                        Label("Started at \(startedAt, formatter: Self.timeFormatter)", systemImage: "clock")
                    }

                    if let endsAt = controller.snapshot.endsAt {
                        Label("Ending at \(endsAt, formatter: Self.timeFormatter)", systemImage: "alarm")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let lastError = controller.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quick Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Manage") {
                    openPresetManager()
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            if controller.pinnedPresets.isEmpty {
                Text("No pinned presets yet. Use Preset Manager to create or pin them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(controller.pinnedPresets.prefix(4))) { preset in
                        presetButton(preset)
                    }
                }
            }
        }
    }

    private var activeSessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Session")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                extendButton(5)
                extendButton(15)
                extendButton(30)
            }

            Button("Restart Last") {
                controller.restartLast()
            }
            .buttonStyle(.bordered)
            .disabled(controller.recentSessions.isEmpty)
        }
    }

    private var customDurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom Duration")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper(value: $controller.suggestedMinutes, in: 1...480) {
                Text("\(controller.suggestedMinutes) minutes")
            }

            Picker("Power Mode", selection: $controller.suggestedPowerMode) {
                ForEach(PowerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Button(controller.isRunning ? "Restart for \(controller.suggestedMinutes) Minutes" : "Start for \(controller.suggestedMinutes) Minutes") {
                controller.start()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(controller.recentSessions) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayName)
                        Text("\(entry.minutesRequested)m • \(entry.powerMode.title) • \(entry.source.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(entry.endedAt, formatter: Self.timeFormatter)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            if settingsExpanded {
                settingsSection
            }

            HStack {
                Button("Presets") {
                    openPresetManager()
                }

                Button("Automations") {
                    openAutomationManager()
                }

                settingsDisclosure

                Button("Refresh") {
                    Task {
                        await controller.refresh()
                    }
                }

                if controller.isRunning {
                    Button("Stop") {
                        controller.stop()
                    }
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }

            Text("Spotlight actions: Start, Stop, Check Status")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsDisclosure: some View {
        Button {
            settingsExpanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Label("Settings", systemImage: "gearshape")

                Image(systemName: settingsExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsGroup(
                title: "Menu Bar",
                status: "Turn this off to show only the icon. The icon drains as the session counts down.",
                statusIsError: false
            ) {
                Toggle(
                    "Show Remaining Time in Menu Bar",
                    isOn: Binding(
                        get: { controller.showMenuBarTime },
                        set: { controller.setShowMenuBarTime($0) }
                    )
                )
            }

            settingsGroup(
                title: "App",
                status: controller.launchAtLoginStatus,
                statusIsError: controller.launchAtLoginStatusIsError
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(
                        "Open Spotlight Caffeinate at Login",
                        isOn: Binding(
                            get: { controller.launchAtLoginEnabled },
                            set: { controller.setLaunchAtLoginEnabled($0) }
                        )
                    )

                    Button("Open Preset Manager") {
                        openPresetManager()
                    }
                    .buttonStyle(.link)

                    Button("Open Automation Manager") {
                        openAutomationManager()
                    }
                    .buttonStyle(.link)
                }
            }

            settingsGroup(
                title: "Calendar",
                status: controller.calendarStatus,
                statusIsError: controller.calendarStatusIsError
            ) {
                Button("Open Automation Manager") {
                    openAutomationManager()
                }
                .buttonStyle(.link)
            }

            settingsGroup(
                title: "Notifications",
                status: controller.notificationStatus,
                statusIsError: controller.notificationStatusIsError
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    if controller.notificationAuthorizationState == .granted {
                        Toggle(
                            "Notify When Caffeinate Ends",
                            isOn: Binding(
                                get: { controller.notificationsEnabled },
                                set: { controller.setNotificationsEnabled($0) }
                            )
                        )
                    } else {
                        Button("Enable Notifications") {
                            controller.requestNotificationAuthorization()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open Notification Settings") {
                            controller.openNotificationSettings()
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func settingsGroup<Content: View>(
        title: String,
        status: String?,
        statusIsError: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            content()

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(statusIsError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func presetButton(_ preset: CaffeinatePreset) -> some View {
        Button(preset.name) {
            controller.startPreset(preset)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func extendButton(_ minutes: Int) -> some View {
        Button("+\(minutes)m") {
            controller.extend(minutes: minutes)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func openPresetManager() {
        openWindow(id: "preset-manager")
    }

    private func openAutomationManager() {
        openWindow(id: "automation-manager")
    }
}
