import Foundation

public final class APIKeyPoolManager: @unchecked Sendable {
    private let keychain: KeychainStoring
    private let storage: VoicofskiStorage
    private let client: GeminiAPIClientProtocol
    private let nowProvider: @Sendable () -> Date
    private let lock = NSLock()

    private var keys: [APIKeyMetadata] = []

    public init(
        keychain: KeychainStoring = MacOSKeychainStore(),
        storage: VoicofskiStorage = VoicofskiStorage(),
        client: GeminiAPIClientProtocol = GeminiAPIClient(),
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.keychain = keychain
        self.storage = storage
        self.client = client
        self.nowProvider = nowProvider
        self.keys = storage.loadKeysMetadata()
        _ = refreshCooldowns()
    }

    // MARK: - Read State

    public func listKeys() -> [APIKeyMetadata] {
        lock.lock()
        defer { lock.unlock() }
        return keys.sorted { $0.orderIndex < $1.orderIndex }
    }

    public var activeOrUntestedCount: Int {
        listKeys().filter { $0.status == .active || $0.status == .untested }.count
    }

    public var hasEligibleKeys: Bool {
        _ = refreshCooldowns()
        return activeOrUntestedCount > 0
    }

    // MARK: - Manage Keys

    @discardableResult
    public func addKey(label: String, secret: String) throws -> APIKeyMetadata {
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty else {
            throw VoicofskiError.invalidAPIKey("API key cannot be empty.")
        }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = UUID()
        try keychain.save(secret: trimmedSecret, forKeyID: id)

        lock.lock()
        let nextOrder = (keys.map(\.orderIndex).max() ?? -1) + 1
        let resolvedLabel = trimmedLabel.isEmpty ? "Key \(nextOrder + 1)" : trimmedLabel
        let meta = APIKeyMetadata(
            id: id,
            label: resolvedLabel,
            orderIndex: nextOrder,
            status: .untested,
            createdAt: nowProvider()
        )
        keys.append(meta)
        let snapshot = keys
        lock.unlock()

        try storage.saveKeysMetadata(snapshot)
        return meta
    }

    public func removeKey(id: UUID) throws {
        try keychain.deleteSecret(forKeyID: id)

        lock.lock()
        keys.removeAll { $0.id == id }
        normalizeOrderLocked()
        let snapshot = keys
        lock.unlock()

        try storage.saveKeysMetadata(snapshot)
    }

    public func updateLabel(id: UUID, newLabel: String) throws {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        if let idx = keys.firstIndex(where: { $0.id == id }) {
            keys[idx].label = trimmed
        }
        let snapshot = keys
        lock.unlock()

        try storage.saveKeysMetadata(snapshot)
    }

    public func moveKey(id: UUID, direction: Int) throws {
        lock.lock()
        keys.sort { $0.orderIndex < $1.orderIndex }
        guard let idx = keys.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        let target = idx + direction
        guard target >= 0 && target < keys.count else {
            lock.unlock()
            return
        }
        keys.swapAt(idx, target)
        normalizeOrderLocked()
        let snapshot = keys
        lock.unlock()

        try storage.saveKeysMetadata(snapshot)
    }

    // MARK: - Cooldown & Daily 09:00 UTC Reset

    /// Computes the next `09:00:00 UTC` instant strictly after `date`
    /// (Google AI Studio resets around `08:00 UTC` / midnight PT; +1h safety buffer = `09:00 UTC`).
    public static func nextResetDate(after date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        var components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        components.second = 0

        if let todayNineUTC = utcCalendar.date(from: components), todayNineUTC > date {
            return todayNineUTC
        }

        let tomorrow = utcCalendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        var tomorrowComponents = utcCalendar.dateComponents([.year, .month, .day], from: tomorrow)
        tomorrowComponents.hour = 9
        tomorrowComponents.minute = 0
        tomorrowComponents.second = 0
        return utcCalendar.date(from: tomorrowComponents) ?? date.addingTimeInterval(86400)
    }

    /// Re-activates any exhausted keys whose `nextResetAt` has passed. Returns `true` if at least one key recovered.
    @discardableResult
    public func refreshCooldowns() -> Bool {
        let now = nowProvider()
        var recoveredAny = false

        lock.lock()
        for i in keys.indices {
            if keys[i].status == .exhausted,
               let resetAt = keys[i].nextResetAt,
               now >= resetAt {
                keys[i].status = .active
                keys[i].nextResetAt = nil
                keys[i].lastError = nil
                recoveredAny = true
            }
        }
        let snapshot = keys
        lock.unlock()

        if recoveredAny {
            try? storage.saveKeysMetadata(snapshot)
        }
        return recoveredAny
    }

