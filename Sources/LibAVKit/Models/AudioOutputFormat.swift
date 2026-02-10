import Foundation

/// Represents the sample format for audio data
public enum AudioSampleFormat: Sendable, Equatable {
    case int16
    case int24
    case int32
    case float32
    case float64

    /// The number of bytes per sample for this format
    public var bytesPerSample: Int {
        switch self {
        case .int16: 2
        case .int24: 3
        case .int32: 4
        case .float32: 4
        case .float64: 8
        }
    }

    /// The bits per sample for this format
    public var bitsPerSample: Int {
        switch self {
        case .int16: 16
        case .int24: 24
        case .int32: 32
        case .float32: 32
        case .float64: 64
        }
    }
}

/// Unified audio format representation for the entire audio pipeline
public struct AudioOutputFormat: Equatable, Sendable {
    public let sampleRate: Double
    public let channelCount: Int
    public let sampleFormat: AudioSampleFormat
    public let isInterleaved: Bool

    public init(
        sampleRate: Double,
        channelCount: Int,
        sampleFormat: AudioSampleFormat = .float32,
        isInterleaved: Bool = false
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.isInterleaved = isInterleaved
    }

    /// Creates a default CD-quality format (44.1kHz, stereo, float32)
    public static var cdQuality: AudioOutputFormat {
        AudioOutputFormat(
            sampleRate: 44100,
            channelCount: 2,
            sampleFormat: .float32,
            isInterleaved: false
        )
    }

    /// A human-readable description of the format
    public var description: String {
        let rateKHz = sampleRate / 1000.0
        let rateStr = rateKHz.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0fkHz", rateKHz)
            : String(format: "%.1fkHz", rateKHz)
        return "\(rateStr)/\(sampleFormat.bitsPerSample)-bit/\(channelCount)ch"
    }
}

/// Standard sample rates used in audio
public enum StandardSampleRate: Double, CaseIterable, Sendable {
    case rate44100 = 44100
    case rate48000 = 48000
    case rate88200 = 88200
    case rate96000 = 96000
    case rate176400 = 176_400
    case rate192000 = 192_000
    case rate352800 = 352_800
    case rate384000 = 384_000

    /// Check if this is a hi-res sample rate (above CD quality)
    public var isHiRes: Bool {
        self.rawValue > 48000
    }

    /// The base rate family (44.1kHz or 48kHz)
    public var baseFamily: Double {
        switch self {
        case .rate44100, .rate88200, .rate176400, .rate352800:
            44100
        case .rate48000, .rate96000, .rate192000, .rate384000:
            48000
        }
    }
}
