import AppKit
import ApplicationServices
import DuplixCore
import Foundation

public struct PlaybackQueueItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let historyItem: VoicofskiHistoryItem
    public let audioURL: URL

    public init(id: UUID = UUID(), historyItem: VoicofskiHistoryItem, audioURL: URL) {
        self.id = id
        self.historyItem = historyItem
        self.audioURL = audioURL
    }
}

@MainActor
public final class VoicofskiEngine: ObservableObject {
    public static let shared = VoicofskiEngine()

    // MARK: - Published UI State

    @Published public var isEnabled: Bool = true {
        didSet {
            settings.isSelectionTriggerEnabled = isEnabled
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published public var selectedVoice: VoicofskiVoice = .female {
        didSet { settings.selectedVoice = selectedVoice }
    }

    @Published public var targetLanguage: VoicofskiTargetLanguage = .persian {
        didSet { settings.targetLanguage = targetLanguage }
    }

    @Published public var composerMode: VoicofskiMode = .direct
    @Published public var composerInputText: String = ""
    @Published public var translatedReviewText: String = ""
    @Published public var isAwaitingTranslationReview: Bool = false

    @Published public private(set) var keys: [APIKeyMetadata] = []
    @Published public private(set) var history: [VoicofskiHistoryItem] = []
    @Published public private(set) var pendingQueue: [PendingQuotaRequest] = []
    @Published public private(set) var playbackQueue: [PlaybackQueueItem] = []

    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var busyStatusText: String? = nil
    @Published public private(set) var currentlyPlayingItem: VoicofskiHistoryItem? = nil
    @Published public private(set) var hasAccessibilityPermission: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var statusMessage: String? = nil

    // Navigation callbacks wired by AppDelegate & MainView
    public var onOpenMainWindowRequested: (() -> Void)?
    public var onFocusVoicofskiTabRequested: (() -> Void)?

    // MARK: - Dependencies

    private let settings = VoicofskiSettingsStore()
    private let storage = VoicofskiStorage()
    private let client = GeminiAPIClient()
    private let keyPool: APIKeyPoolManager
    private let selectionMonitor = SelectionMonitor()
    private let audioPlayer = VoicofskiAudioPlayer()

    private var triggerPanel: SelectionTriggerPanel?
    private var notchPanel: NotchPlayerPanel?
    private var pendingSelection: DetectedSelection?
    private var activeGenerationTask: Task<Void, Never>?
    private var cooldownTimer: Timer?

    private init() {
        self.keyPool = APIKeyPoolManager(
            keychain: MacOSKeychainStore(),
            storage: storage,
            client: client
        )

        self.isEnabled = settings.isSelectionTriggerEnabled
        self.selectedVoice = settings.selectedVoice
        self.targetLanguage = settings.targetLanguage
        self.keys = keyPool.listKeys()
        self.history = storage.loadHistory()
        self.pendingQueue = storage.loadPendingQueue()
        self.hasAccessibilityPermission = AXIsProcessTrusted()

        setupCallbacks()
        startCooldownWatcher()
    }

    // MARK: - Lifecycle

    public func start() {
        refreshPermissions()
        refreshKeysAndCooldowns()
        if isEnabled {
            startMonitoring()
        }
    }

    public func stop() {
        stopMonitoring()
        notchPanel?.hidePanel()
        audioPlayer.stop()
        activeGenerationTask?.cancel()
        activeGenerationTask = nil
    }

    public func refreshPermissions() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissions()
        if !hasAccessibilityPermission,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func refreshKeysAndCooldowns() {
        let recovered = keyPool.refreshCooldowns()
        keys = keyPool.listKeys()
        if recovered && !pendingQueue.isEmpty {
            statusMessage = "API key quota reset — \(pendingQueue.count) queued item(s) ready to run."
        }
    }

    public var activeKeyCount: Int {
        keys.filter { $0.status == .active || $0.status == .untested }.count
    }

    // MARK: - Selection Monitor & Panels Setup

    private func setupCallbacks() {
        selectionMonitor.shouldIgnoreWindowPoint = { [weak self] point in
            guard let self else { return false }
            let inTrigger = self.triggerPanel?.containsScreenPoint(point) == true
            let inNotch = self.notchPanel?.containsScreenPoint(point) == true
            return inTrigger || inNotch
        }

        selectionMonitor.onSelectionDetected = { [weak self] detected in
            guard let self, self.isEnabled else { return }
            self.pendingSelection = detected
            self.ensureTriggerPanel().showCollapsed(
                anchorPoint: detected.anchorPoint,
                selectionRect: detected.selectionRect
            )
        }

        selectionMonitor.onDismissRequested = { [weak self] in
            self?.triggerPanel?.dismiss(notify: false)
        }

        audioPlayer.onProgressUpdated = { [weak self] progress, current, duration, level in
            guard let self else { return }
            self.notchPanel?.updatePlaybackProgress(
                progress: progress,
                currentTime: current,
                duration: duration,
                audioLevel: level,
                isPlaying: self.audioPlayer.isPlaying
            )
        }

        audioPlayer.onPlaybackFinished = { [weak self] in
            // Per specification: keep Notch HUD open after playback finishes so user can Replay or manually close.
            guard let self else { return }
            self.notchPanel?.updatePlaybackProgress(
                progress: 1.0,
                currentTime: self.audioPlayer.duration,
                duration: self.audioPlayer.duration,
                audioLevel: 0,
                isPlaying: false
            )
        }
    }

    private func startMonitoring() {
        selectionMonitor.start()
    }

    private func stopMonitoring() {
        selectionMonitor.stop()
        triggerPanel?.dismiss(notify: false)
    }

    private func ensureTriggerPanel() -> SelectionTriggerPanel {
        if let existing = triggerPanel { return existing }
        let panel = SelectionTriggerPanel()
        panel.onDirectTTSRequested = { [weak self] in
            self?.handleFloatingAction(mode: .direct)
        }
        panel.onTranslateTTSRequested = { [weak self] in
            self?.handleFloatingAction(mode: .translate)
        }
        panel.onDismissed = { [weak self] in
            self?.pendingSelection = nil
        }
        self.triggerPanel = panel
        return panel
    }

    private func ensureNotchPanel() -> NotchPlayerPanel {
        if let existing = notchPanel { return existing }
        let panel = NotchPlayerPanel()
        panel.onTogglePlayPause = { [weak self] in
            self?.audioPlayer.togglePlayPause()
        }
        panel.onReplay = { [weak self] in
            self?.audioPlayer.replay()
        }
        panel.onSeek = { [weak self] progress in
            self?.audioPlayer.seek(toProgress: progress)
        }
        panel.onCycleRate = { [weak self] in
            guard let self else { return }
            let newRate = self.audioPlayer.cyclePlaybackRate()
            self.notchPanel?.updateSpeedLabel(rate: newRate)
        }
        panel.onNextQueued = { [weak self] in
            self?.playNextQueuedItem()
        }
        panel.onCancelOrClose = { [weak self] in
            self?.handleNotchCloseOrCancel()
        }
        self.notchPanel = panel
        return panel
    }

    private func startCooldownWatcher() {
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshKeysAndCooldowns()
            }
        }
    }

