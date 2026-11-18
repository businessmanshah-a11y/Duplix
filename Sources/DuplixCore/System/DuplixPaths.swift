import Foundation
import Darwin

public enum DuplixPaths {
    /// Resolves the true macOS user home directory (e.g. `/Users/<username>`) directly from
    /// POSIX user records (`getpwuid`), making Duplix immune to `HOME` / `CFFIXED_USER_HOME`
    /// overrides when launched from inside an isolated Duplix clone or terminal.
    public static var realHomeDirectoryURL: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
