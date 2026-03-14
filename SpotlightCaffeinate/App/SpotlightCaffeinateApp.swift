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

        return MenuBarExtra {
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
    }
}
