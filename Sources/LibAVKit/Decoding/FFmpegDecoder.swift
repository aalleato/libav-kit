import AVFoundation
import CFFmpeg
import Foundation

public enum FFmpegError: Error, LocalizedError {
    case openFailed(String)
    case streamInfoNotFound
    case audioStreamNotFound
    case codecNotFound
    case codecOpenFailed
    case decodeFailed
    case resamplerfailed
    case endOfFile
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case let .openFailed(path):
            "Failed to open audio file: \(path)"
        case .streamInfoNotFound:
            "Could not find stream information"
        case .audioStreamNotFound:
            "No audio stream found"
        case .codecNotFound:
            "Audio codec not found"
        case .codecOpenFailed:
            "Failed to open audio codec"
        case .decodeFailed:
            "Audio decoding failed"
        case .resamplerfailed:
            "Failed to initialize audio resampler"
        case .endOfFile:
            "End of file reached"
        case .notConfigured:
            "Decoder not configured"
        }
    }
}

// FFmpeg constants that can't be imported as macros
private let AV_NOPTS_VALUE: Int64 = .init(bitPattern: 0x8000_0000_0000_0000)
private let AVERROR_EOF_VALUE: Int32 = -541_478_725

public final class FFmpegDecoder: @unchecked Sendable {
    private var formatContext: UnsafeMutablePointer<AVFormatContext>?
    private var codecContext: UnsafeMutablePointer<AVCodecContext>?
    private var swrContext: OpaquePointer?
    private var audioStreamIndex: Int32 = -1

    // Default output format (can be overridden via configure())
    private var outputSampleRate: Int32 = 44100
    private var outputChannels: Int32 = 2
    private var outputSampleFormat: AVSampleFormat = AV_SAMPLE_FMT_FLT

    /// Track if we're in passthrough mode (no resampling needed)
    private var isPassthrough: Bool = false

    // Source format information (populated after open)
    public private(set) var duration: TimeInterval = 0
    public private(set) var sampleRate: Int = 0
    public private(set) var channels: Int = 0
    public private(set) var bitrate: Int = 0
    public private(set) var codecName: String = ""
    public private(set) var bitsPerSample: Int = 0

    /// The source audio format detected from the file
    public var sourceFormat: AudioOutputFormat? {
        guard sampleRate > 0, channels > 0 else { return nil }
        return AudioOutputFormat(
            sampleRate: Double(sampleRate),
            channelCount: channels,
            sampleFormat: detectSourceSampleFormat(),
            isInterleaved: false
        )
    }

    /// The configured output format
    public var configuredOutputFormat: AudioOutputFormat {
        AudioOutputFormat(
            sampleRate: Double(outputSampleRate),
            channelCount: Int(outputChannels),
            sampleFormat: avSampleFormatToAudioSampleFormat(outputSampleFormat),
            isInterleaved: false
        )
    }

    private var packet: UnsafeMutablePointer<AVPacket>?
    private var frame: UnsafeMutablePointer<AVFrame>?

    public init() {
        packet = av_packet_alloc()
        frame = av_frame_alloc()
    }

    deinit {
        close()
        if packet != nil {
            av_packet_free(&self.packet)
        }
        if frame != nil {
            av_frame_free(&self.frame)
        }
    }

    /// Configure the decoder output format before calling open()
    public func configure(outputFormat: AudioOutputFormat) {
        outputSampleRate = Int32(outputFormat.sampleRate)
        outputChannels = Int32(outputFormat.channelCount)
        outputSampleFormat = audioSampleFormatToAVSampleFormat(outputFormat.sampleFormat)
    }

    /// Reconfigure output format and rebuild resampler (call after open())
    /// This allows changing the output format without re-opening the file
    public func reconfigure(outputFormat: AudioOutputFormat) throws {
        guard codecContext != nil else {
            throw FFmpegError.notConfigured
        }

        // Update output format
        outputSampleRate = Int32(outputFormat.sampleRate)
        outputChannels = Int32(outputFormat.channelCount)
        outputSampleFormat = audioSampleFormatToAVSampleFormat(outputFormat.sampleFormat)

        // Rebuild resampler with new settings
        if swrContext != nil {
            swr_free(&swrContext)
        }
        try setupResampler()
    }

    public func open(url: URL) throws {
        close()

        let path = url.path
        var fmtCtx: UnsafeMutablePointer<AVFormatContext>?

        guard avformat_open_input(&fmtCtx, path, nil, nil) == 0 else {
            throw FFmpegError.openFailed(path)
        }
        formatContext = fmtCtx

        guard avformat_find_stream_info(formatContext, nil) >= 0 else {
            throw FFmpegError.streamInfoNotFound
        }

        // Find audio stream
        for i in 0 ..< Int32(formatContext!.pointee.nb_streams) {
            let stream = formatContext!.pointee.streams[Int(i)]!
            if stream.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                audioStreamIndex = i
                break
            }
        }

