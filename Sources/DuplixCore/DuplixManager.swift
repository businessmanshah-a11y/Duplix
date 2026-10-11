import Foundation

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

        public var errorDescription: String? {
            switch self {
            case .cloneNotFound(let query):
                return "Clone matching '\(query)' was not found."
            case .launchFailed(let msg):
                return "Failed to launch clone: \(msg)"
            case .appPathNotFound(let path):
                return "Application bundle does not exist at path: \(path)"
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

    /// High-level method to clone an application bundle end-to-end.
    @discardableResult
    public func createClone(
        sourceAppURL: URL,
        customName: String? = nil,
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
        let cloneName = try customName ?? generateNextCloneName(sourceAppName: meta.displayName)
        let sanitizedName = meta.displayName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: ".")
        let cloneBundleID = "com.duplix.clone.\(sanitizedName).\(cloneId.uuidString.lowercased().prefix(8))"

        let destinationURL = clonesDirectoryURL.appendingPathComponent("\(cloneName).app", isDirectory: true)
        let cloneDataURL = dataDirectoryURL.appendingPathComponent(cloneId.uuidString, isDirectory: true)

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

        // 6. Strip quarantine and ad-hoc resign
        try codeSigner.resign(bundleURL: destinationURL)

        // 7. Register with LaunchServices
        try launchServices.register(bundleURL: destinationURL)

        // 8. Create and persist record
        let record = CloneRecord(
            id: cloneId,
            name: cloneName,
            sourceAppName: meta.displayName,
            sourceAppBundleID: meta.bundleIdentifier,
            cloneBundleID: cloneBundleID,
            appPath: destinationURL.path,
            dataPath: cloneDataURL.path,
            engineType: meta.engineType,
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

    /// Launches an isolated clone using `/usr/bin/open -n -a`
    public func launchClone(identifierOrName: String) throws {
        var record = try findClone(by: identifierOrName)

        guard FileManager.default.fileExists(atPath: record.appPath) else {
            throw ManagerError.appPathNotFound(record.appPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        // -n: Open a new instance even if one is already running
        // -a: Specify the application
        process.arguments = ["-n", "-a", record.appPath]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ManagerError.launchFailed("open command returned \(process.terminationStatus)")
        }

        // Update last launched date
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

        // Unregister from LaunchServices
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
