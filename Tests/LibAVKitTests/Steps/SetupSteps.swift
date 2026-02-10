import Foundation
import LibAVKit
import PickleKit

/// Given steps — set up test fixtures and context.
struct SetupSteps: StepDefinitions {
    init() {
        TestContext.shared.reset()
        TestContext.shared.tempDir = try? TemporaryDirectory()
        TestContext.shared.fixtureDir = Bundle.module.resourceURL?
            .appendingPathComponent("Fixtures/Parametric")
    }

    // MARK: - Audio file setup

    /// Given a "<codec>" file at "<source_fixture>"
    let givenSourceFile = StepDefinition.given(
        #"a "([^"]+)" file at "([^"]+)""#
    ) { match in
        let relativePath = match.captures[1]
        let ctx = TestContext.shared

        guard let fixtureDir = ctx.fixtureDir else {
            throw StepError.missingFixture("Fixture directory not found in bundle")
        }
        guard let tempDir = ctx.tempDir else {
            throw StepError.missingFixture("Temporary directory not created")
        }

        let sourceURL = fixtureDir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw StepError.missingFixture("Fixture not found: \(relativePath)")
        }

        // Copy to temp dir so we don't modify the original
        let fileName = sourceURL.lastPathComponent
        let workingCopy = tempDir.url.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension)
        // Use UUID to avoid collisions when same fixture used in embed+remove
        try FileManager.default.copyItem(at: sourceURL, to: workingCopy)

        ctx.workingCopy = workingCopy
    }

    // MARK: - Cover art setup

    /// Given a cover art image at "<filename>"
    let givenCoverArt = StepDefinition.given(
        #"a cover art image at "([^"]+)""#
    ) { match in
        let filename = match.captures[0]
        let ctx = TestContext.shared

        guard let fixtureURL = Bundle.module.resourceURL?
            .appendingPathComponent("Fixtures/\(filename)") else {
            throw StepError.missingFixture("Cover art fixture directory not found")
        }

        ctx.coverArtData = try Data(contentsOf: fixtureURL)
    }

    // MARK: - Error path setup

    /// Given a non-existent file at "<path>"
    let givenNonExistentFile = StepDefinition.given(
        #"a non-existent file at "([^"]+)""#
    ) { match in
        let path = match.captures[0]
        TestContext.shared.workingCopy = URL(fileURLWithPath: path)
    }
}

enum StepError: Error, CustomStringConvertible {
    case missingFixture(String)
    case assertion(String)

    var description: String {
        switch self {
        case let .missingFixture(msg): "Missing fixture: \(msg)"
        case let .assertion(msg): "Assertion failed: \(msg)"
        }
    }
}
