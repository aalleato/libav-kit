import CFFmpeg
import Foundation

/// Copies metadata tags from source AudioMetadata to an output AVFormatContext
public final class EncoderMetadataWriter: @unchecked Sendable {
    public init() {}

    /// Write metadata tags to the output format context before calling avformat_write_header
    /// - Parameters:
    ///   - metadata: Source metadata to copy
    ///   - formatContext: Output format context to write tags to
    public func write(metadata: AudioMetadata, to formatContext: UnsafeMutablePointer<AVFormatContext>) {
        setTag("title", value: metadata.title, on: &formatContext.pointee.metadata)
        setTag("artist", value: metadata.artist, on: &formatContext.pointee.metadata)
        setTag("album", value: metadata.album, on: &formatContext.pointee.metadata)
        setTag("album_artist", value: metadata.albumArtist, on: &formatContext.pointee.metadata)
        setTag("genre", value: metadata.genre, on: &formatContext.pointee.metadata)

        if let year = metadata.year {
            setTag("date", value: String(year), on: &formatContext.pointee.metadata)
        }

        if let trackNumber = metadata.trackNumber {
            setTag("track", value: String(trackNumber), on: &formatContext.pointee.metadata)
        }

        if let discNumber = metadata.discNumber {
            setTag("disc", value: String(discNumber), on: &formatContext.pointee.metadata)
        }
    }

    /// Add a cover art stream to the output format context and return
    /// the stream index for writing the art packet after the header.
    /// Must be called before `avformat_write_header()`.
    /// - Parameters:
    ///   - coverArt: Raw image data (JPEG or PNG)
    ///   - formatContext: Output format context
    ///   - outputFormat: Target output format (used to check cover art support)
    /// - Returns: The stream index for the cover art, or nil if not applicable
    @discardableResult
    public func addCoverArtStream(
        _ coverArt: Data,
        to formatContext: UnsafeMutablePointer<AVFormatContext>,
        outputFormat: OutputFormat
    ) -> Int32? {
        guard !coverArt.isEmpty, outputFormat.supportsCoverArt else { return nil }

        guard let stream = avformat_new_stream(formatContext, nil) else { return nil }

        let codecId = detectImageCodec(coverArt)
        let dims = VorbisPictureBlock.extractImageDimensions(coverArt)
        stream.pointee.codecpar.pointee.codec_type = AVMEDIA_TYPE_VIDEO
        stream.pointee.codecpar.pointee.codec_id = codecId
        stream.pointee.codecpar.pointee.width = dims.width
        stream.pointee.codecpar.pointee.height = dims.height
        stream.pointee.disposition = AV_DISPOSITION_ATTACHED_PIC

        return stream.pointee.index
    }

    /// Write the cover art image data as a packet to the output format context.
    /// Must be called after `avformat_write_header()`.
    /// - Parameters:
    ///   - coverArt: Raw image data (JPEG or PNG)
    ///   - formatContext: Output format context
    ///   - streamIndex: The stream index returned by `addCoverArtStream()`
    public func writeCoverArtPacket(
        _ coverArt: Data,
        to formatContext: UnsafeMutablePointer<AVFormatContext>,
        streamIndex: Int32
    ) {
        var packet = UnsafeMutablePointer<AVPacket>?
            .none
        packet = av_packet_alloc()
        guard let pkt = packet else { return }
        defer { av_packet_free(&packet) }

        let size = Int32(coverArt.count)
        guard av_new_packet(pkt, size) >= 0 else { return }

        coverArt.withUnsafeBytes { bytes in
            guard let src = bytes.baseAddress else { return }
            pkt.pointee.data.update(
                from: src.assumingMemoryBound(to: UInt8.self),
                count: Int(size)
            )
        }
        pkt.pointee.stream_index = streamIndex
        pkt.pointee.flags |= AV_PKT_FLAG_KEY

        av_interleaved_write_frame(formatContext, pkt)
    }

    /// Write cover art as a METADATA_BLOCK_PICTURE Vorbis comment tag.
    /// OGG-based formats (Opus, Vorbis) use this instead of an attached picture stream.
    /// Must be called before `avformat_write_header()`.
    /// - Parameters:
    ///   - coverArt: Raw image data (JPEG or PNG)
    ///   - formatContext: Output format context
    public func addCoverArtAsVorbisComment(
        _ coverArt: Data,
        to formatContext: UnsafeMutablePointer<AVFormatContext>
    ) {
        guard let base64 = VorbisPictureBlock.base64Encoded(imageData: coverArt) else { return }
        setTag("METADATA_BLOCK_PICTURE", value: base64, on: &formatContext.pointee.metadata)
    }

    /// Copy all metadata tags from a source format context to output format context
    /// - Parameters:
    ///   - source: Source format context with metadata to copy
    ///   - destination: Output format context to receive tags
    public func copyAll(
        from source: UnsafeMutablePointer<AVFormatContext>,
        to destination: UnsafeMutablePointer<AVFormatContext>
    ) {
        av_dict_copy(&destination.pointee.metadata, source.pointee.metadata, 0)
    }

    // MARK: - Private

    private func setTag(
        _ key: String,
        value: String?,
        on dict: inout OpaquePointer?
    ) {
        guard let value, !value.isEmpty else { return }
        av_dict_set(&dict, key, value, 0)
    }

    /// Detect whether image data is JPEG or PNG based on magic bytes
    private func detectImageCodec(_ data: Data) -> AVCodecID {
        guard data.count >= 4 else { return AV_CODEC_ID_MJPEG }

        // PNG magic: 89 50 4E 47
        if data[data.startIndex] == 0x89,
           data[data.startIndex + 1] == 0x50,
           data[data.startIndex + 2] == 0x4E,
           data[data.startIndex + 3] == 0x47 {
            return AV_CODEC_ID_PNG
        }

        return AV_CODEC_ID_MJPEG
    }
}
