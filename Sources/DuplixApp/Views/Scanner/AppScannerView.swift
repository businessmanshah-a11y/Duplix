import SwiftUI
import DuplixCore

public struct AppScannerView: View {
    @ObservedObject public var viewModel: AppScannerViewModel
    public let onCloneCreated: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 14)
    ]

    public init(viewModel: AppScannerViewModel, onCloneCreated: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCloneCreated = onCloneCreated
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search installed apps...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Filter Picker
                Picker("", selection: $viewModel.selectedFilter) {
                    ForEach(AppScannerViewModel.EngineFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Button(action: {
                    Task { await viewModel.scanApplications() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Rescan Applications")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // App Grid / List
            ScrollView {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Scanning /Applications...")
                            .padding(40)
                        Spacer()
                    }
                } else if viewModel.filteredApps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No Applications Found")
                            .font(.headline)
                        Text("Try searching with another keyword or change the filter.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(50)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.filteredApps, id: \.bundleIdentifier) { app in
                            appRowCard(app: app)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(item: $viewModel.appToClone) { app in
            CloneCreatorSheet(
                sourceApp: app,
                onDismiss: { viewModel.appToClone = nil },
                onCreated: {
                    onCloneCreated()
                }
            )
        }
    }

    @ViewBuilder
    private func appRowCard(app: AppMetadata) -> some View {
        HStack(spacing: 12) {
            IconBadgePreviewView(
                appURL: app.bundleURL,
                badgeConfig: nil,
                size: 46
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    engineBadge(engine: app.engineType)

                    if let ver = app.version {
                        Text("v\(ver)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button(action: { viewModel.appToClone = app }) {
                Text("Clone")
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func engineBadge(engine: EngineType) -> some View {
        let (color, title): (Color, String) = {
            switch engine {
            case .electron: return (.purple, "Electron")
            case .gecko: return (.orange, "Gecko")
            case .nativeCocoa: return (.blue, "Native")
            case .unknown: return (.gray, "Generic")
            }
        }()

        Text(title)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
