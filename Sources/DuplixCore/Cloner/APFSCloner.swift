import Foundation

public struct APFSCloner: Sendable {
    public init() {}

    public enum CloneError: LocalizedError, Sendable {
        case sourceNotFound(URL)
        case destinationAlreadyExists(URL)
        case failedToCreateDirectory(URL, String)
        case cloneCommandFailed(Int32, String)
        case cloneVerificationFailed(URL)

        public var errorDescription: String? {
            switch self {
            case .sourceNotFound(let url):
                return "Source application does not exist: \(url.path)"
            case .destinationAlreadyExists(let url):
                return "Destination already exists: \(url.path)"
            case .failedToCreateDirectory(let url, let details):
                return "Failed to create directory at \(url.path): \(details)"
            case .cloneCommandFailed(let code, let err):
                return "APFS CoW clone command failed with exit code \(code): \(err)"
            case .cloneVerificationFailed(let url):
                return "Cloned bundle verification failed at \(url.path)"
            }
        }
    }

    /// Performs an instant APFS Copy-on-Write (CoW) clone of the application bundle.
    public func clone(
        sourceURL: URL,
        destinationURL: URL,
        overwrite: Bool = false
    ) throws {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CloneError.sourceNotFound(sourceURL)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            if overwrite {
                try fileManager.removeItem(at: destinationURL)
            } else {
                throw CloneError.destinationAlreadyExists(destinationURL)
            }
        }

        let parentDir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            do {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                throw CloneError.failedToCreateDirectory(parentDir, error.localizedDescription)
            }
        }

        // Execute /bin/cp with -c (clonefile/CoW) and -R (recursive)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/cp")
        process.arguments = ["-c", "-R", sourceURL.path, destinationURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CloneError.cloneCommandFailed(-1, error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown cp error"
            throw CloneError.cloneCommandFailed(process.terminationStatus, errorString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Verify clone integrity
        let contentsInfo = destinationURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)

        guard fileManager.fileExists(atPath: contentsInfo.path) else {
            throw CloneError.cloneVerificationFailed(destinationURL)
        }
    }
}
