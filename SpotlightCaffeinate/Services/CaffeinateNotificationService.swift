import Foundation
import UserNotifications

enum NotificationPreferenceUpdateResult {
    case enabled
    case disabled
    case denied
}

actor CaffeinateNotificationService {
    static let shared = CaffeinateNotificationService()

    private static let notificationsEnabledKey = "notifyOnCompletion"
    private let notificationIdentifier = "io.taylorfinklea.spotlightcaffeinate.completion"
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    nonisolated static func notificationsEnabledPreference(defaults: UserDefaults = .standard) -> Bool {
        guard let value = defaults.object(forKey: notificationsEnabledKey) as? Bool else {
            return true
        }

        return value
    }

    func updatePreference(enabled: Bool, currentSnapshot: CaffeinateSnapshot) async -> NotificationPreferenceUpdateResult {
        guard enabled else {
            storePreference(false)
            cancelPendingCompletionNotification()
            return .disabled
        }

        guard await ensureAuthorization() else {
            storePreference(false)
            cancelPendingCompletionNotification()
            return .denied
        }

        storePreference(true)

        if currentSnapshot.isRunning {
            await scheduleCompletionNotificationIfNeeded(for: currentSnapshot)
        }

        return .enabled
    }

    func scheduleCompletionNotificationIfNeeded(for snapshot: CaffeinateSnapshot) async {
        cancelPendingCompletionNotification()

        guard Self.notificationsEnabledPreference(defaults: defaults), snapshot.isRunning else {
            return
        }

        guard await ensureAuthorization() else {
            storePreference(false)
            return
        }

        let remainingSeconds = max(1, snapshot.remainingSeconds(at: .now))
        let content = UNMutableNotificationContent()
        content.title = "Caffeinate Finished"
        content.body = notificationBody(for: snapshot)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingSeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await add(request)
        } catch {
            // Keep failures non-fatal. The caffeinate run itself still succeeded.
        }
    }

    func cancelPendingCompletionNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }

    private func notificationBody(for snapshot: CaffeinateSnapshot) -> String {
        if let minutesRequested = snapshot.minutesRequested {
            return "Your \(minutesRequested)-minute caffeinate session has ended."
        }

        return "Your Mac can sleep normally again."
    }

    private func storePreference(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.notificationsEnabledKey)
    }

    private func ensureAuthorization() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await requestAuthorization()) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
