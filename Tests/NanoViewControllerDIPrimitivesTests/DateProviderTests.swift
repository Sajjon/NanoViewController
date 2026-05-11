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

    func test_now_advancesMonotonically() async throws {
        let provider = DefaultDateProvider()
        let first = provider.now()
        try await Task.sleep(for: .milliseconds(20))
        let second = provider.now()

        XCTAssertGreaterThan(second, first)
    }
}
