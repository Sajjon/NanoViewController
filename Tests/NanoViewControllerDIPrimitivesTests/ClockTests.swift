// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

@testable import NanoViewControllerDIPrimitives
import XCTest

/// Tests for `MainQueueClock` — the production `Clock` impl backed by a
/// `@MainActor` `Task` + `Task.sleep`. Verifies the cancellation semantics
/// of the refactored API: cancelling the returned `Task` must skip the
/// scheduled block.
@MainActor
final class ClockTests: XCTestCase {
    func test_schedule_firesBlock_afterDelay() async throws {
        let clock = MainQueueClock()
        var fired = false

        let task = clock.schedule(after: 0.05) {
            fired = true
        }

        // Wait long enough for the sleep + block to fire.
        try await Task.sleep(for: .milliseconds(150))
        _ = task

        XCTAssertTrue(fired)
    }

    func test_cancelledTask_doesNot_fireBlock() async throws {
        let clock = MainQueueClock()
        var fired = false

        let task = clock.schedule(after: 0.1) {
            fired = true
        }

        // Cancel before the sleep completes.
        task.cancel()

        // Wait past the original deadline; the block must NOT have fired.
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(fired, "Cancelled task must not invoke its block")
    }

    func test_multipleSchedules_fireIndependently() async throws {
        let clock = MainQueueClock()
        var counter = 0

        _ = clock.schedule(after: 0.02) { counter += 1 }
        _ = clock.schedule(after: 0.04) { counter += 1 }
        _ = clock.schedule(after: 0.06) { counter += 1 }

        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(counter, 3)
    }

    func test_cancelOneTask_doesNotAffect_others() async throws {
        let clock = MainQueueClock()
        var firstFired = false
        var secondFired = false

        let first = clock.schedule(after: 0.05) { firstFired = true }
        _ = clock.schedule(after: 0.05) { secondFired = true }

        first.cancel()

        try await Task.sleep(for: .milliseconds(150))

        XCTAssertFalse(firstFired)
        XCTAssertTrue(secondFired)
    }
}
