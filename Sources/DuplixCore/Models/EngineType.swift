import Foundation

public enum EngineType: String, Codable, Sendable {
    case electron = "Electron / Chromium"
    case gecko = "Gecko (Firefox)"
    case nativeCocoa = "Native Cocoa / AppKit"
    case native = "Native / System"
    case unknown = "Unknown / Generic"

    public var description: String {
        return rawValue
    }
}
