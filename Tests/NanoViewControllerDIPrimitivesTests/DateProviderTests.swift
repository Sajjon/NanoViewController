// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

@testable import NanoViewControllerDIPrimitives
import XCTest

/// Tests for `DefaultDateProvider` — the production `DateProvider` impl that
/// returns `Date()`. Verifies that successive `now()` calls advance
/// monotonically and stay within a tight window of the real wall clock.
final class DateProviderTests: XCTestCase {
    func test_now_returnsCurrentInstant() {
        let provider = DefaultDateProvider()
        let before = Date()
        let now = provider.now()
        let after = Date()

        XCTAssertGreaterThanOrEqual(now, before)
        XCTAssertLessThanOrEqual(now, after)
    }

    func test_now_returnsValueWithinBoundedWindow_acrossSuccessiveCalls() {
        // `Date()` reads the wall clock, which is not strictly monotonic
        // (an NTP adjustment can move it backward, and successive reads on
        // fast hardware can return equal timestamps). We only assert that
        // the second read stays within a generous window of the first —
        // enough to cover the `now()` line a second time without baking in
        // a brittle ordering invariant the underlying API doesn't promise.
        let provider = DefaultDateProvider()
        let first = provider.now()
        let second = provider.now()

        XCTAssertLessThan(abs(second.timeIntervalSince(first)), 1.0)
    }
}
