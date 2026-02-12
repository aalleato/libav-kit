import ArgumentParser
import Foundation
import LibAVKit

@main
struct LibAVPlay: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "libav-play",
        abstract: "Play audio files using LibAVKit.",
        discussion: """
        File mode:  libav-play song.flac
        STDIN mode: cat song.flac | libav-play --format flac -
        """
    )

    @Argument(help: "Audio file path, or \"-\" to read from STDIN.")
    var file: String?

    @Option(help: "Playback volume (0.0–1.0).")
    var volume: Float = 1.0

    @Option(help: "Format hint for STDIN (e.g. flac, mp3, opus). Required when reading from STDIN.")
    var format: String?

    func run() throws {
        // Disable stdout buffering so \r progress updates appear immediately
        setbuf(stdout, nil)

        let isSTDIN = file == "-" || (file == nil && !isatty(STDIN_FILENO).boolValue)

        if isSTDIN {
            try runSTDINMode()
        } else if let file {
            try runFileMode(path: file)
        } else {
            print("No file specified. Use --help for usage.")
            throw ExitCode.failure
        }
    }

    // MARK: - File Mode (AudioPlayer)

    private func runFileMode(path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            print("File not found: \(path)")
            throw ExitCode.failure
        }

        let player = AudioPlayer()

        // Set up signal handling for Ctrl+C
        let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        sigSource.setEventHandler {
            print("\nStopping playback...")
            player.stop()
            LibAVPlay.exit()
        }
        sigSource.resume()

        do {
            try player.open(url: url)
        } catch {
            print("Failed to open file: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        player.volume = volume
        printHeader(
            title: player.metadata.title,
            artist: player.metadata.artist,
            album: player.metadata.album,
            codec: player.metadata.codec,
            sampleRate: player.sampleRate,
            channels: player.channels,
            duration: player.duration
        )

        player.onProgress = { time in
            writeProgress(elapsed: time, duration: player.duration)
        }

        player.onStateChange = { state in
            if state == .completed {
                print("\nPlayback complete.")
                LibAVPlay.exit()
            }
        }

        player.onError = { error in
            print("\nPlayback error: \(error)")
            LibAVPlay.exit(withError: ExitCode.failure)
        }

        player.play()
        dispatchMain()
    }

    // MARK: - STDIN Mode (Decoder + AVAudioEngineOutput)

    private func runSTDINMode() throws {
        guard let format else {
            print("--format is required when reading from STDIN.")
            throw ExitCode.failure
        }

        let decoder = Decoder()
        do {
            try decoder.open(path: "pipe:0", inputFormat: format)
        } catch {
            print("Failed to open STDIN: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // Reconfigure decoder to match source format for playback
        guard let sourceFormat = decoder.sourceFormat else {
            print("Could not detect source format from STDIN.")
            throw ExitCode.failure
        }
        let outputFormat = AudioOutputFormat(
            sampleRate: sourceFormat.sampleRate,
            channelCount: sourceFormat.channelCount,
            sampleFormat: .float32,
            isInterleaved: false
        )
        try decoder.reconfigure(outputFormat: outputFormat)

        printHeader(
            title: nil,
            artist: nil,
            album: nil,
            codec: decoder.codecName,
            sampleRate: decoder.sampleRate,
            channels: decoder.channels,
            duration: decoder.duration
        )

        let output = AVAudioEngineOutput()
        try output.configure(sampleRate: Double(decoder.sampleRate), channels: decoder.channels)
        try output.start()
        output.volume = volume

        // Set up signal handling for Ctrl+C
        let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        sigSource.setEventHandler {
            print("\nStopping playback...")
            output.stop()
            decoder.close()
            LibAVPlay.exit()
        }
        sigSource.resume()

        // Track elapsed time from decoded samples
        let sampleRate = Double(decoder.sampleRate)
        let totalDuration = decoder.duration
        let progress = SampleCounter()

        // Decode loop on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                while true {
                    try decoder.decodeNextFrame { frame in
                        output.scheduleAudio(frame)
                        progress.add(frame.frameCount)
                        let elapsed = Double(progress.count) / sampleRate
                        writeProgress(elapsed: elapsed, duration: totalDuration)
                    }
                }
            } catch let error as DecoderError where error.isEndOfFile {
                // Wait for audio output to finish
                output.waitForCompletion { false }
                print("\nPlayback complete.")
                LibAVPlay.exit()
            } catch {
                print("\nDecode error: \(error.localizedDescription)")
                LibAVPlay.exit(withError: ExitCode.failure)
            }
        }

        dispatchMain()
    }
}

// MARK: - Sample Counter

private final class SampleCounter: @unchecked Sendable {
    private(set) var count: Int64 = 0
    func add(_ n: Int) { count += Int64(n) }
}

// MARK: - Helpers

private func printHeader(
    title: String?, artist: String?, album: String?,
    codec: String, sampleRate: Int, channels: Int, duration: TimeInterval
) {
    print("Now playing:")
    if let title { print("  Title:  \(title)") }
    if let artist { print("  Artist: \(artist)") }
    if let album { print("  Album:  \(album)") }
    if !codec.isEmpty { print("  Codec:  \(codec)") }
    print("  Format: \(sampleRate) Hz, \(channels) ch")
    if duration > 0 { print("  Length: \(formatTime(duration))") }
    print()
}

private func writeProgress(elapsed: TimeInterval, duration: TimeInterval) {
    if duration > 0 {
        let pct = elapsed / duration * 100
        fputs("\r  \(formatTime(elapsed)) / \(formatTime(duration))  [\(String(format: "%.0f", pct))%]", stdout)
    } else {
        fputs("\r  \(formatTime(elapsed))", stdout)
    }
}

private func formatTime(_ seconds: TimeInterval) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%d:%02d", mins, secs)
}

private extension DecoderError {
    var isEndOfFile: Bool {
        if case .endOfFile = self { return true }
        return false
    }
}

private extension Int32 {
    var boolValue: Bool { self != 0 }
}
