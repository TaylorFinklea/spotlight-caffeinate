import Foundation
import Observation

@MainActor
@Observable
final class CaffeinateController {
    var snapshot: CaffeinateSnapshot = .inactive
    var currentTime = Date()
    var suggestedMinutes = 5
    var notificationsEnabled: Bool
    var notificationStatus: String?
    var lastError: String?

    @ObservationIgnored
    private let service: CaffeinateService

    @ObservationIgnored
    private let notificationService: CaffeinateNotificationService

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    init(
        service: CaffeinateService = .shared,
        notificationService: CaffeinateNotificationService = .shared
    ) {
        self.service = service
        self.notificationService = notificationService
        notificationsEnabled = false

        Task { [weak self] in
            await self?.syncNotificationSettings()
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

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled

        Task {
            let result = await notificationService.updatePreference(
                enabled: enabled,
                currentSnapshot: snapshot
            )

            switch result {
            case .enabled:
                notificationsEnabled = true
                notificationStatus = nil
            case .disabled:
                notificationsEnabled = false
                notificationStatus = "Turn this on to get a macOS notification when caffeinate finishes."
            case .denied:
                notificationsEnabled = false
                notificationStatus = "Allow notifications for Spotlight Caffeinate in System Settings to enable completion alerts."
            }
        }
    }

    func refresh() async {
        do {
            snapshot = try await service.status()
            currentTime = .now
            await syncNotificationSettings()
            if !snapshot.isRunning {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func syncNotificationSettings() async {
        let settings = await notificationService.currentSettings()
        notificationsEnabled = settings.preferenceEnabled && settings.authorization == .granted

        switch settings.authorization {
        case .granted:
            notificationStatus = notificationsEnabled ? nil : "Turn this on to get a macOS notification when caffeinate finishes."
        case .notDetermined:
            notificationStatus = "Turn this on to allow completion notifications."
        case .denied:
            notificationStatus = "Allow notifications for Spotlight Caffeinate in System Settings to enable completion alerts."
        }
    }
}
