import Foundation

public struct VoicofskiSettingsStore: Sendable {
    private enum Keys {
        static let selectionTriggerEnabled = "duplix.voicofski.selectionTriggerEnabled"
        static let selectedVoice = "duplix.voicofski.selectedVoice"
        static let targetLanguage = "duplix.voicofski.targetLanguage"
    }

    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private func defaults() -> UserDefaults {
        if let suiteName, let custom = UserDefaults(suiteName: suiteName) {
            return custom
        }
        return .standard
    }

    public var isSelectionTriggerEnabled: Bool {
        get {
            let ud = defaults()
            if ud.object(forKey: Keys.selectionTriggerEnabled) == nil {
                return true
            }
            return ud.bool(forKey: Keys.selectionTriggerEnabled)
        }
        nonmutating set {
            defaults().set(newValue, forKey: Keys.selectionTriggerEnabled)
        }
    }

    public var selectedVoice: VoicofskiVoice {
        get {
            guard let raw = defaults().string(forKey: Keys.selectedVoice),
                  let voice = VoicofskiVoice(rawValue: raw) else {
                return .female
            }
            return voice
        }
        nonmutating set {
            defaults().set(newValue.rawValue, forKey: Keys.selectedVoice)
        }
    }

    public var targetLanguage: VoicofskiTargetLanguage {
        get {
            guard let raw = defaults().string(forKey: Keys.targetLanguage),
                  let lang = VoicofskiTargetLanguage(rawValue: raw) else {
                return .persian
            }
            return lang
        }
        nonmutating set {
            defaults().set(newValue.rawValue, forKey: Keys.targetLanguage)
        }
    }
}
