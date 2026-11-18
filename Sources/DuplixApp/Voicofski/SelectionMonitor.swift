import AppKit
import ApplicationServices
import CoreGraphics
import DuplixCore

public struct DetectedSelection: Sendable {
    public let text: String?
    public let anchorPoint: CGPoint
    public let selectionRect: CGRect?

    public init(text: String?, anchorPoint: CGPoint, selectionRect: CGRect?) {
        self.text = text
        self.anchorPoint = anchorPoint
        self.selectionRect = selectionRect
    }
}

@MainActor
public final class SelectionMonitor {
    public var onSelectionDetected: ((DetectedSelection) -> Void)?
    public var onDismissRequested: (() -> Void)?
    public var shouldIgnoreWindowPoint: ((CGPoint) -> Bool)?

    private var globalMouseDownMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalScrollMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var localKeyDownMonitor: Any?

    private var mouseDownLocation: CGPoint?
    private var debounceTask: Task<Void, Never>?
    private var isPerformingClipboardProbe = false

    public private(set) var isRunning: Bool = false

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let location = NSEvent.mouseLocation
            let isRight = event.type == .rightMouseDown
            Task { @MainActor in
                self?.handleMouseDown(at: location, isRightClick: isRight)
            }
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            let location = NSEvent.mouseLocation
            let clickCount = event.clickCount
            Task { @MainActor in
                self?.handleMouseUp(at: location, clickCount: clickCount)
            }
        }

        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            Task { @MainActor in
                self?.debounceTask?.cancel()
                self?.onDismissRequested?()
            }
        }

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            Task { @MainActor in
                self?.handleKeyDown(keyCode: keyCode, flags: flags)
            }
        }

        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                if self?.shouldIgnoreWindowPoint?(location) == true {
                    return
                }
                self?.debounceTask?.cancel()
                self?.onDismissRequested?()
            }
            return event
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Esc
                Task { @MainActor in
                    self?.onDismissRequested?()
                }
            }
            return event
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        debounceTask?.cancel()
        debounceTask = nil

        if let m = globalMouseDownMonitor { NSEvent.removeMonitor(m); globalMouseDownMonitor = nil }
        if let m = globalMouseUpMonitor { NSEvent.removeMonitor(m); globalMouseUpMonitor = nil }
        if let m = globalScrollMonitor { NSEvent.removeMonitor(m); globalScrollMonitor = nil }
        if let m = globalKeyDownMonitor { NSEvent.removeMonitor(m); globalKeyDownMonitor = nil }
        if let m = localMouseDownMonitor { NSEvent.removeMonitor(m); localMouseDownMonitor = nil }
        if let m = localKeyDownMonitor { NSEvent.removeMonitor(m); localKeyDownMonitor = nil }
    }

    // MARK: - Event Handling

    private func handleMouseDown(at location: CGPoint, isRightClick: Bool) {
        if shouldIgnoreWindowPoint?(location) == true {
            return
        }

        debounceTask?.cancel()
        onDismissRequested?()

        if isRightClick {
            mouseDownLocation = nil
            return
        }

        mouseDownLocation = location
    }

    private func handleMouseUp(at location: CGPoint, clickCount: Int) {
        if shouldIgnoreWindowPoint?(location) == true {
            return
        }

        guard AXIsProcessTrusted() else { return }

        // Ignore selections inside Duplix itself (user already has the built-in Composer)
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            mouseDownLocation = nil
            return
        }

        let start = mouseDownLocation
        mouseDownLocation = nil

        let dragDistance: CGFloat
        if let start {
            dragDistance = hypot(location.x - start.x, location.y - start.y)
        } else {
            dragDistance = 0
        }

        let isDragSelection = dragDistance >= 8.0
        let isMultiClickSelection = clickCount >= 2

        guard isDragSelection || isMultiClickSelection else {
            onDismissRequested?()
            return
        }

        let anchor = location
        let pid = frontApp.processIdentifier

        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 140_000_000) // 140ms settle delay
            guard !Task.isCancelled, let self else { return }
            await self.inspectCurrentSelection(
                frontAppPID: pid,
                fallbackMousePoint: anchor,
                allowClipboardProbe: dragDistance >= 10.0 || isMultiClickSelection
            )
        }
    }

    private func handleKeyDown(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        // Ignore our own synthetic Cmd+C clipboard probe
        if isPerformingClipboardProbe {
            return
        }

        // Esc dismisses immediately
        if keyCode == 53 {
            debounceTask?.cancel()
            onDismissRequested?()
            return
        }

        // Do not immediately dismiss on Cmd+C itself; dismissal occurs on subsequent click/deselect or 10s timeout
        let isCommandCopy = (keyCode == 8 && flags.contains(.command))
        if isCommandCopy {
            return
        }

        if !flags.contains(.shift) && !flags.contains(.command) {
            debounceTask?.cancel()
            onDismissRequested?()
        }
    }

    // MARK: - Hybrid Accessibility + Non-Destructive Clipboard Probe

    private func inspectCurrentSelection(
        frontAppPID: pid_t,
        fallbackMousePoint: CGPoint,
        allowClipboardProbe: Bool
    ) async {
        // 1. Try native Accessibility API first (also enabling Chromium/Electron manual accessibility)
        let axResult = readAccessibilitySelection(frontAppPID: frontAppPID)

        if let axText = axResult.text {
            let trimmed = VoicofskiTextMetrics.trimmed(axText)
            if !trimmed.isEmpty {
                // Accessibility returned real selected text — strictly enforce >= 3 characters rule
                guard VoicofskiTextMetrics.meetsMinimumSelectionLength(trimmed) else {
                    onDismissRequested?()
                    return
                }

                let detected = DetectedSelection(
                    text: trimmed,
                    anchorPoint: fallbackMousePoint,
                    selectionRect: axResult.appKitRect
                )
                onSelectionDetected?(detected)
                return
            }
        }

        // 2. If the focused element is clearly a non-text UI control (slider/scrollbar/button), stop here
        guard axResult.mayHaveUnexposedText, allowClipboardProbe else {
            return
        }

        // 3. Electron / Chrome / Antigravity IDE / PDF fallback:
        // Perform a silent, non-destructive Cmd+C probe that immediately restores the user's clipboard.
        // If no text is selected (e.g. dragging empty space or a window), pasteboard changeCount stays unchanged -> zero false positives!
        if let probedText = await captureSelectedTextViaClipboardFallback() {
            guard !Task.isCancelled else { return }
            let detected = DetectedSelection(
                text: probedText,
                anchorPoint: fallbackMousePoint,
                selectionRect: axResult.appKitRect
            )
            onSelectionDetected?(detected)
        }
    }

    private struct AXSelectionResult {
        let text: String?
        let appKitRect: CGRect?
        let mayHaveUnexposedText: Bool
    }

    private func readAccessibilitySelection(frontAppPID: pid_t) -> AXSelectionResult {
        let appElement = AXUIElementCreateApplication(frontAppPID)

        // Hint Chromium / Electron apps (Chrome, Antigravity IDE, VS Code, Slack) to expose their accessibility tree
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        // Resolve focused element from frontmost app first, falling back to system-wide focused element
        var focusedObj: CFTypeRef?
        var err = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedObj)
        if err != .success || focusedObj == nil {
            let systemWide = AXUIElementCreateSystemWide()
            err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedObj)
        }

        guard err == .success, let focusedElement = focusedObj else {
            return AXSelectionResult(text: nil, appKitRect: nil, mayHaveUnexposedText: true)
        }

        let axElement = focusedElement as! AXUIElement

        // Skip non-text chrome widgets so dragging sliders/scrollbars never triggers a probe
        var roleObj: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleObj)
        let role = (roleObj as? String) ?? ""
        let nonTextRoles: Set<String> = [
            "AXSlider", "AXScrollBar", "AXSplitter", "AXCheckBox",
            "AXRadioButton", "AXPopUpButton", "AXMenuItem", "AXToolbar", "AXTabGroup"
        ]
        if nonTextRoles.contains(role) {
            return AXSelectionResult(text: nil, appKitRect: nil, mayHaveUnexposedText: false)
        }

        var selectedTextObj: CFTypeRef?
        let textErr = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextObj)
        if textErr == .success, let selectedText = selectedTextObj as? String {
            let trimmed = VoicofskiTextMetrics.trimmed(selectedText)
            if !trimmed.isEmpty {
                let bounds = readSelectionAppKitRect(for: axElement)
                return AXSelectionResult(text: trimmed, appKitRect: bounds, mayHaveUnexposedText: false)
            }
            // IMPORTANT: Chrome/Electron/WebViews often return `.success` with an empty string `""`
            // even when text IS selected inside the canvas/DOM. Allow clipboard probe!
            return AXSelectionResult(text: nil, appKitRect: nil, mayHaveUnexposedText: true)
        }

        return AXSelectionResult(text: nil, appKitRect: nil, mayHaveUnexposedText: true)
    }

    private func readSelectionAppKitRect(for element: AXUIElement) -> CGRect? {
        var rangeObj: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeObj) == .success,
              let rangeValue = rangeObj else {
            return nil
        }

        var boundsObj: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsObj
        ) == .success,
              let boundsValue = boundsObj else {
            return nil
        }

        var quartzRect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &quartzRect),
              quartzRect.width > 0 || quartzRect.height > 0 else {
            return nil
        }

        guard let primaryScreen = NSScreen.screens.first else {
            return nil
        }
        let primaryHeight = primaryScreen.frame.height
        let appKitY = primaryHeight - quartzRect.origin.y - quartzRect.height
        return CGRect(x: quartzRect.origin.x, y: appKitY, width: quartzRect.width, height: quartzRect.height)
    }

    // MARK: - Non-Destructive Clipboard Fallback

    /// Captures selected text from the frontmost app by simulating `Cmd+C`, then immediately restores the previous clipboard contents.
    public func captureSelectedTextViaClipboardFallback() async -> String? {
        guard !isPerformingClipboardProbe else { return nil }
        isPerformingClipboardProbe = true
        defer { isPerformingClipboardProbe = false }

        let pasteboard = NSPasteboard.general
        let savedItems = snapshotPasteboard(pasteboard)
        let originalChangeCount = pasteboard.changeCount

        simulateCommandC()

        // Wait briefly for target app (Chrome / Electron / PDF) to write selection to pasteboard
        try? await Task.sleep(nanoseconds: 95_000_000)

        var captured: String? = nil
        if pasteboard.changeCount != originalChangeCount {
            captured = pasteboard.string(forType: .string)
        }

        // Restore user's previous clipboard contents cleanly
        restorePasteboard(pasteboard, items: savedItems)

        guard let text = captured, VoicofskiTextMetrics.meetsMinimumSelectionLength(text) else {
            return nil
        }
        return VoicofskiTextMetrics.trimmed(text)
    }

    private func simulateCommandC() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let cKeyCode: CGKeyCode = 8 // 'c'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, items: [[(NSPasteboard.PasteboardType, Data)]]) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored: [NSPasteboardItem] = items.map { pairs in
            let pbItem = NSPasteboardItem()
            for (type, data) in pairs {
                pbItem.setData(data, forType: type)
            }
            return pbItem
        }
        pasteboard.writeObjects(restored)
    }
}
