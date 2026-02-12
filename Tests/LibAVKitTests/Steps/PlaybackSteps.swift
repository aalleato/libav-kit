import Foundation
import LibAVKit
import PickleKit

/// Playback-specific When/Then step definitions.
struct PlaybackSteps: StepDefinitions {
    init() {}

    // MARK: - When steps

    /// When I play the file (plays to completion, blocking)
    let playToCompletion = StepDefinition.when(
        #"I play the file$"#
    ) { _ in
        let ctx = TestContext.shared
        guard let url = ctx.workingCopy else {
            throw StepError.assertion("No working copy set")
        }

        let player = AudioPlayer()
        ctx.player = player

        // Track state transitions
        player.onStateChange = { state in
            ctx.stateTransitions.append(state)
        }

        try player.open(url: url)
        player.play()

        // Wait for completion
        let timeout: TimeInterval = 30
        let deadline = Date().addingTimeInterval(timeout)
        while player.state == .playing, Date() < deadline {
            sleepBriefly(0.05)
        }

        guard player.state == .completed else {
            throw StepError.assertion(
                "Expected playback to complete, but state is \(player.state)"
            )
        }
    }

    /// When I start playing the file (non-blocking, returns while playing)
    let startPlaying = StepDefinition.when(
        #"I start playing the file"#
    ) { _ in
        let ctx = TestContext.shared
        guard let url = ctx.workingCopy else {
            throw StepError.assertion("No working copy set")
        }

        let player = AudioPlayer()
        ctx.player = player

        player.onStateChange = { state in
            ctx.stateTransitions.append(state)
        }

        try player.open(url: url)
        player.play()

        // Give the decode loop a moment to start
        sleepBriefly(0.1)
    }

    /// When I pause playback
    let pausePlayback = StepDefinition.when(
        #"I pause playback"#
    ) { _ in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        player.pause()
    }

    /// When I resume playback
    let resumePlayback = StepDefinition.when(
        #"I resume playback"#
    ) { _ in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        player.play()
        // Give decode loop a moment to resume
        sleepBriefly(0.05)
    }

    /// When I stop playback
    let stopPlayback = StepDefinition.when(
        #"I stop playback"#
    ) { _ in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        player.stop()
    }

    /// When I seek to <N> seconds
    let seekTo = StepDefinition.when(
        #"I seek to ([0-9.]+) seconds"#
    ) { match in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        let seconds = Double(match.captures[0])!
        player.seek(to: seconds)
        // Give the player a moment to process the seek
        sleepBriefly(0.1)
    }

    /// When I set the volume to <N>
    let setVolume = StepDefinition.when(
        #"I set the volume to ([0-9.]+)"#
    ) { match in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        let volume = Float(match.captures[0])!
        player.volume = volume
    }

    /// When I attempt to play the file (error path)
    let attemptPlay = StepDefinition.when(
        #"I attempt to play the file"#
    ) { _ in
        let ctx = TestContext.shared
        guard let url = ctx.workingCopy else {
            throw StepError.assertion("No working copy set")
        }

        let player = AudioPlayer()
        ctx.player = player

        do {
            try player.open(url: url)
            player.play()
        } catch {
            ctx.playbackError = error
        }
    }

    // MARK: - Then steps

    /// Then the playback state is "<state>"
    let playbackStateIs = StepDefinition.then(
        #"the playback state is "([^"]+)""#
    ) { match in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        let expectedStr = match.captures[0]
        let expected = parsePlaybackState(expectedStr)
        guard player.state == expected else {
            throw StepError.assertion(
                "Expected playback state '\(expectedStr)', got '\(player.state)'"
            )
        }
    }

    /// Then the reported duration matches the file duration
    let durationMatches = StepDefinition.then(
        #"the reported duration matches the file duration"#
    ) { _ in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        guard player.duration > 0 else {
            throw StepError.assertion("Player duration is 0")
        }
    }

    /// Then the reported sample rate is <N>
    let reportedSampleRate = StepDefinition.then(
        #"the reported sample rate is (\d+)"#
    ) { match in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        let expected = Int(match.captures[0])!
        guard player.sampleRate == expected else {
            throw StepError.assertion(
                "Expected sample rate \(expected), got \(player.sampleRate)"
            )
        }
    }

    /// Then the reported channel count is <N>
    let reportedChannels = StepDefinition.then(
        #"the reported channel count is (\d+)"#
    ) { match in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        let expected = Int(match.captures[0])!
        guard player.channels == expected else {
            throw StepError.assertion(
                "Expected \(expected) channel(s), got \(player.channels)"
            )
        }
    }

    /// Then the playback position is 0
    let positionIsZero = StepDefinition.then(
        #"the playback position is 0$"#
    ) { _ in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        guard player.currentTime < 0.05 else {
            throw StepError.assertion(
                "Expected position ~0, got \(player.currentTime)"
            )
        }
    }

    /// Then the playback position is approximately <N> seconds
    let positionApprox = StepDefinition.then(
        #"the playback position is approximately ([0-9.]+) seconds"#
    ) { match in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        let expected = Double(match.captures[0])!
        let tolerance = 0.5
        let diff = abs(player.currentTime - expected)
        guard diff <= tolerance else {
            throw StepError.assertion(
                "Expected position ~\(expected)s, got \(player.currentTime)s (tolerance \(tolerance)s)"
            )
        }
    }

    /// Then the volume is <N>
    let volumeIs = StepDefinition.then(
        #"the volume is ([0-9.]+)"#
    ) { match in
        guard let player = TestContext.shared.player else {
            throw StepError.assertion("No player active")
        }
        let expected = Float(match.captures[0])!
        let tolerance: Float = 0.01
        guard abs(player.volume - expected) <= tolerance else {
            throw StepError.assertion(
                "Expected volume \(expected), got \(player.volume)"
            )
        }
    }

    /// Then the playback fails with an error
    let playbackFails = StepDefinition.then(
        #"the playback fails with an error"#
    ) { _ in
        guard TestContext.shared.playbackError != nil else {
            throw StepError.assertion("Expected playback to fail with an error, but it succeeded")
        }
    }
}

// MARK: - Helpers

private func parsePlaybackState(_ str: String) -> PlaybackState {
    switch str.lowercased() {
    case "idle": return .idle
    case "playing": return .playing
    case "paused": return .paused
    case "stopped": return .stopped
    case "completed": return .completed
    default: fatalError("Unknown playback state: \(str)")
    }
}

/// Sleep helper that avoids Swift 6's async context restriction on Thread.sleep.
@inline(never)
private nonisolated func sleepBriefly(_ seconds: TimeInterval) {
    usleep(UInt32(seconds * 1_000_000))
}
