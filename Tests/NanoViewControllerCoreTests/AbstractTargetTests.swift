// MIT License — Copyright (c) 2018-2026 Alexander Cyon - https://github.com/sajjon

import Combine
@testable import NanoViewControllerCore
import XCTest

/// Tests `AbstractTarget` — the `@objc` target/action bridge that turns a
/// UIKit selector callback into a Combine pulse on the captured subject.
@MainActor
final class AbstractTargetTests: XCTestCase {
    func test_pressed_forwardsEventToTriggerSubject() {
        // ARRANGE
        let subject = PassthroughSubject<Void, Never>()
        let sut = AbstractTarget(triggerSubject: subject)
        var received = 0
        let cancellable = subject.sink { received += 1 }

        // ACT
        sut.pressed()
        sut.pressed()

        // ASSERT
        XCTAssertEqual(received, 2)
        cancellable.cancel()
    }
}
