import Foundation

public struct CodeSigner: Sendable {
    public init() {}

    public enum SigningError: LocalizedError, Sendable {
        case stripAttributesFailed(Int32, String)
        case codesignFailed(Int32, String)

        public var errorDescription: String? {
            switch self {
            case .stripAttributesFailed(let code, let msg):
                return "Failed to clear quarantine attributes (exit code \(code)): \(msg)"
            case .codesignFailed(let code, let msg):
                return "Failed to ad-hoc codesign app bundle (exit code \(code)): \(msg)"
            }
        }
    }

    /// Strips quarantine and extended attributes from the application bundle.
    public func stripQuarantineAttributes(at bundleURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-cr", bundleURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown xattr error"
            throw SigningError.stripAttributesFailed(process.terminationStatus, errorString.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Signs the application bundle recursively using ad-hoc signature (-s -).
    public func adHocSign(at bundleURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "-s", "-", bundleURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown codesign error"
            throw SigningError.codesignFailed(process.terminationStatus, errorString.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Complete security pipeline: strip quarantine and re-sign.
    public func resign(bundleURL: URL) throws {
        try stripQuarantineAttributes(at: bundleURL)
        try adHocSign(at: bundleURL)
    }
}
