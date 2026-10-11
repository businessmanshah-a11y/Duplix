import Foundation
import DuplixCore

public enum NavigationSection: String, Hashable, CaseIterable {
    case clones = "My Clones"
    case scanner = "Installed Apps"
    case about = "About Duplix"

    public var icon: String {
        switch self {
        case .clones: return "square.2.layers.3d"
        case .scanner: return "apps.ipad"
        case .about: return "info.circle"
        }
    }
}

@MainActor
public final class ClonesDashboardViewModel: ObservableObject {
    @Published public var clones: [CloneRecord] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var cloneToEditBadge: CloneRecord? = nil
    @Published public var cloneToReset: CloneRecord? = nil
    @Published public var cloneToDelete: CloneRecord? = nil
    @Published public var selectedSection: NavigationSection = .clones

    private let manager = DuplixManager.shared

    public init() {
        Task {
            await loadClones()
        }
    }

    public func loadClones() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.clones = try await manager.listClones()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func launch(clone: CloneRecord) async {
        do {
            try await manager.launchClone(identifierOrName: clone.id.uuidString)
            await loadClones()
        } catch {
            self.errorMessage = "Failed to launch: \(error.localizedDescription)"
        }
    }

    public func openDataDirectory(clone: CloneRecord) async {
        do {
            try await manager.openDataDirectory(identifierOrName: clone.id.uuidString)
        } catch {
            self.errorMessage = "Failed to open data folder: \(error.localizedDescription)"
        }
    }

    public func resetData(clone: CloneRecord) async {
        do {
            try await manager.resetData(identifierOrName: clone.id.uuidString)
            await loadClones()
        } catch {
            self.errorMessage = "Failed to reset session data: \(error.localizedDescription)"
        }
    }

    public func delete(clone: CloneRecord) async {
        do {
            try await manager.deleteClone(identifierOrName: clone.id.uuidString, deleteData: true)
            await loadClones()
        } catch {
            self.errorMessage = "Failed to delete clone: \(error.localizedDescription)"
        }
    }

    public func updateBadge(clone: CloneRecord, config: BadgeConfig) async {
        do {
            _ = try await manager.updateBadge(identifierOrName: clone.id.uuidString, badgeConfig: config)
            await loadClones()
        } catch {
            self.errorMessage = "Failed to update badge: \(error.localizedDescription)"
        }
    }
}
