import Foundation

/// Bridges Duplix mobile features with iOS system-level extensions, Action Button shortcuts,
/// and Share Sheet interfaces within Apple's secure sandboxed ecosystem.
public struct IOSCompanionBridge: Sendable {
    public static let urlScheme = "duplix-voice"

    public init() {}

    /// Builds a deep-link URL suitable for iOS Action Button, Lock Screen widgets, or Siri Shortcuts
    /// to trigger an instant voice recording memo.
    public func buildVoiceMemoLaunchURL(autoRecord: Bool = true) -> URL? {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = "memo"
        if autoRecord {
            components.queryItems = [URLQueryItem(name: "action", value: "start_recording")]
        }
        return components.url
    }

    /// Builds a deep-link URL for Voicofski text-to-speech or translation from Share Sheet.
    public func buildVoicofskiSpeakURL(text: String, languageCode: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = "speak"
        var items = [URLQueryItem(name: "text", value: text)]
        if let lang = languageCode {
            items.append(URLQueryItem(name: "lang", value: lang))
        }
        components.queryItems = items
        return components.url
    }

    /// App group identifier for sharing state between iOS main app and Share/Widget extensions.
    public var appGroupIdentifier: String {
        return "group.com.duplix.shared"
    }
}
