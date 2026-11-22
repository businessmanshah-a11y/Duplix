import Foundation

/// Represents a cloned application instance running inside a mobile sandboxed environment
/// (e.g. Android Work Profile or iOS multi-container).
public struct MobileCloneRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let packageName: String
    public let sourceAppName: String
    public var customName: String
    public let profileId: Int
    public var badgeLabel: String
    public var badgeColorHex: String
    public var isFrozen: Bool
    public let createdAt: Date
    public var lastLaunchedAt: Date?

    public init(
        id: UUID = UUID(),
        packageName: String,
        sourceAppName: String,
        customName: String,
        profileId: Int,
        badgeLabel: String,
        badgeColorHex: String = "#4f46e5",
        isFrozen: Bool = false,
        createdAt: Date = Date(),
        lastLaunchedAt: Date? = nil
    ) {
        self.id = id
        self.packageName = packageName
        self.sourceAppName = sourceAppName
        self.customName = customName
        self.profileId = profileId
        self.badgeLabel = badgeLabel
        self.badgeColorHex = badgeColorHex
        self.isFrozen = isFrozen
        self.createdAt = createdAt
        self.lastLaunchedAt = lastLaunchedAt
    }

    /// Toggles the frozen/snooze state to suspend background sync and save battery.
    public mutating func toggleFreeze() {
        self.isFrozen.toggle()
    }
}
