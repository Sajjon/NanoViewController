// MIT License — Copyright (c) 2018-2026 Open Zesame

import Combine
@testable import NanoViewControllerCombine
import XCTest

/// Tests for `Publisher.sinkOnMain` — the Sendable-aware sink that hops
/// values onto the `@MainActor` `receiveValue` closure via a caller-supplied
/// schedule. Covers the three relevant axes:
///
///   * the `@MainActor` typing of the schedule's inner block (compile-time
///     enforcement that a custom schedule has to invoke its block from a
///     main-actor context),
///   * synchronous delivery via a custom schedule (the test-double pattern
///     documented on `sinkOnMain`),
///   * default-schedule asynchronous delivery hopping via
///     `DispatchQueue.main.async`.
@MainActor
final class SinkOnMainTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Custom synchronous schedule

    func test_customSchedule_invokesBlock_synchronously() {
        // A schedule that runs the block immediately. The test runs on
        // `@MainActor` (class-level annotation), so `assumeIsolated` succeeds.
        let subject = PassthroughSubject<Int, Never>()
        var received: [Int] = []

        subject
            .sinkOnMain(schedule: { block in
                MainActor.assumeIsolated { block() }
            }) { value in
                received.append(value)
            }
            .store(in: &cancellables)

        subject.send(1)
        subject.send(2)
        subject.send(3)

        // No runloop pump needed — synchronous schedule delivered all three.
        XCTAssertEqual(received, [1, 2, 3])
    }

    // MARK: - Default async schedule

    func test_defaultSchedule_deliversValues_afterRunloopPump() {
        let subject = PassthroughSubject<String, Never>()
        var received: [String] = []
        let expectation = expectation(description: "delivered")

        subject
            .sinkOnMain { value in
                received.append(value)
                if received.count == 2 { expectation.fulfill() }
            }
            .store(in: &cancellables)

        subject.send("a")
        subject.send("b")

        // Default schedule is `DispatchQueue.main.async` — values arrive
        // on a later runloop tick, not synchronously.
        XCTAssertEqual(received, [])
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received, ["a", "b"])
    }

    // MARK: - Cancellation

    func test_cancellation_stops_furtherDelivery() {
        let subject = PassthroughSubject<Int, Never>()
        var received: [Int] = []

        let cancellable = subject.sinkOnMain(schedule: { block in
            MainActor.assumeIsolated { block() }
        }) { value in
            received.append(value)
        }

        subject.send(1)
        cancellable.cancel()
        subject.send(2)

        XCTAssertEqual(received, [1])
    }
}
