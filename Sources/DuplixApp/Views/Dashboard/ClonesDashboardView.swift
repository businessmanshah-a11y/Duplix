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
                    .help("Refresh Clones & Check Updates")

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

                // Updates Available Banner
                if !viewModel.outdatedClones.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.outdatedClones.count) Clone Update\(viewModel.outdatedClones.count == 1 ? "" : "s") Available")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("Original apps have been updated. Sync your clones in 1 click with zero data or session loss.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            Task { await viewModel.updateAllClones() }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Update All")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.regular)
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                }

                // Error / Success banners
                if let err = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                        Button("Dismiss") { viewModel.errorMessage = nil }
                            .buttonStyle(.plain)
                            .font(.caption2)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 24)
                }

                if let succ = viewModel.successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(succ)
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                        Button("Dismiss") { viewModel.successMessage = nil }
                            .buttonStyle(.plain)
                            .font(.caption2)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 24)
                }

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
                                updateInfo: viewModel.updateInfos[clone.id],
                                isUpdating: viewModel.isUpdating[clone.id] ?? false,
                                onLaunch: {
                                    Task { await viewModel.launch(clone: clone) }
                                },
                                onUpdate: {
                                    viewModel.cloneToConfirmUpdate = clone
                                },
                                onOpenData: {
                                    Task { await viewModel.openDataDirectory(clone: clone) }
                                },
                                onEditBadge: {
                                    viewModel.cloneToEditBadge = clone
                                },
                                onRepair: {
                                    Task { await viewModel.repairClone(clone: clone) }
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
        .alert("Update Clone?", isPresented: Binding(
            get: { viewModel.cloneToConfirmUpdate != nil },
            set: { if !$0 { viewModel.cloneToConfirmUpdate = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.cloneToConfirmUpdate = nil }
            Button("Update Now") {
                if let c = viewModel.cloneToConfirmUpdate {
                    Task { await viewModel.updateClone(clone: c) }
                    viewModel.cloneToConfirmUpdate = nil
                }
            }
        } message: {
            if let c = viewModel.cloneToConfirmUpdate,
               let info = viewModel.updateInfos[c.id] {
                Text("Update '\(c.name)' to v\(info.sourceVersion)?\n\nAll your logins, accounts, extensions, cookies, and workspace data in '\(c.dataPath)' will remain 100% intact.")
            } else if let c = viewModel.cloneToConfirmUpdate {
                Text("Update '\(c.name)' to the latest version of its source application? All session data will be preserved.")
            }
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
