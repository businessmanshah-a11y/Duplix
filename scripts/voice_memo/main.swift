import Cocoa
import AVFoundation
import CoreGraphics

@main
class VoiceMemoApp: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = VoiceMemoApp()
        app.delegate = delegate
        app.run()
    }

    var statusItem: NSStatusItem!
    var pillPanel: FloatingPillPanel!
    var audioRecorder: AVAudioRecorder?
    var timer: Timer?
    var meterTimer: Timer?
    var secondsElapsed: Int = 0
    var isRecording: Bool = false
    let outputURL = URL(fileURLWithPath: "/tmp/antigravity_voice_memo.m4a")

    private var wasCmdOptPressed = false
    private var lastToggleTime = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupPillPanel()
        setupHotkeys()
        
        // Check / request mic permission early so macOS displays the permission prompt
        checkMicrophonePermission(promptIfNeeded: true) { granted in
            if granted {
                print("[VoiceMemo] Microphone access granted.")
            } else {
                print("[VoiceMemo] Microphone access not yet granted.")
            }
        }
        
        print("[VoiceMemo] Ready! Press Option+Command (⌥⌘) or click the menu bar mic to record.")
    }

    // MARK: - Menu Bar Status Item
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🎙️"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Toggle Recording (⌥⌘)", action: #selector(toggleRecording), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Open Microphone Settings...", action: #selector(openMicSettings), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleRecording()
        }
    }

    @objc func openMicSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Floating Pill Panel
    func setupPillPanel() {
        pillPanel = FloatingPillPanel()
        pillPanel.onStop = { [weak self] in
            self?.stopRecording(attach: true)
        }
        pillPanel.onCancel = { [weak self] in
            self?.stopRecording(attach: false)
        }
    }

    // MARK: - Global Hotkeys (Option + Command)
    func setupHotkeys() {
        // Global monitor for when other apps (Antigravity IDE) are active
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            if event.type == .flagsChanged {
                self?.handleFlagsChanged(event)
            } else if event.type == .keyDown {
                self?.handleKeyEvent(event)
            }
        }
        
        // Local monitor when pill is active
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            if event.type == .flagsChanged {
                self?.handleFlagsChanged(event)
                return event
            } else if event.type == .keyDown {
                if self?.handleKeyEvent(event) == true {
                    return nil
                }
            }
            return event
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Check if exactly Command and Option are pressed together (no Shift, Control, etc.)
        let isOnlyCmdOpt = (flags == [.command, .option])

        if isOnlyCmdOpt && !wasCmdOptPressed {
            wasCmdOptPressed = true
            DispatchQueue.main.async { [weak self] in
                self?.toggleRecording()
            }
        } else if !isOnlyCmdOpt {
            wasCmdOptPressed = false
        }
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmdOpt = flags.contains([.command, .option])
        
        // Fallback: V key (9) or Space (49) with Cmd+Opt
        if isCmdOpt && (event.keyCode == 9 || event.keyCode == 49) {
            DispatchQueue.main.async { [weak self] in
                self?.toggleRecording()
            }
            return true
        }
        
        // Escape cancels while recording
        if isRecording && event.keyCode == 53 {
            DispatchQueue.main.async { [weak self] in
                self?.stopRecording(attach: false)
            }
            return true
        }

        return false
    }

    @objc func toggleRecording() {
        let now = Date()
        guard now.timeIntervalSince(lastToggleTime) > 0.4 else { return }
        lastToggleTime = now

        if isRecording {
            stopRecording(attach: true)
        } else {
            startRecording()
        }
    }

    // MARK: - Permissions
    func checkMicrophonePermission(promptIfNeeded: Bool, completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            switch status {
            case .granted:
                completion(true)
            case .undetermined:
                if promptIfNeeded {
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                } else {
                    completion(false)
                }
            case .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        } else {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                completion(true)
            case .notDetermined:
                if promptIfNeeded {
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                } else {
                    completion(false)
                }
            case .denied, .restricted:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }

    func showMicrophoneDeniedAlert() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "⚠️ دسترسی به میکروفون غیرفعال است"
            alert.informativeText = "برای ضبط صدا در Antigravity، لطفاً در بخش تنظیمات سیستم دسترسی میکروفون را برای برنامه VoiceMemo فعال فرمایید:\n\nSystem Settings > Privacy & Security > Microphone"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "باز کردن تنظیمات میکروفون")
            alert.addButton(withTitle: "انصراف")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openMicSettings()
            }
        }
    }

    // MARK: - Recording Engine
    func startRecording() {
        guard !isRecording else { return }

        checkMicrophonePermission(promptIfNeeded: true) { [weak self] granted in
            guard let self = self else { return }
            if !granted {
                self.showMicrophoneDeniedAlert()
                return
            }

            self.performStartRecording()
        }
    }

    private func performStartRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 64000
        ]

        do {
            try? FileManager.default.removeItem(at: outputURL)
            audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
            guard let rec = audioRecorder else {
                print("[VoiceMemo] Error: recorder instantiation failed.")
                return
            }

            rec.isMeteringEnabled = true
            guard rec.prepareToRecord() else {
                print("[VoiceMemo] Error: prepareToRecord failed.")
                return
            }

            guard rec.record() else {
                print("[VoiceMemo] Error: Could not start recording.")
                return
            }

            isRecording = true
            secondsElapsed = 0
            
            // Update menu bar icon
            statusItem.button?.title = "🔴"
            
            // Show floating pill
            pillPanel.show()
            pillPanel.updateTimer("00:00")
            pillPanel.updateAudioLevel(0)
            
            // 1-second timer for elapsed duration
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.secondsElapsed += 1
                let m = self.secondsElapsed / 60
                let s = self.secondsElapsed % 60
                let timeStr = String(format: "%02d:%02d", m, s)
                self.pillPanel.updateTimer(timeStr)
            }

            // High-frequency meter timer (60ms) for responsive audio visualization
            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                guard let self = self, let rec = self.audioRecorder, rec.isRecording else { return }
                rec.updateMeters()
                let peak = rec.peakPower(forChannel: 0)
                // Map peak dB from [-50, 0] to [0.0, 1.0]
                let normalized = max(0.0, min(1.0, CGFloat((peak + 50.0) / 50.0)))
                self.pillPanel.updateAudioLevel(normalized)
            }
            
            print("[VoiceMemo] Recording started...")
        } catch {
            print("[VoiceMemo] Recording failed:", error)
        }
    }

    func stopRecording(attach: Bool) {
        guard isRecording else { return }
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        meterTimer?.invalidate()
        meterTimer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        statusItem.button?.title = "🎙️"
        pillPanel.hide()

        guard attach else {
            print("[VoiceMemo] Recording cancelled.")
            try? FileManager.default.removeItem(at: outputURL)
            return
        }

        // Check if file exists and has actual data
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
              let size = attrs[.size] as? UInt64, size > 1024 else {
            print("[VoiceMemo] Warning: Audio file is empty or corrupted.")
            return
        }

        print("[VoiceMemo] Recording saved to: \(outputURL.path) (\(size) bytes)")
        
        // Put file onto pasteboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([outputURL as NSURL])

        // Wait a short moment (0.2s) so physical keys can be released, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let src = CGEventSource(stateID: .hidSystemState)
            let vDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
            vUp?.flags = .maskCommand
            
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)
            
            print("[VoiceMemo] Voice memo attached to chat via Cmd+V!")
        }
    }
}

