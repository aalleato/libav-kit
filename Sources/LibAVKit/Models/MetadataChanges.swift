import Foundation

/// Changes to apply to a song's metadata
public struct MetadataChanges: Sendable, Equatable {
    public var title: String?
    public var artistName: String?
    public var albumTitle: String?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var genre: String?
    public var year: Int?

    /// Extended Vorbis tags (key is raw tag name like "COMPOSER")
    public var extendedTags: [String: String]

    /// Custom user-defined tags (arbitrary key/value pairs)
    public var customTags: [String: String]

    /// When true, custom tags are embedded as key=value pairs in the COMMENT field
    /// rather than written as separate metadata tags.
    public var embedCustomTagsInComment: Bool

    public init(
        title: String? = nil,
        artistName: String? = nil,
        albumTitle: String? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        genre: String? = nil,
        year: Int? = nil,
        extendedTags: [String: String] = [:],
        customTags: [String: String] = [:],
        embedCustomTagsInComment: Bool = false
    ) {
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.genre = genre
        self.year = year
        self.extendedTags = extendedTags
        self.customTags = customTags
        self.embedCustomTagsInComment = embedCustomTagsInComment
    }

    /// Returns true if no changes are specified
    public var isEmpty: Bool {
        title == nil &&
            artistName == nil &&
            albumTitle == nil &&
            trackNumber == nil &&
            discNumber == nil &&
            genre == nil &&
            year == nil &&
            extendedTags.isEmpty &&
            customTags.isEmpty
    }
}
