import SwiftUI

@main
struct AppSchedulerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — lives entirely in the menu bar
        Settings { EmptyView() }
    }
}
