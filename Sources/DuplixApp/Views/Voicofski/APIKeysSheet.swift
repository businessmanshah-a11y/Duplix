import SwiftUI
import DuplixCore

@MainActor
private final class APIKeysSheetState: ObservableObject {
    @Published var newLabel: String = ""
    @Published var newSecret: String = ""
    @Published var testingKeyID: UUID? = nil
    @Published var localError: String? = nil
}

public struct APIKeysSheet: View {
    @ObservedObject var engine: VoicofskiEngine
    let onOpenGuide: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var form = APIKeysSheetState()

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google AI Studio API Keys")
                        .font(.headline)
                    Text("Stored in macOS Keychain · Auto-switches sequentially on daily quota")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Setup Guide") {
                    onOpenGuide()
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            // Add Key Form
            HStack(spacing: 8) {
                TextField("Label (e.g. Gmail 1)", text: $form.newLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                SecureField("Paste AIza... API key", text: $form.newSecret)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    addKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(form.newSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let localError = form.localError {
                Text(localError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            if engine.keys.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No API keys added yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(engine.keys.enumerated()), id: \.element.id) { index, key in
                            keyRow(key, index: index, total: engine.keys.count)
                        }
                    }
                }
                .frame(minHeight: 160, maxHeight: 260)
            }

            HStack {
                Text("Exhausted keys reset automatically at 09:00 UTC.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    private func keyRow(_ key: APIKeyMetadata, index: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            Text("#\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 22)

            Circle()
                .fill(statusColor(for: key.status))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(key.label)
                    .font(.subheadline.weight(.medium))

                Text(statusSubtitle(for: key))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if form.testingKeyID == key.id {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 44)
            } else {
                Button("Test") {
                    form.testingKeyID = key.id
                    Task {
                        await engine.testAPIKey(id: key.id)
                        form.testingKeyID = nil
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 2) {
                Button {
                    engine.moveAPIKey(id: key.id, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)

                Button {
                    engine.moveAPIKey(id: key.id, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(index == total - 1)
            }

            Button {
                engine.removeAPIKey(id: key.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func addKey() {
        do {
            try engine.addAPIKey(label: form.newLabel, secret: form.newSecret)
            form.newLabel = ""
            form.newSecret = ""
            form.localError = nil
        } catch {
            form.localError = error.localizedDescription
        }
    }

    private func statusColor(for status: APIKeyHealthStatus) -> Color {
        switch status {
        case .active: return .green
        case .untested: return .blue
        case .exhausted: return .orange
        case .invalid: return .red
        }
    }

    private func statusSubtitle(for key: APIKeyMetadata) -> String {
        switch key.status {
        case .active:
            return "Active"
        case .untested:
            return "Ready (untested)"
        case .exhausted:
            if let resetAt = key.nextResetAt {
                let fmt = DateFormatter()
                fmt.timeStyle = .short
                fmt.dateStyle = .none
                return "Quota reached · Resets ~\(fmt.string(from: resetAt))"
            }
            return "Quota reached"
        case .invalid:
            return key.lastError ?? "Invalid key"
        }
    }
}
