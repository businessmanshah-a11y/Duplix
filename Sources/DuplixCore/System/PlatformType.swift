import Foundation

/// Represents the host operating system platform supported by Duplix.
public enum PlatformType: String, Sendable, Codable, CaseIterable {
    case macOS = "macOS"
    case windows = "windows"
    case linux = "linux"

    /// The active operating system detected at runtime or compile-time.
    public static var current: PlatformType {
        #if os(macOS)
        return .macOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #else
        return .macOS
        #endif
    }

    /// User-facing display name.
    public var displayName: String {
        switch self {
        case .macOS:
            return "macOS"
        case .windows:
            return "Windows"
        case .linux:
            return "Linux"
        }
    }

    /// Standard bundle or launcher shortcut extension used on this platform.
    public var shortcutExtension: String {
        switch self {
        case .macOS:
            return "app"
        case .windows:
            return "lnk"
        case .linux:
            return "desktop"
        }
    }

    /// Whether this platform uses Unix-like file paths (`/`) or Windows paths (`\`).
    public var isUnixLike: Bool {
        return self != .windows
    }
}