        guard audioStreamIndex >= 0 else {
            throw FFmpegError.audioStreamNotFound
        }

        let stream = formatContext!.pointee.streams[Int(audioStreamIndex)]!
        let codecPar = stream.pointee.codecpar!

        // Find decoder
        guard let codec = avcodec_find_decoder(codecPar.pointee.codec_id) else {
            throw FFmpegError.codecNotFound
        }

        codecContext = avcodec_alloc_context3(codec)
        avcodec_parameters_to_context(codecContext, codecPar)

        guard avcodec_open2(codecContext, codec, nil) == 0 else {
            throw FFmpegError.codecOpenFailed
        }

        // Extract metadata
        let timeBase = stream.pointee.time_base
        if stream.pointee.duration != AV_NOPTS_VALUE {
            duration = Double(stream.pointee.duration) * av_q2d(timeBase)
        } else if formatContext!.pointee.duration != AV_NOPTS_VALUE {
            duration = Double(formatContext!.pointee.duration) / Double(AV_TIME_BASE)
        }

        sampleRate = Int(codecContext!.pointee.sample_rate)
        channels = Int(codecContext!.pointee.ch_layout.nb_channels)
        bitrate = Int(codecPar.pointee.bit_rate)
        codecName = String(cString: avcodec_get_name(codecPar.pointee.codec_id))
        bitsPerSample = Int(codecPar.pointee.bits_per_raw_sample)
        if bitsPerSample == 0 {
            bitsPerSample = Int(av_get_bytes_per_sample(codecContext!.pointee.sample_fmt) * 8)
        }

