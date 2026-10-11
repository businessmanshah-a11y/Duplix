import Foundation

public struct AppMetadata: Codable, Sendable {
    public let bundleURL: URL
    public let bundleIdentifier: String
    public let displayName: String
    public let executableName: String
    public let executableURL: URL
    public let iconFileName: String?
    public let engineType: EngineType
    public let version: String?

    public init(
        bundleURL: URL,
        bundleIdentifier: String,
        displayName: String,
        executableName: String,
        executableURL: URL,
        iconFileName: String?,
        engineType: EngineType,
        version: String?
    ) {
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.executableName = executableName
        self.executableURL = executableURL
        self.iconFileName = iconFileName
        self.engineType = engineType
        self.version = version
    }
}
