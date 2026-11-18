import AppKit
import AVFoundation
import CoreGraphics
import ApplicationServices
import DuplixCore

public enum MicrophonePermissionState: String, Equatable {
    case granted
    case denied
    case undetermined
}

public struct LastRecordingInfo: Equatable {
    public let url: URL
    public let durationSeconds: Int
    public let fileSizeBytes: UInt64
    public let recordedAt: Date

    public var formattedDuration: String {
        String(format: "%02d:%02d", durationSeconds / 60, durationSeconds % 60)
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
    }
}

@MainActor
public final class VoiceMemoEngine: NSObject, ObservableObject {
    public static let shared = VoiceMemoEngine()

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var microphoneStatus: MicrophonePermissionState = .undetermined
    @Published public private(set) var hasAccessibilityPermission: Bool = false
    @Published public var launchAtLogin: Bool = false
    @Published public var autoStartWithDuplix: Bool = true {
        didSet {
            UserDefaults.standard.set(autoStartWithDuplix, forKey: Keys.autoStartWithDuplix)
        }
    }
    @Published public private(set) var lastRecording: LastRecordingInfo? = nil
    @Published public private(set) var statusMessage: String? = nil
    @Published public private(set) var errorMessage: String? = nil

    public var onOpenMainWindowRequested: (() -> Void)?

    private enum Keys {
        static let autoStartWithDuplix = "duplix.voicememo.autoStartWithDuplix"
    }

    private var statusItem: NSStatusItem?
    private var pillPanel: FloatingPillPanel?
    private var audioRecorder: AVAudioRecorder?
    private var currentOutputURL: URL?
    private var durationTimer: Timer?
    private var meterTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var permissionMonitorTask: Task<Void, Never>?

    private var wasCmdOptPressed = false
    private var lastToggleTime = Date.distantPast

    private var launchAgentURL: URL {
        DuplixPaths.realHomeDirectoryURL
            .appendingPathComponent("Library/LaunchAgents/com.duplix.app.plist")
    }

    private override init() {
        super.init()
        if UserDefaults.standard.object(forKey: Keys.autoStartWithDuplix) == nil {
            self.autoStartWithDuplix = true
        } else {
            self.autoStartWithDuplix = UserDefaults.standard.bool(forKey: Keys.autoStartWithDuplix)
        }
        self.launchAtLogin = FileManager.default.fileExists(atPath: launchAgentURL.path)
        refreshPermissions()
    }

    // MARK: - Lifecycle

    public func start() {
        guard !isEnabled else {
            refreshPermissions()
            return
        }

        terminateLegacyStandaloneVoiceMemo()
        setupStatusItem()
        setupPillPanel()
        setupHotkeys()
        isEnabled = true
        errorMessage = nil
        statusMessage = "Voice Memo is active in the menu bar (🎙️)."
        refreshPermissions()
    }

    public func stop() {
        if isRecording {
            stopRecording(attach: false)
        }
        teardownHotkeys()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        pillPanel?.orderOut(nil)
        pillPanel = nil
        isEnabled = false
        statusMessage = nil
    }

    public func toggleEnabled() {
        if isEnabled {
            stop()
        } else {
            start()
        }
    }

    public func startPermissionMonitoring() {
        permissionMonitorTask?.cancel()
        permissionMonitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshPermissions()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    public func stopPermissionMonitoring() {
        permissionMonitorTask?.cancel()
        permissionMonitorTask = nil
    }

    /// Terminates any old standalone `com.duplix.voicememo` helper so there are no duplicate menu bar icons or conflicting hotkeys.
    private func terminateLegacyStandaloneVoiceMemo() {
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == "com.duplix.voicememo" ||
               app.localizedName == "VoiceMemoApp" ||
               app.localizedName == "VoiceMemo" {
                app.terminate()
            }
        }
    }

    // MARK: - Launch at Login (Background LaunchAgent)

