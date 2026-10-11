import Foundation

public struct CloneConfig: Codable, Sendable {
    public let id: UUID
    public let sourceAppURL: URL
    public let cloneName: String
    public let cloneBundleID: String
    public let destinationURL: URL
    public let dataDirectoryURL: URL
    public let engineType: EngineType
    public let badgeConfig: BadgeConfig?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceAppURL: URL,
        cloneName: String,
        cloneBundleID: String,
        destinationURL: URL,
        dataDirectoryURL: URL,
        engineType: EngineType,
        badgeConfig: BadgeConfig? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceAppURL = sourceAppURL
        self.cloneName = cloneName
        self.cloneBundleID = cloneBundleID
        self.destinationURL = destinationURL
        self.dataDirectoryURL = dataDirectoryURL
        self.engineType = engineType
        self.badgeConfig = badgeConfig
        self.createdAt = createdAt
    }
}

public struct CloneRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let sourceAppName: String
    public let sourceAppBundleID: String
    public let cloneBundleID: String
    public let appPath: String
    public let dataPath: String
    public let engineType: EngineType
    public var badgeConfig: BadgeConfig?
    public let createdAt: Date
    public var lastLaunchedAt: Date?

    public init(
        id: UUID,
        name: String,
        sourceAppName: String,
        sourceAppBundleID: String,
        cloneBundleID: String,
        appPath: String,
        dataPath: String,
        engineType: EngineType,
        badgeConfig: BadgeConfig? = nil,
        createdAt: Date,
        lastLaunchedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.cloneBundleID = cloneBundleID
        self.appPath = appPath
        self.dataPath = dataPath
        self.engineType = engineType
        self.badgeConfig = badgeConfig
        self.createdAt = createdAt
        self.lastLaunchedAt = lastLaunchedAt
    }
}
