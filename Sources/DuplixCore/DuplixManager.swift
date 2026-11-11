import Foundation
import AppKit

public actor DuplixManager {
    public static let shared = DuplixManager()

    public let clonesDirectoryURL: URL
    public let dataDirectoryURL: URL
    public let registryFileURL: URL

    private let engineDetector = EngineDetector()
    private let cloner = APFSCloner()
    private let plistModifier = PlistModifier()
    private let launcherGenerator = LauncherGenerator()
    private let codeSigner = CodeSigner()
    private let launchServices = LaunchServices()
    private let iconManager = IconManager()

    public init(
        clonesDirectoryURL: URL? = nil,
        dataDirectoryURL: URL? = nil,
        registryFileURL: URL? = nil
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let appSupportDuplix = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Duplix", isDirectory: true)

        self.clonesDirectoryURL = clonesDirectoryURL ?? home
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Duplix Clones", isDirectory: true)

        self.dataDirectoryURL = dataDirectoryURL ?? appSupportDuplix
            .appendingPathComponent("data", isDirectory: true)

        self.registryFileURL = registryFileURL ?? appSupportDuplix
            .appendingPathComponent("clones.json", isDirectory: false)
    }

    public enum ManagerError: LocalizedError, Sendable {
        case cloneNotFound(String)
        case launchFailed(String)
        case appPathNotFound(String)
        case sourceAppNotFound(String)
        case appIsRunning(String)
        case updateFailed(String)

        public var errorDescription: String? {
            switch self {
            case .cloneNotFound(let query):
                return "Clone matching '\(query)' was not found."
            case .launchFailed(let msg):
                return "Failed to launch clone: \(msg)"
            case .appPathNotFound(let path):
                return "Application bundle does not exist at path: \(path)"
            case .sourceAppNotFound(let msg):
                return "Source application not found: \(msg)"
            case .appIsRunning(let msg):
                return msg
            case .updateFailed(let msg):
                return "Update failed: \(msg)"
            }
        }
    }

    /// Loads the stored clone records from disk.
    public func loadRegistry() throws -> [CloneRecord] {
        guard FileManager.default.fileExists(atPath: registryFileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: registryFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CloneRecord].self, from: data)) ?? []
    }

    /// Saves the clone records list to disk.
    private func saveRegistry(_ records: [CloneRecord]) throws {
        let parentDir = registryFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        try data.write(to: registryFileURL, options: .atomic)
    }

    /// Returns list of all clones, updating availability on disk.
    public func listClones() throws -> [CloneRecord] {
        return try loadRegistry()
    }

    /// Suggests a default clone name if none provided, e.g. "Antigravity IDE (Clone 1)"
    public func generateNextCloneName(sourceAppName: String) throws -> String {
        let existing = try loadRegistry()
        let matchingCount = existing.filter { $0.sourceAppName == sourceAppName }.count
        return "\(sourceAppName) (Clone \(matchingCount + 1))"
    }

    /// High-level method to clone an application bundle end-to-end, including badging.
    @discardableResult
    public func createClone(
        sourceAppURL: URL,
        customName: String? = nil,
        badgeConfig: BadgeConfig? = nil,
        overwrite: Bool = false
    ) throws -> CloneRecord {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: sourceAppURL.path) else {
            throw ManagerError.appPathNotFound(sourceAppURL.path)
        }

        // 1. Inspect source app
        let meta = try engineDetector.inspect(appURL: sourceAppURL)

        // 2. Generate identifiers & names
        let cloneId = UUID()
        let shortId = String(cloneId.uuidString.lowercased().prefix(8))
        let existing = try loadRegistry()
        let matchingCount = existing.filter { $0.sourceAppName == meta.displayName }.count
        let cloneName = customName ?? "\(meta.displayName) (Clone \(matchingCount + 1))"
        let sanitizedName = meta.displayName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: ".")
        let cloneBundleID = "com.duplix.clone.\(sanitizedName).\(shortId)"

        let destinationURL = clonesDirectoryURL.appendingPathComponent("\(cloneName).app", isDirectory: true)
        let cloneDataURL = dataDirectoryURL.appendingPathComponent(shortId, isDirectory: true)

        // Determine badge configuration
        let finalBadge = badgeConfig ?? BadgeConfig.automatic(forCloneIndex: matchingCount + 1)

        // Ensure directories exist
        try fileManager.createDirectory(at: clonesDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cloneDataURL, withIntermediateDirectories: true)

        // 3. APFS CoW clone
        try cloner.clone(sourceURL: sourceAppURL, destinationURL: destinationURL, overwrite: overwrite)

        // 4. Modify Info.plist
        let launcherName = "duplix_launcher"
        let (originalExecutable, _) = try plistModifier.modify(
            appBundleURL: destinationURL,
            newBundleIdentifier: cloneBundleID,
            displayName: cloneName,
            launcherExecutableName: launcherName
        )

        // 5. Generate isolated launcher script
        try launcherGenerator.generateLauncher(
            appBundleURL: destinationURL,
            originalExecutableName: originalExecutable,
            launcherExecutableName: launcherName,
            dataDirectoryPath: cloneDataURL.path,
            engineType: meta.engineType
        )

        // 6. Apply Icon Badging
        _ = try? iconManager.badgeApp(
            appBundleURL: destinationURL,
            preferredIconName: meta.iconFileName,
            config: finalBadge
        )

        // 7. Strip quarantine and ad-hoc resign
        try codeSigner.resign(bundleURL: destinationURL)

        // 8. Register with LaunchServices
        try launchServices.register(bundleURL: destinationURL)

        // 9. Create and persist record
        let record = CloneRecord(
            id: cloneId,
            name: cloneName,
            sourceAppName: meta.displayName,
            sourceAppBundleID: meta.bundleIdentifier,
            sourceAppPath: sourceAppURL.standardized.path,
            cloneBundleID: cloneBundleID,
            appPath: destinationURL.path,
            dataPath: cloneDataURL.path,
            engineType: meta.engineType,
            badgeConfig: finalBadge,
            createdAt: Date()
        )

        var records = try loadRegistry()
        if overwrite {
            records.removeAll { $0.name == cloneName || $0.appPath == destinationURL.path }
        }
        records.append(record)
        try saveRegistry(records)

        return record
    }

    /// Updates or changes the icon badge of an existing clone.
    @discardableResult
    public func updateBadge(identifierOrName: String, badgeConfig: BadgeConfig) throws -> CloneRecord {
        var record = try findClone(by: identifierOrName)
        let appURL = URL(fileURLWithPath: record.appPath)

        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw ManagerError.appPathNotFound(record.appPath)
        }

        try iconManager.badgeApp(
            appBundleURL: appURL,
            preferredIconName: nil,
            config: badgeConfig
        )

        record.badgeConfig = badgeConfig

        var records = try loadRegistry()
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
            try saveRegistry(records)
        }

        try? launchServices.register(bundleURL: appURL)
        return record
    }

    /// Finds a clone by UUID or name
    public func findClone(by identifierOrName: String) throws -> CloneRecord {
        let records = try loadRegistry()
        if let uuid = UUID(uuidString: identifierOrName),
           let match = records.first(where: { $0.id == uuid }) {
            return match
        }
        if let match = records.first(where: { $0.name.lowercased() == identifierOrName.lowercased() }) {
            return match
        }
        if let match = records.first(where: { $0.cloneBundleID == identifierOrName }) {
            return match
        }
        throw ManagerError.cloneNotFound(identifierOrName)
    }

    /// Locates the source app URL for a given clone record.
    public func resolveSourceAppURL(for record: CloneRecord) -> URL? {
        let fileManager = FileManager.default

        if let path = record.sourceAppPath, fileManager.fileExists(atPath: path) {
            return URL(fileURLWithPath: path).standardized
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: record.sourceAppBundleID),
           fileManager.fileExists(atPath: url.path) {
            return url.standardized
        }

        let candidates = [
            URL(fileURLWithPath: "/Applications/\(record.sourceAppName).app"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/\(record.sourceAppName).app", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/\(record.sourceAppName).app")
        ]

        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate.standardized
            }
        }

        return nil
    }

    /// Reads CFBundleShortVersionString or CFBundleVersion from an app bundle's Info.plist.
    public func getBundleVersion(at appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist", isDirectory: false)
        guard let data = try? Data(contentsOf: plistURL),
              let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return nil
        }
        return (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String)
    }

    /// Compares two version strings (e.g. "2.5.5" vs "2.6.0").
    private func isVersion(_ v1: String, olderThan v2: String) -> Bool {
        let clean1 = v1.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean2 = v2.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean1 == clean2 { return false }

        let parts1 = clean1.split(separator: ".").compactMap { Int($0) }
        let parts2 = clean2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(parts1.count, parts2.count) {
            let num1 = i < parts1.count ? parts1[i] : 0
            let num2 = i < parts2.count ? parts2[i] : 0
            if num1 < num2 { return true }
            if num1 > num2 { return false }
        }

        return clean1.compare(clean2, options: .numeric) == .orderedAscending
    }

    /// Checks if a clone has an update available from its original source application.
    public func checkUpdate(for clone: CloneRecord) throws -> CloneVersionInfo? {
        guard let sourceURL = resolveSourceAppURL(for: clone) else {
            return nil
        }

        let cloneURL = URL(fileURLWithPath: clone.appPath)
        guard FileManager.default.fileExists(atPath: cloneURL.path),
              let cloneVersion = getBundleVersion(at: cloneURL),
              let sourceVersion = getBundleVersion(at: sourceURL) else {
            return nil
        }

        let hasUpdate = isVersion(cloneVersion, olderThan: sourceVersion) || (cloneVersion != sourceVersion)

        return CloneVersionInfo(
            cloneVersion: cloneVersion,
            sourceVersion: sourceVersion,
            hasUpdate: hasUpdate,
            sourceAppURL: sourceURL
        )
    }

    /// Checks updates for all registered clones.
    public func checkAllUpdates() throws -> [UUID: CloneVersionInfo] {
        let clones = try loadRegistry()
        var result: [UUID: CloneVersionInfo] = [:]
        for clone in clones {
            if let info = try? checkUpdate(for: clone) {
                result[clone.id] = info
            }
        }
        return result
    }

    /// Updates a clone bundle to match the latest version of its source app with ZERO data loss.
    @discardableResult
    public func updateClone(identifierOrName: String) throws -> CloneRecord {
        var record = try findClone(by: identifierOrName)
        let fileManager = FileManager.default

        guard let sourceURL = resolveSourceAppURL(for: record) else {
            throw ManagerError.sourceAppNotFound("Could not locate original application for '\(record.name)' (\(record.sourceAppName)).")
        }

        let destinationURL = URL(fileURLWithPath: record.appPath)
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw ManagerError.appPathNotFound(record.appPath)
        }

        // 1. Process Check: ensure clone is not currently running
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            if let bundleURL = app.bundleURL, bundleURL.standardized.path == destinationURL.standardized.path {
                return true
            }
            if let bundleID = app.bundleIdentifier, bundleID == record.cloneBundleID {
                return true
            }
            return false
        }

        if isRunning {
            throw ManagerError.appIsRunning("Cannot update '\(record.name)' because it is currently running. Please quit '\(record.name)' and try again.")
        }

        // 2. Unregister from LaunchServices
        try? launchServices.unregister(bundleURL: destinationURL)

        // 3. Create temporary atomic backup: <destinationURL>.bak
        let backupURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent("\(destinationURL.lastPathComponent).bak", isDirectory: true)

        if fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.removeItem(at: backupURL)
        }

        do {
            try fileManager.moveItem(at: destinationURL, to: backupURL)
        } catch {
            throw ManagerError.updateFailed("Failed to create temporary backup: \(error.localizedDescription)")
        }

        // 4. Perform fresh APFS CoW clone from updated source app
        do {
            try cloner.clone(sourceURL: sourceURL, destinationURL: destinationURL, overwrite: true)

            // Inspect the updated source app
            let meta = try engineDetector.inspect(appURL: sourceURL)

            // 5. Re-apply Info.plist modifications
            let launcherName = "duplix_launcher"
            let (originalExecutable, _) = try plistModifier.modify(
                appBundleURL: destinationURL,
                newBundleIdentifier: record.cloneBundleID,
                displayName: record.name,
                launcherExecutableName: launcherName
            )

            // 6. Re-generate isolated launcher script pointing to EXACT SAME dataPath
            try launcherGenerator.generateLauncher(
                appBundleURL: destinationURL,
                originalExecutableName: originalExecutable,
                launcherExecutableName: launcherName,
                dataDirectoryPath: record.dataPath,
                engineType: meta.engineType
            )

            // 7. Re-apply icon badge if configured
            if let badgeConfig = record.badgeConfig {
                _ = try? iconManager.badgeApp(
                    appBundleURL: destinationURL,
                    preferredIconName: meta.iconFileName,
                    config: badgeConfig
                )
            }

            // 8. Resign bundle
            try codeSigner.resign(bundleURL: destinationURL)

            // 9. Re-register with LaunchServices
            try launchServices.register(bundleURL: destinationURL)

            // Success! Remove the backup
            try? fileManager.removeItem(at: backupURL)

            // Update record in registry
            record.sourceAppPath = sourceURL.path
            var records = try loadRegistry()
            if let idx = records.firstIndex(where: { $0.id == record.id }) {
                records[idx] = record
                try saveRegistry(records)
            }

            return record
        } catch {
            // ROLLBACK on failure: restore backup
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            try? fileManager.moveItem(at: backupURL, to: destinationURL)
            try? launchServices.register(bundleURL: destinationURL)

            throw ManagerError.updateFailed("Update failed: \(error.localizedDescription). Restored previous clone bundle.")
        }
    }

    /// Re-generates the launcher script, isolates keychains/URL schemes, and re-signs an existing clone without wiping user data.
    @discardableResult
    public func repairClone(identifierOrName: String) throws -> CloneRecord {
        let record = try findClone(by: identifierOrName)
        let fileManager = FileManager.default
        let appURL = URL(fileURLWithPath: record.appPath)

        guard fileManager.fileExists(atPath: appURL.path) else {
            throw ManagerError.appPathNotFound(record.appPath)
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            if let bundleURL = app.bundleURL, bundleURL.standardized.path == appURL.standardized.path {
                return true
            }
            if let bundleID = app.bundleIdentifier, bundleID == record.cloneBundleID {
                return true
            }
            return false
        }

        if isRunning {
            throw ManagerError.appIsRunning("Cannot repair '\(record.name)' because it is currently running. Please quit '\(record.name)' and try again.")
        }

        let launcherName = "duplix_launcher"
        let (originalExecutable, _) = try plistModifier.modify(
            appBundleURL: appURL,
            newBundleIdentifier: record.cloneBundleID,
            displayName: record.name,
            launcherExecutableName: launcherName,
            originalBundleIDHint: record.sourceAppBundleID
        )

        try launcherGenerator.generateLauncher(
            appBundleURL: appURL,
            originalExecutableName: originalExecutable,
            launcherExecutableName: launcherName,
            dataDirectoryPath: record.dataPath,
            engineType: record.engineType
        )

        try codeSigner.resign(bundleURL: appURL)
        try launchServices.register(bundleURL: appURL)

        return record
    }

    /// Repairs all registered clones with the latest isolation launchers and bundle settings.
    @discardableResult
    public func repairAllClones() throws -> [CloneRecord] {
        let clones = try loadRegistry()
        var repaired: [CloneRecord] = []
        for clone in clones {
            repaired.append(try repairClone(identifierOrName: clone.id.uuidString))
        }
        return repaired
    }

    /// Launches an isolated clone using `/usr/bin/open -n -a`
    public func launchClone(identifierOrName: String) throws {
        var record = try findClone(by: identifierOrName)

        guard FileManager.default.fileExists(atPath: record.appPath) else {
            throw ManagerError.appPathNotFound(record.appPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", record.appPath]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ManagerError.launchFailed("open command returned \(process.terminationStatus)")
        }

        record.lastLaunchedAt = Date()
        var records = try loadRegistry()
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
            try saveRegistry(records)
        }
    }

    /// Opens the isolated data directory in Finder.
    public func openDataDirectory(identifierOrName: String) throws {
        let record = try findClone(by: identifierOrName)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [record.dataPath]
        try process.run()
    }

    /// Clears data directory (resetting sessions and caches).
    public func resetData(identifierOrName: String) throws {
        let record = try findClone(by: identifierOrName)
        let fileManager = FileManager.default
        let dataURL = URL(fileURLWithPath: record.dataPath)

        if fileManager.fileExists(atPath: dataURL.path) {
            try fileManager.removeItem(at: dataURL)
        }
        try fileManager.createDirectory(at: dataURL, withIntermediateDirectories: true)
    }

    /// Deletes the clone bundle and optionally its data folder.
    public func deleteClone(identifierOrName: String, deleteData: Bool = true) throws {
        let record = try findClone(by: identifierOrName)
        let fileManager = FileManager.default

        let appURL = URL(fileURLWithPath: record.appPath)
        try? launchServices.unregister(bundleURL: appURL)

        if fileManager.fileExists(atPath: record.appPath) {
            try fileManager.removeItem(atPath: record.appPath)
        }

        if deleteData && fileManager.fileExists(atPath: record.dataPath) {
            try fileManager.removeItem(atPath: record.dataPath)
        }

        var records = try loadRegistry()
        records.removeAll { $0.id == record.id }
        try saveRegistry(records)
    }
}
