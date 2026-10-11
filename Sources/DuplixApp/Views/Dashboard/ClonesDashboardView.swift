import SwiftUI
import DuplixCore

public struct ClonesDashboardView: View {
    @ObservedObject public var viewModel: ClonesDashboardViewModel
    public let onBrowseAppsRequested: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 380), spacing: 16)
    ]

    public init(viewModel: ClonesDashboardViewModel, onBrowseAppsRequested: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBrowseAppsRequested = onBrowseAppsRequested
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Clones")
                            .font(.system(size: 26, weight: .bold))
                        Text("\(viewModel.clones.count) isolated app instance\(viewModel.clones.count == 1 ? "" : "s") registered")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        Task { await viewModel.loadClones() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh Clones")

                    Button(action: onBrowseAppsRequested) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("New Clone")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading instances...")
                            .padding(40)
                        Spacer()
                    }
                } else if viewModel.clones.isEmpty {
                    emptyStateView
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.clones) { clone in
                            CloneCardView(
                                clone: clone,
                                onLaunch: {
                                    Task { await viewModel.launch(clone: clone) }
                                },
                                onOpenData: {
                                    Task { await viewModel.openDataDirectory(clone: clone) }
                                },
                                onEditBadge: {
                                    viewModel.cloneToEditBadge = clone
                                },
                                onReset: {
                                    viewModel.cloneToReset = clone
                                },
                                onDelete: {
                                    viewModel.cloneToDelete = clone
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(item: $viewModel.cloneToEditBadge) { clone in
            EditBadgeSheet(
                clone: clone,
                onDismiss: { viewModel.cloneToEditBadge = nil },
                onUpdated: {
                    Task { await viewModel.loadClones() }
                }
            )
        }
        .alert("Reset Session Data?", isPresented: Binding(
            get: { viewModel.cloneToReset != nil },
            set: { if !$0 { viewModel.cloneToReset = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.cloneToReset = nil }
            Button("Reset Data", role: .destructive) {
                if let c = viewModel.cloneToReset {
                    Task { await viewModel.resetData(clone: c) }
                    viewModel.cloneToReset = nil
                }
            }
        } message: {
            if let c = viewModel.cloneToReset {
                Text("This will wipe cookies, sessions, and cache for '\(c.name)'. The clone will launch with a fresh profile. This action cannot be undone.")
            }
        }
        .alert("Delete Clone?", isPresented: Binding(
            get: { viewModel.cloneToDelete != nil },
            set: { if !$0 { viewModel.cloneToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.cloneToDelete = nil }
            Button("Delete", role: .destructive) {
                if let c = viewModel.cloneToDelete {
                    Task { await viewModel.delete(clone: c) }
                    viewModel.cloneToDelete = nil
                }
            }
        } message: {
            if let c = viewModel.cloneToDelete {
                Text("Are you sure you want to delete '\(c.name)'? The application bundle and its isolated data will be deleted.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.dashed")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Clones Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Duplicate any installed macOS application to run independent accounts and projects simultaneously.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button(action: onBrowseAppsRequested) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Browse Installed Apps")
                }
                .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
