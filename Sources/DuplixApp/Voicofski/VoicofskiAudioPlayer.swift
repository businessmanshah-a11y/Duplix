import AVFoundation
import Foundation

@MainActor
public final class VoicofskiAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var audioLevel: CGFloat = 0
    @Published public private(set) var playbackRate: Float = 1.0

    public var onPlaybackFinished: (() -> Void)?
    public var onProgressUpdated: ((Double, TimeInterval, TimeInterval, CGFloat) -> Void)?

    private var player: AVAudioPlayer?
    private var tickTimer: Timer?
    private let supportedRates: [Float] = [1.0, 1.25, 1.5]

    public var hasLoadedAudio: Bool {
        player != nil
    }

    public func loadAndPlay(url: URL) throws {
        stop(clearPlayer: true)

        let audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer.delegate = self
        audioPlayer.enableRate = true
        audioPlayer.rate = playbackRate
        audioPlayer.isMeteringEnabled = true
        audioPlayer.prepareToPlay()

        self.player = audioPlayer
        self.duration = audioPlayer.duration
        self.currentTime = 0
        self.progress = 0
        self.audioLevel = 0

        play()
    }

    public func play() {
        guard let player else { return }
        player.rate = playbackRate
        player.play()
        isPlaying = true
        startTickTimer()
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        audioLevel = 0
        stopTickTimer()
        onProgressUpdated?(progress, currentTime, duration, 0)
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            if let player, player.currentTime >= max(0, player.duration - 0.05) {
                replay()
            } else {
                play()
            }
        }
    }

    public func replay() {
        guard let player else { return }
        player.currentTime = 0
        currentTime = 0
        progress = 0
        play()
    }

    public func seek(toProgress targetProgress: Double) {
        guard let player, player.duration > 0 else { return }
        let clamped = min(max(targetProgress, 0), 1)
        player.currentTime = clamped * player.duration
        currentTime = player.currentTime
        progress = clamped
        onProgressUpdated?(progress, currentTime, duration, audioLevel)
    }

    @discardableResult
    public func cyclePlaybackRate() -> Float {
        let nextIndex: Int
        if let idx = supportedRates.firstIndex(of: playbackRate) {
            nextIndex = (idx + 1) % supportedRates.count
        } else {
            nextIndex = 0
        }
        playbackRate = supportedRates[nextIndex]
        if let player {
            player.rate = playbackRate
        }
        return playbackRate
    }

    public func stop(clearPlayer: Bool = true) {
        stopTickTimer()
        player?.stop()
        if clearPlayer {
            player = nil
            duration = 0
        }
        isPlaying = false
        currentTime = 0
        progress = 0
        audioLevel = 0
    }

    // MARK: - Timer

    private func startTickTimer() {
        stopTickTimer()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func handleTick() {
        guard let player else { return }
        currentTime = player.currentTime
        duration = player.duration
        progress = duration > 0 ? min(max(currentTime / duration, 0), 1) : 0

        if player.isPlaying {
            player.updateMeters()
            let power = player.averagePower(forChannel: 0) // -160...0 dB
            let normalized = max(0.0, min(1.0, (power + 48.0) / 48.0))
            audioLevel = CGFloat(normalized)
        } else {
            audioLevel = 0
        }

        onProgressUpdated?(progress, currentTime, duration, audioLevel)
    }

    // MARK: - AVAudioPlayerDelegate

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopTickTimer()
            self.isPlaying = false
            self.audioLevel = 0
            self.currentTime = self.duration
            self.progress = 1.0
            self.onProgressUpdated?(1.0, self.duration, self.duration, 0)
            self.onPlaybackFinished?()
        }
    }
}
