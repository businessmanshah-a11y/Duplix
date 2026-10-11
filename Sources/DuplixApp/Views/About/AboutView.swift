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

                    Text("Version 1.0.0 (Phase 3 Native SwiftUI)")
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
                    featureRow(
                        icon: "cpu.fill",
                        color: .blue,
                        title: "Apple Silicon Native",
                        desc: "Ad-hoc code signing and Gatekeeper compliance for M1/M2/M3/M4 & Intel Macs."
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
                            NSWorkspace.shared.open(URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/docs"))
                        }
                        .buttonStyle(.link)

                        Button("GitHub Project") {
                            if let url = URL(string: "https://github.com") {
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
