import Foundation
import AppKit
import DuplixCore

@MainActor
public final class AppScannerViewModel: ObservableObject {
    @Published public var apps: [AppMetadata] = []
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var selectedFilter: EngineFilter = .all
    @Published public var appToClone: AppMetadata? = nil

    public enum EngineFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case electron = "Electron"
        case gecko = "Gecko"
        case nativeCocoa = "Native"

        public var id: String { rawValue }
    }

    private let detector = EngineDetector()

    public init() {
        Task {
            await scanApplications()
        }
    }

    public var filteredApps: [AppMetadata] {
        apps.filter { app in
            let matchesSearch = searchText.isEmpty ||
                app.displayName.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .electron:
                matchesFilter = app.engineType == .electron
            case .gecko:
                matchesFilter = app.engineType == .gecko
            case .nativeCocoa:
                matchesFilter = app.engineType == .nativeCocoa
            }

            return matchesSearch && matchesFilter
        }
    }

    public func scanApplications() async {
        isLoading = true
        defer { isLoading = false }

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let searchDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]

        var discoveredURLs: [URL] = []
        let clonesDir = home.appendingPathComponent("Applications/Duplix Clones", isDirectory: true).standardized.path

        for directory in searchDirectories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            if let items = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for item in items where item.pathExtension.lowercased() == "app" {
                    if item.standardized.path.hasPrefix(clonesDir) {
                        continue
                    }
                    discoveredURLs.append(item)
                }
            }
        }

        var seenPaths = Set<String>()
        var scannedApps: [AppMetadata] = []

        for url in discoveredURLs {
            let standardPath = url.standardized.path
            guard !seenPaths.contains(standardPath) else { continue }
            seenPaths.insert(standardPath)

            if let meta = try? detector.inspect(appURL: url) {
                scannedApps.append(meta)
            }
        }

        self.apps = scannedApps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
