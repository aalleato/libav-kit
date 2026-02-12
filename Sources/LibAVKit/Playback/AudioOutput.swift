import Foundation

/// Abstraction for audio output hardware.
/// The default implementation is ``AVAudioEngineOutput``. Consumers can
/// provide custom implementations (Core Audio, SDL, mock for testing, etc.).
public protocol AudioOutput: AnyObject, Sendable {
    /// Prepare the output for the given format. Called once per ``AudioPlayer/open(url:)``.
    func configure(sampleRate: Double, channels: Int) throws

    /// Begin (or resume) audio output.
    func start() throws

    /// Pause output, keeping buffers intact.
    func pause()

    /// Stop output and discard scheduled buffers.
    func stop()

    /// Enqueue decoded audio for playback.
    func scheduleAudio(_ frame: DecodedFrame)

    /// Block until all scheduled buffers have been rendered, polling
    /// `checkCancelled` so the caller can interrupt the wait.
    /// Returns `true` if playback completed, `false` if cancelled.
    @discardableResult
    func waitForCompletion(checkCancelled: () -> Bool) -> Bool

    /// The elapsed time (in seconds) since the last ``start()`` call.
    var playbackPosition: TimeInterval { get }

    /// Output volume in the range 0…1.
    var volume: Float { get set }
}
