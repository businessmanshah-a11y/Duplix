import AppKit
import QuartzCore

// MARK: - Live Dancing Audio Visualizer for Notch HUD

@MainActor
final class NotchWaveformView: NSView {
    private var bars: [CALayer] = []
    private let barCount = 7

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

        let barWidth: CGFloat = 2.5
        let spacing: CGFloat = 2.5
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2.0

        for i in 0..<barCount {
            let bar = CALayer()
            let x = startX + CGFloat(i) * (barWidth + spacing)
            let minH: CGFloat = 3.0
            bar.frame = CGRect(x: x, y: (bounds.height - minH) / 2.0, width: barWidth, height: minH)
            bar.cornerRadius = 1.25
            bar.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.35).cgColor
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    func setLevel(_ level: CGFloat, isPlaying: Bool) {
        let maxHeight = max(6.0, bounds.height - 4.0)
        let minHeight: CGFloat = 3.0
        let weights: [CGFloat] = [0.45, 0.78, 1.0, 0.88, 0.96, 0.7, 0.42]
        let jitter = isPlaying ? CGFloat.random(in: 0.82...1.12) : 1.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.06)

        for (i, bar) in bars.enumerated() {
            let factor = weights[i % weights.count]
            let effective = isPlaying ? max(0.12, min(1.0, level * factor * jitter)) : 0.0
            let targetHeight = max(minHeight, minHeight + (maxHeight - minHeight) * effective)
            let y = (bounds.height - targetHeight) / 2.0
            bar.frame = CGRect(x: bar.frame.origin.x, y: y, width: bar.frame.width, height: targetHeight)

            if isPlaying && effective > 0.14 {
                bar.backgroundColor = NSColor(calibratedRed: 0.38, green: 0.78, blue: 1.0, alpha: 0.98).cgColor
            } else {
                bar.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.32).cgColor
            }
        }
        CATransaction.commit()
    }
}

// MARK: - Animated Loading Wave Orb

@MainActor
final class LoadingWaveOrbView: NSView {
    private var pulseRing: CALayer!
    private var coreOrb: CALayer!
    private var iconView: NSImageView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupLayers()
    }

    private func setupLayers() {
        let ring = CALayer()
        ring.frame = bounds.insetBy(dx: 2, dy: 2)
        ring.cornerRadius = ring.bounds.width / 2
        ring.borderWidth = 1.5
        ring.borderColor = NSColor(calibratedRed: 0.38, green: 0.72, blue: 1.0, alpha: 0.7).cgColor
        layer?.addSublayer(ring)
        self.pulseRing = ring

        let orb = CAGradientLayer()
        orb.frame = bounds.insetBy(dx: 5, dy: 5)
        orb.cornerRadius = orb.bounds.width / 2
        orb.colors = [
            NSColor(calibratedRed: 0.38, green: 0.56, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.68, green: 0.36, blue: 0.98, alpha: 1.0).cgColor
        ]
        orb.startPoint = CGPoint(x: 0, y: 0)
        orb.endPoint = CGPoint(x: 1, y: 1)
        layer?.addSublayer(orb)
        self.coreOrb = orb

        let imgView = NSImageView(frame: bounds.insetBy(dx: 8, dy: 8))
        imgView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Generating")?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .bold))
        imgView.contentTintColor = .white
        addSubview(imgView)
        self.iconView = imgView
    }

    func startAnimating() {
        stopAnimating()

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.88
        scale.toValue = 1.32

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.85
        opacity.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 1.15
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulseRing.add(group, forKey: "voicofskiPulse")

        let orbBreathe = CABasicAnimation(keyPath: "transform.scale")
        orbBreathe.fromValue = 0.94
        orbBreathe.toValue = 1.06
        orbBreathe.duration = 0.75
        orbBreathe.autoreverses = true
        orbBreathe.repeatCount = .infinity
        orbBreathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        coreOrb.add(orbBreathe, forKey: "voicofskiBreathe")
    }

    func stopAnimating() {
        pulseRing.removeAllAnimations()
        coreOrb.removeAllAnimations()
    }
}

// MARK: - Scrubbable Thin Progress Bar

@MainActor
final class ScrubbableProgressBar: NSView {
    var onSeek: ((Double) -> Void)?
    var isInteractive: Bool = true

