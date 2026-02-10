import Foundation

/// Target output format for audio conversion
public enum OutputFormat: String, Sendable, Codable, CaseIterable {
    // Lossless
    case flac
    case alac
    case wav
    case aiff
    case wavpack

    // Lossy
    case mp3
    case aac
    case opus
    case vorbis

    public var fileExtension: String {
        switch self {
        case .flac: "flac"
        case .alac, .aac: "m4a"
        case .wav: "wav"
        case .aiff: "aiff"
        case .wavpack: "wv"
        case .mp3: "mp3"
        case .opus: "opus"
        case .vorbis: "ogg"
        }
    }

    public var isLossless: Bool {
        switch self {
        case .flac, .alac, .wav, .aiff, .wavpack:
            true
        case .mp3, .aac, .opus, .vorbis:
            false
        }
    }

    public var displayName: String {
        switch self {
        case .flac: "FLAC"
        case .alac: "ALAC (Apple Lossless)"
        case .wav: "WAV"
        case .aiff: "AIFF"
        case .wavpack: "WavPack"
        case .mp3: "MP3"
        case .aac: "AAC"
        case .opus: "Opus"
        case .vorbis: "Vorbis"
        }
    }

    public var supportsBitrateMode: Bool {
        switch self {
        case .mp3, .aac, .opus, .vorbis:
            true
        case .flac, .alac, .wav, .aiff, .wavpack:
            false
        }
    }

    public var supportsCoverArt: Bool {
        switch self {
        case .flac, .mp3, .aac, .alac, .opus, .vorbis: true
        case .wav, .aiff, .wavpack: false
        }
    }

    /// OGG-based formats embed cover art as a base64-encoded METADATA_BLOCK_PICTURE
    /// Vorbis comment tag, not as an attached picture stream.
    public var usesOggContainer: Bool {
        switch self {
        case .opus, .vorbis: true
        default: false
        }
    }

    public var supportsQualityScale: Bool {
        switch self {
        case .vorbis, .flac:
            true
        default:
            false
        }
    }
}
