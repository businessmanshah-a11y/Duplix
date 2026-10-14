import SwiftUI
import DuplixCore

@MainActor
public final class CloneCreatorFormState: ObservableObject {
    @Published public var cloneName: String
    @Published public var cloneCount: Int = 1
    @Published public var selectedColor: BadgeColor = .blue
    @Published public var customHex: String = ""
    @Published public var badgeText: String = "1"
    @Published public var autoNumberBadges: Bool = true
    @Published public var isCreating: Bool = false
    @Published public var errorMessage: String? = nil

    public init(defaultName: String) {
        self.cloneName = defaultName
    }

    public var currentBadgeConfig: BadgeConfig {
        BadgeConfig(
            color: selectedColor,
            text: autoNumberBadges ? (badgeText.isEmpty ? "1" : badgeText) : (badgeText.isEmpty ? nil : badgeText),
            position: .bottomRight
        )
    }
}

public struct CloneCreatorSheet: View {
    public let sourceApp: AppMetadata
    public let onDismiss: () -> Void
    public let onCreated: () -> Void

    @StateObject private var form: CloneCreatorFormState
    private let manager = DuplixManager.shared

    public init(sourceApp: AppMetadata, onDismiss: @escaping () -> Void, onCreated: @escaping () -> Void) {
        self.sourceApp = sourceApp
        self.onDismiss = onDismiss
        self.onCreated = onCreated
        _form = StateObject(wrappedValue: CloneCreatorFormState(defaultName: "\(sourceApp.displayName) (Clone 1)"))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                IconBadgePreviewView(
                    appURL: sourceApp.bundleURL,
                    badgeConfig: form.currentBadgeConfig,
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Clone \(sourceApp.displayName)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(sourceApp.bundleIdentifier)
                        .font(.caption)
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

            // Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Clone Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clone Display Name")
                            .font(.headline)
                        TextField("Clone Name", text: $form.cloneName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Clone Count
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Number of Instances:")
                                .font(.headline)
                            Spacer()
                            Text("\(form.cloneCount) instance\(form.cloneCount > 1 ? "s" : "")")
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                        }

                        Stepper("", value: $form.cloneCount, in: 1...5)
                            .labelsHidden()

                        Text("Instant APFS Copy-on-Write: clones take zero extra disk space.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Badge Color Palette
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dock Badge Color")
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

                    // Badge Text/Number
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badge Label")
                            .font(.headline)

                        Toggle("Auto-number clones (1, 2, 3...)", isOn: $form.autoNumberBadges)
                            .toggleStyle(.checkbox)

                        if !form.autoNumberBadges {
                            HStack {
                                Text("Custom Text:")
                                    .font(.subheadline)
                                TextField("e.g. WORK, DEV", text: $form.badgeText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }
                    }

                    if let err = form.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: createClones) {
                    HStack(spacing: 8) {
                        if form.isCreating {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(form.isCreating ? "Cloning..." : "Create Clone\(form.cloneCount > 1 ? "s (\(form.cloneCount))" : "")")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(form.isCreating || form.cloneName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480, height: 530)
        .task {
            let existing = (try? await manager.loadRegistry()) ?? []
            let matchingCount = existing.filter { $0.sourceAppName == sourceApp.displayName }.count
            let nextIndex = matchingCount + 1
            if form.cloneName == "\(sourceApp.displayName) (Clone 1)" && nextIndex > 1 {
                form.cloneName = "\(sourceApp.displayName) (Clone \(nextIndex))"
                form.badgeText = "\(nextIndex)"
                form.selectedColor = BadgeColor.defaultForIndex(nextIndex)
            }
        }
    }

    private func createClones() {
        form.isCreating = true
        form.errorMessage = nil

        Task {
            do {
                let existing = (try? await manager.loadRegistry()) ?? []
                let matchingCount = existing.filter { $0.sourceAppName == sourceApp.displayName }.count

                for i in 1...form.cloneCount {
                    let nextIndex = matchingCount + i
                    let name = form.cloneCount == 1 ? form.cloneName : "\(form.cloneName) \(nextIndex)"
                    let color = (form.cloneCount > 1 && form.customHex.isEmpty) ? BadgeColor.defaultForIndex(nextIndex) : form.selectedColor
                    let text = form.autoNumberBadges ? "\(nextIndex)" : (form.badgeText.isEmpty ? nil : form.badgeText)
                    let config = BadgeConfig(color: color, text: text, position: .bottomRight)

                    _ = try await manager.createClone(
                        sourceAppURL: sourceApp.bundleURL,
                        customName: name,
                        badgeConfig: config,
                        overwrite: true
                    )
                }

                await MainActor.run {
                    form.isCreating = false
                    onCreated()
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    form.isCreating = false
                    form.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
