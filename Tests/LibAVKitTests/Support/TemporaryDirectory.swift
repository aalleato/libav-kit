import Foundation

/// A temporary directory that cleans itself up when deallocated.
///
/// Swift Testing creates a fresh suite instance per test, so each test gets its own isolated directory.
final class TemporaryDirectory: @unchecked Sendable {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("libav-kit-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
