import Foundation

extension AudioPlayer {
    /// AsyncStream of playback events. Bridges the closure callbacks
    /// into a single event stream for async consumers.
    public var events: AsyncStream<PlaybackEvent> {
        AsyncStream { continuation in
            self.onStateChange = { state in
                continuation.yield(.stateChanged(state))
            }
            self.onProgress = { time in
                continuation.yield(.progress(time))
            }
            self.onError = { error in
                continuation.yield(.error(error))
            }
            continuation.onTermination = { @Sendable _ in
                self.onStateChange = nil
                self.onProgress = nil
                self.onError = nil
            }
        }
    }
}
