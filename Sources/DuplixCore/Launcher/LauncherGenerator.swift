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
            mkdir -p "$DATA_DIR/Library/Application Support"
            mkdir -p "$DATA_DIR/Library/Caches"
            mkdir -p "$DATA_DIR/Library/Preferences"
            mkdir -p "$DATA_DIR/Library/Keychains"

            # Bridge essential developer configs from real user home
            REAL_HOME="$HOME"
            if [ -n "$REAL_HOME" ] && [ "$REAL_HOME" != "$DATA_DIR" ]; then
              [ -e "$REAL_HOME/.gitconfig" ] && [ ! -e "$DATA_DIR/.gitconfig" ] && [ ! -L "$DATA_DIR/.gitconfig" ] && ln -sf "$REAL_HOME/.gitconfig" "$DATA_DIR/.gitconfig" 2>/dev/null || true
              [ -d "$REAL_HOME/.ssh" ] && [ ! -e "$DATA_DIR/.ssh" ] && [ ! -L "$DATA_DIR/.ssh" ] && ln -sf "$REAL_HOME/.ssh" "$DATA_DIR/.ssh" 2>/dev/null || true
              if [ -d "$REAL_HOME/.gemini" ]; then
                mkdir -p "$DATA_DIR/.gemini"
                [ -d "$REAL_HOME/.gemini/bin" ] && [ ! -e "$DATA_DIR/.gemini/bin" ] && [ ! -L "$DATA_DIR/.gemini/bin" ] && ln -sf "$REAL_HOME/.gemini/bin" "$DATA_DIR/.gemini/bin" 2>/dev/null || true
                [ -d "$REAL_HOME/.gemini/lib" ] && [ ! -e "$DATA_DIR/.gemini/lib" ] && [ ! -L "$DATA_DIR/.gemini/lib" ] && ln -sf "$REAL_HOME/.gemini/lib" "$DATA_DIR/.gemini/lib" 2>/dev/null || true
                if [ -d "$REAL_HOME/.gemini/config/skills" ] && [ ! -e "$DATA_DIR/.gemini/config/skills" ] && [ ! -L "$DATA_DIR/.gemini/config/skills" ]; then
                  mkdir -p "$DATA_DIR/.gemini/config"
                  ln -sf "$REAL_HOME/.gemini/config/skills" "$DATA_DIR/.gemini/config/skills" 2>/dev/null || true
                fi
              fi
            fi

            # Isolate HOME & macOS Keychain BEFORE invoking security CLI so host Preferences/Keychains are never touched
            export HOME="$DATA_DIR"
            export CFFIXED_USER_HOME="$DATA_DIR"
            export XDG_CONFIG_HOME="$DATA_DIR/.config"
            export XDG_DATA_HOME="$DATA_DIR/.local/share"
            export XDG_CACHE_HOME="$DATA_DIR/.cache"
            export XDG_STATE_HOME="$DATA_DIR/.local/state"

            CLONE_KC="$DATA_DIR/Library/Keychains/duplix.keychain-db"
            if [ ! -f "$CLONE_KC" ]; then
              /usr/bin/security create-keychain -p "duplix" "$CLONE_KC" 2>/dev/null || true
              /usr/bin/security set-keychain-settings "$CLONE_KC" 2>/dev/null || true
            fi
            /usr/bin/security unlock-keychain -p "duplix" "$CLONE_KC" 2>/dev/null || true
            /usr/bin/security default-keychain -s "$CLONE_KC" 2>/dev/null || true
            /usr/bin/security list-keychains -s "$CLONE_KC" 2>/dev/null || true

            # Clear any inherited Antigravity parent env and enforce clone-local Gemini directory
            unset ANTIGRAVITY_APP_DATA_DIR ANTIGRAVITY_LS_ADDRESS ANTIGRAVITY_CSRF_TOKEN ANTIGRAVITY_AGENTAPI_EXE AGY_BROWSER_ACTIVE_PORT_FILE 2>/dev/null || true
            export GEMINI_DIR="$DATA_DIR/.gemini"
            export ANTIGRAVITY_GEMINI_DIR="$DATA_DIR/.gemini"

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
            mkdir -p "$DATA_DIR/Library/Application Support"
            mkdir -p "$DATA_DIR/Library/Caches"
            mkdir -p "$DATA_DIR/Library/Preferences"
            mkdir -p "$DATA_DIR/Library/Keychains"

            REAL_HOME="$HOME"
            if [ -n "$REAL_HOME" ] && [ "$REAL_HOME" != "$DATA_DIR" ]; then
              [ -e "$REAL_HOME/.gitconfig" ] && [ ! -e "$DATA_DIR/.gitconfig" ] && [ ! -L "$DATA_DIR/.gitconfig" ] && ln -sf "$REAL_HOME/.gitconfig" "$DATA_DIR/.gitconfig" 2>/dev/null || true
              [ -d "$REAL_HOME/.ssh" ] && [ ! -e "$DATA_DIR/.ssh" ] && [ ! -L "$DATA_DIR/.ssh" ] && ln -sf "$REAL_HOME/.ssh" "$DATA_DIR/.ssh" 2>/dev/null || true
            fi

            export HOME="$DATA_DIR"
            export CFFIXED_USER_HOME="$DATA_DIR"

            CLONE_KC="$DATA_DIR/Library/Keychains/duplix.keychain-db"
            if [ ! -f "$CLONE_KC" ]; then
              /usr/bin/security create-keychain -p "duplix" "$CLONE_KC" 2>/dev/null || true
              /usr/bin/security set-keychain-settings "$CLONE_KC" 2>/dev/null || true
            fi
            /usr/bin/security unlock-keychain -p "duplix" "$CLONE_KC" 2>/dev/null || true
            /usr/bin/security default-keychain -s "$CLONE_KC" 2>/dev/null || true
            /usr/bin/security list-keychains -s "$CLONE_KC" 2>/dev/null || true

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
            mkdir -p "$DATA_DIR"
            mkdir -p "$DATA_DIR/Library/Application Support"
            mkdir -p "$DATA_DIR/Library/Caches"
            mkdir -p "$DATA_DIR/Library/Preferences"
            mkdir -p "$DATA_DIR/Library/Keychains"

            REAL_HOME="$HOME"
            if [ -n "$REAL_HOME" ] && [ "$REAL_HOME" != "$DATA_DIR" ]; then
              [ -e "$REAL_HOME/.gitconfig" ] && [ ! -e "$DATA_DIR/.gitconfig" ] && [ ! -L "$DATA_DIR/.gitconfig" ] && ln -sf "$REAL_HOME/.gitconfig" "$DATA_DIR/.gitconfig" 2>/dev/null || true
              [ -d "$REAL_HOME/.ssh" ] && [ ! -e "$DATA_DIR/.ssh" ] && [ ! -L "$DATA_DIR/.ssh" ] && ln -sf "$REAL_HOME/.ssh" "$DATA_DIR/.ssh" 2>/dev/null || true
            fi

            export HOME="$DATA_DIR"
            export CFFIXED_USER_HOME="$DATA_DIR"

            CLONE_KC="$DATA_DIR/Library/Keychains/duplix.keychain-db"
            if [ ! -f "$CLONE_KC" ]; then
              /usr/bin/security create-keychain -p "duplix" "$CLONE_KC" 2>/dev/null || true
              /usr/bin/security set-keychain-settings "$CLONE_KC" 2>/dev/null || true
            fi
            /usr/bin/security unlock-keychain -p "duplix" "$CLONE_KC" 2>/dev/null || true
            /usr/bin/security default-keychain -s "$CLONE_KC" 2>/dev/null || true
            /usr/bin/security list-keychains -s "$CLONE_KC" 2>/dev/null || true

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