    private var trackLayer: CALayer!
    private var fillLayer: CALayer!
    private var knobLayer: CALayer!
    private var currentProgress: Double = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupLayers()
    }

    private func setupLayers() {
        let track = CALayer()
        track.cornerRadius = 2
        track.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.18).cgColor
        layer?.addSublayer(track)
        self.trackLayer = track

        let fill = CAGradientLayer()
        fill.cornerRadius = 2
        fill.colors = [
            NSColor(calibratedRed: 0.35, green: 0.72, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.65, green: 0.44, blue: 0.98, alpha: 1.0).cgColor
        ]
        fill.startPoint = CGPoint(x: 0, y: 0.5)
        fill.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(fill)
        self.fillLayer = fill

        let knob = CALayer()
        knob.cornerRadius = 4.5
        knob.backgroundColor = NSColor.white.cgColor
        knob.shadowColor = NSColor.black.cgColor
        knob.shadowOpacity = 0.4
        knob.shadowRadius = 2
        knob.shadowOffset = .zero
        layer?.addSublayer(knob)
        self.knobLayer = knob
    }

    override func layout() {
        super.layout()
        updateFrames(animated: false)
    }

    func setProgress(_ value: Double, animated: Bool = false) {
        currentProgress = min(max(value, 0), 1)
        updateFrames(animated: animated)
    }

    private func updateFrames(animated: Bool) {
        let trackHeight: CGFloat = 4
        let midY = bounds.height / 2
        let trackY = midY - trackHeight / 2
        let fillW = bounds.width * CGFloat(currentProgress)

        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.18)

        trackLayer.frame = CGRect(x: 0, y: trackY, width: bounds.width, height: trackHeight)
        fillLayer.frame = CGRect(x: 0, y: trackY, width: fillW, height: trackHeight)

        knobLayer.isHidden = !isInteractive
        let knobSize: CGFloat = 9
        let knobX = min(max(fillW - knobSize / 2, 0), max(0, bounds.width - knobSize))
        knobLayer.frame = CGRect(x: knobX, y: midY - knobSize / 2, width: knobSize, height: knobSize)

        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        guard isInteractive else { return }
        handleScrub(event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isInteractive else { return }
        handleScrub(event)
    }

    private func handleScrub(_ event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        guard bounds.width > 0 else { return }
        let progress = min(max(Double(local.x / bounds.width), 0), 1)
        setProgress(progress, animated: false)
        onSeek?(progress)
    }
}

// MARK: - Notch HUD Floating Player Panel

@MainActor
final class NotchPlayerPanel: NSPanel {
    enum Mode {
        case loading(status: String)
        case playing
        case notice(message: String)
    }

    var onTogglePlayPause: (() -> Void)?
    var onReplay: (() -> Void)?
    var onSeek: ((Double) -> Void)?
    var onCycleRate: (() -> Void)?
    var onNextQueued: (() -> Void)?
    var onCancelOrClose: (() -> Void)?

    private enum Metrics {
        static let loadingWidth: CGFloat = 290
        static let playbackWidth: CGFloat = 368
        static let panelHeight: CGFloat = 48
    }

    private var visualEffect: NSVisualEffectView!

    // Loading views
    private var loadingContainer: NSView!
    private var loadingOrb: LoadingWaveOrbView!
    private var loadingLabel: NSTextField!
    private var loadingBar: ScrubbableProgressBar!
    private var loadingCancelButton: NSButton!

    // Playback views
    private var playbackContainer: NSView!
    private var waveformView: NotchWaveformView!
    private var playPauseButton: NSButton!
    private var replayButton: NSButton!
    private var seekBar: ScrubbableProgressBar!
    private var timeLabel: NSTextField!
    private var speedButton: NSButton!
    private var queueBadgeButton: NSButton!
    private var closeButton: NSButton!

    // Notice banner (subtle status / queue feedback)
    private var noticeContainer: NSView!
    private var noticeLabel: NSTextField!
    private var noticeDismissTimer: Timer?

    // Non-linear loading animation timer
    private var loadingStartDate: Date?
    private var loadingTimer: Timer?

    private var currentMode: Mode = .loading(status: "Generating voice...")

