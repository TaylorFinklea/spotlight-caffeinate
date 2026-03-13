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

        return MenuBarExtra {
            StatusMenuView(controller: controller)
        } label: {
            HStack(spacing: 4) {
                MenuBarBoltIconView()

                Text(controller.snapshot.menuBarTitle(at: now))
                    .monospacedDigit()
            }
            .fixedSize()
            .foregroundStyle(.primary)
        }
        .menuBarExtraStyle(.window)
    }
}
