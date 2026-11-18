import Foundation

public struct AudioStreamParameters: Equatable, Sendable {
    public let bitsPerSample: Int
    public let sampleRate: Int
    public let numChannels: Int

    public init(bitsPerSample: Int = 16, sampleRate: Int = 24000, numChannels: Int = 1) {
        self.bitsPerSample = bitsPerSample
        self.sampleRate = sampleRate
        self.numChannels = numChannels
    }
}

public enum PCMWavEncoder {
    /// Parses bits per sample and sample rate from an audio MIME type string
    /// matching Google AI Studio's `parse_audio_mime_type` (e.g. `audio/L16;rate=24000` or `audio/L16;codec=pcm;rate=24000`).
    public static func parseAudioMimeType(_ mimeType: String) -> AudioStreamParameters {
        var bitsPerSample = 16
        var sampleRate = 24000

        let parts = mimeType.split(separator: ";")
        for rawPart in parts {
            let param = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = param.lowercased()

            if lower.hasPrefix("rate=") {
                let value = String(param.dropFirst("rate=".count))
                if let parsed = Int(value), parsed > 0 {
                    sampleRate = parsed
                }
            } else if lower.hasPrefix("audio/l") {
                if let lIndex = param.range(of: "L", options: .caseInsensitive)?.upperBound {
                    let bitsString = String(param[lIndex...])
                    if let parsed = Int(bitsString), parsed > 0, parsed % 8 == 0 {
                        bitsPerSample = parsed
                    }
                }
            }
        }

        return AudioStreamParameters(bitsPerSample: bitsPerSample, sampleRate: sampleRate, numChannels: 1)
    }

    /// Returns true if the buffer already starts with a standard RIFF/WAVE header.
    public static func isAlreadyWAV(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let riff = Data("RIFF".utf8)
        let wave = Data("WAVE".utf8)
        return data.prefix(4) == riff && data.subdata(in: 8..<12) == wave
    }

    /// Converts raw PCM audio bytes into a standard RIFF/WAV buffer using parameters parsed from `mimeType`.
    public static func convertToWAV(audioData: Data, mimeType: String) -> (wavData: Data, durationSeconds: Double) {
        if isAlreadyWAV(audioData) {
            let params = parseAudioMimeType(mimeType)
            let payloadBytes = max(0, audioData.count - 44)
            let duration = durationSeconds(forPCMByteCount: payloadBytes, parameters: params)
            return (audioData, duration)
        }

        let params = parseAudioMimeType(mimeType)
        let wavData = wrapPCMInWAVHeader(pcmData: audioData, parameters: params)
        let duration = durationSeconds(forPCMByteCount: audioData.count, parameters: params)
        return (wavData, duration)
    }

    /// Prepends a standard 44-byte RIFF/WAVE PCM header to `pcmData`.
    public static func wrapPCMInWAVHeader(pcmData: Data, parameters: AudioStreamParameters = AudioStreamParameters()) -> Data {
        let numChannels = UInt16(parameters.numChannels)
        let sampleRate = UInt32(parameters.sampleRate)
        let bitsPerSample = UInt16(parameters.bitsPerSample)
        let bytesPerSample = UInt16(parameters.bitsPerSample / 8)
        let blockAlign = numChannels * bytesPerSample
        let byteRate = sampleRate * UInt32(blockAlign)
        let dataSize = UInt32(pcmData.count)
        let chunkSize = UInt32(36) + dataSize

        var header = Data(capacity: 44 + pcmData.count)
        header.append(contentsOf: "RIFF".utf8)
        header.appendLittleEndian(chunkSize)
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.appendLittleEndian(UInt32(16))      // Subchunk1Size (16 for PCM)
        header.appendLittleEndian(UInt16(1))       // AudioFormat (1 = Linear PCM)
        header.appendLittleEndian(numChannels)
        header.appendLittleEndian(sampleRate)
        header.appendLittleEndian(byteRate)
        header.appendLittleEndian(blockAlign)
        header.appendLittleEndian(bitsPerSample)
        header.append(contentsOf: "data".utf8)
        header.appendLittleEndian(dataSize)
        header.append(pcmData)
        return header
    }

    public static func durationSeconds(forPCMByteCount byteCount: Int, parameters: AudioStreamParameters) -> Double {
        let bytesPerSample = max(1, parameters.bitsPerSample / 8)
        let byteRate = Double(parameters.sampleRate * parameters.numChannels * bytesPerSample)
        guard byteRate > 0 else { return 0 }
        return Double(byteCount) / byteRate
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
