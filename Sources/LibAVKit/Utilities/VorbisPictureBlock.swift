import Foundation

/// Builds FLAC METADATA_BLOCK_PICTURE binary blocks for Vorbis comment embedding.
/// Used by both the FFmpeg encoder (via `EncoderMetadataWriter`) and the CLI-based
/// album art embedding service for OGG-based formats (Opus, Vorbis).
public enum VorbisPictureBlock {
    /// Builds a FLAC METADATA_BLOCK_PICTURE binary block and returns its base64 encoding.
    /// Returns nil if imageData is empty.
    public static func base64Encoded(imageData: Data) -> String? {
        guard !imageData.isEmpty else { return nil }

        let mimeType = detectMIMEType(imageData)
        let dims = extractImageDimensions(imageData)
        let mimeBytes = Array(mimeType.utf8)

        // FLAC METADATA_BLOCK_PICTURE binary format (all big-endian):
        //   [4] picture type (3 = front cover)
        //   [4] MIME length + [n] MIME string
        //   [4] description length + [n] description string
        //   [4] width, [4] height, [4] color depth, [4] indexed colors
        //   [4] data length + [n] image data
        var block = Data()
        block.appendBigEndianUInt32(3) // Front cover
        block.appendBigEndianUInt32(UInt32(mimeBytes.count))
        block.append(contentsOf: mimeBytes)
        block.appendBigEndianUInt32(0) // Empty description
        block.appendBigEndianUInt32(UInt32(dims.width))
        block.appendBigEndianUInt32(UInt32(dims.height))
        block.appendBigEndianUInt32(mimeType == "image/png" ? 32 : 24)
        block.appendBigEndianUInt32(0) // Indexed colors
        block.appendBigEndianUInt32(UInt32(imageData.count))
        block.append(imageData)

        return block.base64EncodedString()
    }

    /// Detect MIME type from image magic bytes.
    static func detectMIMEType(_ data: Data) -> String {
        if data.count >= 4,
           data[data.startIndex] == 0x89,
           data[data.startIndex + 1] == 0x50 {
            return "image/png"
        }
        return "image/jpeg"
    }

    /// Extract width and height from JPEG or PNG header data.
    public static func extractImageDimensions(_ data: Data) -> (width: Int32, height: Int32) {
        guard data.count >= 24 else { return (1, 1) }

        // PNG: width at bytes 16-19, height at bytes 20-23 (big-endian, in IHDR chunk)
        if data[data.startIndex] == 0x89, data[data.startIndex + 1] == 0x50 {
            let w = Int32(data[data.startIndex + 16]) << 24
                | Int32(data[data.startIndex + 17]) << 16
                | Int32(data[data.startIndex + 18]) << 8
                | Int32(data[data.startIndex + 19])
            let h = Int32(data[data.startIndex + 20]) << 24
                | Int32(data[data.startIndex + 21]) << 16
                | Int32(data[data.startIndex + 22]) << 8
                | Int32(data[data.startIndex + 23])
            if w > 0, h > 0 { return (w, h) }
        }

        // JPEG: scan for SOF0 (0xFFC0) marker which contains dimensions
        if data[data.startIndex] == 0xFF, data[data.startIndex + 1] == 0xD8 {
            var offset = data.startIndex + 2
            while offset + 4 < data.endIndex {
                guard data[offset] == 0xFF else { break }
                let marker = data[offset + 1]
                // SOF markers: C0-C3, C5-C7, C9-CB, CD-CF
                if marker >= 0xC0, marker <= 0xCF, marker != 0xC4, marker != 0xC8, marker != 0xCC {
                    if offset + 8 < data.endIndex {
                        let h = Int32(data[offset + 5]) << 8 | Int32(data[offset + 6])
                        let w = Int32(data[offset + 7]) << 8 | Int32(data[offset + 8])
                        if w > 0, h > 0 { return (w, h) }
                    }
                }
                // Skip to next marker
                if offset + 3 < data.endIndex {
                    let segLen = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
                    offset += 2 + segLen
                } else {
                    break
                }
            }
        }

        return (1, 1)
    }
}

extension Data {
    mutating func appendBigEndianUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        withUnsafePointer(to: &bigEndian) { ptr in
            append(UnsafeBufferPointer(start: ptr, count: 1))
        }
    }
}
