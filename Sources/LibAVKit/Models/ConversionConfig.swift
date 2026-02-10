import Foundation

/// Bitrate encoding mode
public enum BitrateMode: String, Sendable, Codable, CaseIterable {
    case cbr // Constant bitrate: MP3, AAC, Opus
    case vbr // Variable bitrate: MP3, AAC, Vorbis
    case abr // Average bitrate: MP3

    public var displayName: String {
        switch self {
        case .cbr: "CBR (Constant)"
        case .vbr: "VBR (Variable)"
        case .abr: "ABR (Average)"
        }
    }
}

/// AAC encoding profile
public enum AACProfile: String, Sendable, Codable, CaseIterable {
    case lc // AAC-LC (default, broadest compatibility)
    case heV1 // HE-AAC v1 (SBR, good for low bitrates)
    case heV2 // HE-AAC v2 (SBR+PS, stereo-only, very low bitrates)

    public var displayName: String {
        switch self {
        case .lc: "AAC-LC"
        case .heV1: "HE-AAC v1"
        case .heV2: "HE-AAC v2"
        }
    }
}

/// How the user specified the conversion destination
public enum ConversionDestination: Sendable, Equatable {
    /// Template string like ${SOURCE}/${ARTIST}/${ALBUM}/${TRACK} - ${TITLE}
    case template(String)
    /// User picked a specific folder; optional template organizes files within it
    case folder(URL, template: String?)
}

/// Complete configuration for a conversion/export operation
public struct ConversionConfig: Sendable, Equatable {
    public var outputFormat: OutputFormat
    public var encodingSettings: EncodingSettings
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var channels: Int?
    public var destination: ConversionDestination

    public init(
        outputFormat: OutputFormat,
        encodingSettings: EncodingSettings? = nil,
        sampleRate: Int? = nil,
        bitDepth: Int? = nil,
        channels: Int? = nil,
        destination: ConversionDestination
    ) {
        self.outputFormat = outputFormat
        self.encodingSettings = encodingSettings ?? .defaults(for: outputFormat)
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.destination = destination
    }

    public enum MP3 {
        public static func cbr(
            bitrateKbps: Int,
            destination: ConversionDestination,
            sampleRate: Int? = nil,
            channels: Int? = nil
        ) -> ConversionConfig {
            ConversionConfig(
                outputFormat: .mp3,
                encodingSettings: .mp3(
                    MP3EncodingSettings(bitrateMode: .cbr, bitrateKbps: bitrateKbps)
                ),
                sampleRate: sampleRate,
                channels: channels,
                destination: destination
            )
        }

        public static func vbr(
            quality: Int,
            destination: ConversionDestination,
            sampleRate: Int? = nil,
            channels: Int? = nil
        ) -> ConversionConfig {
            ConversionConfig(
                outputFormat: .mp3,
                encodingSettings: .mp3(MP3EncodingSettings(bitrateMode: .vbr, vbrQuality: quality)),
                sampleRate: sampleRate,
                channels: channels,
                destination: destination
            )
        }

        public static func abc(
            quality: Int,
            destination: ConversionDestination,
            sampleRate: Int? = nil,
            channels: Int? = nil
        ) -> ConversionConfig {
            ConversionConfig(
                outputFormat: .mp3,
                encodingSettings: .mp3(MP3EncodingSettings(bitrateMode: .abr, vbrQuality: quality)),
                sampleRate: sampleRate,
                channels: channels,
                destination: destination
            )
        }
    }
}
