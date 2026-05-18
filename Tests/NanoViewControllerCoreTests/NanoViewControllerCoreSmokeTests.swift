// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCore
import XCTest

/// Smoke tests for the Phase 1 set of Core types. Covers the protocols and
/// the helpers that have no UIKit/Combine dependency surface beyond what's
/// already in Core. Richer tests migrate from the Zhip target in Phase 7.
final class NanoViewControllerCoreSmokeTests: XCTestCase {
    @MainActor
    func test_emptyInitializable_canSpinUpInstance() {
        // ARRANGE
        struct Foo: EmptyInitializable {
            var marker = "spun"
        }

        // ACT
        let foo = Foo()

        // ASSERT
        XCTAssertEqual(foo.marker, "spun")
    }

    func test_activityIndicator_emitsFalseOnSubscribe() {
        // ARRANGE
        let indicator = ActivityIndicator()
        var received: [Bool] = []

        // ACT
        let cancellable = indicator.asPublisher().sink { received.append($0) }

        // ASSERT
        XCTAssertEqual(received, [false])
        cancellable.cancel()
    }

    func test_errorTracker_capturesFailures() {
        // ARRANGE
        let tracker = ErrorTracker()
        var captured: [Error] = []
        let trackerCancellable = tracker.asPublisher().sink { captured.append($0) }

        // ACT
        struct StubError: Swift.Error {}
        let upstream = Fail<Int, Swift.Error>(error: StubError())
        let pipelineCancellable = tracker.track(from: upstream).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        // ASSERT
        XCTAssertEqual(captured.count, 1)
        trackerCancellable.cancel()
        pipelineCancellable.cancel()
    }

    @MainActor
    func test_output_designatedInitializerDefaultsToEmptySubscriptions() {
        // ACT
        let output = Output(
            publishers: "publishers",
            navigation: Empty<Int, Never>().eraseToAnyPublisher()
        )

        // ASSERT
        XCTAssertEqual(output.publishers, "publishers")
        XCTAssertTrue(output.cancellables.isEmpty)
    }
}
