import AppKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class CaffeinateController {
    private static let logger = Logger(
        subsystem: "dev.finklea.spotlightcaffeinate",
        category: "controller"
    )

    var snapshot: CaffeinateSnapshot = .inactive
    var presets: [CaffeinatePreset] = []
    var recentSessions: [RecentSessionEntry] = []
    var automationRules: [AutomationRule] = []
    var automationRunHistory: [AutomationRunRecord] = []
    var availableCalendars: [AutomationCalendarOption] = []
    var currentTime = Date()
    var suggestedMinutes = 5
    var suggestedPowerMode: PowerMode = .full
    var glyphStyle: GlyphStyle
    var pulseThreshold: PulseThreshold
    var pulseOpacity: CGFloat = 1.0
    var launchAtLoginEnabled: Bool
    var launchAtLoginStatus: String?
    var launchAtLoginStatusIsError: Bool
    var notificationsEnabled: Bool
    var notificationAuthorizationState: NotificationAuthorizationState
    var notificationStatus: String?
    var notificationStatusIsError: Bool
    var calendarAuthorizationState: AutomationCalendarAuthorizationState
    var calendarStatus: String?
    var calendarStatusIsError: Bool
    var lastError: String?

    @ObservationIgnored
    private let service: CaffeinateService

    @ObservationIgnored
    private let automationService: AutomationService

    @ObservationIgnored
    private let notificationService: CaffeinateNotificationService

    @ObservationIgnored
    private let launchAtLoginService: LaunchAtLoginService

    @ObservationIgnored
    private let automationEngine: AutomationEngine

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?

    @ObservationIgnored
    private var pulseTask: Task<Void, Never>?

    @ObservationIgnored
    private var pulseStepIndex = 0

    @ObservationIgnored
    private nonisolated static let pulseStepCount = 8

    @ObservationIgnored
    private static let notificationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.notifications"
    )!

    @ObservationIgnored
    private nonisolated static let showMenuBarTimeKey = "showMenuBarTime"

    @ObservationIgnored
    private nonisolated static let glyphStyleKey = "glyphStyle"

    @ObservationIgnored
    private nonisolated static let pulseThresholdKey = "pulseThreshold"

    init(
        service: CaffeinateService = .shared,
        automationService: AutomationService = .shared,
        notificationService: CaffeinateNotificationService = .shared,
        launchAtLoginService: LaunchAtLoginService = .shared,
        automationEngine: AutomationEngine = AutomationEngine(),
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.automationService = automationService
        self.notificationService = notificationService
        self.launchAtLoginService = launchAtLoginService
        self.automationEngine = automationEngine
        self.defaults = defaults
        glyphStyle = Self.glyphStylePreference(defaults: defaults)
        pulseThreshold = Self.pulseThresholdPreference(defaults: defaults)
        launchAtLoginEnabled = false
        launchAtLoginStatus = nil
        launchAtLoginStatusIsError = false
        notificationsEnabled = false
        notificationAuthorizationState = .notDetermined
        notificationStatusIsError = false
        calendarAuthorizationState = .notDetermined
        calendarStatus = "Calendar access is only needed for calendar-based automations."
        calendarStatusIsError = false

        Task { [weak self] in
            await self?.refresh()
            await self?.syncNotificationSettings()
            await self?.syncLaunchAtLoginSettings()
            await self?.syncCalendarSettings()
        }

        pulseTask = Task { [weak self] in
            let interval: Duration = .milliseconds(200)

            while !Task.isCancelled {
                guard let self else {
                    return
                }

                self.tickPulse()

                try? await Task.sleep(for: interval)
            }
        }

        pollingTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                currentTime = .now
                await automationEngine.processTick(now: currentTime)
                await refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    deinit {
        pollingTask?.cancel()
        pulseTask?.cancel()
    }

    var isRunning: Bool {
        snapshot.isRunning(at: currentTime)
    }

    var pinnedPresets: [CaffeinatePreset] {
        presets.filter(\.isPinned)
    }

    func start() {
        start(minutes: suggestedMinutes, powerMode: suggestedPowerMode)
    }

    func start(minutes: Int, powerMode: PowerMode = .full) {
        Task {
            do {
                snapshot = try await service.start(minutes: minutes, powerMode: powerMode, source: .app)
                currentTime = .now
                suggestedMinutes = minutes
                suggestedPowerMode = powerMode
                recentSessions = try await service.recentSessions(limit: 5)
                await syncNotificationSettings()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func startPreset(_ preset: CaffeinatePreset) {
        Task {
            do {
                snapshot = try await service.startPreset(id: preset.id, source: .app)
                currentTime = .now
                suggestedMinutes = preset.minutes
                suggestedPowerMode = preset.powerMode
                recentSessions = try await service.recentSessions(limit: 5)
                lastError = nil
                await syncNotificationSettings()
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
                recentSessions = try await service.recentSessions(limit: 5)
                await syncNotificationSettings()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func extend(minutes: Int) {
        Task {
            do {
                snapshot = try await service.extend(minutes: minutes, source: .app)
                currentTime = .now
                recentSessions = try await service.recentSessions(limit: 5)
                lastError = nil
                await syncNotificationSettings()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func restartLast() {
        Task {
            do {
                snapshot = try await service.restartLast(source: .app)
                currentTime = .now
                recentSessions = try await service.recentSessions(limit: 5)
                lastError = nil
                await syncNotificationSettings()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func savePreset(
        id: UUID?,
        name: String,
        minutes: Int,
        powerMode: PowerMode,
        isPinned: Bool
    ) async -> UUID? {
        do {
            presets = try await savePresetList(
                id: id,
                name: name,
                minutes: minutes,
                powerMode: powerMode,
                isPinned: isPinned
            )
            lastError = nil
            return id ?? presets.last?.id
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func saveAutomationRule(
        id: UUID?,
        name: String,
        presetID: UUID,
        trigger: AutomationTrigger,
        enabled: Bool
    ) async -> UUID? {
        do {
            if case .calendar = trigger, enabled, calendarAuthorizationState != .granted {
                let granted = await ensureCalendarAccessIfNeeded()
                guard granted else {
                    return nil
                }
            }

            if let id {
                automationRules = try await automationService.updateRule(
                    id: id,
                    name: name,
                    presetID: presetID,
                    trigger: trigger,
                    enabled: enabled
                )
                lastError = nil
                return id
            }

            automationRules = try await automationService.createRule(
                name: name,
                presetID: presetID,
                trigger: trigger,
                enabled: enabled
            )
            lastError = nil
            return automationRules.last?.id
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func deleteAutomationRule(id: UUID) async {
        do {
            automationRules = try await automationService.deleteRule(id: id)
            automationRunHistory = try await automationService.runHistory(limit: 10)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setAutomationRuleEnabled(id: UUID, enabled: Bool) async {
        do {
            if enabled {
                let hasCalendarAccess = await ensureCalendarAccessIfNeeded(for: id)
                guard hasCalendarAccess else {
                    return
                }
            }

            automationRules = try await automationService.setRuleEnabled(id: id, enabled: enabled)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshAutomationCalendars() async {
        availableCalendars = await automationService.availableCalendars()
        await syncCalendarSettings()
    }

    func requestCalendarAccess() {
        Task {
            _ = await ensureCalendarAccessIfNeeded(forcePrompt: true)
        }
    }

    func deletePreset(id: UUID) async {
        do {
            presets = try await service.deletePreset(id: id)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func movePreset(id: UUID, direction: PresetMoveDirection) async {
        do {
            presets = try await service.movePreset(id: id, direction: direction)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginEnabled = enabled

        Task {
            let settings = await launchAtLoginService.updatePreference(enabled: enabled)
            applyLaunchAtLoginSettings(settings)
        }
    }

    func setGlyphStyle(_ style: GlyphStyle) {
        glyphStyle = style
        defaults.set(style.rawValue, forKey: Self.glyphStyleKey)
    }

    func setPulseThreshold(_ threshold: PulseThreshold) {
        pulseThreshold = threshold
        defaults.set(threshold.rawValue, forKey: Self.pulseThresholdKey)
        if !isNearExpiry, pulseOpacity != 1.0 {
            pulseStepIndex = 0
            pulseOpacity = 1.0
        }
    }

    var isNearExpiry: Bool {
        pulseThreshold.shouldPulse(remainingSeconds: snapshot.remainingSeconds(at: currentTime))
    }

    private func tickPulse() {
        if isNearExpiry {
            pulseStepIndex = (pulseStepIndex + 1) % Self.pulseStepCount
            pulseOpacity = Self.pulseOpacity(forStep: pulseStepIndex)
        } else if pulseOpacity != 1.0 {
            pulseStepIndex = 0
            pulseOpacity = 1.0
        }
    }

    nonisolated static func pulseOpacity(forStep step: Int) -> CGFloat {
        let normalizedPhase = Double(step % pulseStepCount) / Double(pulseStepCount) * 2 * .pi
        let cosValue = cos(normalizedPhase)
        let normalized = (1 + cosValue) / 2
        let minimum = 0.35
        return CGFloat(minimum + normalized * (1.0 - minimum))
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
            presets = try await service.presets()
            recentSessions = try await service.recentSessions(limit: 5)
            automationRules = try await automationService.rules()
            automationRunHistory = try await automationService.runHistory(limit: 10)
            currentTime = .now
            await syncNotificationSettings()
            await syncLaunchAtLoginSettings()
            await syncCalendarSettings()
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

    private func syncCalendarSettings() async {
        calendarAuthorizationState = await automationService.calendarAuthorizationState()

        switch calendarAuthorizationState {
        case .granted:
            calendarStatus = "Calendar automations can monitor selected calendars."
            calendarStatusIsError = false
        case .notDetermined:
            calendarStatus = "Calendar access is only needed for calendar-based automations."
            calendarStatusIsError = false
        case .denied:
            calendarStatus = "Allow Calendar access to create or run calendar automations."
            calendarStatusIsError = true
        }
    }

    private func runNotificationEnableFlow(
        operation: @escaping () async -> NotificationPreferenceUpdateResult
    ) async {
        let previousPolicy = NSApplication.shared.activationPolicy()
        let needsPolicyChange = previousPolicy != .regular
        if needsPolicyChange {
            NSApplication.shared.setActivationPolicy(.regular)
        }

        if needsPolicyChange || !NSApplication.shared.isActive {
            await awaitAppActivation(timeout: .milliseconds(500))
        }

        let result = await operation()

        if needsPolicyChange {
            NSApplication.shared.setActivationPolicy(previousPolicy)
        }

        await applyNotificationPreferenceUpdate(result)
    }

    private func awaitAppActivation(timeout: Duration) async {
        if NSApplication.shared.isActive { return }

        // Register observer before calling activate() to close the race where
        // the notification fires between the activate call and the iterator
        // starting to listen.
        let stream = NotificationCenter.default.notifications(
            named: NSApplication.didBecomeActiveNotification,
            object: NSApplication.shared
        )
        var iterator = stream.makeAsyncIterator()
        NSApplication.shared.activate(ignoringOtherApps: true)
        if NSApplication.shared.isActive { return }

        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
        }
        let observerTask = Task {
            _ = await iterator.next()
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await timeoutTask.value
            }
            group.addTask {
                await observerTask.value
            }
            _ = await group.next()
            group.cancelAll()
        }
        timeoutTask.cancel()
        observerTask.cancel()

        if !NSApplication.shared.isActive {
            Self.logger.warning("App did not become active within notification-enable timeout; proceeding anyway.")
        }
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

    private func savePresetList(
        id: UUID?,
        name: String,
        minutes: Int,
        powerMode: PowerMode,
        isPinned: Bool
    ) async throws -> [CaffeinatePreset] {
        if let id {
            return try await service.updatePreset(
                id: id,
                name: name,
                minutes: minutes,
                powerMode: powerMode,
                isPinned: isPinned
            )
        }

        return try await service.createPreset(
            name: name,
            minutes: minutes,
            powerMode: powerMode,
            isPinned: isPinned
        )
    }

    private func ensureCalendarAccessIfNeeded(for automationRuleID: UUID? = nil, forcePrompt: Bool = false) async -> Bool {
        if let automationRuleID,
           let rule = automationRules.first(where: { $0.id == automationRuleID }),
           case .calendar = rule.trigger {
            return await ensureCalendarAccessIfNeeded(forcePrompt: forcePrompt)
        }

        if !forcePrompt, calendarAuthorizationState == .granted {
            return true
        }

        if !forcePrompt, calendarAuthorizationState == .denied {
            lastError = "Calendar access is required for calendar automations."
            return false
        }

        do {
            let state = try await automationService.requestCalendarAccess()
            await syncCalendarSettings()
            availableCalendars = await automationService.availableCalendars()

            if state == .granted {
                lastError = nil
                return true
            }

            lastError = "Calendar access is required for calendar automations."
            return false
        } catch {
            lastError = error.localizedDescription
            await syncCalendarSettings()
            return false
        }
    }

    private nonisolated static func glyphStylePreference(defaults: UserDefaults) -> GlyphStyle {
        if let raw = defaults.string(forKey: glyphStyleKey),
           let style = GlyphStyle(rawValue: raw) {
            return style
        }

        if let legacyShowTime = defaults.object(forKey: showMenuBarTimeKey) as? Bool, legacyShowTime {
            return .text
        }

        return .default
    }

    private nonisolated static func pulseThresholdPreference(defaults: UserDefaults) -> PulseThreshold {
        if let raw = defaults.string(forKey: pulseThresholdKey),
           let threshold = PulseThreshold(rawValue: raw) {
            return threshold
        }

        return .default
    }
}
