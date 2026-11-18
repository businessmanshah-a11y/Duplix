import SwiftUI
import DuplixCore

@MainActor
private final class VoicofskiViewState: ObservableObject {
    enum ListTab: String, CaseIterable {
        case history = "History"
        case queue = "Queue"
    }

    @Published var showingKeysSheet = false
    @Published var showingGuideSheet = false
    @Published var selectedListTab: ListTab = .history
}

public struct VoicofskiView: View {
    @ObservedObject private var engine = VoicofskiEngine.shared
    @StateObject private var uiState = VoicofskiViewState()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !engine.hasAccessibilityPermission {
                        accessibilityBanner
                    }

                    if engine.keys.isEmpty {
                        missingKeysBanner
                    }

                    if let error = engine.errorMessage {
                        noticeStrip(text: error, isError: true) {
                            engine.errorMessage = nil
                        }
                    } else if let status = engine.statusMessage {
                        noticeStrip(text: status, isError: false) {
                            engine.statusMessage = nil
                        }
                    }

                    composerCard
                    historyAndQueueSection
                }
                .padding(22)
            }
        }
        .onAppear {
            engine.refreshPermissions()
            engine.refreshKeysAndCooldowns()
        }
        .sheet(isPresented: $uiState.showingKeysSheet) {
            APIKeysSheet(engine: engine, onOpenGuide: {
                uiState.showingKeysSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    uiState.showingGuideSheet = true
                }
            })
        }
        .sheet(isPresented: $uiState.showingGuideSheet) {
            AIStudioGuideSheet()
        }
    }

    // MARK: - Top Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Voicofski")
                    .font(.headline)
                Text("Select text anywhere or type below")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Voice Picker (Lora / Bodi)
            Picker("Voice", selection: $engine.selectedVoice) {
                ForEach(VoicofskiVoice.allCases) { voice in
                    Text(voice.shortName).tag(voice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 120)
            .help("Select AI voice: Lora (Female) or Bodi (Male)")

            // API Keys button
            Button {
                uiState.showingKeysSheet = true
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(engine.activeKeyCount > 0 ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text("\(engine.activeKeyCount)/\(engine.keys.count) Keys")
                        .font(.caption.weight(.medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // Quick Setup Guide button
            Button {
                uiState.showingGuideSheet = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Google AI Studio API Key Guide")

            // Selection Trigger Toggle
            Toggle("", isOn: $engine.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .help("Enable system-wide text selection trigger")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    // MARK: - Compact Banners

    private var accessibilityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .foregroundColor(.orange)
            Text("Enable Accessibility to show the floating icon on text selection.")
                .font(.caption)
            Spacer()
            Button("Grant") {
                engine.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var missingKeysBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundColor(.accentColor)
            Text("Add a free Google AI Studio API key to generate voices.")
                .font(.caption)
            Spacer()
            Button("Guide") {
                uiState.showingGuideSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Add Key") {
                uiState.showingKeysSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
        )
    }

    private func noticeStrip(text: String, isError: Bool, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .green)
            Text(text)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill((isError ? Color.red : Color.green).opacity(0.1))
        )
    }

    // MARK: - Composer Card

    private var composerCard: some View {
        let wordCount = VoicofskiTextMetrics.wordCount(engine.composerInputText)
        let isLong = wordCount > VoicofskiTextMetrics.longTextWordThreshold

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Mode", selection: $engine.composerMode) {
                    ForEach(VoicofskiMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)

                if engine.composerMode == .translate {
                    Picker("Target", selection: $engine.targetLanguage) {
                        ForEach(VoicofskiTargetLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                Spacer()

                if wordCount > 0 {
                    Text("\(wordCount) words")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(isLong ? .orange : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(isLong ? Color.orange.opacity(0.16) : Color.secondary.opacity(0.1))
                        )
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $engine.composerInputText)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 86, maxHeight: 150)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(NSColor.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )

                if engine.composerInputText.isEmpty {
                    Text("Paste or type text here...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            if isLong {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Over 500 words — may hit token or daily quota limits.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            // Translation Review Area (Shown after Translate button or Translate selection)
            if engine.isAwaitingTranslationReview {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Translation (\(engine.targetLanguage.displayName))", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Button("Discard") {
                            engine.isAwaitingTranslationReview = false
                            engine.translatedReviewText = ""
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    TextEditor(text: $engine.translatedReviewText)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 72, maxHeight: 130)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.accentColor.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                        )
                }
            }

            HStack {
                if !engine.composerInputText.isEmpty {
                    Button("Clear") {
                        engine.composerInputText = ""
                        engine.translatedReviewText = ""
                        engine.isAwaitingTranslationReview = false
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if engine.isBusy {
                    ProgressView()
                        .controlSize(.small)
                    if let busy = engine.busyStatusText {
                        Text(busy)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if engine.isAwaitingTranslationReview {
                    Button {
                        Task { await engine.confirmReviewedTranslationAndSpeak() }
                    } label: {
                        Label("Generate Voice", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else if engine.composerMode == .translate {
                    Button {
                        Task { await engine.triggerTranslateForReview(text: engine.composerInputText) }
                    } label: {
                        Label("Translate", systemImage: "globe")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!VoicofskiTextMetrics.meetsMinimumSelectionLength(engine.composerInputText))
                } else {
                    Button {
                        Task { await engine.triggerDirectTTS(text: engine.composerInputText) }
                    } label: {
                        Label("Generate Voice", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!VoicofskiTextMetrics.meetsMinimumSelectionLength(engine.composerInputText))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - History & Pending Queue Section

    private var historyAndQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: $uiState.selectedListTab) {
                    Text("History (\(engine.history.count))").tag(VoicofskiViewState.ListTab.history)
                    Text("Pending Queue (\(engine.pendingQueue.count))").tag(VoicofskiViewState.ListTab.queue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)

                Spacer()

                if uiState.selectedListTab == .history && !engine.history.isEmpty {
                    Button {
                        engine.openAudioFolder()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Open Audio Folder")
                }
            }

            if uiState.selectedListTab == .history {
                if engine.history.isEmpty {
                    emptyState(icon: "waveform", title: "No voices yet")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(engine.history) { item in
                            historyRow(item)
                        }
                    }
                }
            } else {
                if engine.pendingQueue.isEmpty {
                    emptyState(icon: "tray", title: "Queue is empty")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(engine.pendingQueue) { req in
                            pendingRow(req)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ item: VoicofskiHistoryItem) -> some View {
        HStack(spacing: 12) {
            Button {
                engine.playHistoryItemInNotchHUD(item)
            } label: {
                Image(systemName: engine.currentlyPlayingItem?.id == item.id ? "waveform" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Play in Notch HUD")

            VStack(alignment: .leading, spacing: 3) {
                Text(item.spokenText)
                    .font(.system(size: 12.5))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.voice.shortName)
                    Text("·")
                    Text(item.formattedDuration)
                    if let lang = item.targetLanguage {
                        Text("·")
                        Text(lang.displayName)
                    }
                    Text("·")
                    Text(item.createdAt, style: .relative)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.spokenText, forType: .string)
                    engine.statusMessage = "Text copied."
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy Text")

                Button {
                    engine.exportHistoryItem(item)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("Export WAV")

                Button {
                    engine.deleteHistoryItem(id: item.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func pendingRow(_ req: PendingQuotaRequest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text(req.text)
                    .font(.system(size: 12.5))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(req.mode.displayName)
                    if let lang = req.targetLanguage {
                        Text("→ \(lang.displayName)")
                    }
                    Text("· \(req.voice.shortName)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button("Run") {
                Task { await engine.processPendingRequest(req) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(engine.isBusy)

            Button {
                engine.removePendingRequest(id: req.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func emptyState(icon: String, title: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.secondary.opacity(0.6))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 28)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
    }
}
