import SwiftUI
import AppKit

@MainActor
public final class VoiceMemoViewModel: ObservableObject {
    @Published public var isRunning: Bool = false
    private var monitoringTask: Task<Void, Never>? = nil

    public init() {
        checkStatus()
        startMonitoring()
    }

    deinit {
        monitoringTask?.cancel()
    }

    public func startMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.checkStatus()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    public func checkStatus() {
        let runningApps = NSWorkspace.shared.runningApplications
        self.isRunning = runningApps.contains { app in
            app.bundleIdentifier == "com.duplix.voicememo" ||
            app.localizedName == "VoiceMemoApp" ||
            app.localizedName == "VoiceMemo"
        }
    }

    public func launchVoiceMemo() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidatePaths = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/VoiceMemo.app").path,
            home.appendingPathComponent("Applications/VoiceMemo.app").path,
            "/Applications/VoiceMemo.app",
            home.appendingPathComponent("Duplix/scripts/voice_memo/VoiceMemo.app").path
        ]

        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = [path]
                try? process.run()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.checkStatus()
                }
                return
            }
        }
    }

    public func quitVoiceMemo() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if app.bundleIdentifier == "com.duplix.voicememo" ||
               app.localizedName == "VoiceMemoApp" ||
               app.localizedName == "VoiceMemo" {
                app.terminate()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkStatus()
        }
    }

    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

public struct VoiceMemoView: View {
    @StateObject private var model = VoiceMemoViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 3)

                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Voice Memo Companion")
                                .font(.system(size: 24, weight: .bold))

                            Text("Built-in")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.18))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }

                        Text("Instant floating AI voice recorder with global Option+Command hotkey.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Status Banner Card
                HStack(spacing: 16) {
                    Circle()
                        .fill(model.isRunning ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.isRunning ? "Voice Memo is Active in Menu Bar (🎙️)" : "Voice Memo is Currently Stopped")
                            .font(.headline)
                        Text(model.isRunning ? "Press ⌥ ⌘ anywhere to start recording." : "Click below to start the background helper.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if model.isRunning {
                        Button("Restart Helper", action: {
                            model.quitVoiceMemo()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                model.launchVoiceMemo()
                            }
                        })
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button("Stop", role: .destructive, action: model.quitVoiceMemo)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                    } else {
                        Button(action: model.launchVoiceMemo) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Launch Voice Memo")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.regular)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(model.isRunning ? Color.green.opacity(0.25) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                // Global Shortcut Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Global Trigger")
                        .font(.headline)

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text("⌥")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.windowBackgroundColor))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

                            Text("+")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("⌘")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.windowBackgroundColor))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Option + Command (Toggle Recording)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Works globally across all windows, editors, and fullscreen apps.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                // Features Grid
                VStack(alignment: .leading, spacing: 14) {
                    Text("How It Works")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(
                            icon: "wand.and.stars",
                            color: .purple,
                            title: "Auto-Attach to Active Chat",
                            desc: "When you finish talking, it copies the compressed audio file to the system clipboard and simulates ⌘V to instantly attach it into your focused AI prompt (Antigravity IDE, Cursor, Claude, Slack)."
                        )

                        Divider()

                        featureRow(
                            icon: "waveform",
                            color: .orange,
                            title: "Live Dancing Waveform HUD",
                            desc: "A sleek translucent floating pill panel appears on your screen with real-time audio visualization bars and a recording timer."
                        )

                        Divider()

                        featureRow(
                            icon: "mic.fill",
                            color: .blue,
                            title: "Studio AAC Compression",
                            desc: "High-clarity compressed .m4a format that sounds crystal clear while remaining under 100 KB for typical voice memos."
                        )

                        Divider()

                        featureRow(
                            icon: "lock.shield",
                            color: .green,
                            title: "System Microphone Permissions",
                            desc: "Requires microphone access in macOS Security & Privacy."
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )

                    Button("Open Microphone Security Settings...", action: model.openMicrophoneSettings)
                        .buttonStyle(.link)
                        .font(.caption)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            model.startMonitoring()
        }
        .onDisappear {
            model.stopMonitoring()
        }
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
