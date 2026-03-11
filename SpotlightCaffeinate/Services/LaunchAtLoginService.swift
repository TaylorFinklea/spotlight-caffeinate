import Foundation
import ServiceManagement

struct LaunchAtLoginSettings: Sendable {
    let isEnabled: Bool
    let statusMessage: String?
    let statusIsError: Bool
}

actor LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private let service = SMAppService.mainApp

    func currentSettings() -> LaunchAtLoginSettings {
        settings(for: service.status)
    }

    func updatePreference(enabled: Bool) -> LaunchAtLoginSettings {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            return settings(
                for: service.status,
                fallbackError: errorMessage(for: error, enabling: enabled)
            )
        }

        return settings(for: service.status)
    }

    private func settings(
        for status: SMAppService.Status,
        fallbackError: String? = nil
    ) -> LaunchAtLoginSettings {
        switch status {
        case .enabled:
            return LaunchAtLoginSettings(
                isEnabled: true,
                statusMessage: nil,
                statusIsError: false
            )
        case .notRegistered:
            return LaunchAtLoginSettings(
                isEnabled: false,
                statusMessage: fallbackError,
                statusIsError: fallbackError != nil
            )
        case .requiresApproval:
            return LaunchAtLoginSettings(
                isEnabled: true,
                statusMessage: "Allow Spotlight Caffeinate in System Settings > General > Login Items to finish enabling launch at login.",
                statusIsError: false
            )
        case .notFound:
            return LaunchAtLoginSettings(
                isEnabled: false,
                statusMessage: fallbackError ?? "Launch at login is unavailable for this build. Use a signed Spotlight Caffeinate app installed in /Applications.",
                statusIsError: true
            )
        @unknown default:
            return LaunchAtLoginSettings(
                isEnabled: false,
                statusMessage: fallbackError ?? "Launch at login status is unavailable.",
                statusIsError: true
            )
        }
    }

    private func errorMessage(for error: Error, enabling: Bool) -> String {
        let nsError = error as NSError

        if enabling {
            return "Could not turn on launch at login for this build. Use a signed Spotlight Caffeinate app installed in /Applications."
        }

        return "Could not turn off launch at login: \(nsError.localizedDescription)"
    }
}
