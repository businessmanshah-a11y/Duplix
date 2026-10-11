import SwiftUI
import DuplixCore

@MainActor
public final class EditBadgeFormState: ObservableObject {
    @Published public var selectedColor: BadgeColor
    @Published public var badgeText: String
    @Published public var customHex: String = ""
    @Published public var isSaving: Bool = false
    @Published public var errorMessage: String? = nil

    public init(initialColor: BadgeColor, initialText: String) {
        self.selectedColor = initialColor
        self.badgeText = initialText
    }

    public var currentConfig: BadgeConfig {
        BadgeConfig(
            color: selectedColor,
            text: badgeText.isEmpty ? nil : badgeText,
            position: .bottomRight
        )
    }
}

public struct EditBadgeSheet: View {
    public let clone: CloneRecord
    public let onDismiss: () -> Void
    public let onUpdated: () -> Void

    @StateObject private var form: EditBadgeFormState
    private let manager = DuplixManager.shared

    public init(clone: CloneRecord, onDismiss: @escaping () -> Void, onUpdated: @escaping () -> Void) {
        self.clone = clone
        self.onDismiss = onDismiss
        self.onUpdated = onUpdated
        _form = StateObject(wrappedValue: EditBadgeFormState(
            initialColor: clone.badgeConfig?.color ?? .blue,
            initialText: clone.badgeConfig?.text ?? ""
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                IconBadgePreviewView(
                    appURL: URL(fileURLWithPath: clone.appPath),
                    badgeConfig: form.currentConfig,
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Dock Badge")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(clone.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // Color Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Badge Color")
                        .font(.headline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                        ForEach(BadgeColor.palette, id: \.name) { color in
                            Button(action: {
                                form.selectedColor = color
                                form.customHex = ""
                            }) {
                                Circle()
                                    .fill(Color(cgColor: color.cgColor))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: form.selectedColor == color ? 3 : 0)
                                    )
                                    .shadow(color: form.selectedColor == color ? Color.black.opacity(0.3) : .clear, radius: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Custom HEX:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("#007AFF", text: $form.customHex)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: form.customHex) { newValue in
                                if !newValue.isEmpty {
                                    form.selectedColor = BadgeColor.fromNameOrHex(newValue)
                                }
                            }
                    }
                }

                // Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Badge Label / Text")
                        .font(.headline)
                    TextField("e.g. 1, DEV, WORK", text: $form.badgeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }

                if let err = form.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding(20)

            Divider()

            // Footer
            HStack {
                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: saveBadge) {
                    HStack(spacing: 8) {
                        if form.isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Apply to Dock")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(form.isSaving)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 440, height: 420)
    }

    private func saveBadge() {
        form.isSaving = true
        form.errorMessage = nil

        Task {
            do {
                _ = try await manager.updateBadge(identifierOrName: clone.id.uuidString, badgeConfig: form.currentConfig)
                await MainActor.run {
                    form.isSaving = false
                    onUpdated()
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    form.isSaving = false
                    form.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
