import AVFoundation

/// Default ``AudioOutput`` implementation backed by `AVAudioEngine` and
/// `AVAudioPlayerNode`.
public final class AVAudioEngineOutput: AudioOutput, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var cachedFormat: AVAudioFormat?

    public init() {
        engine.attach(playerNode)
    }

    deinit {
        engine.stop()
    }

    // MARK: - AudioOutput

    public func configure(sampleRate: Double, channels: Int) throws {
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        )!

        cachedFormat = audioFormat
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)

        do {
            try engine.start()
        } catch {
            throw PlaybackError.audioOutputFailed(error.localizedDescription)
        }
    }

    public func start() throws {
        playerNode.play()
    }

    public func pause() {
        playerNode.pause()
    }

    public func stop() {
        if engine.isRunning {
            engine.stop()
        }
        playerNode.stop()
        engine.disconnectNodeOutput(playerNode)
        cachedFormat = nil
    }

    public func scheduleAudio(_ frame: DecodedFrame) {
        guard let format = cachedFormat,
              let avBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frame.frameCount)),
              let floatData = avBuffer.floatChannelData else { return }
        for ch in 0..<frame.channelCount {
            floatData[ch].update(from: frame.channelData[ch], count: frame.frameCount)
        }
        avBuffer.frameLength = AVAudioFrameCount(frame.frameCount)
        playerNode.scheduleBuffer(avBuffer)
    }

    @discardableResult
    public func waitForCompletion(checkCancelled: () -> Bool) -> Bool {
        let format = playerNode.outputFormat(forBus: 0)
        guard let sentinel = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1) else {
            return false
        }
        sentinel.frameLength = 0

        let semaphore = DispatchSemaphore(value: 0)
        playerNode.scheduleBuffer(sentinel) {
            semaphore.signal()
        }

        let deadline = DispatchTime.now() + .seconds(60)
        while DispatchTime.now() < deadline {
            if semaphore.wait(timeout: .now() + .milliseconds(50)) == .success {
                return true
            }
            if checkCancelled() { return false }
        }
        return false
    }

    public var playbackPosition: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime,
              nodeTime.isSampleTimeValid,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              playerTime.sampleTime >= 0 else {
            return -1
        }
        return Double(playerTime.sampleTime) / playerTime.sampleRate
    }

    public var volume: Float {
        get { playerNode.volume }
        set { playerNode.volume = max(0, min(1, newValue)) }
    }
}
