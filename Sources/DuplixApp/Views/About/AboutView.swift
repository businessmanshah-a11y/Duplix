import SwiftUI
import DuplixCore

public struct AboutView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Brand Banner
                VStack(spacing: 10) {
                    Image(systemName: "square.2.layers.3d")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Duplix")
                        .font(.system(size: 32, weight: .bold))

                    Text("The Free, Native, Open-Source macOS App Cloner")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Version 1.2.0 (Deep Keychain & Session Isolation)")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.top, 30)

                // Feature Highlights
                VStack(spacing: 12) {
                    featureRow(
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        color: .orange,
                        title: "1-Click Clone Updates",
                        desc: "Sync clones when original apps update with zero data, cookie, or session loss."
                    )
                    featureRow(
                        icon: "waveform.circle.fill",
                        color: .red,
                        title: "Voice Memo Companion",
                        desc: "Instant floating AI audio recorder with global ⌥ ⌘ hotkey and auto-chat pasting."
                    )
                    featureRow(
                        icon: "bolt.fill",
                        color: .yellow,
                        title: "APFS Copy-on-Write (CoW)",
                        desc: "Zero extra disk space. Apps duplicate instantly without taking duplicate storage."
                    )
                    featureRow(
                        icon: "lock.shield.fill",
                        color: .green,
                        title: "Complete Session Isolation",
                        desc: "Independent accounts, cookies, cache, and directories for Electron and Native apps."
                    )
                    featureRow(
                        icon: "paintpalette.fill",
                        color: .purple,
                        title: "Distinct Dock Badges",
                        desc: "Color-coded icons and custom labels so you recognize your clones in the Dock."
                    )
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)

                Divider()
                    .frame(maxWidth: 500)

                // Links & Credits
                VStack(spacing: 8) {
                    Text("100% Free & Open-Source under MIT License")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Button("Documentation") {
                            if let url = URL(string: "https://businessmanshah-a11y.github.io/Duplix/") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)

                        Button("GitHub Repository") {
                            if let url = URL(string: "https://github.com/businessmanshah-a11y/Duplix") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