// MARK: - Audio Visualizer View (Dancing Waveform Bars)
class AudioMeterView: NSView {
    private var bars: [CALayer] = []
    private let barCount = 4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        bars.removeAll()

        let barWidth: CGFloat = 3.0
        let spacing: CGFloat = 2.5
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2.0

        for i in 0..<barCount {
            let bar = CALayer()
            let x = startX + CGFloat(i) * (barWidth + spacing)
            let minHeight: CGFloat = 3.0
            bar.frame = CGRect(x: x, y: (bounds.height - minHeight) / 2.0, width: barWidth, height: minHeight)
            bar.cornerRadius = 1.5
            bar.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.25, alpha: 0.85).cgColor
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    func setLevel(_ level: CGFloat) {
        // level is 0.0 ... 1.0
        let maxHeight = bounds.height - 4.0
        let minHeight: CGFloat = 3.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.06)
        
        for (i, bar) in bars.enumerated() {
            // Add subtle variation per bar for a dynamic waveform look
            let factor: CGFloat = (i % 2 == 0) ? 1.0 : 0.75
            let targetHeight = max(minHeight, minHeight + (maxHeight - minHeight) * level * factor)
            let y = (bounds.height - targetHeight) / 2.0
            bar.frame = CGRect(x: bar.frame.origin.x, y: y, width: bar.frame.width, height: targetHeight)
            
            // Brighten color when sound is loud
            if level > 0.15 {
                bar.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.2, alpha: 1.0).cgColor
            } else {
                bar.backgroundColor = NSColor(calibratedRed: 0.6, green: 0.6, blue: 0.6, alpha: 0.4).cgColor
            }
        }
        CATransaction.commit()
    }
}

