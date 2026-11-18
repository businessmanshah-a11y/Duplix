import SwiftUI
import DuplixCore

public struct AIStudioGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Get Your Free API Key")
                    .font(.headline)
                Spacer()
                Button("Open AI Studio") {
                    if let url = URL(string: VoicofskiModelConfig.apiKeyStudioURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: "1", title: "Open Google AI Studio", detail: "Sign in with your Gmail account at aistudio.google.com/apikey.")
                stepRow(number: "2", title: "Create API Key", detail: "Click \"Create API key\" and copy the generated key.")
                stepRow(number: "3", title: "Paste into Voicofski", detail: "Open Keys in Voicofski and save it securely in macOS Keychain.")
                stepRow(number: "4", title: "Add Multiple Keys (Optional)", detail: "Add keys from extra Gmail accounts — Voicofski switches automatically when daily quota runs out.")
            }

            HStack {
                Text("Tip: Make sure your VPN is connected if Google AI Studio is restricted in your region.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