        // Setup resampler (may be passthrough if formats match)
        try setupResampler()
    }

    private func setupResampler() throws {
        guard let ctx = codecContext else { return }

        // Check if we can use passthrough mode (no resampling)
        isPassthrough = checkPassthrough(ctx)

        if isPassthrough {
            // No resampler needed
            swrContext = nil
            return
        }

        var outLayout = AVChannelLayout()
        av_channel_layout_default(&outLayout, outputChannels)

        var swrCtx: OpaquePointer?
        let result = swr_alloc_set_opts2(
            &swrCtx,
            &outLayout,
            outputSampleFormat,
            outputSampleRate,
            &ctx.pointee.ch_layout,
            ctx.pointee.sample_fmt,
            ctx.pointee.sample_rate,
            0,
            nil
        )

        guard result >= 0, let swr = swrCtx else {
            throw FFmpegError.resamplerfailed
        }

        guard swr_init(swr) >= 0 else {
            swr_free(&swrCtx)
            throw FFmpegError.resamplerfailed
        }

        swrContext = swr
    }

    private func checkPassthrough(_ ctx: UnsafeMutablePointer<AVCodecContext>) -> Bool {
        // Check if source format matches configured output format
        let sourceSampleRate = ctx.pointee.sample_rate
        let sourceChannels = ctx.pointee.ch_layout.nb_channels
        let sourceSampleFmt = ctx.pointee.sample_fmt

        // For passthrough, sample rate and channels must match
        guard sourceSampleRate == outputSampleRate,
              sourceChannels == outputChannels else {
            return false
        }

        // Sample format must be float32 planar (our standard output format for AVAudioEngine)
        // or match exactly
        if sourceSampleFmt == AV_SAMPLE_FMT_FLTP || sourceSampleFmt == outputSampleFormat {
            return true
        }

        return false
    }

    public func decodeNextBuffer(maxSamples _: Int = 4096) throws -> AVAudioPCMBuffer? {
        guard let formatContext,
              let codecContext,
              let packet,
              let frame else {
            throw FFmpegError.decodeFailed
        }

        while true {
            let readResult = av_read_frame(formatContext, packet)
            if readResult == AVERROR_EOF_VALUE || readResult == -EAGAIN {
                throw FFmpegError.endOfFile
            }

            defer { av_packet_unref(packet) }

            guard packet.pointee.stream_index == audioStreamIndex else {
                continue
            }

            let sendResult = avcodec_send_packet(codecContext, packet)
            if sendResult < 0 { continue }

            while true {
                let receiveResult = avcodec_receive_frame(codecContext, frame)
                if receiveResult == -EAGAIN || receiveResult == AVERROR_EOF_VALUE {
                    break
                }
                if receiveResult < 0 {
                    throw FFmpegError.decodeFailed
                }

                defer { av_frame_unref(frame) }

                // Use passthrough or resampling based on configuration
                if isPassthrough {
                    if let buffer = passthroughFrame(frame) {
                        return buffer
                    }
                } else {
                    if let buffer = resampleFrame(frame) {
                        return buffer
                    }
                }
            }
        }
    }

    private func passthroughFrame(_ frame: UnsafeMutablePointer<AVFrame>) -> AVAudioPCMBuffer? {
        let sampleCount = frame.pointee.nb_samples
        guard sampleCount > 0 else { return nil }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(outputSampleRate),
            channels: AVAudioChannelCount(outputChannels),
            interleaved: false
        )!

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(sampleCount)
        ) else { return nil }

        guard let floatData = buffer.floatChannelData,
              let extendedData = frame.pointee.extended_data else { return nil }

        // Copy data directly (source is already float32 planar)
        for ch in 0 ..< Int(outputChannels) {
            if let srcPtr = extendedData[ch] {
                let src = UnsafeRawPointer(srcPtr).assumingMemoryBound(to: Float.self)
                floatData[ch].update(from: src, count: Int(sampleCount))
            }
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        return buffer
    }

    private func resampleFrame(_ frame: UnsafeMutablePointer<AVFrame>) -> AVAudioPCMBuffer? {
        guard let swrContext else { return nil }

        let outSamples = swr_get_out_samples(swrContext, frame.pointee.nb_samples)
        guard outSamples > 0 else { return nil }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(outputSampleRate),
            channels: AVAudioChannelCount(outputChannels),
            interleaved: false
        )!

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(outSamples)
        ) else { return nil }

        // Get pointers to output buffer channels
        guard let floatData = buffer.floatChannelData else { return nil }

        var outPointers: [UnsafeMutablePointer<UInt8>?] = [
            UnsafeMutableRawPointer(floatData[0]).assumingMemoryBound(to: UInt8.self),
            UnsafeMutableRawPointer(floatData[1]).assumingMemoryBound(to: UInt8.self),
        ]

        // Get input data pointer
        guard let extendedData = frame.pointee.extended_data else { return nil }

        let convertedSamples = outPointers.withUnsafeMutableBufferPointer { outBufPtr -> Int32 in
            // Create input pointer array
            var inPointers: [UnsafePointer<UInt8>?] = []
            for i in 0 ..< Int(channels) {
                if let ptr = extendedData[i] {
                    inPointers.append(UnsafePointer(ptr))
                }
            }
            // Pad if needed
            while inPointers.count < 2 {
                if let first = inPointers.first {
                    inPointers.append(first)
                } else {
                    break
                }
            }

            return inPointers.withUnsafeBufferPointer { inBufPtr in
                swr_convert(
                    swrContext,
                    outBufPtr.baseAddress,
                    outSamples,
                    inBufPtr.baseAddress,
                    frame.pointee.nb_samples
                )
            }
        }

        guard convertedSamples > 0 else { return nil }
        buffer.frameLength = AVAudioFrameCount(convertedSamples)
        return buffer
    }

    public func seek(to time: TimeInterval) {
        guard let formatContext, audioStreamIndex >= 0 else { return }

        let stream = formatContext.pointee.streams[Int(audioStreamIndex)]!
        let timeBase = stream.pointee.time_base
        let timestamp = Int64(time / av_q2d(timeBase))

        av_seek_frame(formatContext, audioStreamIndex, timestamp, AVSEEK_FLAG_BACKWARD)

        if let codecContext {
            avcodec_flush_buffers(codecContext)
        }

        // Flush the resampler to clear any buffered samples from before the seek
        if let swrContext {
            // Passing nil input flushes the resampler
            swr_convert(swrContext, nil, 0, nil, 0)
        }
    }

    public func close() {
        if swrContext != nil {
            swr_free(&self.swrContext)
        }
        swrContext = nil

        if codecContext != nil {
            avcodec_free_context(&self.codecContext)
        }
        self.codecContext = nil

        if formatContext != nil {
            avformat_close_input(&self.formatContext)
        }
        self.formatContext = nil

        audioStreamIndex = -1
        duration = 0
        sampleRate = 0
        channels = 0
        bitrate = 0
        codecName = ""
        bitsPerSample = 0
        isPassthrough = false
    }

    // MARK: - Format Conversion Helpers

    private func detectSourceSampleFormat() -> AudioSampleFormat {
        guard let ctx = codecContext else { return .float32 }
        return avSampleFormatToAudioSampleFormat(ctx.pointee.sample_fmt)
    }

    func avSampleFormatToAudioSampleFormat(_ fmt: AVSampleFormat) -> AudioSampleFormat {
        switch fmt {
        case AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S16P:
            .int16
        case AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_S32P:
            .int32
        case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
            .float32
        case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:
            .float64
        default:
            .float32
        }
    }

    func audioSampleFormatToAVSampleFormat(_ fmt: AudioSampleFormat) -> AVSampleFormat {
        switch fmt {
        case .int16:
            AV_SAMPLE_FMT_S16P
        case .int24, .int32:
            AV_SAMPLE_FMT_S32P
        case .float32:
            AV_SAMPLE_FMT_FLTP
        case .float64:
            AV_SAMPLE_FMT_DBLP
        }
    }
}
