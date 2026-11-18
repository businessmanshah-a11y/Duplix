import SwiftUI
import DuplixCore

@main
struct DuplixApp: App {
    @NSApplicationDelegateAdaptor(DuplixAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .onAppear {
                    appDelegate.openMainWindowAction = {
                        openWindow(id: "main")
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}
