import LibAVKit

/// Maps encoding settings keys from feature file Examples tables to real EncodingSettings values.
enum EncodingSettingsResolver {
    static func resolve(_ key: String) -> EncodingSettings {
        switch key {
        case "flac_default":
            return .defaults(for: .flac)
        case "lossless":
            return .lossless
        case "mp3_cbr_128":
            return .mp3(MP3EncodingSettings(bitrateMode: .cbr, bitrateKbps: 128))
        case "mp3_vbr_v2":
            return .mp3(MP3EncodingSettings(bitrateMode: .vbr, vbrQuality: 2))
        case "mp3_abr_192":
            return .mp3(MP3EncodingSettings(bitrateMode: .abr, bitrateKbps: 192))
        case "aac_lc_128":
            return .aac(AACEncodingSettings(profile: .lc, bitrateKbps: 128))
        case "aac_hev1_64":
            return .aac(AACEncodingSettings(profile: .heV1, bitrateKbps: 64))
        case "aac_hev2_48":
            return .aac(AACEncodingSettings(profile: .heV2, bitrateKbps: 48))
        case "opus_128":
            return .opus(OpusEncodingSettings(bitrateKbps: 128))
        case "vorbis_q5":
            return .vorbis(VorbisEncodingSettings(quality: 5))
        default:
            fatalError("Unknown encoding settings key: \(key)")
        }
    }
}
