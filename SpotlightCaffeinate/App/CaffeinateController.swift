import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class CaffeinateController {
    var snapshot: CaffeinateSnapshot = .inactive
    var currentTime = Date()
    var suggestedMinutes = 5
    var showMenuBarTime: Bool
    var launchAtLoginEnabled: Bool
    var launchAtLoginStatus: String?
    var launchAtLoginStatusIsError: Bool
    var notificationsEnabled: Bool
    var notificationAuthorizationState: NotificationAuthorizationState
    var notificationStatus: String?
    var notificationStatusIsError: Bool
    var lastError: String?

    @ObservationIgnored
    private let service: CaffeinateService

    @ObservationIgnored
    private let notificationService: CaffeinateNotificationService

    @ObservationIgnored
    private let launchAtLoginService: LaunchAtLoginService

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private static let notificationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.notifications"
    )!

    @ObservationIgnored
    private static let showMenuBarTimeKey = "showMenuBarTime"

    init(
        service: CaffeinateService = .shared,
        notificationService: CaffeinateNotificationService = .shared,
        launchAtLoginService: LaunchAtLoginService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.notificationService = notificationService
        self.launchAtLoginService = launchAtLoginService
        self.defaults = defaults
        showMenuBarTime = Self.showMenuBarTimePreference(defaults: defaults)
        launchAtLoginEnabled = false
        launchAtLoginStatus = nil
        launchAtLoginStatusIsError = false
        notificationsEnabled = false
        notificationAuthorizationState = .notDetermined
        notificationStatusIsError = false

        Task { [weak self] in
            await self?.syncNotificationSettings()
            await self?.syncLaunchAtLoginSettings()
        }

        pollingTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                currentTime = .now
                await refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    var isRunning: Bool {
        snapshot.isRunning(at: currentTime)
    }

    func start() {
        start(minutes: suggestedMinutes)
    }

    func start(minutes: Int) {
        Task {
            do {
                snapshot = try await service.start(minutes: minutes)
                currentTime = .now
                suggestedMinutes = minutes
                await syncNotificationSettings()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func stop() {
        Task {
            do {
                snapshot = try await service.stop()
                currentTime = .now
                await syncNotificationSettings()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginEnabled = enabled

        Task {
            let settings = await launchAtLoginService.updatePreference(enabled: enabled)
            applyLaunchAtLoginSettings(settings)
        }
    }

    func setShowMenuBarTime(_ enabled: Bool) {
        showMenuBarTime = enabled
        defaults.set(enabled, forKey: Self.showMenuBarTimeKey)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled

        Task {
            if enabled {
                await runNotificationEnableFlow { [self] in
                    await self.notificationService.updatePreference(
                        enabled: enabled,
                        currentSnapshot: self.snapshot
                    )
                }
            } else {
                let result = await notificationService.updatePreference(
                    enabled: enabled,
                    currentSnapshot: snapshot
                )
                await applyNotificationPreferenceUpdate(result)
            }
        }
    }

    func requestNotificationAuthorization() {
        Task {
            await runNotificationEnableFlow { [self] in
                await self.notificationService.requestAuthorizationAndEnable(currentSnapshot: self.snapshot)
            }
        }
    }

    func refresh() async {
        do {
            snapshot = try await service.status()
            currentTime = .now
            await syncNotificationSettings()
            await syncLaunchAtLoginSettings()
            if !snapshot.isRunning {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func openNotificationSettings() {
        guard NSWorkspace.shared.open(Self.notificationSettingsURL) else {
            notificationStatus = "Could not open Notification Settings."
            notificationStatusIsError = true
            return
        }

        notificationStatus = "Notification Settings opened."
        notificationStatusIsError = false
    }

    private func syncNotificationSettings() async {
        let settings = await notificationService.currentSettings()
        notificationAuthorizationState = settings.authorization
        notificationsEnabled = settings.preferenceEnabled && settings.authorization == .granted

        switch settings.authorization {
        case .granted:
            notificationStatus = notificationsEnabled ? nil : "Turn this on to get a macOS notification when caffeinate finishes."
            notificationStatusIsError = false
        case .notDetermined:
            notificationStatus = "Click Enable Notifications to show the macOS prompt."
            notificationStatusIsError = false
        case .denied:
            notificationStatus = "Allow notifications for Spotlight Caffeinate in System Settings to enable completion alerts."
            notificationStatusIsError = true
        }
    }

    private func runNotificationEnableFlow(
        operation: @escaping () async -> NotificationPreferenceUpdateResult
    ) async {
        let previousPolicy = NSApplication.shared.activationPolicy()
        if previousPolicy != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)

        do {
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            // Ignore cancellation here. If the task was cancelled, the next await will no-op naturally.
        }

        let result = await operation()

        if previousPolicy != .regular {
            NSApplication.shared.setActivationPolicy(previousPolicy)
        }

        await applyNotificationPreferenceUpdate(result)
    }

    private func applyNotificationPreferenceUpdate(_ result: NotificationPreferenceUpdateResult) async {
        switch result {
        case .enabled:
            notificationsEnabled = true
            notificationStatus = nil
            notificationStatusIsError = false
        case .disabled:
            notificationsEnabled = false
            notificationStatus = "Turn this on to get a macOS notification when caffeinate finishes."
            notificationStatusIsError = false
        case .denied:
            notificationsEnabled = false
            notificationStatus = "Allow notifications for Spotlight Caffeinate in System Settings to enable completion alerts."
            notificationStatusIsError = true
        case .failed(let message):
            notificationsEnabled = false
            notificationStatus = message
            notificationStatusIsError = true
        }

        await syncNotificationSettings()
    }

    private func syncLaunchAtLoginSettings() async {
        let settings = await launchAtLoginService.currentSettings()

        if !settings.isEnabled, settings.statusMessage == nil, launchAtLoginStatusIsError {
            launchAtLoginEnabled = false
            return
        }

        applyLaunchAtLoginSettings(settings)
    }

    private func applyLaunchAtLoginSettings(_ settings: LaunchAtLoginSettings) {
        launchAtLoginEnabled = settings.isEnabled
        launchAtLoginStatus = settings.statusMessage
        launchAtLoginStatusIsError = settings.statusIsError
    }

    private nonisolated static func showMenuBarTimePreference(defaults: UserDefaults) -> Bool {
        guard let value = defaults.object(forKey: "showMenuBarTime") as? Bool else {
            return true
        }

        return value
    }
}
