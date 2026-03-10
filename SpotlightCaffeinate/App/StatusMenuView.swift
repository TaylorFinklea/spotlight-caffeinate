import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Bindable var controller: CaffeinateController

    private static let startedFormatter: DateFormatter = {
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
            notificationsSection
            footerSection
        }
        .padding(16)
        .frame(width: 340)
    }

    private var statusHeader: some View {
        let now = controller.currentTime

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: controller.snapshot.menuBarSymbolName(at: now))
                    .font(.system(size: 28, weight: .semibold))
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

            if controller.isRunning, let startedAt = controller.snapshot.startedAt {
                Label("Started at \(startedAt, formatter: Self.startedFormatter)", systemImage: "clock")
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

            HStack {
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

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(
                "Notify When Caffeinate Ends",
                isOn: Binding(
                    get: { controller.notificationsEnabled },
                    set: { controller.setNotificationsEnabled($0) }
                )
            )

            if let notificationStatus = controller.notificationStatus {
                Text(notificationStatus)
                    .font(.caption)
                    .foregroundStyle(.red)
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
