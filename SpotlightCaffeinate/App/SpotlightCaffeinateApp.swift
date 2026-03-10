import AppIntents
import SwiftUI

@main
struct SpotlightCaffeinateApp: App {
    @State private var controller = CaffeinateController()

    init() {
        SpotlightCaffeinateShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        let now = controller.currentTime

        return MenuBarExtra {
            StatusMenuView(controller: controller)
        } label: {
            Label(
                controller.snapshot.menuBarTitle(at: now),
                systemImage: controller.snapshot.menuBarSymbolName(at: now)
            )
            .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
