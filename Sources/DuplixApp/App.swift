import SwiftUI
import DuplixCore

@main
struct DuplixApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}