// MARK: - Floating Pill Panel UI
class FloatingPillPanel: NSPanel {
    var timerLabel: NSTextField!
    var pulseDot: NSView!
    var meterView: AudioMeterView!
    var onStop: (() -> Void)?
    var onCancel: (() -> Void)?

    init() {
        let width: CGFloat = 236
        let height: CGFloat = 44
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = screenRect.midX - (width / 2)
        let y = screenRect.minY + 80 // Float near bottom above dock

        let rect = NSRect(x: x, y: y, width: width, height: height)
        super.init(contentRect: rect,
                   styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered,
                   defer: false)

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true

        setupUI(width: width, height: height)
    }

    func setupUI(width: CGFloat, height: CGFloat) {
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = height / 2
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        visualEffect.layer?.borderWidth = 1.0

        // Red pulsing dot
        pulseDot = NSView(frame: NSRect(x: 14, y: (height - 10) / 2, width: 10, height: 10))
        pulseDot.wantsLayer = true
        pulseDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        pulseDot.layer?.cornerRadius = 5
        visualEffect.addSubview(pulseDot)

        // Pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.duration = 0.8
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.3
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseDot.layer?.add(pulseAnimation, forKey: "pulse")

        // Timer Label
        timerLabel = NSTextField(frame: NSRect(x: 30, y: (height - 20) / 2 - 1, width: 50, height: 20))
        timerLabel.isEditable = false
        timerLabel.isSelectable = false
        timerLabel.isBezeled = false
        timerLabel.drawsBackground = false
        timerLabel.textColor = .white
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        timerLabel.stringValue = "00:00"
        visualEffect.addSubview(timerLabel)

        // Audio Meter Waveform View
        meterView = AudioMeterView(frame: NSRect(x: 84, y: (height - 22) / 2, width: 34, height: 22))
        visualEffect.addSubview(meterView)

        // Stop Button (Save & Attach)
        let stopButton = NSButton(frame: NSRect(x: 130, y: (height - 28) / 2, width: 56, height: 28))
        stopButton.bezelStyle = .rounded
        stopButton.isBordered = false
        stopButton.wantsLayer = true
        stopButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        stopButton.layer?.cornerRadius = 14
        stopButton.title = "ثبت ■"
        stopButton.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        stopButton.contentTintColor = .white
        stopButton.target = self
        stopButton.action = #selector(stopClicked)
        stopButton.toolTip = "Stop & Attach to Chat (⌥⌘)"
        visualEffect.addSubview(stopButton)

        // Cancel Button (Esc)
        let cancelButton = NSButton(frame: NSRect(x: 194, y: (height - 28) / 2, width: 28, height: 28))
        cancelButton.bezelStyle = .circular
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        cancelButton.layer?.cornerRadius = 14
        cancelButton.title = "✕"
        cancelButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        cancelButton.contentTintColor = .lightGray
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.toolTip = "Cancel (Esc)"
        visualEffect.addSubview(cancelButton)

        self.contentView = visualEffect
    }

    func updateTimer(_ text: String) {
        timerLabel.stringValue = text
    }

    func updateAudioLevel(_ level: CGFloat) {
        meterView.setLevel(level)
    }

    func show() {
        self.alphaValue = 0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    @objc func stopClicked() {
        onStop?()
    }

    @objc func cancelClicked() {
        onCancel?()
    }
}