    // MARK: - Test Key

    @discardableResult
    public func testKey(id: UUID) async -> APIKeyMetadata? {
        guard let secret = try? keychain.loadSecret(forKeyID: id), !secret.isEmpty else {
            updateKeyState(id: id, status: .invalid, nextResetAt: nil, lastError: "Missing secret in Keychain.")
            return listKeys().first { $0.id == id }
        }

        do {
            try await client.testKey(apiKey: secret)
            updateKeyState(id: id, status: .active, nextResetAt: nil, lastError: nil)
        } catch let error as VoicofskiError {
            switch error {
            case .quotaExceeded:
                updateKeyState(
                    id: id,
                    status: .exhausted,
                    nextResetAt: Self.nextResetDate(after: nowProvider()),
                    lastError: error.localizedDescription
                )
            case .invalidAPIKey:
                updateKeyState(id: id, status: .invalid, nextResetAt: nil, lastError: error.localizedDescription)
            case .regionBlocked, .networkFailure, .apiError, .cancelled:
                // Network/VPN issue doesn't mean the key itself is invalid
                updateKeyState(id: id, status: nil, nextResetAt: nil, lastError: error.localizedDescription)
            default:
                updateKeyState(id: id, status: nil, nextResetAt: nil, lastError: error.localizedDescription)
            }
        } catch {
            updateKeyState(id: id, status: nil, nextResetAt: nil, lastError: error.localizedDescription)
        }

        return listKeys().first { $0.id == id }
    }

    // MARK: - Sequential Failover Execution

    public func executeWithFailover<T>(
        _ operation: @Sendable (String) async throws -> T
    ) async throws -> T {
        _ = refreshCooldowns()

        let orderedKeys = listKeys()
        guard !orderedKeys.isEmpty else {
            throw VoicofskiError.noAPIKeys
        }

        var sawExhausted = orderedKeys.contains { $0.status == .exhausted }
        var lastNonQuotaError: Error?

        for meta in orderedKeys {
            if meta.status == .invalid || meta.status == .exhausted {
                continue
            }

            guard let secret = try? keychain.loadSecret(forKeyID: meta.id), !secret.isEmpty else {
                updateKeyState(id: meta.id, status: .invalid, nextResetAt: nil, lastError: "Key missing from Keychain.")
                continue
            }

            do {
                let result = try await operation(secret)
                markKeyUsedSuccessfully(id: meta.id)
                return result
            } catch let error as VoicofskiError {
                switch error {
                case .quotaExceeded:
                    sawExhausted = true
                    updateKeyState(
                        id: meta.id,
                        status: .exhausted,
                        nextResetAt: Self.nextResetDate(after: nowProvider()),
                        lastError: "Daily quota reached"
                    )
                    continue
                case .invalidAPIKey:
                    updateKeyState(id: meta.id, status: .invalid, nextResetAt: nil, lastError: error.localizedDescription)
                    lastNonQuotaError = error
                    continue
                case .regionBlocked, .networkFailure, .cancelled, .apiError, .emptyAudioResponse, .emptyTranslationResponse:
                    // Do not burn other keys on VPN/network/cancellation failures
                    throw error
                case .noAPIKeys, .allKeysExhausted:
                    throw error
                }
            } catch {
                throw error
            }
        }

        if sawExhausted {
            throw VoicofskiError.allKeysExhausted
        }
        if let lastNonQuotaError {
            throw lastNonQuotaError
        }
        throw VoicofskiError.noAPIKeys
    }

    // MARK: - Internal Helpers

    private func markKeyUsedSuccessfully(id: UUID) {
        let now = nowProvider()
        lock.lock()
        if let idx = keys.firstIndex(where: { $0.id == id }) {
            keys[idx].status = .active
            keys[idx].nextResetAt = nil
            keys[idx].lastError = nil
            keys[idx].lastUsedAt = now
        }
        let snapshot = keys
        lock.unlock()
        try? storage.saveKeysMetadata(snapshot)
    }

    private func updateKeyState(
        id: UUID,
        status: APIKeyHealthStatus?,
        nextResetAt: Date?,
        lastError: String?
    ) {
        lock.lock()
        if let idx = keys.firstIndex(where: { $0.id == id }) {
            if let status {
                keys[idx].status = status
            }
            keys[idx].nextResetAt = nextResetAt
            keys[idx].lastError = lastError
        }
        let snapshot = keys
        lock.unlock()
        try? storage.saveKeysMetadata(snapshot)
    }

    private func normalizeOrderLocked() {
        for i in keys.indices {
            keys[i].orderIndex = i
        }
    }
}
