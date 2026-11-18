import AppKit
import SwiftUI

@MainActor
public final class DuplixAppDelegate: NSObject, NSApplicationDelegate {
    public static weak var shared: DuplixAppDelegate?

    public var openMainWindowAction: (() -> Void)?
    private let launchedInBackground = CommandLine.arguments.contains("--background")

    public func applicationWillFinishLaunching(_ notification: Notification) {
        Self.shared = self
        if launchedInBackground {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        let engine = VoiceMemoEngine.shared
        engine.onOpenMainWindowRequested = { [weak self] in
            self?.openMainWindow()
        }

        let voicofski = VoicofskiEngine.shared
        voicofski.onOpenMainWindowRequested = { [weak self] in
            self?.openMainWindow()
        }

        DuplixMenuBarController.shared.start()
        voicofski.start()

        if launchedInBackground {
            engine.start()
            // Close any initial SwiftUI window opened automatically at launch so startup stays silent in menu bar
            DispatchQueue.main.async {
                for window in NSApp.windows where Self.isMainAppWindow(window) {
                    window.orderOut(nil)
                    window.close()
                }
            }
        } else if engine.autoStartWithDuplix {
            engine.start()
        }
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        VoiceMemoEngine.shared.refreshPermissions()
        VoicofskiEngine.shared.refreshPermissions()
        VoicofskiEngine.shared.refreshKeysAndCooldowns()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep Duplix running in the background when Voice Memo or Voicofski is active in the menu bar
        return !(VoiceMemoEngine.shared.isEnabled || VoicofskiEngine.shared.isEnabled)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }

    public func openMainWindow() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        if let existing = NSApp.windows.first(where: { Self.isMainAppWindow($0) }) {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            existing.makeKeyAndOrderFront(nil)
        } else if let openAction = openMainWindowAction {
            openAction()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private static func isMainAppWindow(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel) else { return false }
        return window.level == .normal && window.styleMask.contains(.titled)
    }
}
