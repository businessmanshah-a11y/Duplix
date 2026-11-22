import Foundation

/// Generates Windows launcher scripts (.cmd, .ps1) and shortcut generation scripts (.lnk)
/// with deep user-data-dir and session isolation.
public struct WindowsLauncherGenerator: Sendable {
    public init() {}

    public enum WindowsLauncherError: LocalizedError, Sendable {
        case writeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .writeFailed(let msg):
                return "Failed to write Windows launcher: \(msg)"
            }
        }
    }

    /// Generates command-line arguments needed to isolate the application session.
    public func generateIsolationArguments(
        dataDirectoryPath: String,
        engineType: EngineType
    ) -> [String] {
        switch engineType {
        case .electron:
            return [
                "--user-data-dir=\"\(dataDirectoryPath)\"",
                "--extensions-dir=\"\(dataDirectoryPath)\\Extensions\"",
                "--password-store=basic",
                "--no-default-browser-check"
            ]
        case .gecko:
            return [
                "-profile",
                "\"\(dataDirectoryPath)\"",
                "-no-remote"
            ]
        case .native, .nativeCocoa, .unknown:
            return [
                "--duplix-data=\"\(dataDirectoryPath)\""
            ]
        }
    }

    /// Generates a Windows Batch (.cmd) launcher script.
    public func generateCmdScript(
        executablePath: String,
        dataDirectoryPath: String,
        engineType: EngineType,
        extraArgs: [String] = []
    ) -> String {
        let args = (generateIsolationArguments(dataDirectoryPath: dataDirectoryPath, engineType: engineType) + extraArgs).joined(separator: " ")

        return """
        @echo off
        setlocal
        set "DATA_DIR=\(dataDirectoryPath)"
        if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
        if not exist "%DATA_DIR%\\Extensions" mkdir "%DATA_DIR%\\Extensions"

        :: Bridge developer configs if available
        if exist "%USERPROFILE%\\.gitconfig" if not exist "%DATA_DIR%\\.gitconfig" (
            mklink /H "%DATA_DIR%\\.gitconfig" "%USERPROFILE%\\.gitconfig" >nul 2>&1
        )
        if exist "%USERPROFILE%\\.ssh" if not exist "%DATA_DIR%\\.ssh" (
            mklink /J "%DATA_DIR%\\.ssh" "%USERPROFILE%\\.ssh" >nul 2>&1
        )

        :: Launch isolated instance
        start "" "\(executablePath)" \(args) %*
        endlocal
        """
    }

    /// Generates PowerShell script to build a native Windows Shortcut (.lnk) on the target machine.
    public func generatePowerShellShortcutScript(
        shortcutPath: String,
        targetExePath: String,
        dataDirectoryPath: String,
        engineType: EngineType,
        iconPath: String? = nil,
        description: String = "Duplix Isolated Instance"
    ) -> String {
        let args = generateIsolationArguments(dataDirectoryPath: dataDirectoryPath, engineType: engineType).joined(separator: " ")
        let iconLine: String
        if let icon = iconPath, !icon.isEmpty {
            iconLine = "$Shortcut.IconLocation = \"\(icon)\""
        } else {
            iconLine = "$Shortcut.IconLocation = \"\(targetExePath),0\""
        }

        return """
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("\(shortcutPath)")
        $Shortcut.TargetPath = "\(targetExePath)"
        $Shortcut.Arguments = '\(args)'
        $Shortcut.Description = "\(description)"
        \(iconLine)
        $Shortcut.Save()
        """
    }

    /// Writes the `.cmd` launcher script to disk.
    public func writeCmdLauncher(
        at fileURL: URL,
        executablePath: String,
        dataDirectoryPath: String,
        engineType: EngineType
    ) throws {
        let content = generateCmdScript(
            executablePath: executablePath,
            dataDirectoryPath: dataDirectoryPath,
            engineType: engineType
        )
        let parent = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
