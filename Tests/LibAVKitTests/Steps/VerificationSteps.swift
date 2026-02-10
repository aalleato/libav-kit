import Foundation
import LibAVKit
import PickleKit
import Testing

/// Then steps — verify encoding output, metadata, and cover art.
struct VerificationSteps: StepDefinitions {
    init() {}

    // MARK: - File existence

    let outputFileExists = StepDefinition.then(
        #"the output file exists"#
    ) { _ in
        let ctx = TestContext.shared
        guard let outputURL = ctx.outputURL else {
            throw StepError.assertion("No output URL set")
        }
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw StepError.assertion("Output file does not exist: \(outputURL.path)")
        }
    }

    // MARK: - Audio properties

    let sampleRateIs = StepDefinition.then(
        #"the sample rate is (\d+)"#
    ) { match in
        let expected = Int(match.captures[0])!
        let metadata = try readCurrentMetadata()
        guard metadata.sampleRate == expected else {
            throw StepError.assertion(
                "Expected sample rate \(expected), got \(metadata.sampleRate ?? -1)"
            )
        }
    }

    let channelCountIs = StepDefinition.then(
        #"the channel count is (\d+)"#
    ) { match in
        let expected = Int(match.captures[0])!
        let metadata = try readCurrentMetadata()
        guard metadata.channels == expected else {
            throw StepError.assertion(
                "Expected \(expected) channel(s), got \(metadata.channels ?? -1)"
            )
        }
    }

    let bitDepthIs = StepDefinition.then(
        #"the bit depth is (\d+)"#
    ) { match in
        let expected = Int(match.captures[0])!
        let metadata = try readCurrentMetadata()
        guard metadata.bitDepth == expected else {
            throw StepError.assertion(
                "Expected \(expected)-bit, got \(metadata.bitDepth ?? -1)"
            )
        }
    }

    // MARK: - Cover art assertions

    let fileContainsCoverArt = StepDefinition.then(
        #"the file contains cover art"#
    ) { _ in
        let metadata = try readWorkingCopyMetadata()
        guard metadata.coverArt != nil else {
            throw StepError.assertion("Expected cover art to be present")
        }
    }

    let fileDoesNotContainCoverArt = StepDefinition.then(
        #"the file does not contain cover art"#
    ) { _ in
        let metadata = try readWorkingCopyMetadata()
        guard metadata.coverArt == nil else {
            throw StepError.assertion("Expected cover art to be nil after removal")
        }
    }

    let coverArtBytesMatch = StepDefinition.then(
        #"the cover art bytes match the original"#
    ) { _ in
        let ctx = TestContext.shared
        guard let original = ctx.coverArtData else {
            throw StepError.assertion("No original cover art data to compare")
        }

        let metadata = try readWorkingCopyMetadata()
        guard let readBack = metadata.coverArt else {
            throw StepError.assertion("Cover art is nil — cannot compare bytes")
        }
        guard readBack == original else {
            throw StepError.assertion(
                "Cover art bytes mismatch: got \(readBack.count) bytes, expected \(original.count)"
            )
        }
    }

    // MARK: - Metadata assertions

    let metadataTitle = StepDefinition.then(
        #"the metadata title is "([^"]+)""#
    ) { match in
        let expected = match.captures[0]
        let metadata = try readWorkingCopyMetadata()
        guard metadata.title == expected else {
            throw StepError.assertion(
                "Expected title '\(expected)', got '\(metadata.title ?? "nil")'"
            )
        }
    }

    let metadataArtist = StepDefinition.then(
        #"the metadata artist is "([^"]+)""#
    ) { match in
        let expected = match.captures[0]
        let metadata = try readWorkingCopyMetadata()
        guard metadata.artist == expected else {
            throw StepError.assertion(
                "Expected artist '\(expected)', got '\(metadata.artist ?? "nil")'"
            )
        }
    }

    let metadataAlbum = StepDefinition.then(
        #"the metadata album is "([^"]+)""#
    ) { match in
        let expected = match.captures[0]
        let metadata = try readWorkingCopyMetadata()
        guard metadata.album == expected else {
            throw StepError.assertion(
                "Expected album '\(expected)', got '\(metadata.album ?? "nil")'"
            )
        }
    }

    let metadataTrackNumber = StepDefinition.then(
        #"the metadata track number is (\d+)"#
    ) { match in
        let expected = Int(match.captures[0])!
        let metadata = try readWorkingCopyMetadata()
        guard metadata.trackNumber == expected else {
            throw StepError.assertion(
                "Expected track \(expected), got \(metadata.trackNumber ?? -1)"
            )
        }
    }

    let metadataDiscNumber = StepDefinition.then(
        #"the metadata disc number is (\d+)"#
    ) { match in
        let expected = Int(match.captures[0])!
        let metadata = try readWorkingCopyMetadata()
        guard metadata.discNumber == expected else {
            throw StepError.assertion(
                "Expected disc \(expected), got \(metadata.discNumber ?? -1)"
            )
        }
    }

    let metadataGenre = StepDefinition.then(
        #"the metadata genre is "([^"]+)""#
    ) { match in
        let expected = match.captures[0]
        let metadata = try readWorkingCopyMetadata()
        guard metadata.genre == expected else {
            throw StepError.assertion(
                "Expected genre '\(expected)', got '\(metadata.genre ?? "nil")'"
            )
        }
    }

    let metadataYear = StepDefinition.then(
        #"the metadata year is (\d+)"#
    ) { match in
        let expected = Int(match.captures[0])!
        let metadata = try readWorkingCopyMetadata()
        guard metadata.year == expected else {
            throw StepError.assertion(
                "Expected year \(expected), got \(metadata.year ?? -1)"
            )
        }
    }

    // MARK: - Error assertions

    let writeFailsWithError = StepDefinition.then(
        #"the write fails with an error"#
    ) { _ in
        guard TestContext.shared.writeError != nil else {
            throw StepError.assertion("Expected write to fail with an error, but it succeeded")
        }
    }
}

// MARK: - Helpers

/// Read metadata from the best available source:
/// encoding output (if present), otherwise the working copy.
private func readCurrentMetadata() throws -> AudioMetadata {
    let ctx = TestContext.shared
    // For encoding tests, use cached output metadata
    if let metadata = ctx.outputMetadata {
        return metadata
    }
    // For encoding tests without cached metadata, read from output URL
    if let url = ctx.outputURL {
        return try MetadataReader().read(url: url)
    }
    // For cover art / tag writing tests, read from working copy
    if let url = ctx.workingCopy {
        return try MetadataReader().read(url: url)
    }
    throw StepError.assertion("No output URL or working copy set for metadata read")
}

/// Read metadata from the working copy (for cover art and tag writing tests).
private func readWorkingCopyMetadata() throws -> AudioMetadata {
    guard let url = TestContext.shared.workingCopy else {
        throw StepError.assertion("No working copy set for metadata read")
    }
    return try MetadataReader().read(url: url)
}
