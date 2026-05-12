// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import XCTest

/// Covers the `receive(completion:)` branch of the inner subscription inside
/// `WithLatestFromPublisher` — i.e. completion of the upstream forwards a
/// completion to the downstream and tears the subscription down.
final class WithLatestFromCompletionTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func test_upstreamCompletion_isForwardedDownstream() {
        // ARRANGE
        let upstream = PassthroughSubject<Void, Never>()
        let other = CurrentValueSubject<Int, Never>(0)
        var completed = false
        upstream
            .withLatestFrom(other)
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        // ACT
        upstream.send(completion: .finished)

        // ASSERT
        XCTAssertTrue(completed)
    }
}
