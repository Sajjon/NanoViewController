// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
@testable import NanoViewControllerCore
import XCTest

/// Tests `ActivityIndicator` — the in-flight tracker exposed via
/// `Publisher.trackActivity(_:)`. Verifies the four lifecycle pulses
/// (subscribe → output → completion → cancel) flip the indicator true/false
/// as documented, beyond the bare initial-`false` smoke test.
final class ActivityIndicatorTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func test_subscribingToTracked_setsIndicatorTrue() {
        // ARRANGE
        let indicator = ActivityIndicator()
        let upstream = PassthroughSubject<Int, Never>()
        var received: [Bool] = []
        indicator.asPublisher().sink { received.append($0) }.store(in: &cancellables)

        // ACT
        upstream.trackActivity(indicator)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, [false, true])
    }

    func test_emittingValue_setsIndicatorFalse() {
        // ARRANGE
        let indicator = ActivityIndicator()
        let upstream = PassthroughSubject<Int, Never>()
        var received: [Bool] = []
        indicator.asPublisher().sink { received.append($0) }.store(in: &cancellables)
        upstream.trackActivity(indicator)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // ACT
        upstream.send(1)

        // ASSERT
        XCTAssertEqual(received, [false, true, false])
    }

    func test_completion_setsIndicatorFalse() {
        // ARRANGE
        let indicator = ActivityIndicator()
        let upstream = PassthroughSubject<Int, Never>()
        var received: [Bool] = []
        indicator.asPublisher().sink { received.append($0) }.store(in: &cancellables)
        upstream.trackActivity(indicator)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // ACT
        upstream.send(completion: .finished)

        // ASSERT
        XCTAssertEqual(received, [false, true, false])
    }

    func test_cancellation_setsIndicatorFalse() {
        // ARRANGE
        let indicator = ActivityIndicator()
        let upstream = PassthroughSubject<Int, Never>()
        var received: [Bool] = []
        indicator.asPublisher().sink { received.append($0) }.store(in: &cancellables)
        let trackedCancellable = upstream.trackActivity(indicator)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        // ACT
        trackedCancellable.cancel()

        // ASSERT
        XCTAssertEqual(received, [false, true, false])
    }
}
