import Foundation

public final class VoicofskiStorage: @unchecked Sendable {
    public let baseDirectoryURL: URL
    public let audioDirectoryURL: URL
    public let historyFileURL: URL
    public let pendingQueueFileURL: URL
    public let keysMetadataFileURL: URL

    private let fileManager = FileManager.default
    private let lock = NSLock()

    public init(baseDirectoryURL: URL? = nil) {
        let root = baseDirectoryURL ?? DuplixPaths.realHomeDirectoryURL
            .appendingPathComponent("Library/Application Support/Duplix/Voicofski", isDirectory: true)
        self.baseDirectoryURL = root
        self.audioDirectoryURL = root.appendingPathComponent("audio", isDirectory: true)
        self.historyFileURL = root.appendingPathComponent("history.json", isDirectory: false)
        self.pendingQueueFileURL = root.appendingPathComponent("pending_queue.json", isDirectory: false)
        self.keysMetadataFileURL = root.appendingPathComponent("keys_metadata.json", isDirectory: false)
        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        try? fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Audio Files

    public func audioURL(forFileName fileName: String) -> URL {
        audioDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    public func saveAudioData(_ wavData: Data, id: UUID) throws -> (fileName: String, fileURL: URL) {
        ensureDirectoriesExist()
        let fileName = "\(id.uuidString).wav"
        let url = audioURL(forFileName: fileName)
        try wavData.write(to: url, options: .atomic)
        return (fileName, url)
    }

    public func deleteAudioFile(named fileName: String) {
        let url = audioURL(forFileName: fileName)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - History

    public func loadHistory() -> [VoicofskiHistoryItem] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: historyFileURL),
              let items = try? makeDecoder().decode([VoicofskiHistoryItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    public func saveHistory(_ items: [VoicofskiHistoryItem]) throws {
        lock.lock()
        defer { lock.unlock() }
        ensureDirectoriesExist()
        let data = try makeEncoder().encode(items)
        try data.write(to: historyFileURL, options: .atomic)
    }

    @discardableResult
    public func appendHistoryItem(_ item: VoicofskiHistoryItem) throws -> [VoicofskiHistoryItem] {
        var current = loadHistory()
        current.insert(item, at: 0)
        try saveHistory(current)
        return current
    }

    @discardableResult
    public func deleteHistoryItem(id: UUID) throws -> [VoicofskiHistoryItem] {
        var current = loadHistory()
        if let index = current.firstIndex(where: { $0.id == id }) {
            let removed = current.remove(at: index)
            deleteAudioFile(named: removed.audioFileName)
            try saveHistory(current)
        }
        return current
    }

    // MARK: - Pending Quota Queue

    public func loadPendingQueue() -> [PendingQuotaRequest] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: pendingQueueFileURL),
              let items = try? makeDecoder().decode([PendingQuotaRequest].self, from: data) else {
            return []
        }
        return items.sorted { $0.createdAt < $1.createdAt }
    }

    public func savePendingQueue(_ items: [PendingQuotaRequest]) throws {
        lock.lock()
        defer { lock.unlock() }
        ensureDirectoriesExist()
        let data = try makeEncoder().encode(items)
        try data.write(to: pendingQueueFileURL, options: .atomic)
    }

    @discardableResult
    public func enqueuePendingRequest(_ request: PendingQuotaRequest) throws -> [PendingQuotaRequest] {
        var current = loadPendingQueue()
        current.append(request)
        try savePendingQueue(current)
        return current
    }

    @discardableResult
    public func removePendingRequest(id: UUID) throws -> [PendingQuotaRequest] {
        var current = loadPendingQueue()
        current.removeAll { $0.id == id }
        try savePendingQueue(current)
        return current
    }

    // MARK: - API Keys Metadata

    public func loadKeysMetadata() -> [APIKeyMetadata] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: keysMetadataFileURL),
              let items = try? makeDecoder().decode([APIKeyMetadata].self, from: data) else {
            return []
        }
        return items.sorted { $0.orderIndex < $1.orderIndex }
    }

    public func saveKeysMetadata(_ items: [APIKeyMetadata]) throws {
        lock.lock()
        defer { lock.unlock() }
        ensureDirectoriesExist()
        let data = try makeEncoder().encode(items)
        try data.write(to: keysMetadataFileURL, options: .atomic)
    }
}
