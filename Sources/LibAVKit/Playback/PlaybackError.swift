import Foundation

public enum PlaybackError: Error, LocalizedError {
    case openFailed(String)
    case decodeFailed(String)
    case audioOutputFailed(String)
    case seekFailed
    case notOpen

    public var errorDescription: String? {
        switch self {
        case let .openFailed(path):
            "Failed to open audio file: \(path)"
        case let .decodeFailed(msg):
            "Decoding failed: \(msg)"
        case let .audioOutputFailed(msg):
            "Audio output error: \(msg)"
        case .seekFailed:
            "Seek operation failed"
        case .notOpen:
            "No file is open for playback"
        }
    }
}
