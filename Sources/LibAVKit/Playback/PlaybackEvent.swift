import Foundation

public enum PlaybackEvent: Sendable {
    case stateChanged(PlaybackState)
    case progress(TimeInterval)
    case error(PlaybackError)
}
