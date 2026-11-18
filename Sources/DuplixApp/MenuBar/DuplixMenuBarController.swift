import AppKit
import Combine
import DuplixCore

@MainActor
public final class DuplixMenuBarController: NSObject {
    public static let shared = DuplixMenuBarController()

    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    private override init() {
        super.init()
    }

    public func start() {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.target = self
                button.action = #selector(statusItemClicked)
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            statusItem = item
            bindObservers()
        }
        updateStatusButton()
    }

    public func stop() {
        cancellables.removeAll()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func bindObservers() {
        cancellables.removeAll()

        let vm = VoiceMemoEngine.shared
        let vf = VoicofskiEngine.shared

        vm.$isRecording
            .combineLatest(vm.$elapsedSeconds, vf.$isBusy, vf.$isEnabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)
    }

    public func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        let vm = VoiceMemoEngine.shared
        let vf = VoicofskiEngine.shared

        if vm.isRecording {
            let mins = vm.elapsedSeconds / 60
            let secs = vm.elapsedSeconds % 60
            button.image = nil
            button.title = String(format: "🔴 %02d:%02d", mins, secs)
            button.toolTip = "Recording Voice Memo — Click or press ⌥⌘ to stop & attach"
        } else if vf.isBusy {
            button.title = ""
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Duplix Generating Voice")
            button.toolTip = "Duplix Voicofski — Generating voice..."
        } else {
            button.title = ""
            let img = NSImage(systemSymbolName: "square.2.layers.3d", accessibilityDescription: "Duplix")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "Duplix — Voice Memo (⌥⌘) & Voicofski"
        }
    }

    @objc private func statusItemClicked() {
        let vm = VoiceMemoEngine.shared
        let event = NSApp.currentEvent

        // If Voice Memo is actively recording, left-click immediately stops & attaches
        if vm.isRecording && event?.type != .rightMouseUp {
            vm.stopRecording(attach: true)
            return
        }

        showUnifiedMenu()
    }

    private func showUnifiedMenu() {
        guard let item = statusItem else { return }
        let vm = VoiceMemoEngine.shared
        let vf = VoicofskiEngine.shared
        let menu = NSMenu()

        // MARK: Voice Memo Section
        let vmHeader = NSMenuItem(title: "Voice Memo", action: nil, keyEquivalent: "")
        vmHeader.isEnabled = false
        menu.addItem(vmHeader)

        let recordTitle = vm.isRecording ? "Stop & Attach Recording (⌥⌘)" : "Start Recording (⌥⌘)"
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(menuToggleRecording), keyEquivalent: "")
        recordItem.target = self
        menu.addItem(recordItem)

        if vm.isRecording {
            let cancelItem = NSMenuItem(title: "Cancel Recording (Esc)", action: #selector(menuCancelRecording), keyEquivalent: "")
            cancelItem.target = self
            menu.addItem(cancelItem)
        }

        if vm.lastRecording != nil {
            let recopyItem = NSMenuItem(title: "Copy Last Voice Memo", action: #selector(menuRecopyLast), keyEquivalent: "")
            recopyItem.target = self
            menu.addItem(recopyItem)
        }

        menu.addItem(NSMenuItem.separator())

        // MARK: Voicofski Section
        let vfHeader = NSMenuItem(title: "Voicofski (AI Voice & Translate)", action: nil, keyEquivalent: "")
        vfHeader.isEnabled = false
        menu.addItem(vfHeader)

        let triggerToggle = NSMenuItem(
            title: vf.isEnabled ? "Selection Trigger: On" : "Selection Trigger: Off",
            action: #selector(menuToggleVoicofskiTrigger),
            keyEquivalent: ""
        )
        triggerToggle.target = self
        triggerToggle.state = vf.isEnabled ? .on : .off
        menu.addItem(triggerToggle)

        let voiceToggle = NSMenuItem(
            title: "Voice: \(vf.selectedVoice.displayName) (Switch)",
            action: #selector(menuSwitchVoicofskiVoice),
            keyEquivalent: ""
        )
        voiceToggle.target = self
        menu.addItem(voiceToggle)

        let keysInfo = NSMenuItem(
            title: "API Keys: \(vf.activeKeyCount)/\(vf.keys.count) active",
            action: #selector(menuOpenVoicofski),
            keyEquivalent: ""
        )
        keysInfo.target = self
        menu.addItem(keysInfo)

        if !vf.pendingQueue.isEmpty {
            let queueInfo = NSMenuItem(
                title: "Pending Queue: \(vf.pendingQueue.count) waiting",
                action: #selector(menuOpenVoicofski),
                keyEquivalent: ""
            )
            queueInfo.target = self
            menu.addItem(queueInfo)
        }

        menu.addItem(NSMenuItem.separator())

        // MARK: Duplix System Actions
        let openItem = NSMenuItem(title: "Open Duplix Window", action: #selector(menuOpenMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let micItem = NSMenuItem(title: "Microphone Settings...", action: #selector(menuOpenMicSettings), keyEquivalent: "")
        micItem.target = self
        menu.addItem(micItem)

        let axItem = NSMenuItem(title: "Accessibility Settings...", action: #selector(menuOpenAxSettings), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Duplix", action: #selector(menuQuitDuplix), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func menuToggleRecording() { VoiceMemoEngine.shared.toggleRecording() }
    @objc private func menuCancelRecording() { VoiceMemoEngine.shared.stopRecording(attach: false) }
    @objc private func menuRecopyLast() { VoiceMemoEngine.shared.recopyLastRecording() }

    @objc private func menuToggleVoicofskiTrigger() {
        VoicofskiEngine.shared.isEnabled.toggle()
    }

    @objc private func menuSwitchVoicofskiVoice() {
        let vf = VoicofskiEngine.shared
        vf.selectedVoice = (vf.selectedVoice == .female) ? .male : .female
    }

    @objc private func menuOpenVoicofski() {
        VoicofskiEngine.shared.focusVoicofskiInApp()
    }

    @objc private func menuOpenMainWindow() {
        DuplixAppDelegate.shared?.openMainWindow()
    }

    @objc private func menuOpenMicSettings() { VoiceMemoEngine.shared.openMicrophoneSettings() }
    @objc private func menuOpenAxSettings() { VoiceMemoEngine.shared.openAccessibilitySettings() }
    @objc private func menuQuitDuplix() { NSApp.terminate(nil) }
}
