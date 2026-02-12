import Foundation

/// Lightweight view of decoded audio data. Valid only during the decode callback —
/// the underlying pointers belong to FFmpeg's `AVFrame` and are released when
/// the callback returns.
public struct DecodedFrame {
    public let channelData: [UnsafePointer<Float>]
    public let frameCount: Int
    public let sampleRate: Double
    public let channelCount: Int
}
