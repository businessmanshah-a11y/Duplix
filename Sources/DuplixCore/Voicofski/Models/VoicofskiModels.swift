import Foundation

// MARK: - Voice Selection

public enum VoicofskiVoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case female
    case male

    public var id: String { rawValue }

    /// Exact prebuilt voice name in Google AI Studio (`gemini-3.8-flash-tts`)
    public var aiStudioVoiceName: String {
        switch self {
        case .female: return "Lora"
        case .male: return "Bodi"
        }
    }

    public var displayName: String {
        switch self {
        case .female: return "Female (Lora)"
        case .male: return "Male (Bodi)"
        }
    }

    public var shortName: String {
        switch self {
        case .female: return "Lora"
        case .male: return "Bodi"
        }
    }

    public var descriptionText: String {
        switch self {
        case .female: return "Clear & friendly"
        case .male: return "Quiet & intimate"
        }
    }
}

// MARK: - Supported Translation Target Languages (6 languages)

public enum VoicofskiTargetLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case persian = "fa"
    case english = "en"
    case german = "de"
    case french = "fr"
    case dutch = "nl"
    case arabic = "ar"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .persian: return "Persian"
        case .english: return "English"
        case .german: return "German"
        case .french: return "French"
        case .dutch: return "Dutch"
        case .arabic: return "Arabic"
        }
    }

    public var promptLanguageName: String {
        switch self {
        case .persian: return "Persian (Farsi)"
        case .english: return "English"
        case .german: return "German"
        case .french: return "French"
        case .dutch: return "Dutch"
        case .arabic: return "Arabic"
        }
    }
}

// MARK: - Mode

public enum VoicofskiMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case direct
    case translate

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .direct: return "Speak"
        case .translate: return "Translate"
        }
    }
}

// MARK: - API Key Metadata & Health

public enum APIKeyHealthStatus: String, Codable, Sendable {
    case untested
    case active
    case exhausted
    case invalid
}

public struct APIKeyMetadata: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var label: String
    public var orderIndex: Int
    public var status: APIKeyHealthStatus
    public var nextResetAt: Date?
    public var lastError: String?
    public var lastUsedAt: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        label: String,
        orderIndex: Int,
        status: APIKeyHealthStatus = .untested,
        nextResetAt: Date? = nil,
        lastError: String? = nil,
        lastUsedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.orderIndex = orderIndex
        self.status = status
        self.nextResetAt = nextResetAt
        self.lastError = lastError
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }
}

// MARK: - History Item

public struct VoicofskiHistoryItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let mode: VoicofskiMode
    public let originalText: String
    public let translatedText: String?
    public let targetLanguage: VoicofskiTargetLanguage?
    public let voice: VoicofskiVoice
    public let audioFileName: String
    public let durationSeconds: Double

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        mode: VoicofskiMode,
        originalText: String,
        translatedText: String? = nil,
        targetLanguage: VoicofskiTargetLanguage? = nil,
        voice: VoicofskiVoice,
        audioFileName: String,
        durationSeconds: Double
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mode = mode
        self.originalText = originalText
        self.translatedText = translatedText
        self.targetLanguage = targetLanguage
        self.voice = voice
        self.audioFileName = audioFileName
        self.durationSeconds = durationSeconds
    }

    public var spokenText: String {
        translatedText ?? originalText
    }

    public var formattedDuration: String {
        let total = max(0, Int(durationSeconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Pending Quota Request

public struct PendingQuotaRequest: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let text: String
    public let mode: VoicofskiMode
    public let targetLanguage: VoicofskiTargetLanguage?
    public let voice: VoicofskiVoice

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        text: String,
        mode: VoicofskiMode,
        targetLanguage: VoicofskiTargetLanguage? = nil,
        voice: VoicofskiVoice
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.mode = mode
        self.targetLanguage = targetLanguage
        self.voice = voice
    }
}

// MARK: - Errors

public enum VoicofskiError: Error, LocalizedError, Equatable, Sendable {
    case noAPIKeys
    case allKeysExhausted
    case quotaExceeded
    case invalidAPIKey(String)
    case regionBlocked
    case networkFailure(String)
    case emptyAudioResponse
    case emptyTranslationResponse
    case apiError(Int, String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noAPIKeys:
            return "No Google AI Studio API keys configured. Add a key in Voicofski settings."
        case .allKeysExhausted:
            return "All API keys have reached their daily quota. Your request was saved to the Pending Queue."
        case .quotaExceeded:
            return "API key daily quota exceeded."
        case .invalidAPIKey(let detail):
            return detail.isEmpty ? "Invalid Google AI Studio API key." : "Invalid API key: \(detail)"
        case .regionBlocked:
            return "Google AI Studio is unavailable in this region. Please check your VPN connection."
        case .networkFailure(let detail):
            return "Connection failed — please check your internet or VPN (\(detail))."
        case .emptyAudioResponse:
            return "Gemini TTS did not return any audio data."
        case .emptyTranslationResponse:
            return "Gemini did not return any translated text."
        case .apiError(let status, let message):
            return "API error (\(status)): \(message)"
        case .cancelled:
            return "Request cancelled."
        }
    }
}

// MARK: - Text Metrics & Constants

public enum VoicofskiTextMetrics {
    public static let minSelectionCharacterCount = 3
    public static let longTextWordThreshold = 500

    public static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func meetsMinimumSelectionLength(_ text: String) -> Bool {
        trimmed(text).count >= minSelectionCharacterCount
    }

    public static func wordCount(_ text: String) -> Int {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.count
    }

    public static func exceedsLongTextWarning(_ text: String) -> Bool {
        wordCount(text) > longTextWordThreshold
    }
}

// MARK: - Model Constants

public enum VoicofskiModelConfig {
    public static let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    public static let ttsModel = "gemini-3.8-flash-tts"
    public static let translationModel = "gemini-2.5-flash"
    public static let apiKeyStudioURL = "https://aistudio.google.com/apikey"
}
