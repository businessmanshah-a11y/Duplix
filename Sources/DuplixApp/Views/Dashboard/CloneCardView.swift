import SwiftUI
import DuplixCore

public struct CloneCardView: View {
    public let clone: CloneRecord
    public let onLaunch: () -> Void
    public let onOpenData: () -> Void
    public let onEditBadge: () -> Void
    public let onReset: () -> Void
    public let onDelete: () -> Void

    public init(
        clone: CloneRecord,
        onLaunch: @escaping () -> Void,
        onOpenData: @escaping () -> Void,
        onEditBadge: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.clone = clone
        self.onLaunch = onLaunch
        self.onOpenData = onOpenData
        self.onEditBadge = onEditBadge
        self.onReset = onReset
        self.onDelete = onDelete
    }

    private var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: clone.appPath)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Icon + Info
            HStack(spacing: 14) {
                IconBadgePreviewView(
                    appURL: URL(fileURLWithPath: clone.appPath),
                    badgeConfig: clone.badgeConfig,
                    size: 54
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(clone.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(clone.sourceAppName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        enginePill(engine: clone.engineType)

                        if existsOnDisk {
                            Text("Ready")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("Missing")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }

                Spacer()
            }

            Divider()

            // Info details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Data: ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text((clone.dataPath as NSString).lastPathComponent)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                if let last = clone.lastLaunchedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Launched: \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Controls Bar
            HStack(spacing: 8) {
                Button(action: onLaunch) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Launch")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!existsOnDisk)

                Spacer()

                Button(action: onOpenData) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Open data directory in Finder")

                Button(action: onEditBadge) {
                    Image(systemName: "paintpalette")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Customize Dock badge")

                Menu {
                    Button("Reset Session Data...", role: .destructive, action: onReset)
                    Divider()
                    Button("Delete Clone...", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func enginePill(engine: EngineType) -> some View {
        let (color, text): (Color, String) = {
            switch engine {
            case .electron: return (.purple, "Electron")
            case .gecko: return (.orange, "Gecko")
            case .nativeCocoa: return (.blue, "Native")
            case .unknown: return (.gray, "Generic")
            }
        }()

        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
