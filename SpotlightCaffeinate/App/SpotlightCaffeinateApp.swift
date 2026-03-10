import AppIntents
import SwiftUI

@main
struct SpotlightCaffeinateApp: App {
    @State private var controller = CaffeinateController()

    init() {
        SpotlightCaffeinateShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(controller: controller)
        } label: {
            Label(controller.snapshot.menuBarTitle, systemImage: controller.snapshot.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}
