import Foundation
import DuplixCore

public enum NavigationSection: String, Hashable, CaseIterable {
    case clones = "My Clones"
    case scanner = "Installed Apps"
    case voiceMemo = "Voice Memo"
    case about = "About Duplix"

    public var icon: String {
        switch self {
        case .clones: return "square.2.layers.3d"
        case .scanner: return "apps.ipad"
        case .voiceMemo: return "waveform"
        case .about: return "info.circle"
        }
    }
}

@MainActor
public final class ClonesDashboardViewModel: ObservableObject {
    @Published public var clones: [CloneRecord] = []
    @Published public var updateInfos: [UUID: CloneVersionInfo] = [:]
    @Published public var isUpdating: [UUID: Bool] = [:]
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil
    @Published public var cloneToEditBadge: CloneRecord? = nil
    @Published public var cloneToReset: CloneRecord? = nil
    @Published public var cloneToDelete: CloneRecord? = nil
    @Published public var cloneToConfirmUpdate: CloneRecord? = nil
    @Published public var selectedSection: NavigationSection = .clones

    private let manager = DuplixManager.shared

    public init() {
        Task {
            await loadClones()
        }
    }

    public var outdatedClones: [CloneRecord] {
        clones.filter { updateInfos[$0.id]?.hasUpdate == true }
    }

    public func loadClones() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.clones = try await manager.listClones()
            await checkUpdates()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func checkUpdates() async {
        do {
            self.updateInfos = try await manager.checkAllUpdates()
        } catch {
            // Non-fatal, just log or ignore
        }
    }

    public func updateClone(clone: CloneRecord) async {
        isUpdating[clone.id] = true
        defer { isUpdating[clone.id] = false }

        do {
            _ = try await manager.updateClone(identifierOrName: clone.id.uuidString)
            self.successMessage = "Successfully updated '\(clone.name)'! Session data was preserved."
            await loadClones()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func updateAllClones() async {
        let targets = outdatedClones
        guard !targets.isEmpty else { return }

        var successCount = 0
        var errorCount = 0

        for target in targets {
            isUpdating[target.id] = true
            do {
                _ = try await manager.updateClone(identifierOrName: target.id.uuidString)
                successCount += 1
            } catch {
                errorCount += 1
            }
            isUpdating[target.id] = false
        }

        await loadClones()

        if errorCount == 0 {
            self.successMessage = "Successfully updated all \(successCount) clone(s)!"
        } else {
            self.errorMessage = "Updated \(successCount) clone(s), \(errorCount) failed."
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

    public func repairClone(clone: CloneRecord) async {
        isUpdating[clone.id] = true
        defer { isUpdating[clone.id] = false }

        do {
            _ = try await manager.repairClone(identifierOrName: clone.id.uuidString)
            self.successMessage = "Successfully upgraded isolation (Keychain + HOME + URL schemes) for '\(clone.name)'!"
            await loadClones()
        } catch {
            self.errorMessage = "Failed to repair isolation: \(error.localizedDescription)"
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
