// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
@testable import NanoViewControllerCore
import XCTest

/// Tests that `ErrorTracker` republishes failures from tracked publishers and
/// exposes them through `asPublisher()` for downstream subscribers.
final class ErrorTrackerTests: XCTestCase {
    private enum TestError: Error { case boom }

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func test_asPublisher_emitsErrorFromTrackedFailure() {
        // ARRANGE
        let tracker = ErrorTracker()
        var emitted: Error?
        tracker.asPublisher().sink { emitted = $0 }.store(in: &cancellables)

        // ACT
        Fail<Void, TestError>(error: .boom)
            .trackError(tracker)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // ASSERT
        XCTAssertNotNil(emitted)
    }

    func test_track_passesThroughSuccessfulValues() {
        // ARRANGE
        let tracker = ErrorTracker()
        var received: [Int] = []

        // ACT
        Just(42)
            .setFailureType(to: TestError.self)
            .trackError(tracker)
            .sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
            .store(in: &cancellables)

        // ASSERT
        XCTAssertEqual(received, [42])
    }
}
