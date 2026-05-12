// MIT License — Copyright (c) 2018-2026 Alexander Cyon (github.com/sajjon)

import Combine
@testable import NanoViewControllerCombine
import UIKit
import XCTest

/// Covers the "control already deallocated when subscribed" branch in
/// `UIControlPublisher.receive(subscriber:)` — the publisher must complete
/// immediately so downstream sinks tear down cleanly instead of waiting on a
/// dangling source.
@MainActor
final class UIControlPublisherDeadControlTests: XCTestCase {
    func test_subscribingAfterControlDeallocated_completesImmediately() {
        // ARRANGE
        var control: UIButton? = UIButton(type: .system)
        let publisher = control!.publisher(for: .touchUpInside)

        // ACT
        // Drop the only strong reference. The publisher holds a `WeakBox`,
        // so the control is collected immediately.
        control = nil
        var completed = false
        var receivedValue = false
        let cancellable = publisher.sink(
            receiveCompletion: { _ in completed = true },
            receiveValue: { _ in receivedValue = true }
        )

        // ASSERT
        XCTAssertTrue(completed, "Dead-control branch must complete the subscription")
        XCTAssertFalse(receivedValue, "No value should be delivered for a dead control")
        cancellable.cancel()
    }
}
