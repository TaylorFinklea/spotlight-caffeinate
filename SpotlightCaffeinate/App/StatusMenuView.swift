import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Bindable var controller: CaffeinateController
    @Environment(\.openWindow) private var openWindow

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard

            if controller.isRunning {
                activeControlsSection
            }

            presetsSection
            startComposerSection

            if let latestSession = controller.recentSessions.first {
                recentSessionSection(latestSession)
            }

            footerSection
        }
        .padding(14)
        .frame(width: 372)
    }

    private var statusCard: some View {
        let now = controller.currentTime
        let remainingFraction = CGFloat(controller.snapshot.remainingFraction(at: now))

        return sectionCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    BoltIconView(fillFraction: remainingFraction, size: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(controller.isRunning ? controller.snapshot.displayName : "Caffeinate")
                            .font(.headline)

                        Text(controller.snapshot.menuSubtitle(at: now))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    if controller.isRunning {
                        Text(controller.snapshot.remainingText(at: now))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }

                if controller.isRunning {
                    statusMetadataRow
                }

                if let message = menuBannerMessage {
                    Text(message.text)
                        .font(.caption)
                        .foregroundStyle(message.isError ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var statusMetadataRow: some View {
        HStack(spacing: 12) {
            if let startedAt = controller.snapshot.startedAt {
                Label("Started \(startedAt, formatter: Self.timeFormatter)", systemImage: "clock")
            }

            if let endsAt = controller.snapshot.endsAt {
                Label("Ends \(endsAt, formatter: Self.timeFormatter)", systemImage: "alarm")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var activeControlsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adjust Current Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    extendButton(5)
                    extendButton(15)
                    extendButton(30)
                }

                Button("Stop Session", role: .destructive, action: stopSession)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var presetsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Quick Start")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Manage", action: openPresetManager)
                        .buttonStyle(.link)
                        .font(.caption)
                }

                if controller.pinnedPresets.isEmpty {
                    HStack(spacing: 10) {
                        Text("No pinned presets yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Open Presets", action: openPresetManager)
                            .buttonStyle(.bordered)
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(Array(controller.pinnedPresets.prefix(4))) { preset in
                            presetButton(preset)
                        }
                    }
                }
            }
        }
    }

    private var startComposerSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(controller.isRunning ? "Start New Session" : "Custom Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(value: $controller.suggestedMinutes, in: 1...480) {
                    Text("\(controller.suggestedMinutes) minutes")
                        .font(.body.weight(.medium))
                }

                Picker("Power Mode", selection: $controller.suggestedPowerMode) {
                    ForEach(PowerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(controller.suggestedPowerMode.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(startButtonTitle, action: startSession)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func recentSessionSection(_ entry: RecentSessionEntry) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Latest Session")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Restart Last", action: restartLastSession)
                        .buttonStyle(.bordered)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayName)
                            .font(.body.weight(.medium))

                        Text(entry.summaryLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(entry.endedAt, formatter: Self.timeFormatter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Button("Presets", action: openPresetManager)
                Button("Automations", action: openAutomationManager)
                Button("Settings", action: openSettings)
            }
            .controlSize(.small)

            HStack {
                Button("Refresh", action: refresh)
                    .controlSize(.small)

                Spacer()

                Button("Quit", action: quitApp)
                    .controlSize(.small)
            }

            Text("Spotlight actions: Start, Stop, Check Status")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var startButtonTitle: String {
        controller.isRunning
            ? "Restart for \(controller.suggestedMinutes) Minutes"
            : "Start for \(controller.suggestedMinutes) Minutes"
    }

    private var menuBannerMessage: (text: String, isError: Bool)? {
        if let lastError = controller.lastError {
            return (lastError, true)
        }

        if controller.isRunning, controller.notificationAuthorizationState == .denied {
            return ("Completion alerts are off. Open Settings to restore notifications.", false)
        }

        return nil
    }

    private func sectionCard<Content: View>(
        padding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                .quaternary.opacity(0.3),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
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

    private func startSession() {
        controller.start()
    }

    private func stopSession() {
        controller.stop()
    }

    private func restartLastSession() {
        controller.restartLast()
    }

    private func refresh() {
        Task {
            await controller.refresh()
        }
    }

    private func openPresetManager() {
        openAuxiliaryWindow(id: "preset-manager")
    }

    private func openAutomationManager() {
        openAuxiliaryWindow(id: "automation-manager")
    }

    private func openSettings() {
        openAuxiliaryWindow(id: "settings")
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func openAuxiliaryWindow(id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        Task { @MainActor in
            openWindow(id: id)
        }
    }
}
