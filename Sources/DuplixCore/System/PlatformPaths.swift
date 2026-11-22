import Foundation

/// Resolves standard, idiomatic storage, data, and launcher paths for each supported platform.
public struct PlatformPaths: Sendable {
    public let platform: PlatformType
    public let homeDirectoryURL: URL

    public init(
        platform: PlatformType = .current,
        homeDirectoryURL: URL? = nil
    ) {
        self.platform = platform
        self.homeDirectoryURL = homeDirectoryURL ?? DuplixPaths.realHomeDirectoryURL
    }

    /// Primary registry file location (`clones.json`).
    public var registryFileURL: URL {
        switch platform {
        case .macOS:
            return homeDirectoryURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("Duplix", isDirectory: true)
                .appendingPathComponent("clones.json", isDirectory: false)
        case .linux:
            return homeDirectoryURL
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("duplix", isDirectory: true)
                .appendingPathComponent("clones.json", isDirectory: false)
        case .windows:
            if let appData = ProcessInfo.processInfo.environment["APPDATA"], !appData.isEmpty {
                return URL(fileURLWithPath: appData)
                    .appendingPathComponent("Duplix", isDirectory: true)
                    .appendingPathComponent("clones.json", isDirectory: false)
            }
            return homeDirectoryURL
                .appendingPathComponent("AppData", isDirectory: true)
                .appendingPathComponent("Roaming", isDirectory: true)
                .appendingPathComponent("Duplix", isDirectory: true)
                .appendingPathComponent("clones.json", isDirectory: false)
        }
    }

    /// Base directory where isolated application data, profiles, and sessions are kept.
    public var dataRootDirectoryURL: URL {
        switch platform {
        case .macOS:
            return homeDirectoryURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("Duplix", isDirectory: true)
                .appendingPathComponent("data", isDirectory: true)
        case .linux:
            return homeDirectoryURL
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("share", isDirectory: true)
                .appendingPathComponent("duplix", isDirectory: true)
                .appendingPathComponent("data", isDirectory: true)
        case .windows:
            if let localAppData = ProcessInfo.processInfo.environment["LOCALAPPDATA"], !localAppData.isEmpty {
                return URL(fileURLWithPath: localAppData)
                    .appendingPathComponent("Duplix", isDirectory: true)
                    .appendingPathComponent("data", isDirectory: true)
            }
            return homeDirectoryURL
                .appendingPathComponent("AppData", isDirectory: true)
                .appendingPathComponent("Local", isDirectory: true)
                .appendingPathComponent("Duplix", isDirectory: true)
                .appendingPathComponent("data", isDirectory: true)
        }
    }

    /// Directory where launcher shortcuts (`.app`, `.desktop`, `.lnk`) are stored.
    public var launcherDirectoryURL: URL {
        switch platform {
        case .macOS:
            return homeDirectoryURL
                .appendingPathComponent("Applications", isDirectory: true)
                .appendingPathComponent("Duplix Clones", isDirectory: true)
        case .linux:
            return homeDirectoryURL
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("share", isDirectory: true)
                .appendingPathComponent("applications", isDirectory: true)
        case .windows:
            if let appData = ProcessInfo.processInfo.environment["APPDATA"], !appData.isEmpty {
                return URL(fileURLWithPath: appData)
                    .appendingPathComponent("Microsoft", isDirectory: true)
                    .appendingPathComponent("Windows", isDirectory: true)
                    .appendingPathComponent("Start Menu", isDirectory: true)
                    .appendingPathComponent("Programs", isDirectory: true)
                    .appendingPathComponent("Duplix Clones", isDirectory: true)
            }
            return homeDirectoryURL
                .appendingPathComponent("AppData", isDirectory: true)
                .appendingPathComponent("Roaming", isDirectory: true)
                .appendingPathComponent("Microsoft", isDirectory: true)
                .appendingPathComponent("Windows", isDirectory: true)
                .appendingPathComponent("Start Menu", isDirectory: true)
                .appendingPathComponent("Programs", isDirectory: true)
                .appendingPathComponent("Duplix Clones", isDirectory: true)
        }
    }

    /// Specific isolated data directory for a given clone UUID.
    public func dataDirectoryForClone(id: String) -> URL {
        return dataRootDirectoryURL.appendingPathComponent(id, isDirectory: true)
    }
}
