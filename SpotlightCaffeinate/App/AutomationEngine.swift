import Foundation

@MainActor
final class AutomationEngine {
    private let automationService: AutomationService
    private let powerSourceProvider: any AutomationPowerSourceProviding

    private var lastObservedMinute: Date?
    private var lastObservedPowerSource: AutomationPowerSource?

    init(
        automationService: AutomationService = .shared,
        powerSourceProvider: any AutomationPowerSourceProviding = SystemAutomationPowerSourceProvider()
    ) {
        self.automationService = automationService
        self.powerSourceProvider = powerSourceProvider
    }

    func processTick(now: Date) async {
        let powerSource = powerSourceProvider.currentSource()
        if let lastObservedPowerSource, lastObservedPowerSource != powerSource {
            await automationService.evaluatePowerRules(for: powerSource, at: now)
        }
        lastObservedPowerSource = powerSource

        let minute = floorToMinute(now)
        guard lastObservedMinute != minute else {
            return
        }

        lastObservedMinute = minute
        await automationService.evaluateScheduleRules(at: now)
        await automationService.evaluateCalendarRules(at: now)
    }

    private func floorToMinute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 60) * 60)
    }
}
