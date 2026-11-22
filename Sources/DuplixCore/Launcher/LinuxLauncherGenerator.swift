import Foundation

/// Generates Linux launcher scripts using Bubblewrap (bwrap) sandboxing and FreeDesktop .desktop entries.
public struct LinuxLauncherGenerator: Sendable {
    public init() {}

    public enum LinuxLauncherError: LocalizedError, Sendable {
        case writeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .writeFailed(let msg):
                return "Failed to write Linux launcher: \(msg)"
            }
        }
    }

    /// Generates a Bubblewrap (`bwrap`) shell launcher script with isolated configuration and data directories.
    public func generateBwrapScript(
        executablePath: String,
        appName: String,
        dataDirectoryPath: String,
        engineType: EngineType
    ) -> String {
        return """
        #!/usr/bin/env bash
        set -e

        DATA_DIR="\(dataDirectoryPath)"
        CONFIG_DIR="$DATA_DIR/config"
        SHARE_DIR="$DATA_DIR/share"
        CACHE_DIR="$DATA_DIR/cache"

        mkdir -p "$CONFIG_DIR" "$SHARE_DIR" "$CACHE_DIR"

        # Check if bubblewrap is installed for deep sandboxing
        if command -v bwrap >/dev/null 2>&1; then
            exec bwrap \\
                --ro-bind / / \\
                --dev /dev \\
                --proc /proc \\
                --tmpfs /tmp \\
                --bind "$HOME" "$HOME" \\
                --bind "$CONFIG_DIR" "$HOME/.config" \\
                --bind "$SHARE_DIR" "$HOME/.local/share" \\
                --bind "$CACHE_DIR" "$HOME/.cache" \\
                --setenv XDG_CONFIG_HOME "$CONFIG_DIR" \\
                --setenv XDG_DATA_HOME "$SHARE_DIR" \\
                --setenv XDG_CACHE_HOME "$CACHE_DIR" \\
                "\(executablePath)" "$@"
        else
            # Fallback to direct XDG environment isolation
            export XDG_CONFIG_HOME="$CONFIG_DIR"
            export XDG_DATA_HOME="$SHARE_DIR"
            export XDG_CACHE_HOME="$CACHE_DIR"
            exec "\(executablePath)" "$@"
        fi
        """
    }

    /// Generates a FreeDesktop standard `.desktop` entry file.
    public func generateDesktopEntry(
        cloneName: String,
        launcherScriptPath: String,
        iconPath: String,
        categories: [String] = ["Utility", "Development"],
        comment: String = "Duplix Isolated Instance"
    ) -> String {
        let cats = categories.joined(separator: ";") + ";"
        return """
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=\(cloneName)
        Comment=\(comment)
        Exec=\(launcherScriptPath) %U
        Icon=\(iconPath)
        Terminal=false
        Categories=\(cats)
        StartupNotify=true
        StartupWMClass=Duplix-\(cloneName.replacingOccurrences(of: " ", with: "-"))
        """
    }

    /// Writes both the launcher script and `.desktop` entry file to disk.
    public func writeLinuxLauncher(
        scriptURL: URL,
        desktopFileURL: URL,
        executablePath: String,
        appName: String,
        cloneName: String,
        dataDirectoryPath: String,
        iconPath: String,
        engineType: EngineType
    ) throws {
        let scriptContent = generateBwrapScript(
            executablePath: executablePath,
            appName: appName,
            dataDirectoryPath: dataDirectoryPath,
            engineType: engineType
        )

        let desktopContent = generateDesktopEntry(
            cloneName: cloneName,
            launcherScriptPath: scriptURL.path,
            iconPath: iconPath
        )

        // Ensure directories exist
        let scriptParent = scriptURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: scriptParent.path) {
            try FileManager.default.createDirectory(at: scriptParent, withIntermediateDirectories: true)
        }
        let desktopParent = desktopFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: desktopParent.path) {
            try FileManager.default.createDirectory(at: desktopParent, withIntermediateDirectories: true)
        }

        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        try desktopContent.write(to: desktopFileURL, atomically: true, encoding: .utf8)

        #if os(macOS) || os(Linux)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        #endif
    }
}