    // MARK: - Floating Selection Actions

    private func handleFloatingAction(mode: VoicofskiMode) {
        let snapshot = pendingSelection
        pendingSelection = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            let resolvedText: String?
            if let axText = snapshot?.text, VoicofskiTextMetrics.meetsMinimumSelectionLength(axText) {
                resolvedText = axText
            } else {
                resolvedText = await self.selectionMonitor.captureSelectedTextViaClipboardFallback()
            }

            guard let text = resolvedText, VoicofskiTextMetrics.meetsMinimumSelectionLength(text) else {
                self.ensureNotchPanel().showTransientNotice("Select at least 3 characters.")
                return
            }

            switch mode {
            case .direct:
                await self.triggerDirectTTS(text: text, voice: self.selectedVoice, fromSelection: true)
            case .translate:
                await self.triggerTranslateForReview(text: text, targetLanguage: self.targetLanguage)
            }
        }
    }

    // MARK: - Word Count Warning Guard (> 500 words)

    private func confirmLongTextIfNeeded(_ text: String) -> Bool {
        let words = VoicofskiTextMetrics.wordCount(text)
        guard words > VoicofskiTextMetrics.longTextWordThreshold else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Long Text Warning (\(words) words)"
        alert.informativeText = "This text exceeds 500 words and may consume significant quota or hit your Gemini API token limit. Do you want to continue?"
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Direct TTS Pipeline

    public func triggerDirectTTS(
        text: String,
        voice: VoicofskiVoice? = nil,
        translatedFrom originalText: String? = nil,
        targetLanguage: VoicofskiTargetLanguage? = nil,
        fromSelection: Bool = false
    ) async {
        let trimmed = VoicofskiTextMetrics.trimmed(text)
        guard VoicofskiTextMetrics.meetsMinimumSelectionLength(trimmed) else {
            errorMessage = "Please enter at least 3 characters."
            return
        }

        guard confirmLongTextIfNeeded(trimmed) else {
            return
        }

        let chosenVoice = voice ?? selectedVoice
        let mode: VoicofskiMode = originalText != nil ? .translate : .direct

        refreshKeysAndCooldowns()
        guard !keys.isEmpty else {
            errorMessage = VoicofskiError.noAPIKeys.localizedDescription
            focusVoicofskiInApp()
            return
        }

        let shouldQueueAfterCurrent = (notchPanel?.isVisible == true && audioPlayer.hasLoadedAudio && currentlyPlayingItem != nil)
        let hud = ensureNotchPanel()
        if !shouldQueueAfterCurrent {
            hud.showLoading(status: "Generating voice...")
        } else {
            statusMessage = "Generating next voice in background..."
        }

        isBusy = true
        busyStatusText = "Generating voice..."
        errorMessage = nil

        let pool = self.keyPool
        let apiClient = self.client

        let task = Task<SynthesizedAudioResult, Error> {
            try await pool.executeWithFailover(forModel: VoicofskiModelConfig.ttsModel) { apiKey in
                try await apiClient.synthesizeSpeech(text: trimmed, voice: chosenVoice, apiKey: apiKey)
            }
        }

        activeGenerationTask = Task { [weak self] in
            do {
                let result = try await task.value
                guard let self, !Task.isCancelled else { return }

                let itemID = UUID()
                let saved = try self.storage.saveAudioData(result.wavData, id: itemID)
                let historyItem = VoicofskiHistoryItem(
                    id: itemID,
                    mode: mode,
                    originalText: originalText ?? trimmed,
                    translatedText: originalText != nil ? trimmed : nil,
                    targetLanguage: targetLanguage,
                    voice: chosenVoice,
                    audioFileName: saved.fileName,
                    durationSeconds: result.durationSeconds
                )

                self.history = try self.storage.appendHistoryItem(historyItem)
                self.keys = self.keyPool.listKeys()
                self.isBusy = false
                self.busyStatusText = nil

                if shouldQueueAfterCurrent && self.notchPanel?.isVisible == true && self.currentlyPlayingItem != nil {
                    let queued = PlaybackQueueItem(historyItem: historyItem, audioURL: saved.fileURL)
                    self.playbackQueue.append(queued)
                    self.notchPanel?.updateQueueBadge(count: self.playbackQueue.count)
                    self.statusMessage = "New voice ready in queue (+\(self.playbackQueue.count))."
                } else {
                    self.playHistoryItemInNotchHUD(historyItem)
                }
            } catch let error as VoicofskiError {
                guard let self else { return }
                self.keys = self.keyPool.listKeys()
                self.isBusy = false
                self.busyStatusText = nil

                if error == .cancelled {
                    if !shouldQueueAfterCurrent { self.notchPanel?.hidePanel() }
                    return
                }

                if error == .allKeysExhausted {
                    self.saveToPendingQueue(
                        text: originalText ?? trimmed,
                        mode: mode,
                        targetLanguage: targetLanguage,
                        voice: chosenVoice
                    )
                    self.errorMessage = error.localizedDescription
                    if !shouldQueueAfterCurrent {
                        self.ensureNotchPanel().showTransientNotice("All keys exhausted — saved to Queue.")
                    }
                    return
                }

                self.errorMessage = error.localizedDescription
                if !shouldQueueAfterCurrent {
                    self.ensureNotchPanel().showTransientNotice(error.localizedDescription)
                }
            } catch {
                guard let self else { return }
                self.isBusy = false
                self.busyStatusText = nil
                self.errorMessage = error.localizedDescription
                if !shouldQueueAfterCurrent {
                    self.ensureNotchPanel().showTransientNotice(error.localizedDescription)
                }
            }
        }

        await activeGenerationTask?.value
    }

    // MARK: - Translate + Review Pipeline (Focuses Duplix Voicofski Tab Before TTS)

    public func triggerTranslateForReview(text: String, targetLanguage: VoicofskiTargetLanguage? = nil) async {
        let trimmed = VoicofskiTextMetrics.trimmed(text)
        guard VoicofskiTextMetrics.meetsMinimumSelectionLength(trimmed) else {
            errorMessage = "Please enter at least 3 characters."
            return
        }

        guard confirmLongTextIfNeeded(trimmed) else {
            return
        }

        let lang = targetLanguage ?? self.targetLanguage
        self.composerMode = .translate
        self.composerInputText = trimmed
        self.targetLanguage = lang

        refreshKeysAndCooldowns()
        guard !keys.isEmpty else {
            errorMessage = VoicofskiError.noAPIKeys.localizedDescription
            focusVoicofskiInApp()
            return
        }

        let hud = ensureNotchPanel()
        let isCurrentlyPlaying = (hud.isVisible && currentlyPlayingItem != nil)
        if !isCurrentlyPlaying {
            hud.showLoading(status: "Translating to \(lang.displayName)...")
        }

        isBusy = true
        busyStatusText = "Translating to \(lang.displayName)..."
        errorMessage = nil

        let pool = self.keyPool
        let apiClient = self.client

        do {
            let translated = try await pool.executeWithModelFallback(models: VoicofskiModelConfig.translationModels) { apiKey, model in
                try await apiClient.translate(text: trimmed, targetLanguage: lang, model: model, apiKey: apiKey)
            }

            self.keys = self.keyPool.listKeys()
            self.isBusy = false
            self.busyStatusText = nil
            if !isCurrentlyPlaying {
                hud.hidePanel()
            }

            self.translatedReviewText = translated
            self.isAwaitingTranslationReview = true
            self.statusMessage = "Translation ready — review and click Generate Voice."
            self.focusVoicofskiInApp()
        } catch let error as VoicofskiError {
            self.keys = self.keyPool.listKeys()
            self.isBusy = false
            self.busyStatusText = nil

            if error == .allKeysExhausted {
                saveToPendingQueue(text: trimmed, mode: .translate, targetLanguage: lang, voice: selectedVoice)
            }
            self.errorMessage = error.localizedDescription
            if !isCurrentlyPlaying {
                hud.showTransientNotice(error.localizedDescription)
            }
        } catch {
            self.isBusy = false
            self.busyStatusText = nil
            self.errorMessage = error.localizedDescription
            if !isCurrentlyPlaying {
                hud.showTransientNotice(error.localizedDescription)
            }
        }
    }

    public func confirmReviewedTranslationAndSpeak() async {
        let finalText = VoicofskiTextMetrics.trimmed(translatedReviewText)
        guard VoicofskiTextMetrics.meetsMinimumSelectionLength(finalText) else {
            errorMessage = "Translated text is empty."
            return
        }
        let original = VoicofskiTextMetrics.trimmed(composerInputText)
        isAwaitingTranslationReview = false

        await triggerDirectTTS(
            text: finalText,
            voice: selectedVoice,
            translatedFrom: original.isEmpty ? finalText : original,
            targetLanguage: targetLanguage,
            fromSelection: false
        )
    }

    // MARK: - Playback & Queue Control

    public func playHistoryItemInNotchHUD(_ item: VoicofskiHistoryItem) {
        let fileURL = storage.audioURL(forFileName: item.audioFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            errorMessage = "Audio file is missing on disk."
            return
        }

        do {
            try audioPlayer.loadAndPlay(url: fileURL)
            currentlyPlayingItem = item
            ensureNotchPanel().showPlayback(
                isPlaying: audioPlayer.isPlaying,
                duration: audioPlayer.duration,
                rate: audioPlayer.playbackRate,
                queuedCount: playbackQueue.count
            )
        } catch {
            errorMessage = "Could not play audio: \(error.localizedDescription)"
        }
    }

    public func playNextQueuedItem() {
        guard !playbackQueue.isEmpty else { return }
        let next = playbackQueue.removeFirst()
        playHistoryItemInNotchHUD(next.historyItem)
        notchPanel?.updateQueueBadge(count: playbackQueue.count)
    }

    private func handleNotchCloseOrCancel() {
        if isBusy {
            activeGenerationTask?.cancel()
            activeGenerationTask = nil
            isBusy = false
            busyStatusText = nil
        }

        audioPlayer.stop(clearPlayer: true)
        currentlyPlayingItem = nil

        // If another voice is waiting in the playback queue, automatically load & play it now
        if !playbackQueue.isEmpty {
            playNextQueuedItem()
            return
        }

        notchPanel?.hidePanel()
    }

    // MARK: - Pending Quota Queue Management

    private func saveToPendingQueue(
        text: String,
        mode: VoicofskiMode,
        targetLanguage: VoicofskiTargetLanguage?,
        voice: VoicofskiVoice
    ) {
        let req = PendingQuotaRequest(
            text: text,
            mode: mode,
            targetLanguage: targetLanguage,
            voice: voice
        )
        if let updated = try? storage.enqueuePendingRequest(req) {
            pendingQueue = updated
        }
    }

    public func removePendingRequest(id: UUID) {
        if let updated = try? storage.removePendingRequest(id: id) {
            pendingQueue = updated
        }
    }

    public func processPendingRequest(_ request: PendingQuotaRequest) async {
        removePendingRequest(id: request.id)
        if request.mode == .translate {
            await triggerTranslateForReview(text: request.text, targetLanguage: request.targetLanguage ?? targetLanguage)
        } else {
            await triggerDirectTTS(text: request.text, voice: request.voice, fromSelection: false)
        }
    }

    // MARK: - History Management

    public func deleteHistoryItem(id: UUID) {
        if currentlyPlayingItem?.id == id {
            audioPlayer.stop(clearPlayer: true)
            currentlyPlayingItem = nil
            notchPanel?.hidePanel()
        }
        if let updated = try? storage.deleteHistoryItem(id: id) {
            history = updated
        }
    }

    public func exportHistoryItem(_ item: VoicofskiHistoryItem) {
        let sourceURL = storage.audioURL(forFileName: item.audioFileName)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            errorMessage = "Audio file not found."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Voicofski Audio"
        panel.nameFieldStringValue = "voicofski-\(item.voice.shortName.lowercased()).wav"
        panel.allowedContentTypes = [.wav]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let dest = panel.url {
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: sourceURL, to: dest)
                statusMessage = "Exported audio to \(dest.lastPathComponent)."
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    public func openAudioFolder() {
        NSWorkspace.shared.open(storage.audioDirectoryURL)
    }

    // MARK: - API Key Management

    public func addAPIKey(label: String, secret: String) throws {
        _ = try keyPool.addKey(label: label, secret: secret)
        keys = keyPool.listKeys()
        errorMessage = nil
        if !pendingQueue.isEmpty {
            statusMessage = "Key added — \(pendingQueue.count) queued item(s) can now be processed."
        }
    }

    public func removeAPIKey(id: UUID) {
        try? keyPool.removeKey(id: id)
        keys = keyPool.listKeys()
    }

    public func moveAPIKey(id: UUID, direction: Int) {
        try? keyPool.moveKey(id: id, direction: direction)
        keys = keyPool.listKeys()
    }

    public func testAPIKey(id: UUID) async {
        _ = await keyPool.testKey(id: id)
        keys = keyPool.listKeys()
    }

    // MARK: - Navigation Helper

    public func focusVoicofskiInApp() {
        onFocusVoicofskiTabRequested?()
        onOpenMainWindowRequested?()
    }
}