    public func setLaunchAtLogin(_ enabled: Bool) {
        let fm = FileManager.default
        let agentsDir = launchAgentURL.deletingLastPathComponent()

        if enabled {
            do {
                try fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)

                let executablePath = resolvedAppExecutablePath()
                let plist: [String: Any] = [
                    "Label": "com.duplix.app.autostart",
                    "ProgramArguments": [executablePath, "--background"],
                    "RunAtLoad": true,
                    "LimitLoadToSessionType": "Aqua",
                    "AssociatedBundleIdentifiers": ["com.duplix.app"]
                ]
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: launchAgentURL, options: .atomic)
                self.launchAtLogin = true
                self.errorMessage = nil
                self.statusMessage = "Duplix Voice Memo will start automatically in the menu bar after login."
            } catch {
                self.launchAtLogin = false
                self.errorMessage = "Could not enable Launch at Login: \(error.localizedDescription)"
            }
        } else {
            do {
                if fm.fileExists(atPath: launchAgentURL.path) {
                    try fm.removeItem(at: launchAgentURL)
                }
                self.launchAtLogin = false
                self.errorMessage = nil
                self.statusMessage = "Launch at Login disabled."
            } catch {
                self.errorMessage = "Could not disable Launch at Login: \(error.localizedDescription)"
            }
        }
    }

    private func resolvedAppExecutablePath() -> String {
        let installedAppBinary = "/Applications/Duplix.app/Contents/MacOS/DuplixApp"
        if FileManager.default.isExecutableFile(atPath: installedAppBinary) {
            return installedAppBinary
        }
        if let bundleExec = Bundle.main.executablePath, FileManager.default.isExecutableFile(atPath: bundleExec) {
            return bundleExec
        }
        return installedAppBinary
    }

    // MARK: - Permissions

    public func refreshPermissions() {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                microphoneStatus = .granted
            case .denied:
                microphoneStatus = .denied
            case .undetermined:
                microphoneStatus = .undetermined
            @unknown default:
                microphoneStatus = .undetermined
            }
        } else {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                microphoneStatus = .granted
            case .denied, .restricted:
                microphoneStatus = .denied
            case .notDetermined:
                microphoneStatus = .undetermined
            @unknown default:
                microphoneStatus = .undetermined
            }
        }

        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    public func requestMicrophonePermission(completion: (@MainActor (Bool) -> Void)? = nil) {
        refreshPermissions()
        switch microphoneStatus {
        case .granted:
            completion?(true)
        case .denied:
            openMicrophoneSettings()
            completion?(false)
        case .undetermined:
            if #available(macOS 14.0, *) {
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    Task { @MainActor in
                        self?.refreshPermissions()
                        completion?(granted)
                    }
                }
            } else {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    Task { @MainActor in
                        self?.refreshPermissions()
                        completion?(granted)
                    }
                }
            }
        }
    }

    public func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissions()
        if !hasAccessibilityPermission {
            openAccessibilitySettings()
        }
    }

    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Menu Bar Status Item

    private func setupStatusItem() {
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "🎙️"
            button.toolTip = "Duplix Voice Memo — Click or press ⌥⌘ to record (Right-click for menu)"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggleRecording()
        }
    }

    private func showStatusMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()

        let recordTitle = isRecording ? "Stop & Attach Recording (⌥⌘)" : "Start Recording (⌥⌘)"
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(menuToggleRecording), keyEquivalent: "")
        recordItem.target = self
        menu.addItem(recordItem)

        if isRecording {
            let cancelItem = NSMenuItem(title: "Cancel Recording (Esc)", action: #selector(menuCancelRecording), keyEquivalent: "")
            cancelItem.target = self
            menu.addItem(cancelItem)
        }

        if lastRecording != nil {
            let recopyItem = NSMenuItem(title: "Copy Last Voice Memo", action: #selector(menuRecopyLast), keyEquivalent: "")
            recopyItem.target = self
            menu.addItem(recopyItem)
        }

        menu.addItem(NSMenuItem.separator())

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

        let stopItem = NSMenuItem(title: "Disable Menu Bar Icon", action: #selector(menuDisableVoiceMemo), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)

        let quitItem = NSMenuItem(title: "Quit Duplix", action: #selector(menuQuitDuplix), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func menuToggleRecording() { toggleRecording() }
    @objc private func menuCancelRecording() { stopRecording(attach: false) }
    @objc private func menuRecopyLast() { recopyLastRecording() }
    @objc private func menuOpenMainWindow() { onOpenMainWindowRequested?() }
    @objc private func menuOpenMicSettings() { openMicrophoneSettings() }
    @objc private func menuOpenAxSettings() { openAccessibilitySettings() }
    @objc private func menuDisableVoiceMemo() { stop() }
    @objc private func menuQuitDuplix() { NSApp.terminate(nil) }

    // MARK: - Floating Pill Panel

    private func setupPillPanel() {
        if pillPanel != nil { return }
        let panel = FloatingPillPanel()
        panel.onStop = { [weak self] in
            self?.stopRecording(attach: true)
        }
        panel.onCancel = { [weak self] in
            self?.stopRecording(attach: false)
        }
        pillPanel = panel
    }

    // MARK: - Global & Local Hotkeys (Option + Command)

    private func setupHotkeys() {
        teardownHotkeys()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            let type = event.type
            let modifiers = event.modifierFlags
            let keyCode = event.keyCode
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == .flagsChanged {
                    self.handleFlagsChanged(modifiers)
                } else if type == .keyDown {
                    self.handleKeyEvent(modifiers: modifiers, keyCode: keyCode)
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            let type = event.type
            let modifiers = event.modifierFlags
            let keyCode = event.keyCode
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self else { return false }
                if type == .flagsChanged {
                    self.handleFlagsChanged(modifiers)
                    return false
                } else if type == .keyDown {
                    return self.handleKeyEvent(modifiers: modifiers, keyCode: keyCode)
                }
                return false
            }
            return handled ? nil : event
        }
    }

    private func teardownHotkeys() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        wasCmdOptPressed = false
    }

    private func handleFlagsChanged(_ modifierFlags: NSEvent.ModifierFlags) {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isOnlyCmdOpt = (flags == [.command, .option])

        if isOnlyCmdOpt && !wasCmdOptPressed {
            wasCmdOptPressed = true
            toggleRecording()
        } else if !isOnlyCmdOpt {
            wasCmdOptPressed = false
        }
    }

    @discardableResult
    private func handleKeyEvent(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
        let isCmdOpt = flags.contains([.command, .option])

        // Fallback: Cmd+Opt+V (9) or Cmd+Opt+Space (49)
        if isCmdOpt && (keyCode == 9 || keyCode == 49) {
            toggleRecording()
            return true
        }

        // Escape (53) cancels while recording
        if isRecording && keyCode == 53 {
            stopRecording(attach: false)
            return true
        }

        return false
    }

    // MARK: - Recording Engine

    public func toggleRecording() {
        let now = Date()
        guard now.timeIntervalSince(lastToggleTime) > 0.4 else { return }
        lastToggleTime = now

        if !isEnabled {
            start()
        }

        if isRecording {
            stopRecording(attach: true)
        } else {
            startRecording()
        }
    }

    public func startRecording() {
        guard !isRecording else { return }
        errorMessage = nil

        requestMicrophonePermission { [weak self] granted in
            guard let self else { return }
            if !granted {
                self.errorMessage = "Microphone access is denied. Enable Duplix in System Settings → Privacy & Security → Microphone."
                self.showMicrophoneDeniedAlert()
                return
            }
            self.performStartRecording()
        }
    }

    private func showMicrophoneDeniedAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "To record voice memos, enable Microphone access for Duplix in:\nSystem Settings → Privacy & Security → Microphone"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Microphone Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            openMicrophoneSettings()
        }
    }

    private func cleanupOldTempRecordings() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Date().addingTimeInterval(-3600)
        for file in files where file.lastPathComponent.hasPrefix("duplix_voice_memo_") && file.pathExtension == "m4a" {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func makeOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("duplix_voice_memo_\(stamp).m4a")
    }

    private func performStartRecording() {
        cleanupOldTempRecordings()

        let outputURL = makeOutputURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 64000
        ]

        do {
            try? FileManager.default.removeItem(at: outputURL)
            let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
            recorder.isMeteringEnabled = true

            guard recorder.prepareToRecord(), recorder.record() else {
                errorMessage = "Could not start audio recording. Check your active input device."
                return
            }

            audioRecorder = recorder
            currentOutputURL = outputURL
            isRecording = true
            elapsedSeconds = 0
            errorMessage = nil
            statusMessage = "Recording voice memo..."

            if pillPanel == nil {
                setupPillPanel()
            }

            statusItem?.button?.title = "🔴 00:00"
            pillPanel?.show()
            pillPanel?.updateTimer("00:00")
            pillPanel?.updateAudioLevel(0)

            durationTimer?.invalidate()
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isRecording else { return }
                    self.elapsedSeconds += 1
                    let timeStr = String(format: "%02d:%02d", self.elapsedSeconds / 60, self.elapsedSeconds % 60)
                    self.pillPanel?.updateTimer(timeStr)
                    self.statusItem?.button?.title = "🔴 \(timeStr)"
                }
            }

            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let rec = self.audioRecorder, rec.isRecording else { return }
                    rec.updateMeters()
                    let peak = rec.peakPower(forChannel: 0)
                    let normalized = max(0.0, min(1.0, CGFloat((peak + 50.0) / 50.0)))
                    self.pillPanel?.updateAudioLevel(normalized)
                }
            }
        } catch {
            errorMessage = "Recording failed: \(error.localizedDescription)"
        }
    }

    public func stopRecording(attach: Bool) {
        guard isRecording else { return }

        let recordedDuration = max(1, elapsedSeconds)
        isRecording = false

        durationTimer?.invalidate()
        durationTimer = nil
        meterTimer?.invalidate()
        meterTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        statusItem?.button?.title = "🎙️"
        pillPanel?.hide()

        guard let outputURL = currentOutputURL else { return }
        currentOutputURL = nil

        guard attach else {
            try? FileManager.default.removeItem(at: outputURL)
            statusMessage = "Recording cancelled."
            return
        }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
              let size = attrs[.size] as? UInt64,
              size > 1024 else {
            errorMessage = "Recording was too short or empty."
            return
        }

        let info = LastRecordingInfo(
            url: outputURL,
            durationSeconds: recordedDuration,
            fileSizeBytes: size,
            recordedAt: Date()
        )
        lastRecording = info

        copyToPasteboard(url: outputURL)
        refreshPermissions()

        if hasAccessibilityPermission {
            statusMessage = "Attached voice memo (\(info.formattedDuration), \(info.formattedSize)) via ⌘V."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Self.simulateCommandV()
            }
        } else {
            statusMessage = "Copied voice memo (\(info.formattedSize)) to clipboard — press ⌘V to paste (grant Accessibility for auto-paste)."
        }
    }

    public func recopyLastRecording() {
        guard let info = lastRecording, FileManager.default.fileExists(atPath: info.url.path) else {
            errorMessage = "Last recording file is no longer available."
            return
        }
        copyToPasteboard(url: info.url)
        statusMessage = "Copied last voice memo (\(info.formattedSize)) to clipboard."
    }

    private func copyToPasteboard(url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([url as NSURL])
    }

    private nonisolated static func simulateCommandV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
