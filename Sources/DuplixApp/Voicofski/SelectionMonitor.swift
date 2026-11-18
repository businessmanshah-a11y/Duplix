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
    private var mouseDownTime: Date = .distantPast
    private var debounceTask: Task<Void, Never>?

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
        mouseDownTime = Date()
    }

    private func handleMouseUp(at location: CGPoint, clickCount: Int) {
        if shouldIgnoreWindowPoint?(location) == true {
            return
        }

        guard AXIsProcessTrusted() else { return }

        // Ignore selections made inside Duplix itself (user already has the in-app Composer)
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
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

        let isDragSelection = dragDistance >= 6.0
        let isMultiClickSelection = clickCount >= 2

        guard isDragSelection || isMultiClickSelection else {
            // Simple single click — likely deselected text
            onDismissRequested?()
            return
        }

        let anchor = location
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000) // 160ms settle delay
            guard !Task.isCancelled, let self else { return }
            self.inspectCurrentSelection(fallbackMousePoint: anchor, wasDragOrMultiClick: true)
        }
    }

    private func handleKeyDown(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        // Esc dismisses immediately
        if keyCode == 53 {
            debounceTask?.cancel()
            onDismissRequested?()
            return
        }

        // Typing or arrow navigation without shift clears selection
        let isCommandCopy = (keyCode == 8 && flags.contains(.command)) // Cmd+C
        if isCommandCopy {
            // Give a brief moment; if user subsequently clicks/deselects it dismisses cleanly
            return
        }

        if !flags.contains(.shift) && !flags.contains(.command) {
            debounceTask?.cancel()
            onDismissRequested?()
        }
    }

    // MARK: - Accessibility Inspection

    private func inspectCurrentSelection(fallbackMousePoint: CGPoint, wasDragOrMultiClick: Bool) {
        let axResult = readAccessibilitySelection()

        if let axText = axResult.text {
            // Accessibility gave us the exact selected string — enforce >= 3 characters rule strictly
            guard VoicofskiTextMetrics.meetsMinimumSelectionLength(axText) else {
                onDismissRequested?()
                return
            }

            let detected = DetectedSelection(
                text: VoicofskiTextMetrics.trimmed(axText),
                anchorPoint: fallbackMousePoint,
                selectionRect: axResult.appKitRect
            )
            onSelectionDetected?(detected)
            return
        }

        // Some Electron / WebView / PDF apps do not expose kAXSelectedTextAttribute directly.
        // Only show the subtle corner trigger if the focused element looks text-capable or user performed a clear text drag/multi-click.
        if wasDragOrMultiClick && axResult.mayHaveUnexposedText {
            let detected = DetectedSelection(
                text: nil, // Will be resolved cleanly via non-destructive Cmd+C fallback only if user clicks the trigger
                anchorPoint: fallbackMousePoint,
                selectionRect: nil
            )
            onSelectionDetected?(detected)
        }
    }

    private struct AXSelectionResult {
        let text: String?
        let appKitRect: CGRect?
        let mayHaveUnexposedText: Bool
    }

    private func readAccessibilitySelection() -> AXSelectionResult {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedObj: CFTypeRef?
        let focusedErr = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedObj)
        guard focusedErr == .success, let focusedElement = focusedObj else {
            return AXSelectionResult(text: nil, appKitRect: nil, mayHaveUnexposedText: true)
        }

        let axElement = focusedElement as! AXUIElement

        // Check role to avoid popping up when dragging window chrome / sliders / splitters
        var roleObj: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleObj)
        let role = (roleObj as? String) ?? ""
        let nonTextRoles: Set<String> = [
            "AXSlider", "AXScrollBar", "AXSplitter", "AXButton", "AXCheckBox",
            "AXRadioButton", "AXPopUpButton", "AXMenuItem", "AXToolbar", "AXTabGroup"
        ]
        if nonTextRoles.contains(role) {
            return AXSelectionResult(text: nil, appKitRect: nil, mayHaveUnexposedText: false)
        }

        var selectedTextObj: CFTypeRef?
        let textErr = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextObj)
        if textErr == .success, let selectedText = selectedTextObj as? String {
            let bounds = readSelectionAppKitRect(for: axElement)
            return AXSelectionResult(text: selectedText, appKitRect: bounds, mayHaveUnexposedText: false)
        }

        // Accessibility did not expose selected text directly (common in Chrome/Electron/PDF)
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

        // Convert Quartz top-left global coordinates to AppKit bottom-left coordinates
        guard let primaryScreen = NSScreen.screens.first else {
            return nil
        }
        let primaryHeight = primaryScreen.frame.height
        let appKitY = primaryHeight - quartzRect.origin.y - quartzRect.height
        return CGRect(x: quartzRect.origin.x, y: appKitY, width: quartzRect.width, height: quartzRect.height)
    }

    // MARK: - Non-Destructive Clipboard Fallback (Only on Explicit Trigger Click)

    /// Captures selected text from the frontmost app by simulating `Cmd+C`, then restores the previous clipboard contents.
    public func captureSelectedTextViaClipboardFallback() async -> String? {
        let pasteboard = NSPasteboard.general
        let savedItems = snapshotPasteboard(pasteboard)
        let originalChangeCount = pasteboard.changeCount

        simulateCommandC()

        // Wait briefly for target application to populate the clipboard
        try? await Task.sleep(nanoseconds: 110_000_000)

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
