import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Bindable var controller: CaffeinateController
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
            customDurationSection
            footerSection
        }
        .padding(16)
        .frame(width: 340)
    }

    private var statusHeader: some View {
        let now = controller.currentTime

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                BoltIconView(size: 28)
                    .foregroundStyle(controller.isRunning ? .green : .secondary)

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
            Text("Quick Start")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                presetButton(5)
                presetButton(15)
                presetButton(30)
                presetButton(60)
            }
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

            Button(controller.isRunning ? "Restart for \(controller.suggestedMinutes) Minutes" : "Start for \(controller.suggestedMinutes) Minutes") {
                controller.start()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            if settingsExpanded {
                settingsSection
            }

            HStack {
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
                title: "App",
                status: controller.launchAtLoginStatus,
                statusIsError: controller.launchAtLoginStatusIsError
            ) {
                Toggle(
                    "Open Spotlight Caffeinate at Login",
                    isOn: Binding(
                        get: { controller.launchAtLoginEnabled },
                        set: { controller.setLaunchAtLoginEnabled($0) }
                    )
                )
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

    private func presetButton(_ minutes: Int) -> some View {
        Button("\(minutes)m") {
            controller.start(minutes: minutes)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}
