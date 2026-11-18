import AppKit
import QuartzCore

@MainActor
final class SelectionTriggerPanel: NSPanel {
    var onDirectTTSRequested: (() -> Void)?
    var onTranslateTTSRequested: (() -> Void)?
    var onDismissed: (() -> Void)?

    private enum Layout {
        static let collapsedSize = CGSize(width: 28, height: 28)
        static let expandedSize = CGSize(width: 72, height: 32)
        static let cornerMargin: CGFloat = 8
        static let autoDismissSeconds: TimeInterval = 10.0
    }

    private var containerEffect: NSVisualEffectView!
    private var collapsedButton: NSButton!
    private var expandedStack: NSStackView!
    private var directButton: NSButton!
    private var translateButton: NSButton!

    private var isExpanded: Bool = false
    private var currentAnchorRect: CGRect?
    private var currentAnchorPoint: CGPoint = .zero
    private var autoDismissTimer: Timer?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Layout.collapsedSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.appearance = NSAppearance(named: .darkAqua)

        setupUI()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - UI Setup (Pure Icons, Zero Text Labels, Zero Emojis)

    private func setupUI() {
        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Layout.collapsedSize))
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.appearance = NSAppearance(named: .darkAqua)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = Layout.collapsedSize.height / 2
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0.75
        visualEffect.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.2).cgColor
        visualEffect.layer?.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.27, blue: 0.27, alpha: 0.92).cgColor
        self.containerEffect = visualEffect

        // Stage 1: Compact Accent Trigger Icon
        let triggerBtn = NSButton(frame: visualEffect.bounds)
        triggerBtn.autoresizingMask = [.width, .height]
        triggerBtn.isBordered = false
        triggerBtn.title = ""
        triggerBtn.target = self
        triggerBtn.action = #selector(collapsedButtonClicked)
        triggerBtn.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voicofski")?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .bold))
        triggerBtn.contentTintColor = .white
        triggerBtn.toolTip = "Voicofski"
        visualEffect.addSubview(triggerBtn)
        self.collapsedButton = triggerBtn

        // Stage 2: Expanded 2-Icon Action Bar (Direct Voice + Translate)
        let speakBtn = makeActionIconButton(
            symbolName: "speaker.wave.2.fill",
            fallbackSymbol: "speaker.wave.2.fill",
            tintColor: .white,
            background: NSColor(calibratedRed: 0.94, green: 0.27, blue: 0.27, alpha: 0.92),
            toolTip: "Speak Selection",
            action: #selector(directTTSClicked)
        )
        self.directButton = speakBtn

        let translateBtn = makeActionIconButton(
            symbolName: "translate",
            fallbackSymbol: "globe",
            tintColor: .white,
            background: NSColor(calibratedRed: 0.26, green: 0.52, blue: 0.96, alpha: 0.92),
            toolTip: "Translate & Speak",
            action: #selector(translateTTSClicked)
        )
        self.translateButton = translateBtn

        let stack = NSStackView(views: [speakBtn, translateBtn])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        visualEffect.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor)
        ])
        self.expandedStack = stack

        self.contentView = visualEffect
    }

    private func makeActionIconButton(
        symbolName: String,
        fallbackSymbol: String,
        tintColor: NSColor,
        background: NSColor,
        toolTip: String,
        action: Selector
    ) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.isBordered = false
        btn.title = ""
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 13
        btn.layer?.backgroundColor = background.cgColor
        btn.target = self
        btn.action = action
        btn.toolTip = toolTip

        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)
            ?? NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: toolTip)
        btn.image = img?.withSymbolConfiguration(config)
        btn.contentTintColor = tintColor

        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 26),
            btn.heightAnchor.constraint(equalToConstant: 26)
        ])
        return btn
    }

    // MARK: - Presentation & Smart Corner Placement

    func showCollapsed(anchorPoint: CGPoint, selectionRect: CGRect?) {
        self.currentAnchorPoint = anchorPoint
        self.currentAnchorRect = selectionRect
        self.isExpanded = false

        collapsedButton.isHidden = false
        expandedStack.isHidden = true
        containerEffect.layer?.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.27, blue: 0.27, alpha: 0.92).cgColor
        containerEffect.layer?.cornerRadius = Layout.collapsedSize.height / 2

        let targetFrame = computePlacementFrame(size: Layout.collapsedSize, anchorPoint: anchorPoint, selectionRect: selectionRect)
        setFrame(targetFrame, display: true)

        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }

        scheduleAutoDismissTimer()
    }

    func expandActions() {
        guard !isExpanded else { return }
        isExpanded = true

        collapsedButton.isHidden = true
        expandedStack.isHidden = false
        containerEffect.layer?.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 0.86).cgColor
        containerEffect.layer?.cornerRadius = Layout.expandedSize.height / 2

        let targetFrame = computePlacementFrame(
            size: Layout.expandedSize,
            anchorPoint: currentAnchorPoint,
            selectionRect: currentAnchorRect
        )

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(targetFrame, display: true)
        }

        scheduleAutoDismissTimer()
    }

    func dismiss(notify: Bool = false) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil

        guard isVisible else { return }
        orderOut(nil)
        isExpanded = false
        if notify {
            onDismissed?()
        }
    }

    func containsScreenPoint(_ point: CGPoint) -> Bool {
        guard isVisible else { return false }
        return frame.insetBy(dx: -4, dy: -4).contains(point)
    }

    /// Places the trigger at the top-right corner of selection, automatically flipping to bottom if clipped by top edge / menu bar.
    private func computePlacementFrame(size: CGSize, anchorPoint: CGPoint, selectionRect: CGRect?) -> CGRect {
        let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(anchorPoint, $0.frame, false) })
            ?? NSScreen.main
        let visible = activeScreen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let referenceRect = selectionRect ?? CGRect(x: anchorPoint.x - 4, y: anchorPoint.y - 10, width: 8, height: 20)

        // Default: top-right corner of the selected region
        var originX = referenceRect.maxX + Layout.cornerMargin
        var originY = referenceRect.maxY + Layout.cornerMargin

        // Flip to bottom corner if top placement would clip above visibleFrame (menu bar / notch)
        if originY + size.height > visible.maxY - 6 {
            originY = referenceRect.minY - size.height - Layout.cornerMargin
        }

        // Flip to left side if right edge overflows visibleFrame
        if originX + size.width > visible.maxX - 8 {
            originX = referenceRect.minX - size.width - Layout.cornerMargin
        }

        // Final safe clamping inside visibleFrame
        originX = min(max(originX, visible.minX + 8), visible.maxX - size.width - 8)
        originY = min(max(originY, visible.minY + 8), visible.maxY - size.height - 8)

        return CGRect(origin: CGPoint(x: originX, y: originY), size: size)
    }

    private func scheduleAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: Layout.autoDismissSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(notify: true)
            }
        }
    }

    // MARK: - Actions

    @objc private func collapsedButtonClicked() {
        expandActions()
    }

    @objc private func directTTSClicked() {
        dismiss(notify: false)
        onDirectTTSRequested?()
    }

    @objc private func translateTTSClicked() {
        dismiss(notify: false)
        onTranslateTTSRequested?()
    }
}
