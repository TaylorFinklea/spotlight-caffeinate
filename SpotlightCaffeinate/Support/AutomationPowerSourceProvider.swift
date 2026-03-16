import Foundation
import IOKit.ps

protocol AutomationPowerSourceProviding: Sendable {
    func currentSource() -> AutomationPowerSource
}

struct SystemAutomationPowerSourceProvider: AutomationPowerSourceProviding {
    func currentSource() -> AutomationPowerSource {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as? String
        else {
            return .disconnected
        }

        return type == kIOPMACPowerKey ? .connected : .disconnected
    }
}
