import Foundation

public struct LaunchServices: Sendable {
    public init() {}

    public static let lsregisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    public enum LaunchServicesError: LocalizedError, Sendable {
        case registrationFailed(Int32, String)

        public var errorDescription: String? {
            switch self {
            case .registrationFailed(let code, let msg):
                return "Failed to register bundle with LaunchServices (exit code \(code)): \(msg)"
            }
        }
    }

    /// Registers the app bundle with LaunchServices to refresh macOS Dock, Finder, and system handlers.
    public func register(bundleURL: URL) throws {
        guard FileManager.default.fileExists(atPath: Self.lsregisterPath) else {
            // If lsregister is not at the expected path, silently ignore or log
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.lsregisterPath)
        process.arguments = ["-f", bundleURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown lsregister error"
            throw LaunchServicesError.registrationFailed(process.terminationStatus, errorString.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Unregisters an application bundle when removed.
    public func unregister(bundleURL: URL) throws {
        guard FileManager.default.fileExists(atPath: Self.lsregisterPath) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.lsregisterPath)
        process.arguments = ["-u", bundleURL.path]

        try process.run()
        process.waitUntilExit()
    }
}
