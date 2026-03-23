import AppIntents
import SwiftUI

@main
struct SpotlightCaffeinateApp: App {
    @NSApplicationDelegateAdaptor(NotificationCenterDelegate.self) private var notificationCenterDelegate
    @State private var controller = CaffeinateController()

    init() {
        SpotlightCaffeinateShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        let now = controller.currentTime
        let remainingFraction = CGFloat(controller.snapshot.remainingFraction(at: now))

        MenuBarExtra {
            StatusMenuView(controller: controller)
        } label: {
            HStack(spacing: controller.showMenuBarTime ? 4 : 0) {
                MenuBarBoltIconView(fillFraction: remainingFraction)

                if controller.showMenuBarTime {
                    Text(controller.snapshot.menuBarTitle(at: now))
                        .monospacedDigit()
                }
            }
            .fixedSize()
            .foregroundStyle(.primary)
        }
        .menuBarExtraStyle(.window)

        Window("Preset Manager", id: "preset-manager") {
            PresetManagerView(controller: controller)
        }
        .defaultSize(width: 720, height: 430)

        Window("Automation Manager", id: "automation-manager") {
            AutomationManagerView(controller: controller)
        }
        .defaultSize(width: 860, height: 560)

        Window("Settings", id: "settings") {
            SettingsView(controller: controller)
        }
        .defaultSize(width: 420, height: 320)
    }
}
