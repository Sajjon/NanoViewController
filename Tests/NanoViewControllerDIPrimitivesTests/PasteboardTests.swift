// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Foundation
@testable import NanoViewControllerDIPrimitives
import XCTest

/// Tests for the `Pasteboard` protocol's extension overload `copy(_:)`.
///
/// We deliberately do NOT exercise `DefaultPasteboard` against
/// `UIPasteboard.general` — touching the live system pasteboard from unit
/// tests is flaky and slow on the simulator (and the whole point of the
/// abstraction is that consumers inject mocks, so chasing line-coverage on
/// the trivial production wrapper by mutating the singleton defeats the
/// purpose).
@MainActor
final class PasteboardTests: XCTestCase {
    /// Mock conformer that records every `copy(_:expiringAfter:)` invocation,
    /// so we can verify the protocol-extension overload forwards correctly.
    private final class RecordingPasteboard: Pasteboard {
        private(set) var copies: [(value: String, expiringAfter: TimeInterval?)] = []
        func copy(_ string: String, expiringAfter: TimeInterval?) {
            copies.append((string, expiringAfter))
        }
    }

    func test_copyExtensionOverload_forwardsWithNilExpiration() {
        // ARRANGE
        let pasteboard = RecordingPasteboard()

        // ACT
        pasteboard.copy("hello")

        // ASSERT
        XCTAssertEqual(pasteboard.copies.count, 1)
        XCTAssertEqual(pasteboard.copies.first?.value, "hello")
        XCTAssertNil(pasteboard.copies.first?.expiringAfter)
    }
}
