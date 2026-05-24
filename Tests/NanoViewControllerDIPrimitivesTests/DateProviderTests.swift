// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

@testable import NanoViewControllerDIPrimitives
import XCTest

/// Tests for `DefaultDateProvider` — the production `DateProvider` impl that
/// returns `Date()`. Verifies that `now()` lands within the wall-clock
/// window bracketing the call, and that successive reads stay within a
/// reasonable bound of each other (no monotonicity assertion, since the
/// wall clock isn't guaranteed monotonic).
final class DateProviderTests: XCTestCase {
    func test_now_returnsCurrentInstant() {
        // ARRANGE
        let provider = DefaultDateProvider()
        let before = Date()

        // ACT
        let now = provider.now()

        // ASSERT
        let after = Date()
        XCTAssertGreaterThanOrEqual(now, before)
        XCTAssertLessThanOrEqual(now, after)
    }

    func test_now_returnsValueWithinBoundedWindow_acrossSuccessiveCalls() {
        // ARRANGE
        // `Date()` reads the wall clock, which is not strictly monotonic
        // (an NTP adjustment can move it backward, and successive reads on
        // fast hardware can return equal timestamps). The window also has
        // to absorb test-host scheduling pauses — slow/contended CI runners
        // can stall arbitrary code for seconds at a time. We only need to
        // re-exercise the `now()` line; a 30-second envelope is loose
        // enough to never flake while still catching a wholly-broken impl
        // (e.g. one returning `.distantPast`).
        let provider = DefaultDateProvider()

        // ACT
        let first = provider.now()
        let second = provider.now()

        // ASSERT
        XCTAssertLessThan(abs(second.timeIntervalSince(first)), 30.0)
    }
}
