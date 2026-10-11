import Foundation

public struct LauncherGenerator: Sendable {
    public init() {}

    public enum LauncherError: LocalizedError, Sendable {
        case failedToWriteLauncher(URL, String)
        case failedToSetPermissions(URL, String)

        public var errorDescription: String? {
            switch self {
            case .failedToWriteLauncher(let url, let details):
                return "Failed to write launcher script at \(url.path): \(details)"
            case .failedToSetPermissions(let url, let details):
                return "Failed to set executable permissions for \(url.path): \(details)"
            }
        }
    }

    /// Generates and installs an isolated launcher script inside Contents/MacOS/
    public func generateLauncher(
        appBundleURL: URL,
        originalExecutableName: String,
        launcherExecutableName: String,
        dataDirectoryPath: String,
        engineType: EngineType
    ) throws {
        let macOSDir = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)

        let launcherURL = macOSDir.appendingPathComponent(launcherExecutableName, isDirectory: false)

        let scriptContent: String
        switch engineType {
        case .electron:
            scriptContent = """
            #!/bin/bash
            set -e

            DIR="$(cd "$(dirname "$0")" && pwd)"
            DATA_DIR="\(dataDirectoryPath)"
            mkdir -p "$DATA_DIR"
            mkdir -p "$DATA_DIR/Extensions"

            exec "$DIR/\(originalExecutableName)" \\
              --user-data-dir="$DATA_DIR" \\
              --password-store=basic \\
              --extensions-dir="$DATA_DIR/Extensions" \\
              --use-mock-keychain \\
              "$@"
            """

        case .gecko:
            scriptContent = """
            #!/bin/bash
            set -e

            DIR="$(cd "$(dirname "$0")" && pwd)"
            DATA_DIR="\(dataDirectoryPath)"
            mkdir -p "$DATA_DIR"

            exec "$DIR/\(originalExecutableName)" \\
              --profile "$DATA_DIR" \\
              --no-remote \\
              "$@"
            """

        case .nativeCocoa, .unknown:
            scriptContent = """
            #!/bin/bash
            set -e

            DIR="$(cd "$(dirname "$0")" && pwd)"
            DATA_DIR="\(dataDirectoryPath)"
            mkdir -p "$DATA_DIR/Library/Application Support"
            mkdir -p "$DATA_DIR/Library/Caches"
            mkdir -p "$DATA_DIR/Library/Preferences"

            export HOME="$DATA_DIR"
            export CFFIXED_USER_HOME="$DATA_DIR"

            exec "$DIR/\(originalExecutableName)" "$@"
            """
        }

        do {
            try scriptContent.write(to: launcherURL, atomically: true, encoding: .utf8)
        } catch {
            throw LauncherError.failedToWriteLauncher(launcherURL, error.localizedDescription)
        }

        // Apply chmod 755 (rwxr-xr-x)
        let permissions: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        do {
            try FileManager.default.setAttributes(permissions, ofItemAtPath: launcherURL.path)
        } catch {
            throw LauncherError.failedToSetPermissions(launcherURL, error.localizedDescription)
        }
    }
}
