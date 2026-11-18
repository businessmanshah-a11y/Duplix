import AppKit
import QuartzCore

// MARK: - Audio Visualizer View (Dancing Waveform Bars)

@MainActor
final class AudioMeterView: NSView {
    private var bars: [CALayer] = []
    private let barCount = 5

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
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
            bar.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.36, blue: 0.28, alpha: 0.9).cgColor
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    func setLevel(_ level: CGFloat) {
        let maxHeight = bounds.height - 4.0
        let minHeight: CGFloat = 3.0
        let weights: [CGFloat] = [0.65, 0.9, 1.0, 0.85, 0.6]

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.06)

        for (i, bar) in bars.enumerated() {
            let factor = weights[i % weights.count]
            let targetHeight = max(minHeight, minHeight + (maxHeight - minHeight) * level * factor)
            let y = (bounds.height - targetHeight) / 2.0
            bar.frame = CGRect(x: bar.frame.origin.x, y: y, width: bar.frame.width, height: targetHeight)

            if level > 0.15 {
                bar.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.32, blue: 0.25, alpha: 1.0).cgColor
            } else {
                bar.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.35).cgColor
            }
        }
        CATransaction.commit()
    }
}

// MARK: - Floating Pill Panel UI

@MainActor
final class FloatingPillPanel: NSPanel {
    private var timerLabel: NSTextField!
    private var pulseDot: NSView!
    private var meterView: AudioMeterView!

    var onStop: (() -> Void)?
    var onCancel: (() -> Void)?

    private static let pillWidth: CGFloat = 212
    private static let pillHeight: CGFloat = 44

    init() {
        let rect = Self.centeredBottomRect()
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.appearance = NSAppearance(named: .darkAqua)

        setupUI(width: Self.pillWidth, height: Self.pillHeight)
    }

    private static func centeredBottomRect() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
        let screenRect = activeScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = screenRect.midX - (pillWidth / 2)
        let y = screenRect.minY + 80
        return NSRect(x: x, y: y, width: pillWidth, height: pillHeight)
    }

    private func setupUI(width: CGFloat, height: CGFloat) {
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.appearance = NSAppearance(named: .darkAqua)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.72).cgColor
        visualEffect.layer?.cornerRadius = height / 2
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        visualEffect.layer?.borderWidth = 1.0

        // Red pulsing recording indicator dot
        pulseDot = NSView(frame: NSRect(x: 15, y: (height - 9) / 2, width: 9, height: 9))
        pulseDot.wantsLayer = true
        pulseDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        pulseDot.layer?.cornerRadius = 4.5
        visualEffect.addSubview(pulseDot)

        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.duration = 0.8
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.3
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseDot.layer?.add(pulseAnimation, forKey: "pulse")

        // Timer Label (high-contrast white monospaced digits)
        timerLabel = NSTextField(frame: NSRect(x: 31, y: (height - 19) / 2 - 1, width: 48, height: 19))
        timerLabel.isEditable = false
        timerLabel.isSelectable = false
        timerLabel.isBezeled = false
        timerLabel.drawsBackground = false
        timerLabel.textColor = .white
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timerLabel.stringValue = "00:00"
        visualEffect.addSubview(timerLabel)

        // Audio Meter Waveform View
        meterView = AudioMeterView(frame: NSRect(x: 84, y: (height - 22) / 2, width: 42, height: 22))
        visualEffect.addSubview(meterView)

        // Stop & Attach Button (Universal Icon-Only, no language text)
        let stopButton = NSButton(frame: NSRect(x: 136, y: (height - 30) / 2, width: 30, height: 30))
        stopButton.isBordered = false
        stopButton.wantsLayer = true
        stopButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        stopButton.layer?.cornerRadius = 15
        stopButton.title = ""
        stopButton.imagePosition = .imageOnly
        if let stopImg = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop and Attach") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            stopButton.image = stopImg.withSymbolConfiguration(config)
        }
        stopButton.contentTintColor = .white
        stopButton.target = self
        stopButton.action = #selector(stopClicked)
        stopButton.toolTip = "Stop & Attach (⌥⌘)"
        visualEffect.addSubview(stopButton)

        // Cancel Button (Universal Icon-Only)
        let cancelButton = NSButton(frame: NSRect(x: 174, y: (height - 28) / 2, width: 28, height: 28))
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        cancelButton.layer?.cornerRadius = 14
        cancelButton.title = ""
        cancelButton.imagePosition = .imageOnly
        if let cancelImg = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Cancel") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            cancelButton.image = cancelImg.withSymbolConfiguration(config)
        }
        cancelButton.contentTintColor = NSColor.white.withAlphaComponent(0.85)
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
        setFrame(Self.centeredBottomRect(), display: true)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.orderOut(nil)
            }
        })
    }

    @objc private func stopClicked() {
        onStop?()
    }

    @objc private func cancelClicked() {
        onCancel?()
    }
}
