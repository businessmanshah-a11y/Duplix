import Foundation

public struct SynthesizedAudioResult: Sendable {
    public let wavData: Data
    public let durationSeconds: Double
    public let mimeType: String

    public init(wavData: Data, durationSeconds: Double, mimeType: String) {
        self.wavData = wavData
        self.durationSeconds = durationSeconds
        self.mimeType = mimeType
    }
}

public protocol GeminiAPIClientProtocol: Sendable {
    func testKey(apiKey: String) async throws
    func translate(text: String, targetLanguage: VoicofskiTargetLanguage, model: String, apiKey: String) async throws -> String
    func synthesizeSpeech(text: String, voice: VoicofskiVoice, apiKey: String) async throws -> SynthesizedAudioResult
}

public final class GeminiAPIClient: GeminiAPIClientProtocol {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Test Key (zero generation token cost)

    public func testKey(apiKey: String) async throws {
        guard let url = URL(string: "\(VoicofskiModelConfig.baseURL)/models?pageSize=1") else {
            throw VoicofskiError.networkFailure("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 20

        let (data, response) = try await perform(request)
        try validateHTTPResponse(response, data: data)
    }

    // MARK: - Translate (Gemini 3.8 Flash / Fallback Text Models)

    public func translate(
        text: String,
        targetLanguage: VoicofskiTargetLanguage,
        model: String = VoicofskiModelConfig.translationModel,
        apiKey: String
    ) async throws -> String {
        guard let url = URL(string: "\(VoicofskiModelConfig.baseURL)/models/\(model):generateContent") else {
            throw VoicofskiError.networkFailure("Invalid translation URL")
        }

        let systemPrompt = """
        You are a precise translator. Translate the user's text naturally and accurately into \(targetLanguage.promptLanguageName). Return ONLY the translated text with no explanations, quotes, markdown wrappers, or extra commentary.
        """

        let payload: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await perform(request)
        try validateHTTPResponse(response, data: data)

        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        let combined = decoded.candidates?
            .first?
            .content?
            .parts?
            .compactMap { $0.text }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !combined.isEmpty else {
            throw VoicofskiError.emptyTranslationResponse
        }

        return combined
    }

    // MARK: - Synthesize Speech (gemini-3.8-flash-tts — Lora / Bodi)

    public func synthesizeSpeech(
        text: String,
        voice: VoicofskiVoice,
        apiKey: String
    ) async throws -> SynthesizedAudioResult {
        guard let url = URL(string: "\(VoicofskiModelConfig.baseURL)/models/\(VoicofskiModelConfig.ttsModel):generateContent") else {
            throw VoicofskiError.networkFailure("Invalid TTS URL")
        }

        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 1,
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": voice.aiStudioVoiceName
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await perform(request)
        try validateHTTPResponse(response, data: data)

        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        var rawAudio = Data()
        var resolvedMimeType = "audio/L16;rate=24000"

        if let parts = decoded.candidates?.first?.content?.parts {
            for part in parts {
                if let inlineData = part.inlineData,
                   let base64 = inlineData.data,
                   let chunk = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
                    rawAudio.append(chunk)
                    if let mime = inlineData.mimeType, !mime.isEmpty {
                        resolvedMimeType = mime
                    }
                }
            }
        }

        guard !rawAudio.isEmpty else {
            throw VoicofskiError.emptyAudioResponse
        }

        let converted = PCMWavEncoder.convertToWAV(audioData: rawAudio, mimeType: resolvedMimeType)
        return SynthesizedAudioResult(
            wavData: converted.wavData,
            durationSeconds: converted.durationSeconds,
            mimeType: resolvedMimeType
        )
    }

    // MARK: - Networking & Error Classification

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is CancellationError {
            throw VoicofskiError.cancelled
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw VoicofskiError.cancelled
        } catch {
            throw VoicofskiError.networkFailure(error.localizedDescription)
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw VoicofskiError.networkFailure("Unexpected non-HTTP response")
        }

        guard !(200...299).contains(http.statusCode) else {
            return
        }

        let apiErr = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data).error
        let message = apiErr?.message ?? String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
        let statusStr = (apiErr?.status ?? "").uppercased()
        let lowerMsg = message.lowercased()

        // 429 or explicit quota exhaustion
        if http.statusCode == 429 ||
            statusStr == "RESOURCE_EXHAUSTED" ||
            lowerMsg.contains("quota") ||
            lowerMsg.contains("rate limit") ||
            lowerMsg.contains("resource exhausted") {
            throw VoicofskiError.quotaExceeded
        }

        // Region / geo-restriction (e.g., VPN needed)
        if lowerMsg.contains("location is not supported") ||
            lowerMsg.contains("user location") ||
            lowerMsg.contains("not available in your country") ||
            lowerMsg.contains("region") && http.statusCode == 400 {
            throw VoicofskiError.regionBlocked
        }

        // Model not found / deprecated for new users (HTTP 404)
        if http.statusCode == 404 ||
            statusStr == "NOT_FOUND" ||
            lowerMsg.contains("no longer available") ||
            lowerMsg.contains("is not found") {
            throw VoicofskiError.modelNotAvailable(message)
        }

        // Invalid API key
        if http.statusCode == 401 ||
            lowerMsg.contains("api key not valid") ||
            lowerMsg.contains("api_key_invalid") ||
            lowerMsg.contains("invalid api key") ||
            (http.statusCode == 403 && !lowerMsg.contains("location")) {
            throw VoicofskiError.invalidAPIKey(message)
        }

        throw VoicofskiError.apiError(http.statusCode, message)
    }
}

// MARK: - Gemini JSON Codable Models

private struct GeminiGenerateResponse: Decodable {
    let candidates: [Candidate]?

    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
        let inlineData: InlineData?
    }

    struct InlineData: Decodable {
        let mimeType: String?
        let data: String?
    }
}

private struct GeminiErrorEnvelope: Decodable {
    let error: GeminiAPIError?

    struct GeminiAPIError: Decodable {
        let code: Int?
        let message: String?
        let status: String?
    }
}
