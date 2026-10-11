import Foundation

public struct EngineDetector: Sendable {
    public init() {}

    public enum DetectionError: LocalizedError, Sendable {
        case notAnAppBundle(URL)
        case missingInfoPlist(URL)
        case invalidInfoPlist(URL)
        case missingExecutable(String)

        public var errorDescription: String? {
            switch self {
            case .notAnAppBundle(let url):
                return "The specified path is not a valid macOS application bundle (.app): \(url.path)"
            case .missingInfoPlist(let url):
                return "Info.plist was not found in: \(url.path)"
            case .invalidInfoPlist(let url):
                return "Unable to parse Info.plist in: \(url.path)"
            case .missingExecutable(let name):
                return "Executable binary '\(name)' was not found in Contents/MacOS/"
            }
        }
    }

    /// Inspects an app bundle and extracts complete metadata including engine type.
    public func inspect(appURL: URL) throws -> AppMetadata {
        guard appURL.pathExtension == "app" else {
            throw DetectionError.notAnAppBundle(appURL)
        }

        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist", isDirectory: false)

        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw DetectionError.missingInfoPlist(infoPlistURL)
        }

        let plistData = try Data(contentsOf: infoPlistURL)
        guard let plist = try PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw DetectionError.invalidInfoPlist(infoPlistURL)
        }

        let bundleIdentifier = (plist["CFBundleIdentifier"] as? String) ?? "unknown.bundle.id"
        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        guard let executableName = plist["CFBundleExecutable"] as? String else {
            throw DetectionError.missingExecutable("CFBundleExecutable not defined")
        }

        let executableURL = contentsURL
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent(executableName, isDirectory: false)

        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw DetectionError.missingExecutable(executableName)
        }

        let iconFileName = plist["CFBundleIconFile"] as? String
        let version = (plist["CFBundleShortVersionString"] as? String)
            ?? (plist["CFBundleVersion"] as? String)

        let engineType = detectEngine(at: contentsURL)

        return AppMetadata(
            bundleURL: appURL,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            executableName: executableName,
            executableURL: executableURL,
            iconFileName: iconFileName,
            engineType: engineType,
            version: version
        )
    }

    /// Identifies the runtime framework and engine of the app bundle.
    public func detectEngine(at contentsURL: URL) -> EngineType {
        let fileManager = FileManager.default

        // 1. Check for Electron Framework or Chromium-based browsers
        let frameworksURL = contentsURL.appendingPathComponent("Frameworks", isDirectory: true)
        let chromiumFrameworks = [
            "Electron Framework.framework",
            "Google Chrome Framework.framework",
            "Chromium Framework.framework",
            "Brave Browser Framework.framework",
            "Microsoft Edge Framework.framework",
            "Arc Framework.framework",
            "Opera Framework.framework"
        ]

        for frameworkName in chromiumFrameworks {
            let frameworkURL = frameworksURL.appendingPathComponent(frameworkName, isDirectory: true)
            if fileManager.fileExists(atPath: frameworkURL.path) {
                return .electron
            }
        }

        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let appAsar = resourcesURL.appendingPathComponent("app.asar", isDirectory: false)
        let defaultAppAsar = resourcesURL.appendingPathComponent("default_app.asar", isDirectory: false)

        if fileManager.fileExists(atPath: appAsar.path)
            || fileManager.fileExists(atPath: defaultAppAsar.path) {
            return .electron
        }

        // 2. Check for Gecko (Firefox, Zen, Thunderbird)
        let omniJa = resourcesURL.appendingPathComponent("omni.ja", isDirectory: false)
        let appIni = resourcesURL.appendingPathComponent("application.ini", isDirectory: false)

        if fileManager.fileExists(atPath: omniJa.path) || fileManager.fileExists(atPath: appIni.path) {
            return .gecko
        }

        // 3. Fallback: native macOS AppKit / Cocoa
        return .nativeCocoa
    }
}
