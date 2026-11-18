import SwiftUI
import AppKit

public struct VoiceMemoView: View {
    @ObservedObject private var engine = VoiceMemoEngine.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                statusBannerCard

                if let error = engine.errorMessage {
                    feedbackBanner(text: error, isError: true)
                } else if let status = engine.statusMessage {
                    feedbackBanner(text: status, isError: false)
                }

                permissionsCard
                startupSettingsCard

                if let last = engine.lastRecording {
                    lastRecordingCard(last)
                }

                shortcutCard
                featuresCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            engine.refreshPermissions()
            engine.startPermissionMonitoring()
        }
        .onDisappear {
            engine.stopPermissionMonitoring()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: engine.isRecording ? [Color.red, Color.pink] : [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 3)

                Image(systemName: engine.isRecording ? "mic.fill" : "waveform.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Voice Memo")
                        .font(.system(size: 24, weight: .bold))

                    Text("Native Engine")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }

                Text("Built directly into Duplix — instant floating AI voice recorder with global ⌥⌘ hotkey.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Status Banner Card

    private var statusBannerCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(statusIndicatorColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if engine.isRecording {
                Button(action: { engine.stopRecording(attach: true) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Stop & Attach")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Cancel") {
                    engine.stopRecording(attach: false)
                }
                .buttonStyle(.bordered)
            } else if engine.isEnabled {
                Button(action: { engine.startRecording() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                        Text("Record Now")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Stop", role: .destructive) {
                    engine.stop()
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: { engine.start() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Enable Voice Memo")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
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
                .strokeBorder(statusBorderColor, lineWidth: 1)
        )
    }

    private var statusIndicatorColor: Color {
        if engine.isRecording { return .red }
        return engine.isEnabled ? .green : .secondary.opacity(0.5)
    }

    private var statusBorderColor: Color {
        if engine.isRecording { return .red.opacity(0.45) }
        return engine.isEnabled ? .green.opacity(0.28) : .white.opacity(0.1)
    }

    private var statusTitle: String {
        if engine.isRecording {
            let formatted = String(format: "%02d:%02d", engine.elapsedSeconds / 60, engine.elapsedSeconds % 60)
            return "Recording in Progress (\(formatted))"
        }
        return engine.isEnabled ? "Voice Memo is Active in Menu Bar (🎙️)" : "Voice Memo is Currently Off"
    }

    private var statusSubtitle: String {
        if engine.isRecording {
            return "Press ⌥⌘ to stop & auto-attach, or Esc to cancel."
        }
        return engine.isEnabled
            ? "Stays active even when you close this window. Press ⌥⌘ anywhere to record."
            : "Enable to show the 🎙️ menu bar icon and activate the global ⌥⌘ shortcut."
    }

    // MARK: - Feedback Banner

    private func feedbackBanner(text: String, isError: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .green)
            Text(text)
                .font(.caption)
                .foregroundColor(isError ? .red : .primary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((isError ? Color.red : Color.green).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder((isError ? Color.red : Color.green).opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Permissions Card

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("macOS Permissions")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    engine.refreshPermissions()
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            VStack(spacing: 12) {
                // Microphone permission row
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundColor(engine.microphoneStatus == .granted ? .green : .orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Microphone Access")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            permissionBadge(
                                granted: engine.microphoneStatus == .granted,
                                deniedText: engine.microphoneStatus == .denied ? "Denied" : "Not Requested"
                            )
                        }
                        Text("Required to capture voice audio for your AI prompts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if engine.microphoneStatus == .granted {
                        Button("Settings") {
                            engine.openMicrophoneSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button(engine.microphoneStatus == .denied ? "Open Settings" : "Grant Access") {
                            engine.requestMicrophonePermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                }

                Divider()

                // Accessibility permission row
                HStack(spacing: 12) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.title3)
                        .foregroundColor(engine.hasAccessibilityPermission ? .green : .orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Accessibility (Global ⌥⌘ & Auto-Paste)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            permissionBadge(
                                granted: engine.hasAccessibilityPermission,
                                deniedText: "Action Needed"
                            )
                        }
                        Text("Enables the global ⌥⌘ hotkey across all apps and automatic ⌘V pasting into chats.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if engine.hasAccessibilityPermission {
                        Button("Settings") {
                            engine.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Grant Access") {
                            engine.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
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
        }
    }

    private func permissionBadge(granted: Bool, deniedText: String) -> some View {
        Text(granted ? "Granted" : deniedText)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((granted ? Color.green : Color.orange).opacity(0.18))
            .foregroundColor(granted ? .green : .orange)
            .clipShape(Capsule())
    }

    // MARK: - Startup & Background Settings

    private var startupSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Startup & Background")
                .font(.headline)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Voice Memo automatically at macOS Login")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Silently launches Duplix in the menu bar after system restarts so ⌥⌘ is always ready.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { engine.launchAtLogin },
                        set: { engine.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activate Voice Memo when Duplix opens")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Automatically shows the 🎙️ menu bar icon and keeps it running if you close this window.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $engine.autoStartWithDuplix)
                        .labelsHidden()
                        .toggleStyle(.switch)
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
        }
    }

    // MARK: - Last Recording Card

    private func lastRecordingCard(_ info: LastRecordingInfo) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.badge.mic")
                .font(.title2)
                .foregroundColor(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Last Voice Memo")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Duration: \(info.formattedDuration) • Size: \(info.formattedSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Copy Again") {
                engine.recopyLastRecording()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Global Shortcut Card

    private var shortcutCard: some View {
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
                    Text("Works globally across all windows, Spaces, and fullscreen apps. Press Esc to cancel.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
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
        }
    }

    // MARK: - How It Works Card

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How It Works")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(
                    icon: "wand.and.stars",
                    color: .purple,
                    title: "Auto-Attach to Active Chat",
                    desc: "When you finish talking, it copies the compressed .m4a file to your clipboard and simulates ⌘V to instantly attach it into Antigravity IDE, Cursor, Claude, or Slack."
                )

                Divider()

                featureRow(
                    icon: "waveform",
                    color: .orange,
                    title: "Fullscreen-Ready Floating HUD",
                    desc: "A translucent floating pill appears on your active screen — even over fullscreen apps — with live audio waveform bars and a recording timer."
                )

                Divider()

                featureRow(
                    icon: "mic.fill",
                    color: .blue,
                    title: "Studio AAC Compression",
                    desc: "High-clarity mono 44.1 kHz AAC (.m4a) that stays crisp and lightweight (typically under 100 KB)."
                )

                Divider()

                featureRow(
                    icon: "shield.checkered",
                    color: .green,
                    title: "Unified Single-App Architecture",
                    desc: "Runs natively inside Duplix with a single macOS permission identity — no nested helper crashes or duplicate TCC entries."
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
