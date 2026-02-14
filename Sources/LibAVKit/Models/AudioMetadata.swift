import Foundation

public struct AudioMetadata: Sendable {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var year: Int?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var genre: String?
    public var duration: TimeInterval = 0
    public var codec: String = ""
    public var bitrate: Int?
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var channels: Int?
    public var coverArt: Data?
    /// Indicates if this is a Dolby Atmos track (E-AC-3 JOC or TrueHD Atmos)
    public var isAtmos: Bool = false

    public static let empty = AudioMetadata()

    public init() {}
}
