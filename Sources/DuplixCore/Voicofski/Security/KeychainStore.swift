import Foundation
import Security

public protocol KeychainStoring: Sendable {
    func save(secret: String, forKeyID id: UUID) throws
    func loadSecret(forKeyID id: UUID) throws -> String?
    func deleteSecret(forKeyID id: UUID) throws
}

public enum KeychainStoreError: Error, LocalizedError {
    case encodingFailed
    case osStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode API key for Keychain storage."
        case .osStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error (\(status)): \(message)"
            }
            return "Keychain error (\(status))."
        }
    }
}

public final class MacOSKeychainStore: KeychainStoring {
    public let service: String

    public init(service: String = "com.duplix.voicofski.apikeys") {
        self.service = service
    }

    public func save(secret: String, forKeyID id: UUID) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainStoreError.encodingFailed
        }

        let account = id.uuidString
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Delete any existing entry first for clean upsert
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.osStatus(status)
        }
    }

    public func loadSecret(forKeyID id: UUID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.osStatus(status)
        }

        guard let data = item as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            return nil
        }

        return secret
    }

    public func deleteSecret(forKeyID id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.osStatus(status)
        }
    }
}

/// Thread-safe in-memory Keychain implementation for automated unit tests.
public final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: String] = [:]

    public init() {}

    public func save(secret: String, forKeyID id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[id] = secret
    }

    public func loadSecret(forKeyID id: UUID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[id]
    }

    public func deleteSecret(forKeyID id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: id)
    }
}
