import Foundation

public struct PlistModifier: Sendable {
    public init() {}

    public enum PlistError: LocalizedError, Sendable {
        case fileNotFound(URL)
        case deserializationFailed(URL, String)
        case serializationFailed(String)
        case missingKey(String)

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let url):
                return "Info.plist not found at \(url.path)"
            case .deserializationFailed(let url, let details):
                return "Failed to parse plist at \(url.path): \(details)"
            case .serializationFailed(let details):
                return "Failed to serialize modified plist: \(details)"
            case .missingKey(let key):
                return "Required key '\(key)' is missing from Info.plist"
            }
        }
    }

    /// Modifies Info.plist of the target clone bundle to assign unique identifiers and point to the custom launcher.
    public func modify(
        appBundleURL: URL,
        newBundleIdentifier: String,
        displayName: String,
        launcherExecutableName: String
    ) throws -> (originalExecutable: String, originalBundleID: String) {
        let infoPlistURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)

        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw PlistError.fileNotFound(infoPlistURL)
        }

        let data = try Data(contentsOf: infoPlistURL)
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard var dict = try PropertyListSerialization.propertyList(
            from: data,
            options: .mutableContainersAndLeaves,
            format: &format
        ) as? [String: Any] else {
            throw PlistError.deserializationFailed(infoPlistURL, "Invalid plist dictionary")
        }

        let originalBundleID = (dict["CFBundleIdentifier"] as? String) ?? "com.unknown.app"
        guard let originalExecutable = dict["CFBundleExecutable"] as? String else {
            throw PlistError.missingKey("CFBundleExecutable")
        }

        // Update bundle identity
        dict["CFBundleIdentifier"] = newBundleIdentifier
        dict["CFBundleDisplayName"] = displayName
        // Preserve original CFBundleName so frameworks (Electron, Chromium) can find their Helper apps
        if dict["CFBundleName"] == nil {
            dict["CFBundleName"] = displayName
        }

        // Store original executable and attach new launcher
        dict["DuplixOriginalExecutable"] = originalExecutable
        dict["CFBundleExecutable"] = launcherExecutableName

        // Also add Duplix metadata markers
        dict["DuplixIsClone"] = true
        dict["DuplixEngineVersion"] = "1.0.0"

        do {
            let modifiedData = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .xml,
                options: 0
            )
            try modifiedData.write(to: infoPlistURL, options: .atomic)
        } catch {
            throw PlistError.serializationFailed(error.localizedDescription)
        }

        return (originalExecutable: originalExecutable, originalBundleID: originalBundleID)
    }
}