    init() {
        let initialFrame = Self.topCenterRect(width: Metrics.loadingWidth, height: Metrics.panelHeight)
        super.init(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
        self.appearance = NSAppearance(named: .darkAqua)

        setupUI()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Notch / Active Screen Top-Center Positioning

    private static func topCenterRect(width: CGFloat, height: CGFloat) -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main

        guard let screen = activeScreen else {
            return NSRect(x: 540, y: 800, width: width, height: height)
        }

        let visible = screen.visibleFrame
        let full = screen.frame

        // Detect MacBook notch via safeAreaInsets.top (macOS 12+)
        let notchHeight = screen.safeAreaInsets.top
        let topAnchorY: CGFloat
        if notchHeight > 0 {
            // Sit cleanly directly below the MacBook notch
            topAnchorY = full.maxY - notchHeight - height - 6
        } else {
            // Non-notch Mac or external monitor: sit centered right below the Menu Bar
            topAnchorY = visible.maxY - height - 8
        }

        let x = visible.midX - (width / 2)
        return NSRect(x: x, y: topAnchorY, width: width, height: height)
    }

    // MARK: - UI Setup

    private func setupUI() {
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: Metrics.playbackWidth, height: Metrics.panelHeight))
        effect.autoresizingMask = [.width, .height]
        effect.appearance = NSAppearance(named: .darkAqua)
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 0.84).cgColor
        effect.layer?.cornerRadius = Metrics.panelHeight / 2
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.75
        effect.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor
        self.visualEffect = effect

        setupLoadingContainer(inside: effect)
        setupPlaybackContainer(inside: effect)
        setupNoticeContainer(inside: effect)

        self.contentView = effect
    }

    private func setupLoadingContainer(inside parent: NSView) {
        let container = NSView(frame: parent.bounds)
        container.autoresizingMask = [.width, .height]

        let orb = LoadingWaveOrbView(frame: NSRect(x: 10, y: 10, width: 28, height: 28))
        container.addSubview(orb)
        self.loadingOrb = orb

        let label = NSTextField(labelWithString: "Generating voice...")
        label.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        label.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.9)
        label.frame = NSRect(x: 46, y: 24, width: 196, height: 16)
        container.addSubview(label)
        self.loadingLabel = label

        let bar = ScrubbableProgressBar(frame: NSRect(x: 46, y: 10, width: 196, height: 12))
        bar.isInteractive = false
        container.addSubview(bar)
        self.loadingBar = bar

        let cancelBtn = makeCircularIconButton(
            symbol: "xmark",
            pointSize: 10,
            bg: NSColor(calibratedWhite: 1.0, alpha: 0.12),
            tint: NSColor(calibratedWhite: 1.0, alpha: 0.78),
            toolTip: "Cancel",
            action: #selector(closeClicked)
        )
        cancelBtn.frame = NSRect(x: Metrics.loadingWidth - 36, y: 11, width: 26, height: 26)
        cancelBtn.autoresizingMask = [.minXMargin]
        container.addSubview(cancelBtn)
        self.loadingCancelButton = cancelBtn

        parent.addSubview(container)
        self.loadingContainer = container
    }

    private func setupPlaybackContainer(inside parent: NSView) {
        let container = NSView(frame: parent.bounds)
        container.autoresizingMask = [.width, .height]
        container.isHidden = true

        // Play/Pause
        let playBtn = makeCircularIconButton(
            symbol: "pause.fill",
            pointSize: 11,
            bg: NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 0.92),
            tint: .white,
            toolTip: "Play / Pause",
            action: #selector(playPauseClicked)
        )
        playBtn.frame = NSRect(x: 10, y: 10, width: 28, height: 28)
        container.addSubview(playBtn)
        self.playPauseButton = playBtn

        // Live Waveform
        let wave = NotchWaveformView(frame: NSRect(x: 44, y: 11, width: 34, height: 26))
        container.addSubview(wave)
        self.waveformView = wave

        // Seekbar
        let seek = ScrubbableProgressBar(frame: NSRect(x: 84, y: 17, width: 110, height: 14))
        seek.isInteractive = true
        seek.onSeek = { [weak self] progress in
            self?.onSeek?(progress)
        }
        container.addSubview(seek)
        self.seekBar = seek

        // Time label
        let time = NSTextField(labelWithString: "00:00")
        time.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        time.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.78)
        time.alignment = .center
        time.frame = NSRect(x: 198, y: 16, width: 38, height: 15)
        container.addSubview(time)
        self.timeLabel = time

        // Speed pill
        let speedBtn = NSButton(frame: NSRect(x: 238, y: 13, width: 34, height: 22))
        speedBtn.isBordered = false
        speedBtn.wantsLayer = true
        speedBtn.layer?.cornerRadius = 11
        speedBtn.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        speedBtn.attributedTitle = makeSpeedAttributedTitle("1x")
        speedBtn.target = self
        speedBtn.action = #selector(speedClicked)
        speedBtn.toolTip = "Playback Speed"
        container.addSubview(speedBtn)
        self.speedButton = speedBtn

        // Replay
        let replayBtn = makeCircularIconButton(
            symbol: "gobackward",
            pointSize: 11,
            bg: NSColor(calibratedWhite: 1.0, alpha: 0.12),
            tint: NSColor(calibratedWhite: 1.0, alpha: 0.85),
            toolTip: "Replay",
            action: #selector(replayClicked)
        )
        replayBtn.frame = NSRect(x: 277, y: 11, width: 26, height: 26)
        container.addSubview(replayBtn)
        self.replayButton = replayBtn

        // Queue badge button (+N, shown only when items are queued)
        let queueBtn = NSButton(frame: NSRect(x: 306, y: 12, width: 24, height: 24))
        queueBtn.isBordered = false
        queueBtn.wantsLayer = true
        queueBtn.layer?.cornerRadius = 12
        queueBtn.layer?.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.18, alpha: 0.92).cgColor
        queueBtn.target = self
        queueBtn.action = #selector(nextQueuedClicked)
        queueBtn.isHidden = true
        queueBtn.toolTip = "Play Next Queued Voice"
        container.addSubview(queueBtn)
        self.queueBadgeButton = queueBtn

        // Close
        let closeBtn = makeCircularIconButton(
            symbol: "xmark",
            pointSize: 10,
            bg: NSColor(calibratedWhite: 1.0, alpha: 0.12),
            tint: NSColor(calibratedWhite: 1.0, alpha: 0.78),
            toolTip: "Close",
            action: #selector(closeClicked)
        )
        closeBtn.frame = NSRect(x: Metrics.playbackWidth - 36, y: 11, width: 26, height: 26)
        closeBtn.autoresizingMask = [.minXMargin]
        container.addSubview(closeBtn)
        self.closeButton = closeBtn

        parent.addSubview(container)
        self.playbackContainer = container
    }

    private func setupNoticeContainer(inside parent: NSView) {
        let container = NSView(frame: parent.bounds)
        container.autoresizingMask = [.width, .height]
        container.isHidden = true

        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 16, y: 15, width: Metrics.loadingWidth - 32, height: 18)
        label.autoresizingMask = [.width]
        container.addSubview(label)
        self.noticeLabel = label

        parent.addSubview(container)
        self.noticeContainer = container
    }

    private func makeCircularIconButton(
        symbol: String,
        pointSize: CGFloat,
        bg: NSColor,
        tint: NSColor,
        toolTip: String,
        action: Selector
    ) -> NSButton {
        let btn = NSButton()
        btn.isBordered = false
        btn.title = ""
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 13
        btn.layer?.backgroundColor = bg.cgColor
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .semibold))
        btn.contentTintColor = tint
        btn.target = self
        btn.action = action
        btn.toolTip = toolTip
        return btn
    }

    private func makeSpeedAttributedTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
                .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.9)
            ]
        )
    }

    // MARK: - Public State Transitions

    func showLoading(status: String = "Generating voice...") {
        noticeDismissTimer?.invalidate()
        currentMode = .loading(status: status)

        loadingContainer.isHidden = false
        playbackContainer.isHidden = true
        noticeContainer.isHidden = true

        loadingLabel.stringValue = status
        loadingBar.setProgress(0.02, animated: false)
        loadingOrb.startAnimating()
        startNonLinearLoadingProgress()

        resizeAndPresent(width: Metrics.loadingWidth)
    }

    func showPlayback(isPlaying: Bool, duration: TimeInterval, rate: Float, queuedCount: Int) {
        noticeDismissTimer?.invalidate()
        stopNonLinearLoadingProgress(snapToFull: true)
        loadingOrb.stopAnimating()
        currentMode = .playing

        loadingContainer.isHidden = true
        playbackContainer.isHidden = false
        noticeContainer.isHidden = true

        updatePlayPauseIcon(isPlaying: isPlaying)
        updateSpeedLabel(rate: rate)
        updateQueueBadge(count: queuedCount)
        updatePlaybackProgress(progress: 0, currentTime: 0, duration: duration, audioLevel: 0, isPlaying: isPlaying)

        resizeAndPresent(width: Metrics.playbackWidth)
    }

    func showTransientNotice(_ message: String, duration: TimeInterval = 3.2) {
        stopNonLinearLoadingProgress(snapToFull: false)
        loadingOrb.stopAnimating()
        currentMode = .notice(message: message)

        loadingContainer.isHidden = true
        playbackContainer.isHidden = true
        noticeContainer.isHidden = false
        noticeLabel.stringValue = message

        resizeAndPresent(width: 310)

        noticeDismissTimer?.invalidate()
        noticeDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hidePanel()
            }
        }
    }

    func updatePlaybackProgress(
        progress: Double,
        currentTime: TimeInterval,
        duration: TimeInterval,
        audioLevel: CGFloat,
        isPlaying: Bool
    ) {
        seekBar.setProgress(progress, animated: false)
        waveformView.setLevel(audioLevel, isPlaying: isPlaying)
        updatePlayPauseIcon(isPlaying: isPlaying)

        let displaySeconds = max(0, Int(currentTime.rounded()))
        timeLabel.stringValue = String(format: "%02d:%02d", displaySeconds / 60, displaySeconds % 60)
    }

    func updateSpeedLabel(rate: Float) {
        let formatted: String
        if abs(rate - 1.0) < 0.01 {
            formatted = "1x"
        } else if abs(rate - 1.25) < 0.01 {
            formatted = "1.25x"
        } else {
            formatted = "1.5x"
        }
        speedButton.attributedTitle = makeSpeedAttributedTitle(formatted)
    }

    func updateQueueBadge(count: Int) {
        if count > 0 {
            queueBadgeButton.isHidden = false
            queueBadgeButton.attributedTitle = NSAttributedString(
                string: "+\(count)",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
            )
        } else {
            queueBadgeButton.isHidden = true
        }
    }

    func hidePanel() {
        noticeDismissTimer?.invalidate()
        noticeDismissTimer = nil
        stopNonLinearLoadingProgress(snapToFull: false)
        loadingOrb.stopAnimating()
        orderOut(nil)
    }

    func containsScreenPoint(_ point: CGPoint) -> Bool {
        guard isVisible else { return false }
        return frame.insetBy(dx: -4, dy: -4).contains(point)
    }

    // MARK: - Non-Linear Staged Loading Curve (0→30% fast, 30→60% steady, 60→86% glide)

    private func startNonLinearLoadingProgress() {
        loadingTimer?.invalidate()
        loadingStartDate = Date()

        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickNonLinearProgress()
            }
        }
    }

    private func tickNonLinearProgress() {
        guard let start = loadingStartDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let target: Double

        if elapsed <= 0.75 {
            // Stage 1: Fast surge 0% -> 30%
            let t = elapsed / 0.75
            target = 0.02 + 0.28 * (1 - pow(1 - t, 2))
        } else if elapsed <= 3.25 {
            // Stage 2: Steady slower cruise 30% -> 60%
            let t = (elapsed - 0.75) / 2.5
            target = 0.30 + 0.30 * t
        } else if elapsed <= 5.5 {
            // Stage 3: Smooth renewed momentum 60% -> 84%
            let t = (elapsed - 3.25) / 2.25
            target = 0.60 + 0.24 * (1 - pow(1 - t, 1.6))
        } else {
            // Gentle asymptotic creep up to 92% while awaiting response
            let extra = elapsed - 5.5
            target = min(0.92, 0.84 + 0.08 * (1 - exp(-extra / 4.0)))
        }

        loadingBar.setProgress(target, animated: true)
    }

    private func stopNonLinearLoadingProgress(snapToFull: Bool) {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingStartDate = nil
        if snapToFull {
            loadingBar.setProgress(1.0, animated: true)
        }
    }

    // MARK: - Helpers & Actions

    private func updatePlayPauseIcon(isPlaying: Bool) {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: isPlaying ? "Pause" : "Play")?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
    }

    private func resizeAndPresent(width: CGFloat) {
        let targetRect = Self.topCenterRect(width: width, height: Metrics.panelHeight)
        if isVisible {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(targetRect, display: true)
            }
        } else {
            setFrame(targetRect, display: true)
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().alphaValue = 1
            }
        }
    }

    @objc private func playPauseClicked() { onTogglePlayPause?() }
    @objc private func replayClicked() { onReplay?() }
    @objc private func speedClicked() { onCycleRate?() }
    @objc private func nextQueuedClicked() { onNextQueued?() }
    @objc private func closeClicked() { onCancelOrClose?() }
}
