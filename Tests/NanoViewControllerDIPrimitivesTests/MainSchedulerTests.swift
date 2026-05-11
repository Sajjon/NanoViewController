// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

@testable import NanoViewControllerDIPrimitives
import XCTest

/// Tests for the two production `MainScheduler` impls:
///
///   * ``ImmediateMainScheduler`` — runs `work` synchronously on the calling
///     main-actor context. Used by tests so navigation pulses can be asserted
///     on the next line.
///   * ``DispatchMainScheduler`` — hops `work` onto a fresh `@MainActor`
///     `Task`, so callers must not assume the work has finished by the time
///     `schedule(_:)` returns.
@MainActor
final class MainSchedulerTests: XCTestCase {
    // MARK: - ImmediateMainScheduler

    func test_immediate_runsBlockSynchronously() {
        let scheduler = ImmediateMainScheduler()
        var ran = false

        scheduler.schedule { ran = true }

        XCTAssertTrue(ran, "ImmediateMainScheduler must invoke work before schedule(_:) returns")
    }

    func test_immediate_runsBlocksInOrder() {
        let scheduler = ImmediateMainScheduler()
        var calls: [Int] = []

        scheduler.schedule { calls.append(1) }
        scheduler.schedule { calls.append(2) }
        scheduler.schedule { calls.append(3) }

        XCTAssertEqual(calls, [1, 2, 3])
    }

    // MARK: - DispatchMainScheduler

    func test_dispatch_eventuallyRunsBlockOnMainActor() async {
        let scheduler = DispatchMainScheduler()
        let expectation = expectation(description: "block ran on main actor")
        var ran = false

        scheduler.schedule {
            ran = true
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(ran)
    }

    func test_dispatch_returnsBeforeBlockRuns() {
        // The production impl wraps `work` in a `Task { @MainActor in … }`,
        // so on the calling main-actor turn the block has not yet run.
        let scheduler = DispatchMainScheduler()
        var ran = false

        scheduler.schedule { ran = true }

        XCTAssertFalse(ran, "DispatchMainScheduler must defer work until the next main-actor cycle")
    }
}
